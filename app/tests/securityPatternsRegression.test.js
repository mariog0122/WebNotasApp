import { describe, expect, it } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

const workspaceRoot = path.resolve(import.meta.dirname, '../..')
const read = (file) => fs.readFileSync(path.join(workspaceRoot, file), 'utf8')

describe('similar security pattern remediation', () => {
  it('guards grade writes by permission, assignment and unlocked period', () => {
    const sql = read('supabase/migrations/20260909140502_harden_grades_authorization.sql')
    expect(sql).toContain("public.can_access_student(student_id, 'grades.read')")
    expect(sql).toContain('public.can_manage_grade(')
    expect(sql).toContain("gd.quarter_id, 'grades.update'")
    expect(sql).not.toContain('or (school_id is null')
    expect(sql).toContain('alter column school_id set not null')
  })

  it('keeps billing proofs private and records them only through an authorized RPC', () => {
    const sql = read('supabase/migrations/20260909143412_harden_billing_proof_access.sql')
    const profile = read('app/src/views/Profile.vue')

    expect(sql).toMatch(/set public\s*=\s*false/)
    expect(sql).toContain("public.has_tenant_permission('billing.manage')")
    expect(sql).toContain("private.can_access_billing_proof(name, 'billing.read')")
    expect(sql).toContain('revoke all on function public.upload_tenant_payment_proof')
    expect(sql).toContain('from public, anon')
    expect(profile).toContain("rpc('upload_tenant_payment_proof'")
    expect(profile).not.toMatch(/from\('tenant_billing_profiles'\)[\s\S]{0,300}\.upsert\(/)
  })

  it('validates tenant ownership in both course-copy RPC overloads', () => {
    const sql = read('supabase/migrations/20260909155901_harden_course_copy_authorization.sql')
    expect(sql).toContain('source_year.school_id <> target_year.school_id')
    expect(sql).toContain('actor_school_id is distinct from source_year.school_id')
    expect(sql).toContain("public.has_tenant_permission('settings.manage')")
    expect(sql).toContain('source_course.tutor_name')
    expect(sql).toContain('from public, anon')
  })

  it('restores missing RLS policies and removes anonymous definer access', () => {
    const sql = read('supabase/migrations/20260909165234_resolve_security_advisor_warnings.sql')
    expect(sql).toContain('create policy invoices_select')
    expect(sql).toContain('create policy lesson_plan_versions_insert')
    expect(sql).toContain('create policy student_support_events_insert')
    expect(sql).toContain('revoke all on function public.save_teacher_report(jsonb)')
    expect(sql).toContain('alter function private.touch_lesson_plans_updated_at()')
    expect(sql).toContain('set search_path = pg_catalog, public, private')
  })

  it('removes permissive policy bypasses and redundant indexes', () => {
    const sql = read('supabase/migrations/20260909172714_consolidate_policies_and_indexes.sql')
    expect(sql).toContain('alter column school_id set not null')
    expect(sql).toContain("public.has_tenant_permission('settings.manage')")
    expect(sql).toContain('drop policy if exists courses_insert_policy')
    expect(sql).toContain('create policy institution_ai_settings_insert')
    expect(sql).toContain('drop index if exists public.idx_grades_student_definition')
    expect(sql).toContain('drop index if exists public.idx_payments_school_id')
  })

  it('caches auth.uid in RLS policies and covers remaining foreign keys', () => {
    const sql = read('supabase/migrations/20260909174316_optimize_rls_and_foreign_keys.sql')
    expect(sql).toContain("replace(v_policy.qual, 'auth.uid()', '(SELECT auth.uid())')")
    expect(sql).toContain('idx_fk_attendance_records_teacher_id')
    expect(sql).toContain('idx_fk_lesson_plan_versions_created_by')
    expect(sql).toContain('idx_fk_student_support_events_support_plan_id')
    expect(sql).toContain('idx_fk_teacher_reports_subject_id')
  })
})
