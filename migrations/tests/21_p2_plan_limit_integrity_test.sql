begin;

do $$
declare
  v_school_id uuid;
  v_limit integer;
  v_rejected boolean := false;
begin
  select tl.school_id, tl.max_students
    into v_school_id, v_limit
  from public.tenant_limits tl
  limit 1;

  if v_school_id is null then
    raise exception 'Expected at least one tenant limit row';
  end if;

  begin
    update public.tenant_limits
    set max_students = v_limit + 1
    where school_id = v_school_id;
  exception
    when sqlstate 'P0001' then
      if sqlerrm = 'PLAN_STUDENT_LIMIT_IMMUTABLE' then
        v_rejected := true;
      else
        raise;
      end if;
  end;

  if not v_rejected then
    raise exception 'Expected plan student limit override to be rejected';
  end if;

  if (select max_students from public.tenant_limits where school_id = v_school_id) <> v_limit then
    raise exception 'Student limit changed after rejected override';
  end if;
end $$;

rollback;
