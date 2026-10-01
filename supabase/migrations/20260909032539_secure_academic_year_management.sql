-- Gestión segura y multi-institución de años lectivos.
-- La institución de un usuario tenant siempre se obtiene de auth.uid().

insert into public.permissions (code, module, description)
values
  ('academic_year.read', 'academic_year', 'Consultar años lectivos de la institución'),
  ('academic_year.create', 'academic_year', 'Crear años lectivos en la institución'),
  ('academic_year.update', 'academic_year', 'Editar y bloquear años lectivos'),
  ('academic_year.activate', 'academic_year', 'Definir el año lectivo vigente'),
  ('academic_year.close', 'academic_year', 'Cerrar años lectivos'),
  ('academic_year.delete', 'academic_year', 'Eliminar años lectivos sin dependencias')
on conflict (code) do update
set module = excluded.module,
    description = excluded.description;

insert into public.role_permissions (tenant_role_id, permission_id)
select tr.id, p.id
from public.tenant_roles tr
cross join public.permissions p
where tr.name in ('school_admin', 'rector')
  and p.code in (
    'academic_year.read', 'academic_year.create', 'academic_year.update',
    'academic_year.activate', 'academic_year.close', 'academic_year.delete'
  )
on conflict do nothing;

-- Todos los perfiles institucionales conservan la lectura que ya tenían.
insert into public.role_permissions (tenant_role_id, permission_id)
select tr.id, p.id
from public.tenant_roles tr
join public.permissions p on p.code = 'academic_year.read'
on conflict do nothing;

alter table public.academic_years
  add column if not exists is_locked boolean not null default false;

alter table public.academic_years
  alter column school_id set not null,
  alter column start_year set not null,
  alter column end_year set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.academic_years'::regclass
      and conname = 'academic_years_valid_year_range'
  ) then
    alter table public.academic_years
      add constraint academic_years_valid_year_range
      check (end_year > start_year);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.academic_years'::regclass
      and conname = 'academic_years_canonical_name'
  ) then
    alter table public.academic_years
      add constraint academic_years_canonical_name
      check (name = start_year::text || '-' || end_year::text);
  end if;
end
$$;

create unique index if not exists academic_years_one_current_per_school
  on public.academic_years (school_id)
  where is_current;

revoke all on public.academic_years from anon;
revoke truncate, references, trigger on public.academic_years from authenticated;
grant select, insert, update, delete on public.academic_years to authenticated;

alter table public.academic_years enable row level security;

drop policy if exists academic_years_select on public.academic_years;
drop policy if exists academic_years_insert on public.academic_years;
drop policy if exists academic_years_update on public.academic_years;
drop policy if exists academic_years_delete on public.academic_years;
drop policy if exists academic_years_manage on public.academic_years;

create policy academic_years_select
on public.academic_years for select to authenticated
using (
  public.is_platform_admin()
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('academic_year.read')
  )
);

create policy academic_years_insert
on public.academic_years for insert to authenticated
with check (
  public.is_platform_admin()
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('academic_year.create')
  )
);

create policy academic_years_update
on public.academic_years for update to authenticated
using (
  public.is_platform_admin()
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('academic_year.update')
  )
)
with check (
  public.is_platform_admin()
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('academic_year.update')
  )
);

create policy academic_years_delete
on public.academic_years for delete to authenticated
using (
  public.is_platform_admin()
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('academic_year.delete')
  )
);

