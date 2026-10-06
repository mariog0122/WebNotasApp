-- =============================================================================
-- LOGREVA — ENDURECIMIENTO PENDIENTE (ejecutar DESPUÉS de subir el zip nuevo)
-- Proyecto Supabase: ykokuwkvplifbjxgdveu ("Logreva")
--
-- Contexto (2026-10-01): se aplicaron en producción las funciones de las
-- migraciones del 16 y 19 de septiembre. Las sentencias de este archivo se
-- aplazaron A PROPÓSITO porque quitan la escritura directa sobre tablas y
-- romperían la versión ANTERIOR de la app (la que aún esté en Hostinger).
-- La versión nueva escribe solo mediante las funciones ya creadas.
--
-- Ejecutar solo cuando el zip nuevo ya esté publicado y probado.
-- Este archivo NO es una migración: el CLI de Supabase no lo aplica solo.
-- =============================================================================

begin;

-- 20260919190000_secure_grade_definition_rename
revoke update on public.grade_definitions from authenticated;

-- 20260919193000_secure_course_persistence
revoke insert, update on public.courses from authenticated;

-- 20260919194500_secure_subject_catalog
revoke insert, update, delete on public.subjects from authenticated;

-- 20260919200000_secure_default_quarter_creation
revoke insert, update, delete on public.quarters from authenticated;

-- 20260919203000_secure_institution_config
revoke insert, update, delete on public.system_config from authenticated;

-- 20260919210000_atomic_student_support_plan_creation
revoke insert on public.student_support_plans from authenticated;

-- 20260919213000_atomic_lesson_plan_version_save
revoke update on public.lesson_plans from authenticated;
revoke insert on public.lesson_plan_versions from authenticated;

-- 20260916030023_harden_student_wellbeing_authorization (corte de políticas)
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

-- 20260916023802_harden_teacher_reports_authorization (corte de políticas)
drop policy if exists teacher_reports_select on public.teacher_reports;
drop policy if exists teacher_reports_insert on public.teacher_reports;
drop policy if exists teacher_reports_update on public.teacher_reports;
drop policy if exists teacher_reports_delete on public.teacher_reports;

create policy teacher_reports_select on public.teacher_reports
for select to authenticated
using (public.can_read_teacher_report(school_id, teacher_id, course_id));

revoke insert, update, delete on table public.teacher_reports from authenticated;
grant select on table public.teacher_reports to authenticated;

commit;

notify pgrst, 'reload schema';
