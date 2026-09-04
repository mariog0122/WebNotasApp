import { ref, onMounted, watch, computed, reactive } from 'vue'
import { supabase } from '../lib/supabase'
import { translateError } from '../lib/errorDictionary'
import { toast } from 'vue-sonner'
import { getProjectValue as libGetProjectValue, calculateStudentAverages } from '../lib/gradingLogic'
import { useNetwork } from './useNetwork'
import { normalizeStoragePath, resolvePrivateImageUrl } from '../lib/storageUtils'
import { useAuthStore } from '../stores/auth'
import { useAcademicYearStore } from '../stores/academicYear'
import { isInstitutionAdmin } from '../lib/permissions'
import {
  createCourseStudentsLoader,
  createLatestRequestGuard,
  loadGradeSheetPrerequisites,
} from '../lib/gradeSheetLoading'

/** Inyeccion para subvistas del modulo de calificaciones */
export const gradesPageInjectionKey = Symbol('gradesPage')

export function useGradesPage() {
  // State
const courses = ref([])
const quarters = ref([])
const subjects = ref([]) // Subjects for the selected course
const { isOnline } = useNetwork()
const authStore = useAuthStore()
const academicYearStore = useAcademicYearStore()

const selectedCourse = ref(null)
const selectedQuarter = ref(null)
const isYearLocked = computed(() => academicYearStore.isLocked)
const activeQuarterIsLocked = computed(() => {
  if (isYearLocked.value && !isInstitutionAdmin(authStore.accessContext)) return true
  const current = quarters.value.find(q => q.id === selectedQuarter.value)
  return current ? !!current.is_locked : false
})
const activeSubjectId = ref(null) // The subject currently being graded (expanded)
const activeSubject = ref(null)
const studentsCount = ref(0)
const quartersLoading = ref(false)
const quartersError = ref('')
const subjectsError = ref('')
const institutionName = ref('')
const institutionLogoUrl = ref('')
const institutionTutorName = ref('')
const institutionRectorName = ref('')
const academicPeriods = ref('TRIMESTRE')

// Grade Management
const gradeDefinitions = ref([])
const students = ref([])
const grades = ref({}) // Map: student_id -> { definition_id: score }
const existingGradeKeys = ref(new Set())
const loadingStudents = ref(false)
const loadingGrades = ref(false)
const saving = ref(false)
const message = ref('')
/** Aviso no intrusivo (sustituye alert) cuando falta periodo u otros avisos de flujo */
const periodHint = ref('')

// Pagination state for students in the active grade sheet
const gradesPage = ref(1)
const gradesPageSize = 20
const paginatedStudents = computed(() => {
  const start = (gradesPage.value - 1) * gradesPageSize
  const end = start + gradesPageSize
  const list = students.value || []
  return list.slice(start, end)
})

// Memoize heavily used averages for all students to prevent rendering lag
const studentAveragesMap = computed(() => {
  const map = {}
  const subId = activeSubject.value?.subject_id
  students.value.forEach(stu => {
    map[stu.id] = getStudentAverages(stu.id, subId)
  })
  return map
})

const totalGradesPages = computed(() => Math.ceil((students.value?.length || 0) / gradesPageSize) || 1)
const setGradesPage = (p) => {
  if (p >= 1 && p <= totalGradesPages.value) gradesPage.value = p
}

const QUALITATIVE_OPTIONS = [
  { value: 'A+', label: 'A+ · Destreza o aprendizaje alcanzado' },
  { value: 'A-', label: 'A- · Destreza o aprendizaje alcanzado' },
  { value: 'B+', label: 'B+ · Destreza o aprendizaje en proceso de desarrollo' },
  { value: 'B-', label: 'B- · Destreza o aprendizaje en proceso de desarrollo' },
  { value: 'C+', label: 'C+ · Destreza o aprendizaje en proceso de desarrollo' },
  { value: 'C-', label: 'C- · Destreza o aprendizaje en proceso de desarrollo' },
  { value: 'D+', label: 'D+ · Destreza o aprendizaje iniciado' },
  { value: 'D-', label: 'D- · Destreza o aprendizaje iniciado' },
  { value: 'E+', label: 'E+ · Destreza o aprendizaje iniciado' },
  { value: 'E-', label: 'E- · Destreza o aprendizaje iniciado' }
]

const qualitativeScores = ref({})
const qualitativeExistingKeys = ref(new Set())
const qualitativeMessage = ref('')

// Global Project (per course + quarter)
const showProjectModal = ref(false)
const projectSubjects = ref(new Set())
const projectSubjectGrades = ref({})
const projectExistingKeys = ref(new Set())
const projectStudents = ref([])
const projectSaving = ref(false)
const projectMessage = ref('')
const projectAvailable = ref(true)

// Default Definitions (Excel layout)
const DEFAULT_DEFINITIONS = [
  // INDIVIDUAL (8 columns)
  { name: 'Lecciones 1', category: 'INDIVIDUAL', sort_order: 1 },
  { name: 'Lecciones 2', category: 'INDIVIDUAL', sort_order: 2 },
  { name: 'Pruebas 1', category: 'INDIVIDUAL', sort_order: 3 },
  { name: 'Pruebas 2', category: 'INDIVIDUAL', sort_order: 4 },
  { name: 'Tareas 1', category: 'INDIVIDUAL', sort_order: 5 },
  { name: 'Tareas 2', category: 'INDIVIDUAL', sort_order: 6 },
  { name: 'Proyectos 1', category: 'INDIVIDUAL', sort_order: 7 },
  { name: 'Proyectos 2', category: 'INDIVIDUAL', sort_order: 8 },

  // GRUPAL (8 columns)
  { name: 'Proyectos 1', category: 'GRUPAL', sort_order: 9 },
  { name: 'Proyectos 2', category: 'GRUPAL', sort_order: 10 },
  { name: 'Exposiciones 1', category: 'GRUPAL', sort_order: 11 },
  { name: 'Exposiciones 2', category: 'GRUPAL', sort_order: 12 },
  { name: 'Talleres 1', category: 'GRUPAL', sort_order: 13 },
  { name: 'Talleres 2', category: 'GRUPAL', sort_order: 14 },
  { name: 'Productos 1', category: 'GRUPAL', sort_order: 15 },
  { name: 'Productos 2', category: 'GRUPAL', sort_order: 16 },

  // REFUERZO (1 column)
  { name: 'Refuerzo Pedagogico', category: 'REFUERZO', sort_order: 17 },

  // SUMATIVA (2 columns)
  { name: 'Proyecto Interdisciplinario', category: 'SUMATIVA', sort_order: 18 },
  { name: 'Examen del Trimestre', category: 'SUMATIVA', sort_order: 19 },
]

// Modal for renaming
const showHeaderModal = ref(false)
const editingDefinition = ref(null)

onMounted(async () => {
  await fetchCourses()
  await fetchQuarters()
  await fetchInstitutionConfig()
})

// --- Data Fetching ---
const fetchCourses = async () => {
  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  let query = supabase.from('courses').select('id, name, level, track, academic_year').order('name')
  if (sId) {
    query = query.or(`school_id.eq.${sId},school_id.is.null`)
  }
  const yearName = academicYearStore.selectedYearName
  if (yearName) {
    query = query.eq('academic_year', yearName)
  }
  const { data } = await query
  let filteredCourses = data || []

  const userIds = [authStore.user?.id, authStore.profile?.id].filter(Boolean)
  const isAdmin = isInstitutionAdmin(authStore.accessContext)

  if (!isAdmin && userIds.length > 0) {
    const { data: assignedLinks } = await supabase
      .from('course_subjects')
      .select('course_id')
      .in('teacher_id', userIds)

    const assignedCourseIds = new Set((assignedLinks || []).map(l => l.course_id))
    filteredCourses = filteredCourses.filter(c => assignedCourseIds.has(c.id))
  }

  courses.value = filteredCourses
  if (selectedCourse.value && !courses.value.some(c => c.id === selectedCourse.value)) {
    selectedCourse.value = null
  }
}

watch(() => academicYearStore.selectedYearName, () => {
  fetchCourses()
})

const selectedCourseObj = computed(() => courses.value.find(c => c.id === selectedCourse.value))
const isQualitativeCourse = computed(() => {
  const level = selectedCourseObj.value?.level || ''
  return ['INICIAL', 'PREPARATORIA', 'ELEMENTAL'].includes(level)
})

const fetchInstitutionConfig = async () => {
  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!sId) return
  const { data, error } = await supabase
    .from('system_config')
    .select('key, value')
    .eq('school_id', sId)
    .in('key', ['institution_name', 'institution_logo_url', 'institution_tutor_name', 'institution_rector_name', 'academic_periods'])
  if (error) return
  const map = Object.fromEntries((data || []).map(item => [item.key, item.value]))
  institutionName.value = map.institution_name || ''
  institutionLogoUrl.value = await resolvePrivateImageUrl(
    supabase,
    'institution-assets',
    normalizeStoragePath(map.institution_logo_url, 'institution-assets'),
  ).catch(() => '')
  institutionTutorName.value = map.institution_tutor_name || ''
  institutionRectorName.value = map.institution_rector_name || ''
  academicPeriods.value = map.academic_periods || 'TRIMESTRE'
}

