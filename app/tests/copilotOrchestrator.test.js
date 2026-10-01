import { beforeEach, describe, expect, it, vi } from 'vitest'
import { LogrevaCopilotOrchestrator } from '../src/lib/ai/agents/LogrevaCopilotOrchestrator'
import { supabase } from '../src/lib/supabase'

vi.mock('../src/lib/supabase', () => ({ supabase: { from: vi.fn() } }))
let queries, results
const access = () => ({ userId: 'user-a', activeSchoolId: 'school-a', activeMembership: {
  role: 'teacher', permissions: ['attendance.read', 'grades.read', 'students.read'],
} })
const agent = (extra = {}) => new LogrevaCopilotOrchestrator({
  schoolId: 'school-a', userId: 'user-a', academicYear: '2026-2027', accessContext: access(), ...extra,
})
beforeEach(() => {
  queries = []; results = {}
  supabase.from.mockImplementation(table => {
    const calls = []
    queries.push({ table, calls })
    const query = { then: (resolve, reject) => Promise.resolve(results[table] || { data: [], count: 0, error: null }).then(resolve, reject) }
    for (const op of ['select', 'eq', 'in', 'order', 'limit']) query[op] = (...args) => { calls.push([op, ...args]); return query }
    return query
  })
})

describe('copilot uses actual records and never invents institutional data', () => {
  it('reports zero when there are no attendance records', async () => {
    expect(await agent().getAttendanceSummary('2026-09-10')).toMatchObject({ totalAbsences: 0, details: [] })
  })
  it('fails closed without an institution or authenticated context', async () => {
    await expect(agent({ schoolId: null }).getAttendanceSummary()).rejects.toThrow()
    await expect(agent({ accessContext: null }).getActiveCourses()).rejects.toThrow()
    expect(queries).toEqual([])
  })
  it('does not turn a database outage into a successful empty result', async () => {
    results.attendance_records = { data: null, error: { message: 'offline' } }
    await expect(agent().getAttendanceSummary()).rejects.toThrow()
  })
  it('uses the real attendance schema and counts events beyond the displayed sample', async () => {
    results.attendance_records = { data: [{ status: 'atraso', student: { full_name: 'Alumno sintético' }, course: { name: 'Curso sintético' } }], count: 23, error: null }
    const summary = await agent().getAttendanceSummary('2026-09-10')
    expect(summary.totalAbsences).toBe(23)
    expect(summary.details).toEqual([{ student: 'Alumno sintético', course: 'Curso sintético', status: 'Atraso' }])
    expect(queries[0].calls).toContainEqual(['eq', 'attendance_date', '2026-09-10'])
    expect(queries[0].calls).toContainEqual(['eq', 'school_id', 'school-a'])
    expect(queries[0].calls).toContainEqual(['eq', 'academic_year', '2026-2027'])
    expect(queries[0].calls).toContainEqual(['eq', 'teacher_id', 'user-a'])
    expect(summary.summary).toContain('registros')
  })
  it('uses the institutional civil date instead of the next UTC day', async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-09-11T02:00:00Z'))
    try { expect((await agent().getAttendanceSummary()).date).toBe('2026-09-10') }
    finally { vi.useRealTimers() }
  })
  it('does not let a presentation role grant permissions', async () => {
    const bot = agent({ accessContext: { ...access(), activeMembership: { role: 'parent', permissions: [] } } })
    bot.setRole('Rectorado')
    await expect(bot.getAttendanceSummary()).rejects.toThrow()
    expect(queries).toEqual([])
  })
  it('returns no courses when the teacher has no assignments', async () => {
    expect(await agent().getActiveCourses()).toEqual([])
  })
  it('uses assigned courses in the selected academic year without invented enrolment', async () => {
    results.course_subjects = { data: [{ course_id: 'c1' }], error: null }
    results.courses = { data: [{ id: 'c1', name: 'Curso A', level: 'EGB' }], error: null }
    expect(await agent().getActiveCourses()).toEqual([{ id: 'c1', name: 'Curso A', level: 'EGB' }])
    const courseQuery = queries.find(q => q.table === 'courses')
    expect(courseQuery.calls).toContainEqual(['in', 'id', ['c1']])
    expect(courseQuery.calls).toContainEqual(['eq', 'academic_year', '2026-2027'])
    expect(courseQuery.calls.find(c => c[0] === 'select')[1]).not.toMatch(/parallel|shift/)
  })
  it('does not invent tasks or academic alerts without a connected source', async () => {
    expect((await agent().processQuery('tareas pendientes')).data).toBeUndefined()
    expect((await agent().processQuery('alertas académicas')).data).toBeUndefined()
  })
  it('recognizes students and keeps course keywords from swallowing notices or planning', async () => {
    expect((await agent().processQuery('buscar estudiantes')).actionRoute).toBe('/students')
    expect((await agent().processQuery('aviso para el curso')).type).toBe('notice')
    expect((await agent().processQuery('planificar unidad del curso')).type).toBe('planning')
  })
  it('does not claim an automatic message was sent or invent an event date', async () => {
    const response = await agent().processQuery('aviso para representantes')
    expect(response.message).not.toMatch(/un clic|despacharlo/)
    expect(JSON.stringify(response)).not.toMatch(/próximo viernes|2do BGU/)
  })
})
