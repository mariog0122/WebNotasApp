import { describe, expect, it, vi } from 'vitest'

import {
  createCourseStudentsLoader,
  createLatestRequestGuard,
  loadGradeSheetPrerequisites,
} from '../src/lib/gradeSheetLoading.js'

const deferred = () => {
  let resolve
  let reject
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise
    reject = rejectPromise
  })
  return { promise, resolve, reject }
}

describe('grade sheet loading coordination', () => {
  it('reuses the same students request for a course and school', async () => {
    const fetchStudents = vi.fn().mockResolvedValue([{ id: 'student-1', full_name: 'Ana' }])
    const loader = createCourseStudentsLoader(fetchStudents)

    const [first, second] = await Promise.all([
      loader.load({ courseId: 'course-1', schoolId: 'school-1' }),
      loader.load({ courseId: 'course-1', schoolId: 'school-1' }),
    ])
    const third = await loader.load({ courseId: 'course-1', schoolId: 'school-1' })

    expect(fetchStudents).toHaveBeenCalledTimes(1)
    expect(first).toEqual(second)
    expect(third).toEqual(first)
  })

  it('loads students and definitions concurrently and publishes students first', async () => {
    const students = deferred()
    const definitions = deferred()
    const published = []
    const loadStudents = vi.fn(() => students.promise)
    const ensureDefinitions = vi.fn(() => definitions.promise)

    const loading = loadGradeSheetPrerequisites({
      loadStudents,
      ensureDefinitions,
      onStudents: (value) => published.push(value),
    })

    expect(loadStudents).toHaveBeenCalledTimes(1)
    expect(ensureDefinitions).toHaveBeenCalledTimes(1)

    students.resolve([{ id: 'student-1', full_name: 'Ana' }])
    await Promise.resolve()
    await Promise.resolve()

    expect(published).toEqual([[{ id: 'student-1', full_name: 'Ana' }]])

    definitions.resolve(true)
    await expect(loading).resolves.toEqual({
      students: [{ id: 'student-1', full_name: 'Ana' }],
      definitionsReady: true,
    })
  })

  it('invalidates older subject requests when a newer selection starts', () => {
    const guard = createLatestRequestGuard()
    const first = guard.next()
    const second = guard.next()

    expect(guard.isCurrent(first)).toBe(false)
    expect(guard.isCurrent(second)).toBe(true)

    guard.invalidate()
    expect(guard.isCurrent(second)).toBe(false)
  })
})