const fetchStudentsForCourse = async ({ courseId, schoolId }) => {
  let query = supabase
    .from('students')
    .select('id, full_name, representative_name, representative_cedula, representative_phone, student_address')
    .eq('course_id', courseId)
    .order('full_name')
  if (schoolId) {
    query = query.or(`school_id.eq.${schoolId},school_id.is.null`)
  }
  const { data, error } = await query
  if (error) throw error
  return data || []
}

const courseStudentsLoader = createCourseStudentsLoader(fetchStudentsForCourse)
const gradeSheetRequestGuard = createLatestRequestGuard()

const fetchCourseStudents = async (courseId) => {
  if (!courseId) {
    projectStudents.value = []
    return []
  }
  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  try {
    const data = await courseStudentsLoader.load({ courseId, schoolId: sId })
    projectStudents.value = data
    seedProjectGradeRows()
    return data
  } catch (error) {
    toast.error('Error cargando estudiantes', { description: translateError(error) })
    projectStudents.value = []
    return []
  }
}

/** Evita lecturas `projectSubjectGrades[studentId][...]` undefined entre awaits (render del modal de proyecto). */
const seedProjectGradeRows = () => {
  for (const s of projectStudents.value) {
    if (!projectSubjectGrades.value[s.id]) {
      projectSubjectGrades.value[s.id] = {}
    }
  }
}

const fetchQuarters = async () => {
    quartersLoading.value = true
    quartersError.value = ''
    try {
        // Timeout de seguridad para la carga de datos
        const sId = authStore.activeSchoolId || authStore.profile?.school_id
        let query = supabase.from('quarters').select('*').order('created_at')
        if (sId) {
          query = query.or(`school_id.eq.${sId},school_id.is.null`)
        }
        const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('Fetch Quarters Timeout')), 15000))
        
        const { data, error } = await Promise.race([query, timeoutPromise])
        
        if (error) throw error
        quarters.value = (data || []).filter(q => q.name !== 'test_q')
        if (quarters.value.length > 0 && !selectedQuarter.value) {
            const active = quarters.value.find(q => q.is_active)
            selectedQuarter.value = active ? active.id : quarters.value[0].id
        }
    } catch (error) {
        console.error('fetchQuarters error:', error)
        toast.error('Error al cargar periodos', {
          description: translateError(error)
        })
    } finally {
        quartersLoading.value = false
    }
}

