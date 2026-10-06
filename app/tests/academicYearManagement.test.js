import { describe, expect, it } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'
import {
  canCreateAcademicYear,
  hasAccessPermission,
} from '../src/lib/permissions'
import {
  buildAcademicYearCreateArgs,
  parseAcademicYearName,
} from '../src/lib/academicYears'

const appRoot = path.resolve(import.meta.dirname, '..')
const workspaceRoot = path.resolve(appRoot, '..')
const readApp = (file) => fs.readFileSync(path.join(appRoot, file), 'utf8')
const readWorkspace = (file) => fs.readFileSync(path.join(workspaceRoot, file), 'utf8')

describe('academic year management authorization', () => {
  const context = (role, permissions = []) => ({
    isPlatformAdmin: false,
    isPlatformOwner: false,
    activeSchoolId: 'school-a',
    activeMembership: { schoolId: 'school-a', role, permissions },
    raw: {},
  })

  it('uses semantic create permission and denies a teacher', () => {
    expect(canCreateAcademicYear(context('school_admin', ['academic_year.create']))).toBe(true)
    expect(canCreateAcademicYear(context('rector', ['academic_year.create']))).toBe(true)
    expect(canCreateAcademicYear(context('teacher', ['academic_year.read']))).toBe(false)
    expect(hasAccessPermission(context('teacher', ['academic_year.read']), 'academic_year.create')).toBe(false)
  })

  it('keeps platform administrators authorized', () => {
    expect(canCreateAcademicYear({ isPlatformAdmin: true, activeMembership: null, raw: {} })).toBe(true)
  })
})

describe('academic year creation contract', () => {
  it('parses and validates the canonical YYYY-YYYY name', () => {
    expect(parseAcademicYearName('2027-2028')).toEqual({
      name: '2027-2028',
      startYear: 2027,
      endYear: 2028,
    })
    expect(() => parseAcademicYearName('2028-2027')).toThrow('posterior')
    expect(() => parseAcademicYearName('próximo')).toThrow('YYYY-YYYY')
  })

  it('does not send a tenant school id for a tenant administrator', () => {
    expect(buildAcademicYearCreateArgs('2027-2028', false, null)).toEqual({
      p_name: '2027-2028',
      p_start_year: 2027,
      p_end_year: 2028,
      p_make_current: false,
    })
  })

  it('sends the selected school only for a platform administrator', () => {
    expect(buildAcademicYearCreateArgs('2027-2028', true, 'school-a')).toEqual({
      p_name: '2027-2028',
      p_start_year: 2027,
      p_end_year: 2028,
      p_make_current: true,
      p_school_id: 'school-a',
    })
  })
})

describe('academic year integration regression', () => {
  it('defines the Courses authorization flag and creates through the guarded RPC', () => {
    const courses = readApp('src/views/Courses.vue')
    const store = readApp('src/stores/academicYear.js')
    expect(courses).toContain('const canCreateYear = computed')
    expect(courses).toContain('v-if="canCreateYear"')
    expect(store).toContain("rpc('create_academic_year'")
    expect(store).not.toMatch(/\.from\(['"]academic_years['"]\)\s*\n\s*\.insert\(/)
  })

  it('fails closed when the lock RPC fails and never updates the table directly', () => {
    const store = readApp('src/stores/academicYear.js')
    expect(store).toContain("rpc('toggle_academic_year_lock'")
    expect(store).not.toContain('RPC toggle_academic_year_lock no disponible')
    expect(store).not.toMatch(/\.from\(['"]academic_years['"]\)\s*\n\s*\.update\(\{\s*is_locked:/)
    expect(store).toContain('El servidor no confirmó el cambio de bloqueo del año lectivo.')
  })

  it('ships tenant-safe RLS, constraints, idempotency and audit logging', () => {
    const migration = readWorkspace('supabase/migrations/20260909032539_secure_academic_year_management.sql')
    expect(migration).toContain("has_tenant_permission('academic_year.create')")
    expect(migration).toContain("has_tenant_permission('academic_year.update')")
    expect(migration).toContain('academic_years_valid_year_range')
    expect(migration).toContain('academic_years_one_current_per_school')
    expect(migration).toContain('create or replace function public.create_academic_year')
    expect(migration).toContain('pg_advisory_xact_lock')
    expect(migration).toContain("insert into public.audit_log")
    expect(migration).toContain('revoke all on public.academic_years from anon')
  })
})
