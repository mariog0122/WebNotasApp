import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const source = readFileSync(new URL('../src/composables/useGradesPage.js', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919180000_atomic_project_subject_grades.sql', import.meta.url),
  'utf8',
)

describe('project subject grade persistence', () => {
  it('uses one confirmed RPC without chunked deletes or direct upserts', () => {
    const block = source.slice(source.indexOf('const saveProjectGrades'), source.indexOf('const toggleProjectSubject'))
    expect(block).toContain("rpc('save_project_subject_grades_batch'")
    expect(block).toContain('Number(data.upserted) === upserts.length')
    expect(block).toContain('Number(data.deleted) === toDelete.length')
    expect(block).not.toContain("from('project_subject_grades')")
    expect(block).not.toContain('chunkSize')
  })

  it('validates tenant, permissions, score targets and complete row counts server-side', () => {
    expect(migration).toContain('create or replace function public.save_project_subject_grades_batch')
    expect(migration).toContain("public.has_tenant_permission('grades.update')")
    expect(migration).toContain('public.can_manage_project_score')
    expect(migration).toContain('join public.project_settings')
    expect(migration).toContain('not coalesce(q.is_locked, false)')
    expect(migration).toContain('pg_advisory_xact_lock')
    expect(migration).toContain('v_deleted <> v_delete_count or v_upserted <> v_upsert_count')
  })
})
