import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const source = readFileSync(new URL('../src/composables/useGradesPage.js', import.meta.url), 'utf8')
const reports = readFileSync(new URL('../src/views/Reports.vue', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919184500_atomic_project_settings.sql', import.meta.url),
  'utf8',
)

describe('atomic project settings', () => {
  it('replaces project subjects through one confirmed RPC', () => {
    const block = source.slice(
      source.indexOf('const saveProjectSettings = async'),
      source.indexOf('const fetchProjectGrades = async'),
    )
    expect(block).toContain("rpc('save_project_settings_batch'")
    expect(block).toContain('Number(data.selected_count) !== subjectIds.length')
    expect(block).not.toContain("from('project_settings').insert")
    expect(block).not.toContain("from('project_settings')\n      .delete")
  })

  it('validates tenant, period, assignments and removal safety in the database', () => {
    expect(migration).toContain('create or replace function public.save_project_settings_batch')
    expect(migration).toContain("public.has_tenant_permission('grades.update')")
    expect(migration).toContain("public.has_tenant_permission('settings.manage')")
    expect(migration).toContain("public.has_tenant_permission('academic_year.update')")
    expect(migration).toContain('project_subject_grades')
    expect(migration).toContain('Elimina primero las notas del proyecto')
    expect(migration).toContain('pg_advisory_xact_lock')
    expect(migration).toContain("'PROJECT_SETTINGS_REPLACED'")
  })

  it('fails closed when either project read fails', () => {
    expect(source).toContain('projectSettingsAvailable.value = false')
    expect(source).toContain('projectGradesAvailable.value = false')
    expect(source).toContain('projectSettingsAvailable.value && projectGradesAvailable.value')
    expect(reports).toContain('if (psError && !isMissingProjectTableError(psError)) throw psError')
    expect(reports).toContain('if (pgError && !isMissingProjectTableError(pgError)) throw pgError')
  })
})
