create table if not exists public.edge_function_error_events (
  id uuid primary key default gen_random_uuid(),
  function_name text not null check (function_name ~ '^[a-z0-9-]{1,80}$'),
  error_message text not null check (error_message ~ '^[A-Z0-9_]{1,80}$'),
  status_code integer not null check (status_code between 500 and 599),
  school_id uuid references public.schools(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb check (octet_length(metadata::text) <= 2048),
  occurred_at timestamptz not null default now()
);

create index if not exists idx_edge_function_errors_name_time
  on public.edge_function_error_events (function_name, occurred_at desc);
create index if not exists idx_edge_function_errors_time
  on public.edge_function_error_events (occurred_at desc);

alter table public.edge_function_error_events enable row level security;
alter table public.edge_function_error_events force row level security;

drop policy if exists edge_function_errors_platform_select on public.edge_function_error_events;
create policy edge_function_errors_platform_select on public.edge_function_error_events
for select to authenticated using (public.is_platform_admin());

revoke all on public.edge_function_error_events from public, anon, authenticated;
grant select on public.edge_function_error_events to authenticated;
grant all on public.edge_function_error_events to service_role;

create or replace function public.record_edge_function_error(
  p_function_name text,
  p_error_message text,
  p_status_code integer default 500,
  p_school_id uuid default null,
  p_user_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security invoker
set search_path = pg_catalog, public as $$
declare
  new_id uuid;
  recent_count integer;
begin
  if p_function_name is null or p_function_name !~ '^[a-z0-9-]{1,80}$'
    or p_error_message is null or p_error_message !~ '^[A-Z0-9_]{1,80}$'
    or p_status_code not between 500 and 599
    or p_metadata is null or octet_length(p_metadata::text) > 2048 then
    raise exception 'INVALID_EDGE_ERROR_EVENT' using errcode = '22023';
  end if;

  insert into public.edge_function_error_events (
    function_name, error_message, status_code, school_id, user_id, metadata
  ) values (
    p_function_name, p_error_message, p_status_code, p_school_id, p_user_id, p_metadata
  ) returning id into new_id;

  select count(*) into recent_count
  from public.edge_function_error_events
  where function_name = p_function_name
    and status_code >= 500
    and occurred_at >= now() - interval '15 minutes';

  if recent_count = 5 then
    insert into public.audit_log (school_id, user_id, action, table_name, record_id, new_values)
    values (
      p_school_id, p_user_id, 'EDGE_FUNCTION_BURST_ALERT', 'edge_function_error_events', new_id::text,
      jsonb_build_object('function_name', p_function_name, 'recent_errors_15m', recent_count, 'alert_level', 'CRITICAL')
    );
  end if;

  return jsonb_build_object('id', new_id, 'alert_triggered', recent_count >= 5, 'recent_count_15m', recent_count);
end;
$$;

revoke all on function public.record_edge_function_error(text,text,integer,uuid,uuid,jsonb)
  from public, anon, authenticated;
grant execute on function public.record_edge_function_error(text,text,integer,uuid,uuid,jsonb)
  to service_role;

notify pgrst, 'reload schema';
