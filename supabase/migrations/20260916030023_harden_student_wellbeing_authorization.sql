-- Autorización de mínimo privilegio para Bienestar Estudiantil / DECE.
-- Las mutaciones se concentran en RPC SECURITY DEFINER que vuelven a validar
-- institución, estudiante, curso, período y ámbito del usuario.

insert into public.permissions (code, module, description) values
  ('wellbeing.read', 'wellbeing', 'Consultar casos de bienestar estudiantil autorizados'),
  ('wellbeing.create', 'wellbeing', 'Registrar novedades de estudiantes asignados'),
  ('wellbeing.manage', 'wellbeing', 'Gestionar seguimiento y resolución de casos'),
  ('wellbeing.sign', 'wellbeing', 'Registrar firmas digitales de actas DECE')
on conflict (code) do update set
  module = excluded.module,
  description = excluded.description;

insert into public.role_permissions (tenant_role_id, permission_id)
select role.id, permission.id
from public.tenant_roles role
cross join public.permissions permission
where role.name::text in ('school_admin', 'rector', 'counselor')
  and permission.code in ('wellbeing.read', 'wellbeing.create', 'wellbeing.manage', 'wellbeing.sign')
on conflict do nothing;

insert into public.role_permissions (tenant_role_id, permission_id)
select role.id, permission.id
from public.tenant_roles role
cross join public.permissions permission
where role.name::text in ('vicerrector', 'inspector')
  and permission.code in ('wellbeing.read', 'wellbeing.create', 'wellbeing.manage')
on conflict do nothing;

insert into public.role_permissions (tenant_role_id, permission_id)
select role.id, permission.id
from public.tenant_roles role
cross join public.permissions permission
where role.name::text = 'teacher'
  and permission.code in ('wellbeing.read', 'wellbeing.create')
on conflict do nothing;

