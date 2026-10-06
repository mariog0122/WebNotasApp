-- Prevent new tenant-owned academic records from being created without a school.
-- Existing orphaned rows are never reassigned automatically: when present, the
-- NOT VALID check blocks new invalid writes while preserving the legacy row for
-- an explicit, audited data-repair decision.

do $$
declare
  v_table text;
  v_constraint text;
  v_orphan_count bigint;
begin
  foreach v_table in array array[
    'academic_years',
    'courses',
    'quarters',
    'subjects',
    'students',
    'system_config',
    'grade_definitions',
    'course_subjects',
    'grades',
    'attendance_records',
    'student_alerts',
    'teacher_reports'
  ]
  loop
    if not exists (
      select 1
      from pg_catalog.pg_attribute a
      where a.attrelid = format('public.%I', v_table)::regclass
        and a.attname = 'school_id'
        and not a.attisdropped
    ) then
      continue;
    end if;

    if exists (
      select 1
      from pg_catalog.pg_attribute a
      where a.attrelid = format('public.%I', v_table)::regclass
        and a.attname = 'school_id'
        and a.attnotnull
        and not a.attisdropped
    ) then
      continue;
    end if;

    v_constraint := v_table || '_school_id_required';

    if not exists (
      select 1
      from pg_catalog.pg_constraint c
      where c.conrelid = format('public.%I', v_table)::regclass
        and c.conname = v_constraint
    ) then
      execute format(
        'alter table public.%I add constraint %I check (school_id is not null) not valid',
        v_table,
        v_constraint
      );
    end if;

    execute format('select count(*) from public.%I where school_id is null', v_table)
      into v_orphan_count;

    if v_orphan_count = 0 then
      execute format('alter table public.%I validate constraint %I', v_table, v_constraint);
      execute format('alter table public.%I alter column school_id set not null', v_table);
      execute format('alter table public.%I drop constraint %I', v_table, v_constraint);
    else
      raise notice '% retains % legacy row(s) without school_id; new invalid rows are blocked until audited attribution',
        v_table,
        v_orphan_count;
    end if;
  end loop;
end
$$;