// When Course changes, load Subjects cleanly without blocking select UI (INP < 10ms)
watch(selectedCourse, (newVal) => {
  gradeSheetRequestGuard.invalidate()
  activeSubjectId.value = null
  activeSubject.value = null
  subjectsError.value = ''
  loadingStudents.value = false
  loadingGrades.value = false
  students.value = []
  
  if (!newVal) {
    subjects.value = []
    studentsCount.value = 0
    return
  }

  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  courseStudentsLoader.invalidate({ courseId: newVal, schoolId: sId })

  // Defer heavy network queries after main thread paints the select change
  setTimeout(async () => {
    await fetchSubjectsForCourse(newVal)
    const courseStudents = await fetchCourseStudents(newVal)
    studentsCount.value = courseStudents.length
    await fetchProjectSettings()
    await fetchProjectGrades()
    ensureProjectGrid()
  }, 0)
})

const fetchSubjectsForCourse = async (courseId) => {
    if (!courseId) {
        subjects.value = []
        return
    }
    try {
        const sId = authStore.activeSchoolId || authStore.profile?.school_id
        let query = supabase
            .from('course_subjects')
            .select(`
                id,
                subject_id,
                teacher_id,
                subjects (
                    name
                )
            `)
            .eq('course_id', courseId)
        
        if (sId) {
            query = query.or(`school_id.eq.${sId},school_id.is.null`)
        }
        
        const userIds = [authStore.user?.id, authStore.profile?.id].filter(Boolean)
        const isAdmin = isInstitutionAdmin(authStore.accessContext)

        if (!isAdmin && userIds.length > 0) {
            query = query.in('teacher_id', userIds)
        }
        
        const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('Fetch Subjects Timeout')), 15000))
        const { data, error } = await Promise.race([query, timeoutPromise])

        if (error) throw error
        subjects.value = (data || []).map(item => ({
            course_subject_id: item.id,
            subject_id: item.subject_id,
            name: item.subjects?.name || 'Materia desconocida'
        })).sort((a,b) => a.name.localeCompare(b.name))
    } catch (error) {
        console.error('fetchSubjectsForCourse', error)
        subjectsError.value = translateError(error)
    }
}

watch(selectedQuarter, async (newVal) => {
  if (!newVal || !selectedCourse.value) return
  await fetchProjectSettings()
  await fetchProjectGrades()
  ensureProjectGrid()
})

const createDefaultQuarters = async () => {
  quartersError.value = ''
  const items = academicPeriods.value === 'QUIMESTRE'
    ? [
        { name: 'Primer Quimestre', is_active: true, school_id: authStore.activeSchoolId },
        { name: 'Segundo Quimestre', is_active: false, school_id: authStore.activeSchoolId }
      ]
    : [
        { name: 'Primer Trimestre', is_active: true, school_id: authStore.activeSchoolId },
        { name: 'Segundo Trimestre', is_active: false, school_id: authStore.activeSchoolId },
        { name: 'Tercer Trimestre', is_active: false, school_id: authStore.activeSchoolId }
      ]
  const { error } = await supabase
    .from('quarters')
    .insert(items)
  if (error) {
    toast.error('No se pudo crear los periodos', { description: 'Verifica permisos.' })
    return
  }
  await fetchQuarters()
}

const fetchProjectSettings = async () => {
  projectSubjects.value = new Set()
  projectMessage.value = ''
  projectAvailable.value = true
  if (!selectedCourse.value || !selectedQuarter.value) return
  const { data, error } = await supabase
    .from('project_settings')
    .select('subject_id')
    .eq('course_id', selectedCourse.value)
    .eq('quarter_id', selectedQuarter.value)
  if (error) {
    if (error.message && error.message.includes('Could not find the table')) {
      projectMessage.value = 'Modulo de Proyecto no instalado.'
      projectAvailable.value = false
    } else {
      toast.error('Error cargando proyecto', { description: error.message })
    }
    return
  }
  projectSubjects.value = new Set((data || []).map(d => d.subject_id))
}

const saveProjectSettings = async () => {
  if (!selectedCourse.value || !selectedQuarter.value) return
  if (!projectAvailable.value) {
    toast.error('Modulo de Proyecto no instalado.')
    return
  }
  projectSaving.value = true
  projectMessage.value = ''
  const selected = projectSubjects.value
  const { data: current, error: currentError } = await supabase
    .from('project_settings')
    .select('subject_id')
    .eq('course_id', selectedCourse.value)
    .eq('quarter_id', selectedQuarter.value)
  if (currentError) {
    toast.error('Error leyendo proyecto', { description: currentError.message })
    projectSaving.value = false
    return
  }
  const currentSet = new Set((current || []).map(x => x.subject_id))
  const toAdd = [...selected].filter(x => !currentSet.has(x))
  const toRemove = [...currentSet].filter(x => !selected.has(x))

  if (toAdd.length > 0) {
    const insertData = toAdd.map(subjectId => ({
      course_id: selectedCourse.value,
      quarter_id: selectedQuarter.value,
      subject_id: subjectId
    }))
    const { error } = await supabase.from('project_settings').insert(insertData)
    if (error) {
      toast.error('Error guardando proyecto', { description: error.message })
      projectSaving.value = false
      return
    }
  }

  if (toRemove.length > 0) {
    const { error } = await supabase
      .from('project_settings')
      .delete()
      .eq('course_id', selectedCourse.value)
      .eq('quarter_id', selectedQuarter.value)
      .in('subject_id', toRemove)
    if (error) {
      toast.error('Error guardando proyecto', { description: error.message })
      projectSaving.value = false
      return
    }
  }

  toast.success('Proyecto actualizado')
  projectSaving.value = false
}

