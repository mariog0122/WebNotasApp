import { describe, expect, it } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

const sourceRoot = path.resolve(import.meta.dirname, '../src')
const workspaceRoot = path.resolve(import.meta.dirname, '../..')

const walkSourceFiles = directory => fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
  const absolutePath = path.join(directory, entry.name)
  if (entry.isDirectory()) return walkSourceFiles(absolutePath)
  return /\.(?:js|ts|vue)$/.test(entry.name) ? [absolutePath] : []
})

describe('tenant isolation regression', () => {
  it('never treats tenant-less operational rows as shared application data', () => {
    const violations = walkSourceFiles(sourceRoot)
      .filter(file => fs.readFileSync(file, 'utf8').includes('school_id.is.null'))
      .map(file => path.relative(sourceRoot, file))

    expect(violations).toEqual([])
  })

  it('keeps the reusable student query tied to the authenticated access context', () => {
    const source = fs.readFileSync(path.join(sourceRoot, 'composables/useQueries.js'), 'utf8')
    const studentQuery = source.slice(
      source.indexOf('export function useStudentsQuery'),
      source.indexOf('export function useSubjectsQuery'),
    )

    expect(studentQuery).toContain('const authStore = useAuthStore()')
    expect(studentQuery).toContain(".eq('school_id', schoolId.value)")
    expect(studentQuery).toContain('assignedLinksError')
  })

  it('blocks new orphaned rows without silently assigning legacy data', () => {
    const migration = fs.readFileSync(
      path.join(workspaceRoot, 'supabase/migrations/20260919150500_enforce_core_tenant_ownership.sql'),
      'utf8',
    )

    expect(migration).toContain('check (school_id is not null) not valid')
    expect(migration).toContain('where school_id is null')
    expect(migration).not.toMatch(/update\s+public\.[a-z_]+\s+set\s+school_id/i)
  })
})
