-- Ejecutar después de secure_academic_year_management. Todos los cambios se revierten.
begin;

select set_config(
  'audit.test_actor',
  (select id::text from public.profiles where school_id is not null order by created_at limit 1),
  true
);
select set_config(
  'audit.test_school',
  (select school_id::text from public.profiles where id::text = current_setting('audit.test_actor')),
  true
);
select set_config('request.jwt.claim.sub', current_setting('audit.test_actor'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.schools (id, name, code, status, is_active)
values ('38383838-3838-4383-8383-383838383838', 'Academic year foreign fixture', 'AY-FOREIGN', 'active', true);

insert into public.academic_years (
  id, school_id, name, start_year, end_year, is_active, is_current, is_locked
) values (
  '38383838-3838-4383-8383-383838383839',
  '38383838-3838-4383-8383-383838383838',
  '2096-2097', 2096, 2097, true, true, false
);

delete from public.user_platform_roles
where user_id::text = current_setting('audit.test_actor');
update public.profiles
set role = 'teacher', is_active = true
where id::text = current_setting('audit.test_actor');
insert into public.tenant_memberships (user_id, school_id, tenant_role_id, is_active)
select current_setting('audit.test_actor')::uuid,
       current_setting('audit.test_school')::uuid,
       tr.id,
       true
from public.tenant_roles tr
where tr.name = 'teacher'
on conflict (user_id, school_id) do update
set tenant_role_id = excluded.tenant_role_id, is_active = true;

set local role authenticated;

do $$
declare
  v_failed boolean := false;
begin
  if not public.has_tenant_permission('academic_year.read') then
    raise exception 'teacher lost academic-year read access';
  end if;
  if public.has_tenant_permission('academic_year.create') then
    raise exception 'teacher unexpectedly received academic-year create access';
  end if;
  if exists (
    select 1 from public.academic_years
    where id = '38383838-3838-4383-8383-383838383839'
  ) then
    raise exception 'teacher can read a foreign institution academic year';
  end if;

  begin
    perform public.create_academic_year('2097-2098', 2097, 2098, false, null);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'teacher created an academic year through RPC';
  end if;

  v_failed := false;
  begin
    insert into public.academic_years (school_id, name, start_year, end_year)
    values (current_setting('audit.test_school')::uuid, '2097-2098', 2097, 2098);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'teacher created an academic year directly';
  end if;
end
$$;

reset role;
update public.tenant_memberships tm
set tenant_role_id = tr.id
from public.tenant_roles tr
where tm.user_id::text = current_setting('audit.test_actor')
  and tm.school_id::text = current_setting('audit.test_school')
  and tr.name = 'rector';
update public.profiles set role = 'admin'
where id::text = current_setting('audit.test_actor');

set local role authenticated;

do $$
declare
  v_first public.academic_years;
  v_repeat public.academic_years;
  v_second public.academic_years;
  v_failed boolean := false;
begin
  v_first := public.create_academic_year(
    '2097-2098', 2097, 2098, false, '38383838-3838-4383-8383-383838383838'
  );
  if v_first.school_id::text is distinct from current_setting('audit.test_school') then
    raise exception 'tenant-controlled school_id escaped the authenticated institution';
  end if;

  v_repeat := public.create_academic_year('2097-2098', 2097, 2098, false, null);
  if v_repeat.id is distinct from v_first.id then
    raise exception 'repeated create request was not idempotent';
  end if;

  v_second := public.create_academic_year('2098-2099', 2098, 2099, true, null);
  if not v_second.is_current then
    raise exception 'rector could not activate the created academic year';
  end if;
  if (select count(*) from public.academic_years
      where school_id::text = current_setting('audit.test_school') and is_current) <> 1 then
    raise exception 'institution has more than one current academic year';
  end if;

  begin
    perform public.create_academic_year('2099-2098', 2099, 2098, false, null);
  exception when invalid_parameter_value or check_violation then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'invalid year range was accepted';
  end if;

  v_failed := false;
  begin
    perform public.set_academic_year_current('38383838-3838-4383-8383-383838383839');
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'rector activated a foreign institution academic year';
  end if;

  if not exists (
    select 1 from public.audit_log
    where school_id::text = current_setting('audit.test_school')
      and record_id = v_first.id::text
      and action = 'ACADEMIC_YEAR_CREATED'
  ) then
    raise exception 'academic-year creation did not write an audit event';
  end if;
end
$$;

reset role;
rollback;

select 'academic_year_management_tests_passed' as result;
