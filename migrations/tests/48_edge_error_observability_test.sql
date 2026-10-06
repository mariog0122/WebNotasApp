begin;

do $$
begin
  if to_regclass('public.edge_function_error_events') is null then
    raise exception 'OBSERVABILITY: edge error table is missing';
  end if;
  if to_regprocedure('public.record_edge_function_error(text,text,integer,uuid,uuid,jsonb)') is null then
    raise exception 'OBSERVABILITY: server recording RPC is missing';
  end if;
  if has_function_privilege('authenticated', 'public.record_edge_function_error(text,text,integer,uuid,uuid,jsonb)', 'EXECUTE')
    or has_function_privilege('anon', 'public.record_edge_function_error(text,text,integer,uuid,uuid,jsonb)', 'EXECUTE') then
    raise exception 'SECURITY: browser roles can record server errors';
  end if;
  if not has_function_privilege('service_role', 'public.record_edge_function_error(text,text,integer,uuid,uuid,jsonb)', 'EXECUTE') then
    raise exception 'OBSERVABILITY: service role cannot record errors';
  end if;
end;
$$;

-- Exercise the complete alert path with synthetic events; roll back all writes.
set local role service_role;
do $$
declare
  test_name text := 'audit-burst-' || gen_random_uuid()::text;
  response jsonb;
  alert_count integer;
begin
  for event_number in 1..6 loop
    response := public.record_edge_function_error(test_name, 'SYNTHETIC_TEST_FAILURE', 500);
    if (response->>'recent_count_15m')::integer <> event_number then
      raise exception 'OBSERVABILITY: incorrect burst count';
    end if;
    if (response->>'alert_triggered')::boolean <> (event_number >= 5) then
      raise exception 'OBSERVABILITY: incorrect alert threshold';
    end if;
  end loop;
  select count(*) into alert_count from public.audit_log
  where action = 'EDGE_FUNCTION_BURST_ALERT'
    and new_values->>'function_name' = test_name;
  if alert_count <> 1 then
    raise exception 'OBSERVABILITY: expected exactly one audit alert, received %', alert_count;
  end if;
end;
$$;

rollback;
select 'edge_error_observability_tests_passed' as result;
