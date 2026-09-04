const courseStudentsKey = ({ courseId, schoolId }) => `${schoolId || 'global'}:${courseId}`

export const createCourseStudentsLoader = (fetchStudents) => {
  const cache = new Map()
  const inFlight = new Map()

  const load = ({ courseId, schoolId }) => {
    const key = courseStudentsKey({ courseId, schoolId })

    if (cache.has(key)) return Promise.resolve(cache.get(key))
    if (inFlight.has(key)) return inFlight.get(key)

    const request = Promise.resolve(fetchStudents({ courseId, schoolId }))
      .then((students) => {
        const result = students || []
        cache.set(key, result)
        return result
      })
      .finally(() => inFlight.delete(key))

    inFlight.set(key, request)
    return request
  }

  const invalidate = ({ courseId, schoolId } = {}) => {
    if (!courseId) {
      cache.clear()
      inFlight.clear()
      return
    }
    const key = courseStudentsKey({ courseId, schoolId })
    cache.delete(key)
    inFlight.delete(key)
  }

  return { load, invalidate }
}

export const loadGradeSheetPrerequisites = async ({
  loadStudents,
  ensureDefinitions,
  onStudents,
}) => {
  const studentsPromise = Promise.resolve(loadStudents()).then((students) => {
    const result = students || []
    onStudents?.(result)
    return result
  })

  const [students, definitionsReady] = await Promise.all([
    studentsPromise,
    Promise.resolve(ensureDefinitions()),
  ])

  return { students, definitionsReady }
}

export const createLatestRequestGuard = () => {
  let currentRequest = 0

  return {
    next() {
      currentRequest += 1
      return currentRequest
    },
    invalidate() {
      currentRequest += 1
    },
    isCurrent(requestId) {
      return requestId === currentRequest
    },
  }
}
