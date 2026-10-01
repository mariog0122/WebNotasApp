-- Ejecutar después de harden_course_copy_authorization. Todos los cambios se revierten.
begin;

select set_config(
  'audit.copy_school',
  (select ay.school_id::text
   from public.academic_years ay
   where exists (select 1 from public.profiles p where p.school_id = ay.school_id)
     and exists (select 1 from public.courses c where c.school_id = ay.school_id and c.academic_year = ay.name)
   group by ay.school_id
   having count(*) >= 2
   order by ay.school_id
   limit 1),
  true
);
select set_config(
  'audit.copy_source_year',
  (select ay.id::text from public.academic_years ay
   where ay.school_id::text = current_setting('audit.copy_school')
     and exists (select 1 from public.courses c where c.school_id = ay.school_id and c.academic_year = ay.name)
   order by ay.name limit 1),
  true
);
select set_config(
  'audit.copy_target_year',
  (select ay.id::text from public.academic_years ay
   where ay.school_id::text = current_setting('audit.copy_school')
     and ay.id::text <> current_setting('audit.copy_source_year')
   order by ay.name limit 1),
  true
);
select set_config(
  'audit.copy_cross_year',
  (select ay.id::text from public.academic_years ay
   where ay.school_id::text <> current_setting('audit.copy_school')
   order by ay.name limit 1),
  true
);
select set_config(
  'audit.copy_actor',
  (select p.id::text from public.profiles p
   where p.school_id::text = current_setting('audit.copy_school')
   order by p.created_at limit 1),
  true
);

delete from public.user_platform_roles
where user_id::text = current_setting('audit.copy_actor');
update public.profiles
set role = 'teacher', is_active = true
where id::text = current_setting('audit.copy_actor');
insert into public.tenant_memberships (user_id, school_id, tenant_role_id, is_active)
select current_setting('audit.copy_actor')::uuid,
       current_setting('audit.copy_school')::uuid,
       tr.id,
       true
from public.tenant_roles tr
where tr.name = 'teacher'
on conflict (user_id, school_id) do update
set tenant_role_id = excluded.tenant_role_id, is_active = true;

delete from public.courses c
using public.academic_years ay
where ay.id::text = current_setting('audit.copy_target_year')
  and c.school_id = ay.school_id
  and c.academic_year = ay.name
  and c.name = '__AUDIT_COPY_COURSE__';
insert into public.courses (school_id, name, academic_year, level, track, tutor_name)
select ay.school_id, '__AUDIT_COPY_COURSE__', ay.name,
       'Básica', 'General', 'Docente de auditoría'
from public.academic_years ay
where ay.id::text = current_setting('audit.copy_source_year')
  and not exists (
    select 1 from public.courses c
    where c.school_id = ay.school_id
      and c.academic_year = ay.name
      and c.name = '__AUDIT_COPY_COURSE__'
  );

select set_config('request.jwt.claim.sub', current_setting('audit.copy_actor'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_source_name text;
  v_target_name text;
begin
  select name into v_source_name from public.academic_years
  where id::text = current_setting('audit.copy_source_year');
  select name into v_target_name from public.academic_years
  where id::text = current_setting('audit.copy_target_year');

  begin
    perform public.copy_courses_to_academic_year(
      current_setting('audit.copy_school')::uuid,
      v_source_name,
      v_target_name
    );
    raise exception 'teacher copied courses through the legacy overload';
  exception when insufficient_privilege then
    null;
  end;
end
$$;

reset role;

do $$
begin
  if has_function_privilege('anon', 'public.copy_courses_to_academic_year(uuid,text,text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.copy_courses_to_academic_year(uuid,uuid,boolean)', 'EXECUTE') then
    raise exception 'course copy RPC remains executable by anon/public';
  end if;
end
$$;

update public.tenant_memberships tm
set tenant_role_id = tr.id, is_active = true
from public.tenant_roles tr
where tm.user_id::text = current_setting('audit.copy_actor')
  and tm.school_id::text = current_setting('audit.copy_school')
  and tr.name = 'school_admin';

set local role authenticated;

do $$
begin
  begin
    perform public.copy_courses_to_academic_year(
      current_setting('audit.copy_source_year')::uuid,
      current_setting('audit.copy_cross_year')::uuid,
      true
    );
    raise exception 'cross-tenant academic years were accepted';
  exception when insufficient_privilege then
    null;
  end;

  perform public.copy_courses_to_academic_year(
    current_setting('audit.copy_source_year')::uuid,
    current_setting('audit.copy_target_year')::uuid,
    true
  );

  if not exists (
    select 1
    from public.courses c
    join public.academic_years ay
      on ay.school_id = c.school_id and ay.name = c.academic_year
    where ay.id::text = current_setting('audit.copy_target_year')
      and c.name = '__AUDIT_COPY_COURSE__'
      and c.tutor_name = 'Docente de auditoría'
  ) then
    raise exception 'valid course copy did not preserve course metadata';
  end if;
end
$$;

reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where role = 'superadmin' and coalesce(is_active, true) limit 1),
  true
);
set local role authenticated;

do $$
begin
  perform public.copy_courses_to_academic_year(
    current_setting('audit.copy_source_year')::uuid,
    current_setting('audit.copy_target_year')::uuid,
    true
  );
end
$$;

reset role;
rollback;

select 'course_copy_authorization_regression_tests_passed' as result;
