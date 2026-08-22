-- Contract test for migrations/29_p1_atomic_supplementary_scores.sql. Safe: rolls back.
BEGIN;

SELECT set_config(
  'audit.test_actor',
  (SELECT id::text FROM public.profiles ORDER BY created_at LIMIT 1),
  true
);
SELECT set_config('request.jwt.claim.sub', current_setting('audit.test_actor'), true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);

SELECT set_config('audit.test_student', fixture.student_id::text, true),
       set_config('audit.test_course_subject', fixture.course_subject_id::text, true)
FROM (
  SELECT student.id AS student_id, course_subject.id AS course_subject_id
  FROM public.students student
  JOIN public.course_subjects course_subject
    ON course_subject.course_id = student.course_id
   AND course_subject.school_id = student.school_id
  LIMIT 1
) fixture;

DO $$
BEGIN
  IF nullif(current_setting('audit.test_student', true), '') IS NULL THEN
    RAISE EXCEPTION 'supplementary test requires one student/course-subject pair';
  END IF;
END;
$$;

INSERT INTO public.user_platform_roles (user_id, platform_role_id)
SELECT current_setting('audit.test_actor')::uuid, role.id
FROM public.platform_roles role
WHERE role.name = 'platform_admin'
ON CONFLICT DO NOTHING;

SET LOCAL ROLE authenticated;

DO $$
DECLARE
  failed boolean := false;
BEGIN
  PERFORM public.save_supplementary_batch(
    jsonb_build_array(jsonb_build_object(
      'student_id', current_setting('audit.test_student'),
      'course_subject_id', current_setting('audit.test_course_subject'),
      'score', 8.50
    )),
    '[]'::jsonb
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.supplementary_exams
    WHERE student_id::text = current_setting('audit.test_student')
      AND course_subject_id::text = current_setting('audit.test_course_subject')
      AND score = 8.50
  ) THEN
    RAISE EXCEPTION 'atomic supplementary upsert failed';
  END IF;

  BEGIN
    UPDATE public.supplementary_exams
    SET score = 9.00
    WHERE student_id::text = current_setting('audit.test_student')
      AND course_subject_id::text = current_setting('audit.test_course_subject');
  EXCEPTION WHEN insufficient_privilege THEN
    failed := true;
  END;
  IF NOT failed THEN
    RAISE EXCEPTION 'direct supplementary update was not revoked';
  END IF;

  failed := false;
  BEGIN
    PERFORM public.save_supplementary_batch(
      jsonb_build_array(
        jsonb_build_object(
          'student_id', current_setting('audit.test_student'),
          'course_subject_id', current_setting('audit.test_course_subject'),
          'score', 9.00
        ),
        jsonb_build_object(
          'student_id', current_setting('audit.test_student'),
          'course_subject_id', 'ffffffff-ffff-4fff-8fff-ffffffffffff',
          'score', 11.00
        )
      ),
      '[]'::jsonb
    );
  EXCEPTION WHEN numeric_value_out_of_range THEN
    failed := true;
  END;
  IF NOT failed THEN
    RAISE EXCEPTION 'invalid supplementary batch was accepted';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.supplementary_exams
    WHERE student_id::text = current_setting('audit.test_student')
      AND course_subject_id::text = current_setting('audit.test_course_subject')
      AND score = 8.50
  ) THEN
    RAISE EXCEPTION 'invalid batch partially changed supplementary score';
  END IF;

  PERFORM public.save_supplementary_batch(
    '[]'::jsonb,
    jsonb_build_array(jsonb_build_object(
      'student_id', current_setting('audit.test_student'),
      'course_subject_id', current_setting('audit.test_course_subject')
    ))
  );
  IF EXISTS (
    SELECT 1 FROM public.supplementary_exams
    WHERE student_id::text = current_setting('audit.test_student')
      AND course_subject_id::text = current_setting('audit.test_course_subject')
  ) THEN
    RAISE EXCEPTION 'atomic supplementary delete failed';
  END IF;
END;
$$;

RESET ROLE;

DO $$
BEGIN
  IF has_table_privilege('anon', 'public.supplementary_exams', 'INSERT')
     OR has_table_privilege('authenticated', 'public.supplementary_exams', 'UPDATE')
     OR has_function_privilege('anon', 'public.save_supplementary_batch(jsonb,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'supplementary privilege hardening failed';
  END IF;
END;
$$;

ROLLBACK;

SELECT 'p1_atomic_supplementary_scores_tests_passed' AS result;
