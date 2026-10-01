-- Replace multi-request teacher assignment updates with one authorized transaction.

create or replace function public.set_teacher_course_subject_assignments(
  p_user_id uuid,
  p_school_id uuid,
  p_scope_ids uuid[],
  p_selected_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_scope_count integer := coalesce(cardinality(p_scope_ids), 0);
  v_selected_count integer := coalesce(cardinality(p_selected_ids), 0);
  v_updated integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_user_id is null or p_school_id is null or p_scope_ids is null or p_selected_ids is null then
    raise exception 'Datos de asignación incompletos' using errcode = '22023';
  end if;
  if v_scope_count > 5000 or v_selected_count > 5000 then
    raise exception 'Lote de asignaciones demasiado grande' using errcode = '22023';
  end if;
  if not p_selected_ids <@ p_scope_ids then
    raise exception 'Las materias seleccionadas deben pertenecer al alcance visible' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_scope_ids) as item(id) where item.id is null)
     or exists (select 1 from unnest(p_selected_ids) as item(id) where item.id is null) then
    raise exception 'Identificador de materia no válido' using errcode = '22023';
  end if;

  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('users.manage')
  ) then
    raise exception 'No tienes permiso para asignar docentes en esta institución' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles p
    join public.tenant_memberships tm
      on tm.user_id = p.id and tm.school_id = p_school_id and tm.is_active
    join public.tenant_roles tr on tr.id = tm.tenant_role_id and tr.name = 'teacher'
    where p.id = p_user_id
      and p.school_id = p_school_id
      and coalesce(p.is_active, true)
  ) then
    raise exception 'El usuario no es un docente activo de esta institución' using errcode = '22023';
  end if;

  if (
    select count(distinct cs.id)
    from public.course_subjects cs
    where cs.id = any(p_scope_ids) and cs.school_id = p_school_id
  ) <> (select count(distinct item.id) from unnest(p_scope_ids) as item(id)) then
    raise exception 'El alcance contiene materias de otra institución o inexistentes' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text || ':' || p_user_id::text, 0));
  update public.course_subjects
  set teacher_id = null
  where school_id = p_school_id
    and id = any(p_scope_ids)
    and teacher_id = p_user_id
    and not (id = any(p_selected_ids));

  update public.course_subjects
  set teacher_id = p_user_id
  where school_id = p_school_id and id = any(p_selected_ids);
  get diagnostics v_updated = row_count;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    p_school_id,
    auth.uid(),
    'TEACHER_SUBJECT_ASSIGNMENTS_UPDATED',
    'course_subjects',
    p_user_id::text,
    jsonb_build_object('scope_count', v_scope_count, 'selected_count', v_selected_count)
  );

  return jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'school_id', p_school_id,
    'scope_count', v_scope_count,
    'selected_count', v_selected_count,
    'assigned_rows', v_updated
  );
end;
$$;

revoke all on function public.set_teacher_course_subject_assignments(uuid, uuid, uuid[], uuid[]) from public, anon;
grant execute on function public.set_teacher_course_subject_assignments(uuid, uuid, uuid[], uuid[]) to authenticated, service_role;

