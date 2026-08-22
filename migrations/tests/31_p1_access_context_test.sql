begin;

do $test$
declare
  v_user_id uuid;
  v_context jsonb;
  v_is_security_definer boolean;
  v_search_path text;
begin
  select upr.user_id
    into v_user_id
  from public.user_platform_roles upr
  join public.platform_roles pr on pr.id = upr.platform_role_id
  where pr.name::text = 'platform_owner'
  limit 1;

  if v_user_id is null then
    raise exception 'Test precondition failed: platform owner not found';
  end if;

  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_user_id::text, true);
  perform set_config('role', 'authenticated', true);

  select public.get_my_access_context() into v_context;

  if v_context->>'user_id' <> v_user_id::text then
    raise exception 'Access context returned the wrong user';
  end if;
  if coalesce((v_context->>'is_platform_admin')::boolean, false) is not true then
    raise exception 'Platform owner was not recognized as platform admin';
  end if;
  if coalesce((v_context->>'is_platform_owner')::boolean, false) is not true then
    raise exception 'Platform owner was not recognized as owner';
  end if;
  if not coalesce(v_context->'platform_roles', '[]'::jsonb) ? 'platform_owner' then
    raise exception 'Platform role is missing from access context';
  end if;
  if jsonb_typeof(v_context->'memberships') <> 'array' then
    raise exception 'Memberships must be returned as an array';
  end if;

  select p.prosecdef,
         coalesce(array_to_string(p.proconfig, ','), '')
    into v_is_security_definer, v_search_path
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_my_access_context';

  if v_is_security_definer is true then
    raise exception 'Access context RPC must remain SECURITY INVOKER';
  end if;
  if v_search_path not like '%search_path=""%' and v_search_path not like '%search_path=%' then
    raise exception 'Access context RPC must pin an empty search_path';
  end if;
end
$test$;

rollback;