const fetchProjectGrades = async () => {
  projectSubjectGrades.value = {}
  projectExistingKeys.value = new Set()
  projectAvailable.value = true
  seedProjectGradeRows()
  if (!selectedCourse.value || !selectedQuarter.value) return
  const { data, error } = await supabase
    .from('project_subject_grades')
    .select('student_id, subject_id, score')
    .eq('course_id', selectedCourse.value)
    .eq('quarter_id', selectedQuarter.value)
  if (error) {
    if (error.message && error.message.includes('Could not find the table')) {
      projectAvailable.value = false
    } else {
      toast.error('Error cargando notas de proyecto', { description: error.message })
    }
    seedProjectGradeRows()
    return
  }
  ;(data || []).forEach(g => {
    if (!projectSubjectGrades.value[g.student_id]) {
      projectSubjectGrades.value[g.student_id] = {}
    }
    projectSubjectGrades.value[g.student_id][g.subject_id] = g.score
    projectExistingKeys.value.add(`${g.student_id}:${g.subject_id}`)
  })
}

const saveProjectGrades = async () => {
  if (!selectedCourse.value || !selectedQuarter.value) return
  if (!projectAvailable.value) {
    toast.error('Modulo de Proyecto no instalado.')
    return
  }
  projectSaving.value = true
  const selectedSubjects = getSelectedProjectSubjects()
  if (selectedSubjects.length === 0) {
    toast.error('Selecciona al menos una asignatura para Proyecto')
    projectSaving.value = false
    return
  }
  const upserts = []
  const toDelete = []

  projectStudents.value.forEach(s => {
    selectedSubjects.forEach(sub => {
      const val = projectSubjectGrades.value[s.id]?.[sub.subject_id]
      const key = `${s.id}:${sub.subject_id}`
      const cleaned = sanitizeScoreInput(val)
      if (cleaned !== null && cleaned !== undefined && cleaned !== '') {
        upserts.push({
          student_id: s.id,
          course_id: selectedCourse.value,
          quarter_id: selectedQuarter.value,
          subject_id: sub.subject_id,
          score: cleaned
        })
      } else if (projectExistingKeys.value.has(key)) {
        toDelete.push({ student_id: s.id, subject_id: sub.subject_id })
      }
    })
  })

  const deleteGrades = async (items) => {
    if (items.length === 0) return null
    const chunkSize = 50
    for (let i = 0; i < items.length; i += chunkSize) {
      const chunk = items.slice(i, i + chunkSize)
      const orFilter = chunk
        .map(item => `and(student_id.eq.${item.student_id},subject_id.eq.${item.subject_id},course_id.eq.${selectedCourse.value},quarter_id.eq.${selectedQuarter.value})`)
        .join(',')
      const { error } = await supabase.from('project_subject_grades').delete().or(orFilter)
      if (error) return error
    }
    return null
  }

  const deleteError = await deleteGrades(toDelete)
  const upsertError = upserts.length > 0
    ? (await supabase
        .from('project_subject_grades')
        .upsert(upserts, { onConflict: 'student_id, course_id, quarter_id, subject_id' })).error
    : null

  if (!deleteError && !upsertError) {
    toDelete.forEach(item => projectExistingKeys.value.delete(`${item.student_id}:${item.subject_id}`))
    upserts.forEach(item => projectExistingKeys.value.add(`${item.student_id}:${item.subject_id}`))
    toast.success('Notas guardadas')
  } else {
    const errMsg = deleteError?.message || upsertError?.message || 'desconocido'
    toast.error('Error guardando notas', { description: errMsg })
  }
  projectSaving.value = false
}

const toggleProjectSubject = (subjectId) => {
  if (projectSubjects.value.has(subjectId)) {
    projectSubjects.value.delete(subjectId)
  } else {
    projectSubjects.value.add(subjectId)
  }
  ensureProjectGrid()
}

const getSelectedProjectSubjects = () => {
  return subjects.value.filter(s => projectSubjects.value.has(s.subject_id))
}

const ensureProjectGrid = () => {
  const selected = getSelectedProjectSubjects()
  projectStudents.value.forEach(s => {
    if (!projectSubjectGrades.value[s.id]) {
      projectSubjectGrades.value[s.id] = {}
    }
    selected.forEach(sub => {
      if (projectSubjectGrades.value[s.id][sub.subject_id] === undefined) {
        projectSubjectGrades.value[s.id][sub.subject_id] = ''
      }
    })
  })
}

const getCourseName = () => {
  const course = courses.value.find(c => c.id === selectedCourse.value)
  return course ? course.name : ''
}

const getQuarterName = () => {
  const quarter = quarters.value.find(q => q.id === selectedQuarter.value)
  return quarter ? quarter.name : ''
}

const handlePrint = () => {
  window.print()
}

// --- Grade Logic ---
const openGradeSheet = async (subject) => {
  if (activeSubjectId.value === subject.course_subject_id) {
    // Toggle close
    gradeSheetRequestGuard.invalidate()
    activeSubjectId.value = null
    activeSubject.value = null
    loadingStudents.value = false
    loadingGrades.value = false
    return
  }
  
  if (!selectedQuarter.value) {
    periodHint.value = 'Selecciona un periodo (trimestre o quimestre) antes de abrir el acta.'
    setTimeout(() => {
      if (periodHint.value.startsWith('Selecciona un periodo')) periodHint.value = ''
    }, 6000)
    return
  }

  activeSubjectId.value = subject.course_subject_id
  activeSubject.value = subject
  const requestId = gradeSheetRequestGuard.next()
  await loadGradeData(subject.course_subject_id, requestId)
}

