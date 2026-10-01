import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const source = readFileSync(new URL('../src/composables/useGradesPage.js', import.meta.url), 'utf8')
const renameMigration = readFileSync(
  new URL('../../supabase/migrations/20260919190000_secure_grade_definition_rename.sql', import.meta.url),
  'utf8',
)

describe('grade definition initialization', () => {
  it('requires the authorized atomic RPC and never creates virtual writable definitions', () => {
    const ensureBlock = source.slice(
      source.indexOf('const ensureDefinitions'),
      source.indexOf('const getProjectAverage'),
    )

    expect(ensureBlock).toContain("rpc('ensure_default_grade_definitions'")
    expect(ensureBlock).toContain("if (error) throw error")
    expect(ensureBlock).toContain("if (!data?.success)")
    expect(ensureBlock).not.toContain("from('grade_definitions').insert")
    expect(source).not.toContain('virtual-def-')
  })

  it('requires the batch RPC to confirm a grade save before announcing success', () => {
    expect(source).toContain('if (!error && data?.success)')
    expect(source).toContain('Guardado no confirmado.')
  })

  it('renames a definition only through the authorized confirmed RPC', () => {
    const renameBlock = source.slice(
      source.indexOf('const saveHeader = async'),
      source.indexOf('return reactive({'),
    )
    expect(renameBlock).toContain("rpc('rename_grade_definition'")
    expect(renameBlock).toContain('El servidor no confirmó el cambio de nombre.')
    expect(renameBlock).not.toContain("from('grade_definitions')")
    expect(renameMigration).toContain('create or replace function public.rename_grade_definition')
    expect(renameMigration).toContain("public.has_tenant_permission('grades.update')")
    expect(renameMigration).toContain('not coalesce(q.is_locked, false)')
    expect(renameMigration).toContain('revoke update on public.grade_definitions from authenticated')
  })
})