create or replace function private.has_school_permission(
  p_school_id uuid,
  p_permission text
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
  select (select auth.uid()) is not null
    and p_school_id is not null
    and (
      public.has_platform_role(array['platform_owner', 'platform_admin'])
      or exists (
        select 1
        from public.tenant_memberships membership
        join public.role_permissions role_permission
          on role_permission.tenant_role_id = membership.tenant_role_id
        join public.permissions permission
          on permission.id = role_permission.permission_id
        join public.schools school on school.id = membership.school_id
        join public.profiles profile on profile.id = membership.user_id
        where membership.user_id = (select auth.uid())
          and membership.school_id = p_school_id
          and membership.is_active
          and coalesce(profile.is_active, true)
          and coalesce(school.is_active, true)
          and school.status::text in ('trial', 'active', 'past_due', 'grace_period')
          and permission.code = p_permission
      )
    );
$$;

revoke all on function private.has_school_permission(uuid, text)
  from public, anon, authenticated;

create or replace function public.can_access_student_wellbeing_case(
  p_school_id uuid,
  p_course_id uuid,
  p_reported_by uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
  select private.has_school_permission(p_school_id, 'wellbeing.manage')
    or (
      private.has_school_permission(p_school_id, 'wellbeing.read')
      and (
        p_reported_by = (select auth.uid())
        or exists (
          select 1 from public.course_subjects assignment
          where assignment.school_id = p_school_id
            and assignment.course_id = p_course_id
            and assignment.teacher_id = (select auth.uid())
        )
      )
    );
$$;

revoke all on function public.can_access_student_wellbeing_case(uuid, uuid, uuid)
  from public, anon;
grant execute on function public.can_access_student_wellbeing_case(uuid, uuid, uuid)
  to authenticated;

-- Completa la institución de cualquier registro heredado con relaciones válidas.
update public.student_alerts alert
set school_id = student.school_id
from public.students student
where alert.school_id is null
  and student.id = alert.student_id
  and student.school_id is not null;

do $$
begin
  if exists (select 1 from public.student_alerts where school_id is null) then
    raise exception 'STUDENT_ALERTS_WITHOUT_SCHOOL_REQUIRE_MANUAL_REVIEW';
  end if;
end
$$;

alter table public.student_alerts
  alter column school_id set not null;

create or replace function public.create_student_wellbeing_case(p_case jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_school_id uuid;
  v_student_id uuid;
  v_course_id uuid;
  v_quarter_id uuid;
  v_alert_type text;
  v_severity text;
  v_description text;
  v_date_occurred timestamptz;
  v_case public.student_alerts%rowtype;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if p_case is null or jsonb_typeof(p_case) <> 'object' then
    raise exception 'INVALID_CASE_PAYLOAD' using errcode = '22023';
  end if;

  begin
    v_school_id := nullif(p_case->>'school_id', '')::uuid;
    v_student_id := nullif(p_case->>'student_id', '')::uuid;
    v_course_id := nullif(p_case->>'course_id', '')::uuid;
    v_quarter_id := nullif(p_case->>'quarter_id', '')::uuid;
    v_date_occurred := nullif(p_case->>'date_occurred', '')::timestamptz;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'INVALID_CASE_IDENTIFIERS_OR_DATE' using errcode = '22023';
  end;

  v_alert_type := upper(trim(coalesce(p_case->>'alert_type', '')));
  v_severity := upper(trim(coalesce(p_case->>'severity', '')));
  v_description := trim(coalesce(p_case->>'description', ''));

  if not private.has_school_permission(v_school_id, 'wellbeing.create') then
    raise exception 'WELLBEING_CREATE_REQUIRED' using errcode = '42501';
  end if;
  if v_alert_type <> all(array['INDISCIPLINA', 'APROVECHAMIENTO', 'FALTA', 'FUGA', 'ATRASO', 'USO_CELULAR', 'ACOSO', 'OTRA']) then
    raise exception 'INVALID_ALERT_TYPE' using errcode = '22023';
  end if;
  if v_severity <> all(array['LEVE', 'GRAVE', 'MUY_GRAVE']) then
    raise exception 'INVALID_ALERT_SEVERITY' using errcode = '22023';
  end if;
  if char_length(v_description) < 6 or char_length(v_description) > 5000 then
    raise exception 'INVALID_ALERT_DESCRIPTION_LENGTH' using errcode = '22023';
  end if;
  if v_date_occurred is null
    or v_date_occurred > now() + interval '5 minutes'
    or v_date_occurred < now() - interval '5 years' then
    raise exception 'INVALID_OCCURRENCE_DATE' using errcode = '22023';
  end if;
  if not exists (
    select 1
    from public.students student
    join public.courses course
      on course.id = student.course_id
      and course.school_id = student.school_id
    join public.quarters quarter
      on quarter.id = v_quarter_id
      and quarter.school_id = student.school_id
    where student.id = v_student_id
      and student.course_id = v_course_id
      and student.school_id = v_school_id
  ) then
    raise exception 'STUDENT_COURSE_OR_QUARTER_NOT_FOUND_IN_TENANT' using errcode = '42501';
  end if;
  if not private.has_school_permission(v_school_id, 'wellbeing.manage')
    and not exists (
      select 1 from public.course_subjects assignment
      where assignment.school_id = v_school_id
        and assignment.course_id = v_course_id
        and assignment.teacher_id = auth.uid()
    ) then
    raise exception 'ASSIGNED_COURSE_REQUIRED' using errcode = '42501';
  end if;

  insert into public.student_alerts (
    school_id, student_id, course_id, quarter_id, alert_type, severity,
    description, date_occurred, reported_by, status
  ) values (
    v_school_id, v_student_id, v_course_id, v_quarter_id, v_alert_type, v_severity,
    v_description, v_date_occurred, auth.uid(), 'PENDIENTE'
  ) returning * into v_case;

  return to_jsonb(v_case);
end;
$$;

create or replace function public.update_student_wellbeing_case(
  p_alert_id uuid,
  p_status text,
  p_dece_notes text default null,
  p_resolution text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_existing public.student_alerts%rowtype;
  v_updated public.student_alerts%rowtype;
  v_status text := upper(trim(coalesce(p_status, '')));
  v_notes text := nullif(trim(coalesce(p_dece_notes, '')), '');
  v_resolution text := nullif(trim(coalesce(p_resolution, '')), '');
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  select * into v_existing
  from public.student_alerts
  where id = p_alert_id;
  if not found then
    raise exception 'WELLBEING_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;
  if not private.has_school_permission(v_existing.school_id, 'wellbeing.manage') then
    raise exception 'WELLBEING_MANAGE_REQUIRED' using errcode = '42501';
  end if;
  if v_status <> all(array['PENDIENTE', 'EN_REVISION', 'CONVOCADO', 'RESUELTO', 'ARCHIVADO']) then
    raise exception 'INVALID_WELLBEING_STATUS' using errcode = '22023';
  end if;
  if char_length(coalesce(v_notes, '')) > 10000
    or char_length(coalesce(v_resolution, '')) > 10000 then
    raise exception 'WELLBEING_TEXT_TOO_LONG' using errcode = '22023';
  end if;

  update public.student_alerts
  set status = v_status,
      dece_notes = v_notes,
      resolution = v_resolution,
      -- El contenido canónico cambió: una firma previa deja de representar el acta.
      is_digitally_signed = false,
      signature_data = null,
      signed_at = null,
      signed_by = null,
      updated_at = now()
  where id = p_alert_id
    and school_id = v_existing.school_id
  returning * into v_updated;

  return to_jsonb(v_updated);
end;
$$;

create or replace function public.mark_student_wellbeing_convoked(
  p_alert_id uuid,
  p_sent_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_existing public.student_alerts%rowtype;
  v_updated public.student_alerts%rowtype;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  select * into v_existing
  from public.student_alerts
  where id = p_alert_id;
  if not found then
    raise exception 'WELLBEING_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_existing.status in ('RESUELTO', 'ARCHIVADO') then
    return to_jsonb(v_existing);
  end if;
  if not private.has_school_permission(v_existing.school_id, 'wellbeing.manage')
    and not (
      private.has_school_permission(v_existing.school_id, 'wellbeing.create')
      and (
        v_existing.reported_by = auth.uid()
        or exists (
          select 1 from public.course_subjects assignment
          where assignment.school_id = v_existing.school_id
            and assignment.course_id = v_existing.course_id
            and assignment.teacher_id = auth.uid()
        )
      )
    ) then
    raise exception 'WELLBEING_CASE_ACCESS_DENIED' using errcode = '42501';
  end if;
  if p_sent_at is null or p_sent_at > now() + interval '5 minutes' then
    raise exception 'INVALID_NOTIFICATION_DATE' using errcode = '22023';
  end if;

  update public.student_alerts
  set status = 'CONVOCADO', whatsapp_sent_at = p_sent_at, updated_at = now()
  where id = p_alert_id and school_id = v_existing.school_id
  returning * into v_updated;
  return to_jsonb(v_updated);
end;
$$;

create or replace function public.register_student_wellbeing_signature(
  p_alert_id uuid,
  p_signature jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_existing public.student_alerts%rowtype;
  v_updated public.student_alerts%rowtype;
  v_payload jsonb;
  v_registered_signature jsonb;
  v_signed_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if p_signature is null
    or jsonb_typeof(p_signature) <> 'object'
    or pg_column_size(p_signature) > 65536 then
    raise exception 'INVALID_SIGNATURE_PAYLOAD' using errcode = '22023';
  end if;

  select * into v_existing
  from public.student_alerts
  where id = p_alert_id;
  if not found then
    raise exception 'WELLBEING_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;
  if not private.has_school_permission(v_existing.school_id, 'wellbeing.sign') then
    raise exception 'WELLBEING_SIGN_REQUIRED' using errcode = '42501';
  end if;

  v_payload := p_signature->'canonical_payload';
  begin
    v_signed_at := nullif(p_signature->>'signed_at', '')::timestamptz;
  exception when invalid_datetime_format or datetime_field_overflow then
    raise exception 'INVALID_SIGNATURE_DATE' using errcode = '22023';
  end;
  if jsonb_typeof(v_payload) is distinct from 'object'
    or (v_payload->>'alert_id') is distinct from p_alert_id::text
    or (v_payload->>'student_id') is distinct from v_existing.student_id::text
    or (v_payload->>'alert_type') is distinct from v_existing.alert_type
    or (v_payload->>'severity') is distinct from v_existing.severity
    or trim(coalesce(v_payload->>'description', '')) is distinct from trim(v_existing.description)
    or trim(coalesce(v_payload->>'dece_notes', '')) is distinct from trim(coalesce(v_existing.dece_notes, ''))
    or trim(coalesce(v_payload->>'resolution', '')) is distinct from trim(coalesce(v_existing.resolution, '')) then
    raise exception 'SIGNATURE_DOCUMENT_MISMATCH' using errcode = '22023';
  end if;
  if (p_signature->>'algorithm') is distinct from 'SHA256withRSA'
    or coalesce(p_signature->>'document_digest', '') !~ '^[0-9a-fA-F]{64}$'
    or coalesce(p_signature->>'signature_hex', '') !~ '^[0-9a-fA-F]{128,16384}$'
    or char_length(trim(coalesce(p_signature->>'signer_name', ''))) < 3 then
    raise exception 'INVALID_SIGNATURE_METADATA' using errcode = '22023';
  end if;
  if v_signed_at is null
    or v_signed_at > now() + interval '5 minutes'
    or v_signed_at < now() - interval '1 day' then
    raise exception 'INVALID_SIGNATURE_DATE' using errcode = '22023';
  end if;

  -- PostgreSQL registra la evidencia, pero no valida aquí la cadena X.509 ni la
  -- firma RSA. Por ello el servidor impide presentar el resultado como verificado.
  v_registered_signature := (p_signature - 'is_valid' - 'verification_status') || jsonb_build_object(
    'local_signature_valid', true,
    'is_valid', false,
    'verification_status', 'pending_server_verification',
    'registered_at', now(),
    'registered_by', auth.uid()
  );

  update public.student_alerts
  set is_digitally_signed = true,
      signature_data = v_registered_signature,
      signed_at = v_signed_at,
      signed_by = auth.uid(),
      updated_at = now()
  where id = p_alert_id and school_id = v_existing.school_id
  returning * into v_updated;
  return to_jsonb(v_updated);
end;
$$;

do $$
declare
  policy_row record;
begin
  for policy_row in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'student_alerts'
  loop
    execute format('drop policy if exists %I on public.student_alerts', policy_row.policyname);
  end loop;
end
$$;

alter table public.student_alerts enable row level security;

create policy student_alerts_wellbeing_select
on public.student_alerts
for select
to authenticated
using (
  public.can_access_student_wellbeing_case(school_id, course_id, reported_by)
);

grant select on public.student_alerts to authenticated;
revoke insert, update, delete on public.student_alerts from anon, authenticated;

revoke all on function public.create_student_wellbeing_case(jsonb) from public, anon;
revoke all on function public.update_student_wellbeing_case(uuid, text, text, text) from public, anon;
revoke all on function public.mark_student_wellbeing_convoked(uuid, timestamptz) from public, anon;
revoke all on function public.register_student_wellbeing_signature(uuid, jsonb) from public, anon;
grant execute on function public.create_student_wellbeing_case(jsonb) to authenticated;
grant execute on function public.update_student_wellbeing_case(uuid, text, text, text) to authenticated;
grant execute on function public.mark_student_wellbeing_convoked(uuid, timestamptz) to authenticated;
grant execute on function public.register_student_wellbeing_signature(uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