// Cache en memoria para evitar parpadeos y CLS al abrir asignaturas repetidas
const gradesCacheMap = new Map()

const loadGradeData = async (courseSubjectId, requestId) => {
  const cacheKey = `${selectedCourse.value}_${selectedQuarter.value}_${courseSubjectId}`
  message.value = ''
  
  if (gradesCacheMap.has(cacheKey)) {
    const cached = gradesCacheMap.get(cacheKey)
    students.value = cached.students
    gradeDefinitions.value = cached.gradeDefinitions
    grades.value = cached.grades
    qualitativeScores.value = cached.qualitativeScores
    existingGradeKeys.value = new Set(cached.existingGradeKeys)
    qualitativeExistingKeys.value = new Set(cached.qualitativeExistingKeys)
    loadingStudents.value = false
    loadingGrades.value = false
  } else {
    loadingStudents.value = true
    loadingGrades.value = true
    students.value = []
    gradesPage.value = 1
    gradeDefinitions.value = []
    grades.value = {}
    qualitativeScores.value = {}
    qualitativeExistingKeys.value = new Set()
  }

  try {
    const sId = authStore.activeSchoolId || authStore.profile?.school_id

    // Students are shared by every subject in the course. Load them once while
    // grade definitions are prepared in parallel, and publish them immediately.
    const { students: loadedStudents } = await loadGradeSheetPrerequisites({
      loadStudents: () => courseStudentsLoader.load({
        courseId: selectedCourse.value,
        schoolId: sId,
      }),
      ensureDefinitions: () => isQualitativeCourse.value
        ? Promise.resolve(true)
        : ensureDefinitions(courseSubjectId),
      onStudents: (stus) => {
        if (!gradeSheetRequestGuard.isCurrent(requestId)) return
        students.value = stus
        loadingStudents.value = false
        stus.forEach(st => {
          if (!grades.value[st.id]) grades.value[st.id] = {}
          if (qualitativeScores.value[st.id] === undefined) qualitativeScores.value[st.id] = ''
        })
      },
    })

    if (!gradeSheetRequestGuard.isCurrent(requestId)) return
    students.value = loadedStudents
    loadingStudents.value = false

    if (isQualitativeCourse.value) {
      const { data: qGrades, error: qError } = await supabase
        .from('qualitative_grades')
        .select('student_id, score_text')
        .eq('course_subject_id', courseSubjectId)
        .eq('quarter_id', selectedQuarter.value)
      if (!gradeSheetRequestGuard.isCurrent(requestId)) return
      if (qError) {
        toast.error('Error cargando calificaciones', { description: qError.message })
        return
      }
      ;(qGrades || []).forEach(g => {
        qualitativeScores.value[g.student_id] = g.score_text || ''
        qualitativeExistingKeys.value.add(`${g.student_id}`)
      })

      gradesCacheMap.set(cacheKey, {
        students: [...students.value],
        gradeDefinitions: [],
        grades: {},
        qualitativeScores: { ...qualitativeScores.value },
        existingGradeKeys: new Set(),
        qualitativeExistingKeys: new Set(qualitativeExistingKeys.value)
      })
      return
    }

    // Definitions are fetched after their atomic initialization completes.
    let defsQuery = supabase
      .from('grade_definitions')
      .select('*')
      .eq('course_subject_id', courseSubjectId)
      .eq('quarter_id', selectedQuarter.value)
      .order('sort_order')
    if (sId) {
      defsQuery = defsQuery.or(`school_id.eq.${sId},school_id.is.null`)
    }
    const { data: defs, error: defsError } = await defsQuery
    if (!gradeSheetRequestGuard.isCurrent(requestId)) return
    if (defsError) {
      console.warn('Error cargando columnas:', defsError.message)
    }

    // Use DB definitions or fallback in-memory standard definitions
    if (defs && defs.length > 0) {
      gradeDefinitions.value = defs
    } else {
      gradeDefinitions.value = DEFAULT_DEFINITIONS.map(d => ({
        id: `virtual-def-${d.sort_order}`,
        course_subject_id: courseSubjectId,
        quarter_id: selectedQuarter.value,
        name: d.name,
        category: d.category,
        sort_order: d.sort_order
      }))
    }
    
    // Inject virtual "Proyecto" column if project is active globally for the course
    if (projectSubjects.value.size > 0) {
      const hasProjectDef = gradeDefinitions.value.some(d => d.category === 'SUMATIVA' && String(d.name || '').toLowerCase().includes('proyecto'))
      if (!hasProjectDef) {
        gradeDefinitions.value.push({
          id: 'virtual-project-def',
          course_subject_id: courseSubjectId,
          quarter_id: selectedQuarter.value,
          name: 'Proyecto',
          category: 'SUMATIVA',
          weight: 1.0,
          sort_order: 999
        })
      }
    }

    // 4. Load Existing Grades for these columns (if real IDs exist)
    const realDefIds = gradeDefinitions.value
      .map(d => d.id)
      .filter(id => id && !String(id).startsWith('virtual-'))

    if (realDefIds.length > 0) {
      const { data: existingGrades, error: gradesError } = await supabase
        .from('grades')
        .select('student_id, score, grade_definition_id')
        .in('grade_definition_id', realDefIds)
      if (!gradeSheetRequestGuard.isCurrent(requestId)) return
      if (gradesError) {
        toast.error('Error cargando calificaciones', { description: gradesError.message })
      } else {
        existingGradeKeys.value = new Set(
          (existingGrades || []).map(g => `${g.student_id}:${g.grade_definition_id}`)
        )

        existingGrades?.forEach(g => {
          if (grades.value[g.student_id]) {
            grades.value[g.student_id][g.grade_definition_id] = g.score
          }
        })
      }
    }

    gradesCacheMap.set(cacheKey, {
      students: [...students.value],
      gradeDefinitions: [...gradeDefinitions.value],
      grades: JSON.parse(JSON.stringify(grades.value)),
      qualitativeScores: {},
      existingGradeKeys: new Set(existingGradeKeys.value),
      qualitativeExistingKeys: new Set()
    })

  } catch (e) {
    if (!gradeSheetRequestGuard.isCurrent(requestId)) return
    console.error(e)
    toast.error('Error cargando datos', { description: e.message })
  } finally {
    if (gradeSheetRequestGuard.isCurrent(requestId)) {
      loadingStudents.value = false
      loadingGrades.value = false
    }
  }
}

