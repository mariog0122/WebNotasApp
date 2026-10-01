-- ====================================================================
-- MIGRATION: 29_p1_atomic_supplementary_scores.sql
-- PURPOSE: Make final supplementary-score changes atomic and guarded.
-- ====================================================================

CREATE OR REPLACE FUNCTION public.save_supplementary_batch(
  p_upserts jsonb DEFAULT '[]'::jsonb,
  p_deletes jsonb DEFAULT '[]'::jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_upsert_count integer;
  v_delete_count integer;
  v_valid_count integer;
  v_school_id uuid;
  v_first_student_id uuid;
  v_first_course_subject_id uuid;
  v_upserted integer := 0;
  v_deleted integer := 0;
BEGIN
  IF jsonb_typeof(p_upserts) IS DISTINCT FROM 'array'
     OR jsonb_typeof(p_deletes) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'INVALID_SUPPLEMENTARY_BATCH' USING ERRCODE = '22023';
  END IF;

  v_upsert_count := jsonb_array_length(p_upserts);
  v_delete_count := jsonb_array_length(p_deletes);
  IF v_upsert_count + v_delete_count > 10000 THEN
    RAISE EXCEPTION 'SUPPLEMENTARY_BATCH_TOO_LARGE' USING ERRCODE = '22023';
  END IF;
  IF v_upsert_count + v_delete_count = 0 THEN
    RETURN json_build_object('success', true, 'upserted', 0, 'deleted', 0);
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_upserts)
      AS item(student_id uuid, course_subject_id uuid, score numeric)
    WHERE item.score IS NULL OR item.score < 0 OR item.score > 10
  ) THEN
    RAISE EXCEPTION 'SUPPLEMENTARY_SCORE_OUT_OF_RANGE' USING ERRCODE = '22003';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_upserts)
      AS item(student_id uuid, course_subject_id uuid, score numeric)
    GROUP BY item.student_id, item.course_subject_id
    HAVING count(*) > 1
  ) OR EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_deletes)
      AS item(student_id uuid, course_subject_id uuid)
    GROUP BY item.student_id, item.course_subject_id
    HAVING count(*) > 1
  ) OR EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_upserts)
      AS added(student_id uuid, course_subject_id uuid, score numeric)
    JOIN jsonb_to_recordset(p_deletes)
      AS removed(student_id uuid, course_subject_id uuid)
      USING (student_id, course_subject_id)
  ) THEN
    RAISE EXCEPTION 'DUPLICATE_SUPPLEMENTARY_TARGET' USING ERRCODE = '23505';
  END IF;

  SELECT first_item.student_id, first_item.course_subject_id
  INTO v_first_student_id, v_first_course_subject_id
  FROM (
    SELECT item.student_id, item.course_subject_id, 1 AS priority
    FROM jsonb_to_recordset(p_upserts)
      AS item(student_id uuid, course_subject_id uuid, score numeric)
    UNION ALL
    SELECT item.student_id, item.course_subject_id, 2 AS priority
    FROM jsonb_to_recordset(p_deletes)
      AS item(student_id uuid, course_subject_id uuid)
  ) first_item
  ORDER BY first_item.priority
  LIMIT 1;

  SELECT student.school_id
  INTO v_school_id
  FROM public.students student
  JOIN public.course_subjects course_subject
    ON course_subject.id = v_first_course_subject_id
   AND course_subject.course_id = student.course_id
   AND course_subject.school_id = student.school_id
  WHERE student.id = v_first_student_id;

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_SUPPLEMENTARY_TARGET' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_platform_admin() AND (
    v_school_id IS DISTINCT FROM public.get_user_school_id()
    OR NOT public.has_tenant_permission('grades.update')
    OR NOT public.has_tenant_permission('settings.manage')
  ) THEN
    RAISE EXCEPTION 'SUPPLEMENTARY_WRITE_FORBIDDEN' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_valid_count
  FROM jsonb_to_recordset(p_upserts)
    AS item(student_id uuid, course_subject_id uuid, score numeric)
  JOIN public.students student ON student.id = item.student_id
  JOIN public.course_subjects course_subject
    ON course_subject.id = item.course_subject_id
   AND course_subject.course_id = student.course_id
   AND course_subject.school_id = student.school_id
  WHERE student.school_id = v_school_id;
  IF v_valid_count <> v_upsert_count THEN
    RAISE EXCEPTION 'INVALID_SUPPLEMENTARY_TARGET' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_valid_count
  FROM jsonb_to_recordset(p_deletes)
    AS item(student_id uuid, course_subject_id uuid)
  JOIN public.students student ON student.id = item.student_id
  JOIN public.course_subjects course_subject
    ON course_subject.id = item.course_subject_id
   AND course_subject.course_id = student.course_id
   AND course_subject.school_id = student.school_id
  WHERE student.school_id = v_school_id;
  IF v_valid_count <> v_delete_count THEN
    RAISE EXCEPTION 'INVALID_SUPPLEMENTARY_TARGET' USING ERRCODE = '42501';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('supplementary:' || v_school_id::text, 0));

  DELETE FROM public.supplementary_exams exam
  USING jsonb_to_recordset(p_deletes)
    AS item(student_id uuid, course_subject_id uuid)
  WHERE exam.student_id = item.student_id
    AND exam.course_subject_id = item.course_subject_id;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  INSERT INTO public.supplementary_exams (
    student_id, course_subject_id, score, updated_at
  )
  SELECT item.student_id, item.course_subject_id, item.score, timezone('utc'::text, now())
  FROM jsonb_to_recordset(p_upserts)
    AS item(student_id uuid, course_subject_id uuid, score numeric)
  ON CONFLICT (student_id, course_subject_id) DO UPDATE
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

REVOKE INSERT, UPDATE, DELETE ON public.supplementary_exams FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.save_supplementary_batch(jsonb, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_supplementary_batch(jsonb, jsonb) TO authenticated;
