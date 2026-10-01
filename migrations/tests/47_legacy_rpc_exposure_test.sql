begin;

set local role authenticated;
set local request.jwt.claims = '{"sub":"d0600000-0000-4000-8000-000000009999","role":"authenticated"}';

do $$
begin
  begin
    perform public.get_tenant_usage_stats('d0600000-0000-4000-8000-000000000002'::uuid);
    raise exception 'SECURITY: cross-tenant usage statistics were returned';
  exception when insufficient_privilege then
    null;
  end;

  if has_function_privilege('authenticated', 'public.copy_courses_to_academic_year(uuid,text,text)', 'EXECUTE') then
    raise exception 'SECURITY: obsolete course-copy overload remains executable';
  end if;
  if has_function_privilege('authenticated', 'public.invite_teacher_by_email(text)', 'EXECUTE') then
    raise exception 'SECURITY: obsolete teacher invitation RPC remains executable';
  end if;
  if has_function_privilege('authenticated', 'public.is_school_entitled(uuid)', 'EXECUTE') then
    raise exception 'SECURITY: unused entitlement probe remains executable';
  end if;
end;
$$;

rollback;
select 'legacy_rpc_exposure_tests_passed' as result;