const ensureDefinitions = async (courseSubjectId) => {
  if (!courseSubjectId || !selectedQuarter.value) return false
  const sId = authStore.activeSchoolId || authStore.profile?.school_id

  // 1. Try atomic RPC first
  try {
    const { data: rpcRes, error: rpcErr } = await supabase.rpc('ensure_default_grade_definitions', {
      p_course_subject_id: courseSubjectId,
      p_quarter_id: selectedQuarter.value
    })
    if (!rpcErr && rpcRes?.success) {
      return true
    }
  } catch (err) {
    console.warn('RPC ensure_default_grade_definitions not available, falling back:', err)
  }

  // 2. Direct client verification and creation fallback
  let query = supabase
    .from('grade_definitions')
    .select('id', { count: 'exact', head: true })
    .eq('course_subject_id', courseSubjectId)
    .eq('quarter_id', selectedQuarter.value)
  if (sId) {
    query = query.or(`school_id.eq.${sId},school_id.is.null`)
  }
  const { count, error } = await query
  if (error) {
    console.warn('Error verificando columnas:', error.message)
    return true
  }
  
  if (count === 0) {
    const newDefs = DEFAULT_DEFINITIONS.map(d => ({
      course_subject_id: courseSubjectId,
      quarter_id: selectedQuarter.value,
      school_id: sId || authStore.activeSchoolId,
      name: d.name,
      category: d.category,
      sort_order: d.sort_order
    }))
    const { error: insertErr } = await supabase.from('grade_definitions').insert(newDefs)
    if (insertErr) {
      console.warn('Advertencia creando columnas en BD (usando fallback en memoria):', insertErr.message)
      return true
    }
  }
  return true
}

const getProjectAverage = (studentId) => {
  const selectedSubjects = getSelectedProjectSubjects()
  if (selectedSubjects.length === 0) return null
  let sum = 0
  let count = 0
  selectedSubjects.forEach(sub => {
    const val = projectSubjectGrades.value[studentId]?.[sub.subject_id]
    const parsed = parseFloat(val)
    if (!isNaN(parsed)) {
      sum += parsed
      count++
    }
  })
  if (count === 0) return null
  return sum / count
}

const getProjectValue = (studentId, subjectId) => {
  return libGetProjectValue(projectSubjects.value, projectSubjectGrades.value, studentId, subjectId)
}

const getStudentAverages = (studentId, subjectId) => {
  const sGrades = grades.value[studentId] || {}
  const pv = projectSubjects.value.size > 0 ? getProjectAverage(studentId) : null
  return calculateStudentAverages(sGrades, gradeDefinitions.value, pv)
}

const formatGrade = (value) => {
  if (value === null || value === undefined || isNaN(value)) return '-'
  return value.toFixed(2)
}

const sanitizeScoreInput = (raw) => {
  if (raw === null || raw === undefined || raw === '') return ''
  const num = parseFloat(String(raw).replace(',', '.'))
  if (isNaN(num)) return ''
  if (num < 0) return 0
  if (num > 10) return 10
  return Number(num.toFixed(2))
}

const onGradeInput = (studentId, defId, event) => {
  if (defId === 'virtual-project-def') return
  const cleaned = sanitizeScoreInput(event.target.value)
  if (!grades.value[studentId]) {
    grades.value[studentId] = {}
  }
  grades.value[studentId][defId] = cleaned
}

const orderedEditableDefs = computed(() => {
  const individual = gradeDefinitions.value.filter(d => d.category === 'INDIVIDUAL')
  const grupal = gradeDefinitions.value.filter(d => d.category === 'GRUPAL')
  const refuerzo = gradeDefinitions.value.filter(d => d.category === 'REFUERZO')
  const sumativa = gradeDefinitions.value.filter(d => d.category === 'SUMATIVA')
  return [...individual, ...grupal, ...refuerzo, ...sumativa]
})

