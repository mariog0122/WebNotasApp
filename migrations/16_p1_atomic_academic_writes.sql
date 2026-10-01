-- ====================================================================
-- MIGRATION: 16_p1_atomic_academic_writes.sql
-- PURPOSE: Transactional student imports and grade batch persistence.
-- ====================================================================

CREATE OR REPLACE FUNCTION public.import_students_batch(
  p_course_id uuid,
  p_entries jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_school_id uuid;
  v_entry_count integer;
  v_new_count integer;
  v_current_count integer;
  v_limit integer;
  v_inserted integer := 0;
  v_updated integer := 0;
BEGIN
  IF jsonb_typeof(p_entries) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'INVALID_STUDENT_BATCH' USING ERRCODE = '22023';
  END IF;

  v_entry_count := jsonb_array_length(p_entries);
  IF v_entry_count < 1 OR v_entry_count > 5000 THEN
    RAISE EXCEPTION 'STUDENT_BATCH_SIZE_INVALID' USING ERRCODE = '22023';
  END IF;

  SELECT c.school_id INTO v_school_id
  FROM public.courses c
  WHERE c.id = p_course_id;

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'COURSE_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_platform_admin() AND (
    v_school_id IS DISTINCT FROM public.get_user_school_id()
    OR NOT public.has_tenant_permission('students.create')
    OR NOT public.has_tenant_permission('students.update')
  ) THEN
    RAISE EXCEPTION 'STUDENT_IMPORT_FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_entries) AS x(full_name text, student_cedula text)
    WHERE nullif(trim(x.full_name), '') IS NULL
      OR length(trim(x.full_name)) > 200
      OR length(COALESCE(trim(x.student_cedula), '')) > 30
  ) THEN
    RAISE EXCEPTION 'INVALID_STUDENT_ROW' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_entries) AS x(full_name text, student_cedula text)
    WHERE nullif(trim(x.student_cedula), '') IS NOT NULL
    GROUP BY trim(x.student_cedula)
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'DUPLICATE_STUDENT_CEDULA_IN_BATCH' USING ERRCODE = '23505';
  END IF;

  -- Use the same tenant lock as the row trigger to make the capacity check atomic.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_school_id::text, 0));

  SELECT count(*) INTO v_new_count
  FROM jsonb_to_recordset(p_entries) AS x(full_name text, student_cedula text)
  WHERE nullif(trim(x.student_cedula), '') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.students s
       WHERE s.school_id = v_school_id
         AND s.course_id = p_course_id
         AND s.student_cedula = trim(x.student_cedula)
     );

  SELECT count(*) INTO v_current_count
  FROM public.students
  WHERE school_id = v_school_id;

  SELECT max_students INTO v_limit
  FROM public.tenant_limits
  WHERE school_id = v_school_id;

  IF v_limit IS NULL THEN
    RAISE EXCEPTION 'SUBSCRIPTION_LIMIT_REQUIRED' USING ERRCODE = 'P0001';
  END IF;
  IF v_current_count + v_new_count > v_limit THEN
    RAISE EXCEPTION 'STUDENT_LIMIT_REACHED: current %, requested %, limit %',
      v_current_count, v_new_count, v_limit USING ERRCODE = 'P0001';
  END IF;

  WITH input AS (
    SELECT trim(x.full_name) AS full_name,
           nullif(trim(x.student_cedula), '') AS student_cedula
    FROM jsonb_to_recordset(p_entries) AS x(full_name text, student_cedula text)
  )
  UPDATE public.students s
  SET full_name = i.full_name
  FROM input i
  WHERE s.school_id = v_school_id
    AND s.course_id = p_course_id
    AND i.student_cedula IS NOT NULL
    AND s.student_cedula = i.student_cedula;
  GET DIAGNOSTICS v_updated = ROW_COUNT;

  WITH input AS (
    SELECT trim(x.full_name) AS full_name,
           nullif(trim(x.student_cedula), '') AS student_cedula
    FROM jsonb_to_recordset(p_entries) AS x(full_name text, student_cedula text)
  )
  INSERT INTO public.students (
    full_name, student_cedula, course_id, school_id, created_by
  )
  SELECT i.full_name, i.student_cedula, p_course_id, v_school_id, auth.uid()
  FROM input i
  WHERE i.student_cedula IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.students s
       WHERE s.school_id = v_school_id
         AND s.course_id = p_course_id
         AND s.student_cedula = i.student_cedula
     );
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN json_build_object(
    'success', true,
    'inserted', v_inserted,
    'updated', v_updated,
    'total', v_entry_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.save_grade_batch(
  p_upserts jsonb DEFAULT '[]'::jsonb,
  p_deletes jsonb DEFAULT '[]'::jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_school_id uuid;
  v_upsert_count integer;
  v_delete_count integer;
  v_valid_count integer;
  v_upserted integer := 0;
  v_deleted integer := 0;
  v_first_student_id uuid;
BEGIN
  IF jsonb_typeof(p_upserts) IS DISTINCT FROM 'array'
     OR jsonb_typeof(p_deletes) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'INVALID_GRADE_BATCH' USING ERRCODE = '22023';
  END IF;

  v_upsert_count := jsonb_array_length(p_upserts);
  v_delete_count := jsonb_array_length(p_deletes);
  IF v_upsert_count + v_delete_count > 10000 THEN
    RAISE EXCEPTION 'GRADE_BATCH_TOO_LARGE' USING ERRCODE = '22023';
  END IF;
  IF v_upsert_count + v_delete_count = 0 THEN
    RETURN json_build_object('success', true, 'upserted', 0, 'deleted', 0);
  END IF;

  v_first_student_id := COALESCE(
    (p_upserts->0->>'student_id')::uuid,
    (p_deletes->0->>'student_id')::uuid
  );
  SELECT school_id INTO v_school_id FROM public.students WHERE id = v_first_student_id;

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'GRADE_STUDENT_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  IF NOT public.is_platform_admin() AND (
    v_school_id IS DISTINCT FROM public.get_user_school_id()
    OR NOT public.has_tenant_permission('grades.update')
  ) THEN
    RAISE EXCEPTION 'GRADE_WRITE_FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_upserts)
      AS x(student_id uuid, grade_definition_id uuid, score numeric)
    WHERE x.score IS NULL OR x.score < 0 OR x.score > 10
  ) THEN
    RAISE EXCEPTION 'GRADE_SCORE_OUT_OF_RANGE' USING ERRCODE = '22003';
  END IF;

  SELECT count(*) INTO v_valid_count
  FROM jsonb_to_recordset(p_upserts)
    AS x(student_id uuid, grade_definition_id uuid, score numeric)
  JOIN public.students st ON st.id = x.student_id
  JOIN public.grade_definitions gd ON gd.id = x.grade_definition_id
  JOIN public.course_subjects cs ON cs.id = gd.course_subject_id
  JOIN public.quarters q ON q.id = gd.quarter_id
  WHERE st.school_id = v_school_id
    AND gd.school_id = v_school_id
    AND cs.school_id = v_school_id
    AND q.school_id = v_school_id
    AND st.course_id = cs.course_id
    AND NOT COALESCE(q.is_locked, false);

  IF v_valid_count <> v_upsert_count THEN
    RAISE EXCEPTION 'INVALID_OR_LOCKED_GRADE_TARGET' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_valid_count
  FROM jsonb_to_recordset(p_deletes)
    AS x(student_id uuid, grade_definition_id uuid)
  JOIN public.students st ON st.id = x.student_id
  JOIN public.grade_definitions gd ON gd.id = x.grade_definition_id
  JOIN public.course_subjects cs ON cs.id = gd.course_subject_id
  JOIN public.quarters q ON q.id = gd.quarter_id
  WHERE st.school_id = v_school_id
    AND gd.school_id = v_school_id
    AND cs.school_id = v_school_id
    AND q.school_id = v_school_id
    AND st.course_id = cs.course_id
    AND NOT COALESCE(q.is_locked, false);

  IF v_valid_count <> v_delete_count THEN
    RAISE EXCEPTION 'INVALID_OR_LOCKED_GRADE_TARGET' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.grades g
  USING jsonb_to_recordset(p_deletes)
    AS x(student_id uuid, grade_definition_id uuid)
  WHERE g.student_id = x.student_id
    AND g.grade_definition_id = x.grade_definition_id;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  INSERT INTO public.grades (student_id, grade_definition_id, score, updated_at)
  SELECT x.student_id, x.grade_definition_id, x.score, timezone('utc'::text, now())
  FROM jsonb_to_recordset(p_upserts)
    AS x(student_id uuid, grade_definition_id uuid, score numeric)
  ON CONFLICT (student_id, grade_definition_id) DO UPDATE
  SET score = EXCLUDED.score,
      updated_at = timezone('utc'::text, now());
  GET DIAGNOSTICS v_upserted = ROW_COUNT;

  RETURN json_build_object(
    'success', true,
    'upserted', v_upserted,
    'deleted', v_deleted
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.save_qualitative_grade_batch(
  p_course_subject_id uuid,
  p_quarter_id uuid,
  p_upserts jsonb DEFAULT '[]'::jsonb,
  p_delete_student_ids jsonb DEFAULT '[]'::jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_school_id uuid;
  v_course_id uuid;
  v_upsert_count integer;
  v_delete_count integer;
  v_valid_count integer;
  v_upserted integer := 0;
  v_deleted integer := 0;
BEGIN
  IF jsonb_typeof(p_upserts) IS DISTINCT FROM 'array'
     OR jsonb_typeof(p_delete_student_ids) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'INVALID_QUALITATIVE_GRADE_BATCH' USING ERRCODE = '22023';
  END IF;

  v_upsert_count := jsonb_array_length(p_upserts);
  v_delete_count := jsonb_array_length(p_delete_student_ids);
  IF v_upsert_count + v_delete_count > 10000 THEN
    RAISE EXCEPTION 'GRADE_BATCH_TOO_LARGE' USING ERRCODE = '22023';
  END IF;

  SELECT cs.school_id, cs.course_id INTO v_school_id, v_course_id
  FROM public.course_subjects cs
  JOIN public.quarters q ON q.id = p_quarter_id
  WHERE cs.id = p_course_subject_id
    AND q.school_id = cs.school_id
    AND NOT COALESCE(q.is_locked, false);

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_OR_LOCKED_QUALITATIVE_TARGET' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_platform_admin() AND (
    v_school_id IS DISTINCT FROM public.get_user_school_id()
    OR NOT public.has_tenant_permission('grades.update')
  ) THEN
    RAISE EXCEPTION 'GRADE_WRITE_FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_upserts) AS x(student_id uuid, score_text text)
    WHERE x.score_text NOT IN ('A+', 'A-', 'B+', 'B-', 'C+', 'C-', 'D+', 'D-', 'E+', 'E-')
  ) THEN
    RAISE EXCEPTION 'INVALID_QUALITATIVE_SCORE' USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_valid_count
  FROM jsonb_to_recordset(p_upserts) AS x(student_id uuid, score_text text)
  JOIN public.students st ON st.id = x.student_id
  WHERE st.school_id = v_school_id AND st.course_id = v_course_id;
  IF v_valid_count <> v_upsert_count THEN
    RAISE EXCEPTION 'INVALID_QUALITATIVE_STUDENT' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_valid_count
  FROM jsonb_array_elements_text(p_delete_student_ids) d(student_id)
  JOIN public.students st ON st.id = d.student_id::uuid
  WHERE st.school_id = v_school_id AND st.course_id = v_course_id;
  IF v_valid_count <> v_delete_count THEN
    RAISE EXCEPTION 'INVALID_QUALITATIVE_STUDENT' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.qualitative_grades qg
  USING jsonb_array_elements_text(p_delete_student_ids) d(student_id)
  WHERE qg.student_id = d.student_id::uuid
    AND qg.course_subject_id = p_course_subject_id
    AND qg.quarter_id = p_quarter_id;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  INSERT INTO public.qualitative_grades (
    student_id, course_subject_id, quarter_id, score_text
  )
  SELECT x.student_id, p_course_subject_id, p_quarter_id, x.score_text
  FROM jsonb_to_recordset(p_upserts) AS x(student_id uuid, score_text text)
  ON CONFLICT (student_id, course_subject_id, quarter_id) DO UPDATE
  SET score_text = EXCLUDED.score_text;
  GET DIAGNOSTICS v_upserted = ROW_COUNT;

  RETURN json_build_object(
    'success', true,
    'upserted', v_upserted,
    'deleted', v_deleted
  );
END;
$$;

REVOKE ALL ON FUNCTION public.import_students_batch(uuid, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_grade_batch(jsonb, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_qualitative_grade_batch(uuid, uuid, jsonb, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.import_students_batch(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_grade_batch(jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_qualitative_grade_batch(uuid, uuid, jsonb, jsonb) TO authenticated;