create or replace function private.audit_academic_year_changes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_row public.academic_years;
begin
  if tg_op = 'DELETE' then
    v_row := old;
  else
    v_row := new;
  end if;

  insert into public.audit_log (
    school_id, user_id, action, table_name, record_id, old_values, new_values
  ) values (
    v_row.school_id,
    auth.uid(),
    case tg_op
      when 'INSERT' then 'ACADEMIC_YEAR_CREATED'
      when 'UPDATE' then 'ACADEMIC_YEAR_UPDATED'
      when 'DELETE' then 'ACADEMIC_YEAR_DELETED'
    end,
    'academic_years',
    v_row.id::text,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists audit_academic_year_changes on public.academic_years;
create trigger audit_academic_year_changes
after insert or update or delete on public.academic_years
for each row execute function private.audit_academic_year_changes();

create or replace function public.create_academic_year(
  p_name text,
  p_start_year integer,
  p_end_year integer,
  p_make_current boolean default false,
  p_school_id uuid default null
)
returns public.academic_years
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_school_id uuid;
  v_name text := btrim(coalesce(p_name, ''));
  v_existing public.academic_years;
  v_created public.academic_years;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;

  if public.is_platform_admin() then
    v_school_id := coalesce(p_school_id, public.get_user_school_id());
  else
    v_school_id := public.get_user_school_id();
    if not public.has_tenant_permission('academic_year.create') then
      raise exception 'No tienes permiso para crear años lectivos' using errcode = '42501';
    end if;
  end if;

  if v_school_id is null then
    raise exception 'No se pudo determinar la institución activa' using errcode = '22023';
  end if;

  if v_name !~ '^[0-9]{4}-[0-9]{4}$' then
    raise exception 'Usa el formato YYYY-YYYY' using errcode = '22023';
  end if;
  if p_start_year is null or p_end_year is null or p_end_year <= p_start_year then
    raise exception 'El año de fin debe ser posterior al año de inicio' using errcode = '22023';
  end if;
  if v_name <> (p_start_year::text || '-' || p_end_year::text) then
    raise exception 'El nombre no coincide con el rango indicado' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_school_id::text, 0));

  select ay.* into v_existing
  from public.academic_years ay
  where ay.school_id = v_school_id and ay.name = v_name;

  if found then
    if v_existing.start_year <> p_start_year or v_existing.end_year <> p_end_year then
      raise exception 'Ya existe un año lectivo con ese nombre y otro rango' using errcode = '23505';
    end if;

    if p_make_current and not v_existing.is_current then
      update public.academic_years
      set is_current = false
      where school_id = v_school_id and is_current;

      update public.academic_years
      set is_current = true, is_active = true
      where id = v_existing.id
      returning * into v_existing;
    end if;

    return v_existing;
  end if;

  if p_make_current then
    update public.academic_years
    set is_current = false
    where school_id = v_school_id and is_current;
  end if;

  insert into public.academic_years (
    school_id, name, start_year, end_year, is_active, is_current, is_locked
  ) values (
    v_school_id, v_name, p_start_year, p_end_year,
    p_make_current, p_make_current, false
  )
  returning * into v_created;

  return v_created;
end;
$$;

create or replace function public.set_academic_year_current(target_year_id uuid)
returns public.academic_years
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_target public.academic_years;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;

  select * into v_target from public.academic_years where id = target_year_id;
  if not found then raise exception 'Año lectivo no encontrado' using errcode = 'P0002'; end if;

  if not public.is_platform_admin() and (
    v_target.school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('academic_year.activate')
  ) then
    raise exception 'No tienes permiso para activar este año lectivo' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_target.school_id::text, 0));
  update public.academic_years set is_current = false
  where school_id = v_target.school_id and is_current and id <> target_year_id;
  update public.academic_years set is_current = true, is_active = true
  where id = target_year_id returning * into v_target;
  return v_target;
end;
$$;

create or replace function public.close_academic_year(target_year_id uuid)
returns public.academic_years
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_target public.academic_years;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  select * into v_target from public.academic_years where id = target_year_id;
  if not found then raise exception 'Año lectivo no encontrado' using errcode = 'P0002'; end if;
  if not public.is_platform_admin() and (
    v_target.school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('academic_year.close')
  ) then
    raise exception 'No tienes permiso para cerrar este año lectivo' using errcode = '42501';
  end if;
  update public.academic_years
  set is_current = false, is_active = false, is_locked = true
  where id = target_year_id returning * into v_target;
  return v_target;
end;
$$;

create or replace function public.toggle_academic_year_lock(
  target_year_id uuid,
  lock_status boolean
)
returns public.academic_years
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_target public.academic_years;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  select * into v_target from public.academic_years where id = target_year_id;
  if not found then raise exception 'Año lectivo no encontrado' using errcode = 'P0002'; end if;
  if not public.is_platform_admin() and (
    v_target.school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('academic_year.update')
  ) then
    raise exception 'No tienes permiso para bloquear este año lectivo' using errcode = '42501';
  end if;
  update public.academic_years set is_locked = lock_status
  where id = target_year_id returning * into v_target;
  return v_target;
end;
$$;

revoke all on function public.create_academic_year(text, integer, integer, boolean, uuid) from public, anon;
revoke all on function public.set_academic_year_current(uuid) from public, anon;
revoke all on function public.close_academic_year(uuid) from public, anon;
revoke all on function public.toggle_academic_year_lock(uuid, boolean) from public, anon;
grant execute on function public.create_academic_year(text, integer, integer, boolean, uuid) to authenticated, service_role;
grant execute on function public.set_academic_year_current(uuid) to authenticated, service_role;
grant execute on function public.close_academic_year(uuid) to authenticated, service_role;
grant execute on function public.toggle_academic_year_lock(uuid, boolean) to authenticated, service_role;