const pasteExcelGradesText = (rawText, startStudentId = null, startDefId = null) => {
  if (activeQuarterIsLocked.value) {
    toast.error('Periodo cerrado: No se pueden modificar calificaciones.')
    return 0
  }
  if (!rawText || !rawText.trim()) {
    toast.error('El texto copiado está vacío.')
    return 0
  }

  const rows = rawText
    .split(/\r\n|\r|\n/)
    .map(r => r.trim())
    .filter(r => r.length > 0)

  if (rows.length === 0) return 0

  const startStuIdx = startStudentId 
    ? Math.max(0, students.value.findIndex(s => s.id === startStudentId)) 
    : 0

  const defsList = orderedEditableDefs.value
  const startDefIdx = startDefId 
    ? Math.max(0, defsList.findIndex(d => d.id === startDefId)) 
    : 0

  let pastedCount = 0

  rows.forEach((rowStr, rIdx) => {
    const targetStuIdx = startStuIdx + rIdx
    if (targetStuIdx >= students.value.length) return
    const targetStudent = students.value[targetStuIdx]
    if (!targetStudent) return

    if (!grades.value[targetStudent.id]) {
      grades.value[targetStudent.id] = {}
    }

    let cells = rowStr.split('\t')
    if (cells.length === 1 && rowStr.includes(';')) {
      cells = rowStr.split(';')
    }

    cells.forEach((rawCell, cIdx) => {
      const targetDefIdx = startDefIdx + cIdx
      if (targetDefIdx >= defsList.length) return
      const targetDef = defsList[targetDefIdx]
      if (!targetDef) return

      if (targetDef.name.toLowerCase().includes('proyecto') && projectSubjects.value.size > 0) {
        return
      }

      const cellText = rawCell.trim()
      if (cellText === '' || cellText === '-') {
        grades.value[targetStudent.id][targetDef.id] = ''
        pastedCount++
      } else {
        const cleaned = sanitizeScoreInput(cellText)
        if (cleaned !== '') {
          grades.value[targetStudent.id][targetDef.id] = cleaned
          pastedCount++
        }
      }
    })
  })

  if (pastedCount > 0) {
    toast.success('Calificaciones pegadas desde Excel', {
      description: `Se insertaron ${pastedCount} notas en la libreta. Recuerda hacer clic en "Guardar cambios".`
    })
  } else {
    toast.error('No se detectaron valores numéricos válidos (0-10) en el texto.')
  }

  return pastedCount
}

const handlePasteGrades = (startStudentId, startDefId, event) => {
  if (activeQuarterIsLocked.value) return

  const clipboardData = event.clipboardData || window.clipboardData
  if (!clipboardData) return
  const text = clipboardData.getData('text')
  if (!text) return

  const count = pasteExcelGradesText(text, startStudentId, startDefId)
  if (count > 0) {
    event.preventDefault()
  }
}

const onProjectInput = (studentId, subjectId, event) => {
  const cleaned = sanitizeScoreInput(event.target.value)
  if (!projectSubjectGrades.value[studentId]) {
    projectSubjectGrades.value[studentId] = {}
  }
  projectSubjectGrades.value[studentId][subjectId] = cleaned
}

// Debounce para evitar guardados múltiples rápidos
let saveDebounceTimer = null
const isSaving = ref(false)

const getClassroomAverages = () => {
  if (students.value.length === 0 || gradeDefinitions.value.length === 0) return {}
  
  const avgs = {}
  
  // Per definition average
  gradeDefinitions.value.forEach(def => {
    let sum = 0
    let count = 0
    students.value.forEach(stu => {
      let val
      if (def.id === 'virtual-project-def') {
        val = getProjectAverage(stu.id)
      } else {
        val = parseFloat(grades.value[stu.id]?.[def.id])
      }
      if (val !== null && val !== undefined && !isNaN(val)) {
        sum += val
        count++
      }
    })
    avgs[def.id] = count > 0 ? (sum / count) : null
  })

  // Grouped averages and totals
  let totalIndividualSum = 0, totalIndividualCount = 0
  let totalGroupSum = 0, totalGroupCount = 0
  let totalSumSum = 0, totalSumCount = 0
  let GrandTotalSum = 0, GrandTotalCount = 0

  students.value.forEach(stu => {
    const res = getStudentAverages(stu.id, activeSubject.value?.subject_id)
    if (res.avgIndividual !== null) { totalIndividualSum += res.avgIndividual; totalIndividualCount++ }
    if (res.avgGroup !== null) { totalGroupSum += res.avgGroup; totalGroupCount++ }
    if (res.avgSum !== null) { totalSumSum += res.avgSum; totalSumCount++ }
    if (res.total !== null) { GrandTotalSum += res.total; GrandTotalCount++ }
  })

  return {
    ...avgs,
    avgIndividual: totalIndividualCount > 0 ? (totalIndividualSum / totalIndividualCount) : null,
    avgGroup: totalGroupCount > 0 ? (totalGroupSum / totalGroupCount) : null,
    avgSum: totalSumCount > 0 ? (totalSumSum / totalSumCount) : null,
    total: GrandTotalCount > 0 ? (GrandTotalSum / GrandTotalCount) : null
  }
}

const normalizeWhatsappPhone = (phone) => {
  if (!phone) return null
  let digits = String(phone).replace(/\D/g, '')
  if (!digits) return null
  if (digits.startsWith('00')) digits = digits.slice(2)
  if (digits.startsWith('0') && digits.length === 10) {
    digits = `593${digits.slice(1)}`
  } else if (digits.length >= 7 && digits.length <= 10 && !digits.startsWith('593')) {
    digits = `593${digits}`
  }
  return digits.length >= 11 ? digits : null
}

const buildWhatsappMessage = (student) => {
  const courseName = getCourseName()
  const periodName = getQuarterName()
  const subName = activeSubject.value?.name || 'Materia'
  const res = getStudentAverages(student.id, activeSubject.value?.subject_id)
  const avgText = formatGrade(res.total)
  
  return [
    `Estimado/a representante de ${student.full_name},`,
    `Le informamos que el estudiante tiene un promedio actual de *${avgText}* en la materia de *${subName}* (${courseName} - ${periodName}).`,
    `Por favor, acérquese a la institución o contacte al docente para revisar el rendimiento académico.`,
    'Saludos cordiales.'
  ].join('\n')
}

const sendStudentWhatsapp = (student) => {
  const phone = normalizeWhatsappPhone(student.representative_phone)
  if (!phone) {
    toast.error('Teléfono no válido.')
    return
  }
  const message = buildWhatsappMessage(student)
  const url = `https://wa.me/${phone}?text=${encodeURIComponent(message)}`
  window.open(url, '_blank')
}

