-- Contract test for migrations/27_p2_client_observability.sql. Safe: rolls back.
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

SET LOCAL ROLE authenticated;

INSERT INTO public.client_error_events (
  school_id, user_id, fingerprint, error_name, error_code, source, route, release
) VALUES (
  NULL,
  NULL,
  repeat('a', 64),
  'Error',
  'TEST_ERROR',
  'vue',
  '/students',
  'sql-test'
);

DO $$
DECLARE
  index_number integer;
  was_rate_limited boolean := false;
BEGIN
  -- There is already one event in this minute. Fill the remaining allowance.
  FOR index_number IN 2..20 LOOP
    INSERT INTO public.client_error_events (
      fingerprint, error_name, error_code, source, route, release
    ) VALUES (
      md5(index_number::text) || md5(index_number::text),
      'Error',
      'TEST_ERROR',
      'other',
      '/test',
      'sql-test'
    );
  END LOOP;

  BEGIN
    INSERT INTO public.client_error_events (
      fingerprint, error_name, error_code, source, route, release
    ) VALUES (
      repeat('f', 64), 'Error', 'RATE_LIMIT', 'other', '/test', 'sql-test'
    );
  EXCEPTION WHEN program_limit_exceeded THEN
    was_rate_limited := true;
  END;

  IF NOT was_rate_limited THEN
    RAISE EXCEPTION 'client error rate limit was not enforced';
  END IF;
END;
$$;

RESET ROLE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.client_error_events
    WHERE release = 'sql-test'
      AND (
        user_id::text IS DISTINCT FROM current_setting('audit.test_actor')
        OR school_id::text IS DISTINCT FROM current_setting('audit.test_school')
      )
  ) THEN
    RAISE EXCEPTION 'server-side telemetry identity was not enforced';
  END IF;
  IF (SELECT count(*) FROM public.client_error_events WHERE release = 'sql-test') <> 20 THEN
    RAISE EXCEPTION 'unexpected telemetry event count';
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
  health json;
BEGIN
  health := public.get_platform_health();
  IF NOT (health::text LIKE '%Errores del cliente%') THEN
    RAISE EXCEPTION 'platform health does not expose client telemetry';
  END IF;
  IF (SELECT count(*) FROM public.client_error_events WHERE release = 'sql-test') <> 20 THEN
    RAISE EXCEPTION 'platform admin cannot inspect telemetry';
  END IF;
END;
$$;

RESET ROLE;
SET LOCAL ROLE anon;

DO $$
DECLARE
  denied boolean := false;
BEGIN
  BEGIN
    INSERT INTO public.client_error_events (
      fingerprint, error_name, error_code, source, route, release
    ) VALUES (repeat('0', 64), 'Error', 'ANON', 'other', '/', 'sql-test');
  EXCEPTION WHEN insufficient_privilege THEN
    denied := true;
  END;
  IF NOT denied THEN
    RAISE EXCEPTION 'anonymous telemetry insert was accepted';
  END IF;
END;
$$;

RESET ROLE;
ROLLBACK;

SELECT 'p2_client_observability_tests_passed' AS result;
