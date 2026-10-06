-- Manage the institution subject catalog without exposing direct table writes.

create or replace function public.save_subject_record(p_school_id uuid, p_subject_id uuid, p_name text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, auth as $$
declare
  v_subject public.subjects;
  v_is_update boolean := false;
  v_name text := nullif(trim(p_name), '');
begin
  if auth.uid() is null then raise exception 'Autenticación requerida' using errcode = '42501'; end if;
  if p_school_id is null or v_name is null or length(v_name) > 150 then
    raise exception 'El nombre de la asignatura no es válido' using errcode = '22023';
  end if;
  if p_subject_id is not null then
    select * into v_subject from public.subjects where id = p_subject_id for update;
    v_is_update := found;
    if not v_is_update then raise exception 'Asignatura no encontrada' using errcode = 'P0002'; end if;
    if v_subject.school_id is distinct from p_school_id then
      raise exception 'La asignatura pertenece a otra institución' using errcode = '42501';
    end if;
  end if;
  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or (v_is_update and not public.has_tenant_permission('subjects.update') and not public.has_tenant_permission('settings.manage'))
    or (not v_is_update and not public.has_tenant_permission('subjects.create') and not public.has_tenant_permission('settings.manage'))
  ) then
    raise exception 'No tienes permiso para guardar asignaturas' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text || ':subjects', 0));
  if exists (
    select 1 from public.subjects s
    where s.school_id = p_school_id and lower(trim(s.name)) = lower(v_name)
      and (not v_is_update or s.id <> p_subject_id)
  ) then
    raise exception 'Ya existe una asignatura con ese nombre' using errcode = '23505';
  end if;
  if v_is_update then
    update public.subjects set name = v_name where id = p_subject_id and school_id = p_school_id returning * into v_subject;
  else
    insert into public.subjects(school_id, name) values (p_school_id, v_name) returning * into v_subject;
  end if;
  if v_subject.id is null or v_subject.school_id is distinct from p_school_id or v_subject.name is distinct from v_name then
    raise exception 'La base de datos no confirmó el guardado de la asignatura';
  end if;
  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (p_school_id, auth.uid(), case when v_is_update then 'SUBJECT_UPDATED' else 'SUBJECT_CREATED' end,
    'subjects', v_subject.id::text, jsonb_build_object('name', v_name));
  return jsonb_build_object('success', true, 'action', case when v_is_update then 'updated' else 'created' end,
    'subject', to_jsonb(v_subject));
end;
$$;

create or replace function public.import_subjects_batch(p_school_id uuid, p_names text[])
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, auth as $$
declare
  v_requested integer := coalesce(cardinality(p_names), 0);
  v_inserted integer := 0;
begin
  if auth.uid() is null then raise exception 'Autenticación requerida' using errcode = '42501'; end if;
  if p_school_id is null or p_names is null or v_requested < 1 or v_requested > 1000 then
    raise exception 'El lote debe contener entre 1 y 1000 asignaturas' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_names) item(name) where nullif(trim(item.name), '') is null or length(trim(item.name)) > 150)
    or (select count(distinct lower(trim(item.name))) from unnest(p_names) item(name)) <> v_requested then
    raise exception 'El lote contiene nombres vacíos, repetidos o demasiado extensos' using errcode = '22023';
  end if;
  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or (not public.has_tenant_permission('subjects.create') and not public.has_tenant_permission('settings.manage'))
  ) then
    raise exception 'No tienes permiso para importar asignaturas' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text || ':subjects', 0));
  if exists (
    select 1 from unnest(p_names) item(name)
    join public.subjects s on s.school_id = p_school_id and lower(trim(s.name)) = lower(trim(item.name))
  ) then
    raise exception 'El lote contiene una asignatura que ya existe' using errcode = '23505';
  end if;
  insert into public.subjects(school_id, name)
  select p_school_id, trim(item.name) from unnest(p_names) item(name);
  get diagnostics v_inserted = row_count;
  if v_inserted <> v_requested then raise exception 'La base de datos no confirmó la importación completa de asignaturas'; end if;
  insert into public.audit_log(school_id, user_id, action, table_name, new_values)
  values (p_school_id, auth.uid(), 'SUBJECTS_IMPORTED', 'subjects', jsonb_build_object('inserted', v_inserted));
  return jsonb_build_object('success', true, 'school_id', p_school_id, 'inserted_count', v_inserted);
end;
$$;

create or replace function public.delete_subject_record(p_school_id uuid, p_subject_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, auth as $$
declare v_deleted integer := 0;
begin
  if auth.uid() is null then raise exception 'Autenticación requerida' using errcode = '42501'; end if;
  if p_school_id is null or p_subject_id is null then raise exception 'Datos de eliminación incompletos' using errcode = '22023'; end if;
  if not exists (select 1 from public.subjects where id = p_subject_id and school_id = p_school_id) then
    raise exception 'La asignatura no existe o pertenece a otra institución' using errcode = '42501';
  end if;
  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or (not public.has_tenant_permission('subjects.delete') and not public.has_tenant_permission('settings.manage'))
  ) then
    raise exception 'No tienes permiso para eliminar asignaturas' using errcode = '42501';
  end if;
  if exists (select 1 from public.course_subjects cs where cs.school_id = p_school_id and cs.subject_id = p_subject_id) then
    raise exception 'La asignatura sigue vinculada a uno o más cursos. Retírala de esos cursos antes de eliminarla.' using errcode = 'P0001';
  end if;
  delete from public.subjects where id = p_subject_id and school_id = p_school_id;
  get diagnostics v_deleted = row_count;
  if v_deleted <> 1 then raise exception 'La base de datos no confirmó la eliminación de la asignatura'; end if;
  insert into public.audit_log(school_id, user_id, action, table_name, record_id)
  values (p_school_id, auth.uid(), 'SUBJECT_DELETED', 'subjects', p_subject_id::text);
  return jsonb_build_object('success', true, 'school_id', p_school_id, 'subject_id', p_subject_id, 'deleted_count', 1);
end;
$$;

revoke all on function public.save_subject_record(uuid, uuid, text) from public, anon;
revoke all on function public.import_subjects_batch(uuid, text[]) from public, anon;
revoke all on function public.delete_subject_record(uuid, uuid) from public, anon;
grant execute on function public.save_subject_record(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.import_subjects_batch(uuid, text[]) to authenticated, service_role;
grant execute on function public.delete_subject_record(uuid, uuid) to authenticated, service_role;
revoke insert, update, delete on public.subjects from authenticated;