const saveGrades = async () => {
  if (!isOnline.value) {
    toast.error('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  // Prevenir doble clic
  if (isSaving.value || saving.value) return
  
  // Limpiar debounce anterior si existe
  if (saveDebounceTimer) {
    clearTimeout(saveDebounceTimer)
  }

  // Ejecutar inmediatamente el primer guardado
  isSaving.value = true
  saving.value = true
  
  try {
    const upserts = []
    const toDelete = []
    students.value.forEach(s => {
      const sGrades = grades.value[s.id]
      gradeDefinitions.value.forEach(d => {
        if (d.id === 'virtual-project-def') return
        const val = sGrades[d.id]
        const key = `${s.id}:${d.id}`
        const cleaned = sanitizeScoreInput(val)
        if (cleaned !== null && cleaned !== undefined && cleaned !== '') {
          upserts.push({
              student_id: s.id,
              grade_definition_id: d.id,
              score: cleaned
          })
        } else if (existingGradeKeys.value.has(key)) {
          toDelete.push({ student_id: s.id, grade_definition_id: d.id })
        }
      })
    })

    const { error } = await supabase.rpc('save_grade_batch', {
      p_upserts: upserts,
      p_deletes: toDelete
    })

    if (!error) {
      toDelete.forEach(item => existingGradeKeys.value.delete(`${item.student_id}:${item.grade_definition_id}`))
      upserts.forEach(item => existingGradeKeys.value.add(`${item.student_id}:${item.grade_definition_id}`))
      toast.success('Calificaciones guardadas')
    } else {
      toast.error('Error al guardar', { description: translateError(error) })
    }
  } catch (error) {
    console.error('Error guardando calificaciones:', error)
    toast.error('Error guardando calificaciones', { description: translateError(error) })
  } finally {
    saving.value = false
    isSaving.value = false
    // Permitir nuevo guardado después de 1 segundo
    saveDebounceTimer = setTimeout(() => {
      saveDebounceTimer = null
    }, 1000)
  }
}

const saveQualitativeGrades = async () => {
  if (!isOnline.value) {
    toast.error('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (!activeSubjectId.value || !selectedQuarter.value) return
  saving.value = true
  const upserts = []
  const toDelete = []

  students.value.forEach(s => {
    const val = qualitativeScores.value[s.id]
    const key = `${s.id}`
    if (val) {
      upserts.push({
        student_id: s.id,
        course_subject_id: activeSubjectId.value,
        quarter_id: selectedQuarter.value,
        score_text: val
      })
    } else if (qualitativeExistingKeys.value.has(key)) {
      toDelete.push({ student_id: s.id })
    }
  })

  try {
    const { error } = await supabase.rpc('save_qualitative_grade_batch', {
      p_course_subject_id: activeSubjectId.value,
      p_quarter_id: selectedQuarter.value,
      p_upserts: upserts,
      p_delete_student_ids: toDelete.map(item => item.student_id)
    })

    if (error) {
      toast.error('Error al guardar', { description: translateError(error) })
      return
    }

    qualitativeExistingKeys.value = new Set(upserts.map(u => `${u.student_id}`))
    toast.success('Notas guardadas')
  } catch (error) {
    toast.error('Error al guardar', { description: translateError(error) })
  } finally {
    saving.value = false
  }
}

const saveCurrentGrades = async () => {
  if (isQualitativeCourse.value) return saveQualitativeGrades()
  return saveGrades()
}

// Rename Header Logic
const editHeader = (def) => { editingDefinition.value = { ...def }; showHeaderModal.value = true }
const saveHeader = async () => {
  if (!isOnline.value) {
    toast.error('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (!editingDefinition.value) return
  const { error } = await supabase
    .from('grade_definitions')
    .update({ name: editingDefinition.value.name })
    .eq('id', editingDefinition.value.id)
  
  if (!error) {
     const idx = gradeDefinitions.value.findIndex(d => d.id === editingDefinition.value.id)
     if (idx !== -1) gradeDefinitions.value[idx].name = editingDefinition.value.name
     showHeaderModal.value = false
     toast.success('Nombre de columna actualizado')
  } else {
     toast.error('Error al actualizar columna', { description: translateError(error) })
  }
}


  return reactive({
    academicPeriods,
    activeSubject,
    activeSubjectId,
    courses,
    createDefaultQuarters,
    editHeader,
    editingDefinition,
    fetchSubjectsForCourse,
    formatGrade,
    getClassroomAverages,
    getCourseName,
    getProjectAverage,
    getProjectValue,
    getQuarterName,
    getSelectedProjectSubjects,
    getStudentAverages,
    sendStudentWhatsapp,
    gradeDefinitions,
    grades,
    gradesPage,
    gradesPageSize,
    handlePrint,
    institutionLogoUrl,
    institutionName,
    institutionRectorName,
    institutionTutorName,
    isQualitativeCourse,
    loadingStudents,
    loadingGrades,
    message,
    onGradeInput,
    orderedEditableDefs,
    handlePasteGrades,
    pasteExcelGradesText,
    onProjectInput,
    openGradeSheet,
    paginatedStudents,
    studentAveragesMap,
    periodHint,
    projectAvailable,
    projectExistingKeys,
    projectMessage,
    projectStudents,
    projectSubjectGrades,
    projectSubjects,
    projectSaving,
    qualitativeExistingKeys,
    qualitativeMessage,
    qualitativeScores,
    QUALITATIVE_OPTIONS,
    quarters,
    quartersError,
    quartersLoading,
    saveCurrentGrades,
    saveHeader,
    saveProjectGrades,
    saveProjectSettings,
    selectedCourse,
    selectedQuarter,
    isYearLocked,
    activeQuarterIsLocked,
    setGradesPage,
    showHeaderModal,
    showProjectModal,
    students,
    studentsCount,
    subjects,
    subjectsError,
    saving,
    toggleProjectSubject,
    totalGradesPages,
  })
}
