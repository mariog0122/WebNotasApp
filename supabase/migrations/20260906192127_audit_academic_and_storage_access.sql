-- Localized corrections; no renames, deletions of business data or role changes.
drop policy if exists academic_years_insert on public.academic_years;
create policy academic_years_insert on public.academic_years for insert to authenticated
with check (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('settings.manage')));
drop policy if exists academic_years_update on public.academic_years;
create policy academic_years_update on public.academic_years for update to authenticated
using (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('settings.manage')))
with check (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('settings.manage')));
drop policy if exists academic_years_delete on public.academic_years;
create policy academic_years_delete on public.academic_years for delete to authenticated
using (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('settings.manage')));

-- Existing rows were checked for dimension, student/course and score consistency before preparing this migration.
create or replace function private.synchronize_grade_dimensions_from_definition()
returns trigger language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare definition record; student record;
begin
  select gd.course_subject_id,gd.quarter_id,gd.school_id,cs.course_id,q.is_locked
    into definition from public.grade_definitions gd
    join public.course_subjects cs on cs.id=gd.course_subject_id and cs.school_id=gd.school_id
    join public.quarters q on q.id=gd.quarter_id and q.school_id=gd.school_id
    where gd.id=new.grade_definition_id;
  select school_id,course_id into student from public.students where id=new.student_id;
  if definition.school_id is null or student.school_id is distinct from definition.school_id
    or student.course_id is distinct from definition.course_id then
    raise exception 'INVALID_GRADE_DIMENSIONS' using errcode='23514';
  end if;
  if new.score is not null and (new.score<0 or new.score>10) then
    raise exception 'GRADE_SCORE_OUT_OF_RANGE' using errcode='23514';
  end if;
  if auth.uid() is not null and coalesce(definition.is_locked,false) then
    raise exception 'GRADE_PERIOD_LOCKED' using errcode='42501';
  end if;
  new.course_subject_id:=definition.course_subject_id;
  new.quarter_id:=definition.quarter_id;
  new.school_id:=definition.school_id;
  new.updated_at:=now();
  return new;
end $$;
drop policy if exists grades_select on public.grades;
create policy grades_select on public.grades for select to authenticated
using (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.read')));
drop policy if exists grades_insert on public.grades;
create policy grades_insert on public.grades for insert to authenticated
with check (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.update')));
drop policy if exists grades_update on public.grades;
create policy grades_update on public.grades for update to authenticated
using (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.update')))
with check (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.update')));
drop policy if exists grades_delete on public.grades;
create policy grades_delete on public.grades for delete to authenticated
using ((public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.update')))
  and exists(select 1 from public.quarters q where q.id=quarter_id and not coalesce(q.is_locked,false)));

-- Keep the existing receipts/<school UUID>_<filename> convention and historical links.
create or replace function private.can_access_billing_proof(object_name text)
returns boolean language sql stable security definer set search_path=pg_catalog,public as $$
  select public.is_platform_admin() or (
    public.has_tenant_permission('billing.read')
    and split_part(object_name,'/',1)='receipts'
    and split_part(split_part(object_name,'/',2),'_',1)=public.get_user_school_id()::text
    and array_length(string_to_array(object_name,'/'),1)=2
  )
$$;
revoke all on function private.can_access_billing_proof(text) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.can_access_billing_proof(text) to authenticated;
drop policy if exists "Public view for billing proofs" on storage.objects;
drop policy if exists "Allow upload billing proofs" on storage.objects;
drop policy if exists "Allow update billing proofs" on storage.objects;
create policy billing_proofs_select on storage.objects for select to authenticated
using (bucket_id='billing-proofs' and private.can_access_billing_proof(name));
create policy billing_proofs_insert on storage.objects for insert to authenticated
with check (bucket_id='billing-proofs' and private.can_access_billing_proof(name) and public.has_tenant_permission('billing.manage'));
create policy billing_proofs_update on storage.objects for update to authenticated
using (bucket_id='billing-proofs' and private.can_access_billing_proof(name) and public.has_tenant_permission('billing.manage'))
with check (bucket_id='billing-proofs' and private.can_access_billing_proof(name) and public.has_tenant_permission('billing.manage'));
update storage.buckets set public=false,file_size_limit=10485760,
  allowed_mime_types=array['image/jpeg','image/png','image/webp','application/pdf'] where id='billing-proofs';
