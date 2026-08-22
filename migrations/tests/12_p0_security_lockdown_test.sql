-- Ejecutar después de 12_p0_security_lockdown.sql. Todos los fixtures se revierten.
BEGIN;

SELECT set_config(
  'audit.test_actor',
  (SELECT id::text FROM public.profiles ORDER BY created_at LIMIT 1),
  true
);
SELECT set_config(
  'audit.test_school',
  (SELECT school_id::text FROM public.profiles WHERE id::text = current_setting('audit.test_actor')),
  true
);
SELECT set_config('request.jwt.claim.sub', current_setting('audit.test_actor'), true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);

INSERT INTO public.schools (id, name, status, is_active)
VALUES ('ffffffff-ffff-4fff-8fff-fffffffffff1', 'P0 foreign fixture', 'active', true);
INSERT INTO public.courses (id, name, academic_year, school_id)
VALUES (
  'ffffffff-ffff-4fff-8fff-fffffffffff2',
  'P0 foreign course',
  'P0',
  'ffffffff-ffff-4fff-8fff-fffffffffff1'
);
INSERT INTO public.students (id, full_name, course_id, school_id)
VALUES (
  'ffffffff-ffff-4fff-8fff-fffffffffff3',
  'P0 foreign student',
  'ffffffff-ffff-4fff-8fff-fffffffffff2',
  'ffffffff-ffff-4fff-8fff-fffffffffff1'
);

-- Simula al usuario real como usuario tenant, aunque en producción sea plataforma.
DELETE FROM public.user_platform_roles
WHERE user_id::text = current_setting('audit.test_actor');
UPDATE public.profiles
SET role = 'teacher', is_active = true
WHERE id::text = current_setting('audit.test_actor');

SET LOCAL ROLE authenticated;

DO $$
BEGIN
  IF public.get_user_school_id()::text IS DISTINCT FROM current_setting('audit.test_school') THEN
    RAISE EXCEPTION 'P0 test failed: active tenant was not resolved';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.students
    WHERE id = 'ffffffff-ffff-4fff-8fff-fffffffffff3'
  ) THEN
    RAISE EXCEPTION 'P0 test failed: foreign student is visible';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.students
    WHERE school_id = current_setting('audit.test_school')::uuid
  ) THEN
    RAISE EXCEPTION 'P0 test failed: own-tenant students are not visible';
  END IF;

  BEGIN
    INSERT INTO public.courses (name, academic_year, school_id)
    VALUES ('P0 forbidden write', 'P0', 'ffffffff-ffff-4fff-8fff-fffffffffff1');
    RAISE EXCEPTION 'P0 test failed: foreign-tenant insert was accepted';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
  END;
END
$$;

RESET ROLE;
SET LOCAL ROLE anon;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.students)
     OR EXISTS (SELECT 1 FROM public.grades)
     OR EXISTS (SELECT 1 FROM public.profiles)
     OR EXISTS (SELECT 1 FROM public.courses) THEN
    RAISE EXCEPTION 'P0 test failed: anon can read protected rows';
  END IF;
END
$$;

RESET ROLE;
ROLLBACK;

SELECT 'p0_security_lockdown_tests_passed' AS result;
