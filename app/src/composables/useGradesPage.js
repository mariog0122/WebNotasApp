import { ref, onMounted, watch, computed, reactive } from 'vue'
import { supabase } from '../lib/supabase'
import { translateError } from '../lib/errorDictionary'
import { toast } from 'vue-sonner'
import { getProjectValue as libGetProjectValue, calculateStudentAverages } from '../lib/gradingLogic'
import { useNetwork } from './useNetwork'

/** Inyeccion para subvistas del modulo de calificaciones */
export const gradesPageInjectionKey = Symbol('gradesPage')

export function useGradesPage() {
  // State
const courses = ref([])
const quarters = ref([])
const subjects = ref([]) // Subjects for the selected course
const { isOnline } = useNetwork()

const selectedCourse = ref(null)
const selectedQuarter = ref(null)
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

// Memoize heavily used averages for the current page to prevent rendering lag
const studentAveragesMap = computed(() => {
  const map = {}
  const subId = activeSubject.value?.subject_id
  paginatedStudents.value.forEach(stu => {
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
  const { data } = await supabase.from('courses').select('id, name, level, track').order('name')
  courses.value = data || []
}

const selectedCourseObj = computed(() => courses.value.find(c => c.id === selectedCourse.value))
const isQualitativeCourse = computed(() => {
  const level = selectedCourseObj.value?.level || ''
  return ['INICIAL', 'PREPARATORIA', 'ELEMENTAL'].includes(level)
})

const fetchInstitutionConfig = async () => {
  const { data, error } = await supabase
    .from('system_config')
    .select('key, value')
    .in('key', ['institution_name', 'institution_logo_url', 'institution_tutor_name', 'institution_rector_name', 'academic_periods'])
  if (error) return
  const map = Object.fromEntries((data || []).map(item => [item.key, item.value]))
  institutionName.value = map.institution_name || ''
  institutionLogoUrl.value = map.institution_logo_url || ''
  institutionTutorName.value = map.institution_tutor_name || ''
  institutionRectorName.value = map.institution_rector_name || ''
  academicPeriods.value = map.academic_periods || 'TRIMESTRE'
}

const fetchCourseStudents = async (courseId) => {
  if (!courseId) {
    projectStudents.value = []
    return
  }
  const { data, error } = await supabase
    .from('students')
    .select('id, full_name')
    .eq('course_id', courseId)
    .order('full_name')
  if (error) {
    toast.error('Error cargando estudiantes', { description: translateError(error) })
    projectStudents.value = []
    return
  }
  projectStudents.value = data || []
  seedProjectGradeRows()
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
        const fetchPromise = supabase.from('quarters').select('*').order('created_at')
        const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('Fetch Quarters Timeout')), 15000))
        
        const { data, error } = await Promise.race([fetchPromise, timeoutPromise])
        
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

// When Course changes, load Subjects
watch(selectedCourse, async (newVal) => {
  subjects.value = []
  activeSubjectId.value = null
  activeSubject.value = null
  studentsCount.value = 0
  subjectsError.value = ''
  if (!newVal) return

  await fetchSubjectsForCourse(newVal)

  const { count } = await supabase
    .from('students')
    .select('id', { count: 'exact', head: true })
    .eq('course_id', newVal)
  studentsCount.value = count || 0

  await fetchCourseStudents(newVal)
  await fetchProjectSettings()
  await fetchProjectGrades()
  ensureProjectGrid()
})

const fetchSubjectsForCourse = async (courseId) => {
    if (!courseId) {
        subjects.value = []
        return
    }
    try {
        const fetchPromise = supabase
            .from('course_subjects')
            .select(`
                id,
                subject_id,
                subjects (
                    name
                )
            `)
            .eq('course_id', courseId)
        
        const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('Fetch Subjects Timeout')), 15000))
        const { data, error } = await Promise.race([fetchPromise, timeoutPromise])

        if (error) throw error
        subjects.value = data.map(item => ({
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
        { name: 'Primer Quimestre', is_active: true },
        { name: 'Segundo Quimestre', is_active: false }
      ]
    : [
        { name: 'Primer Trimestre', is_active: true },
        { name: 'Segundo Trimestre', is_active: false },
        { name: 'Tercer Trimestre', is_active: false }
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
    activeSubjectId.value = null
    activeSubject.value = null
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
  await loadGradeData(subject.course_subject_id)
}

const loadGradeData = async (courseSubjectId) => {
  loadingGrades.value = true
  message.value = ''
  students.value = []
  gradesPage.value = 1
  gradeDefinitions.value = []
  grades.value = {}
  qualitativeScores.value = {}
  qualitativeExistingKeys.value = new Set()

  try {
    if (isQualitativeCourse.value) {
      const { data: stus, error: studentsError } = await supabase
        .from('students')
        .select('id, full_name, representative_name, representative_cedula, representative_phone, student_address')
        .eq('course_id', selectedCourse.value)
        .order('full_name')
      if (studentsError) {
        toast.error('Error cargando estudiantes', { description: studentsError.message })
        return
      }
      students.value = stus || []

      const { data: qGrades, error: qError } = await supabase
        .from('qualitative_grades')
        .select('student_id, score_text')
        .eq('course_subject_id', courseSubjectId)
        .eq('quarter_id', selectedQuarter.value)
      if (qError) {
        toast.error('Error cargando calificaciones', { description: qError.message })
        return
      }
      students.value.forEach(s => {
        qualitativeScores.value[s.id] = ''
      })
      ;(qGrades || []).forEach(g => {
        qualitativeScores.value[g.student_id] = g.score_text || ''
        qualitativeExistingKeys.value.add(`${g.student_id}`)
      })
      return
    }

    // 1. Ensure Definitions (Idempotent check similar to before)
    const ensured = await ensureDefinitions(courseSubjectId)
    if (!ensured) return

    // 2. Fetch Definitions
    const { data: defs, error: defsError } = await supabase
      .from('grade_definitions')
      .select('*')
      .eq('course_subject_id', courseSubjectId)
      .eq('quarter_id', selectedQuarter.value)
      .order('sort_order')
    if (defsError) {
      toast.error('Error cargando columnas', { description: defsError.message })
      return
    }
    gradeDefinitions.value = defs || []
    if (!gradeDefinitions.value || gradeDefinitions.value.length === 0) {
      toast.error('No hay columnas de calificacion.')
      return
    }

    // 3. Fetch Students for the Course
    const { data: stus, error: studentsError } = await supabase
      .from('students')
      .select('id, full_name, representative_phone, representative_name')
      .eq('course_id', selectedCourse.value)
      .order('full_name')
    if (studentsError) {
      toast.error('Error cargando estudiantes', { description: studentsError.message })
      return
    }
    students.value = stus || []

    // 4. Fetch Grades
    const { data: existingGrades, error: gradesError } = await supabase
      .from('grades')
      .select('student_id, score, grade_definition_id')
      .in('grade_definition_id', defs.map(d => d.id))
    if (gradesError) {
      toast.error('Error cargando calificaciones', { description: gradesError.message })
      return
    }
    
    existingGradeKeys.value = new Set(
      (existingGrades || []).map(g => `${g.student_id}:${g.grade_definition_id}`)
    )

    // Initialize structure
    students.value.forEach(s => {
      grades.value[s.id] = {}
      defs.forEach(d => {
        grades.value[s.id][d.id] = null
      })
    })

    // Fill existing
    existingGrades?.forEach(g => {
      if (grades.value[g.student_id]) {
        grades.value[g.student_id][g.grade_definition_id] = g.score
      }
    })

  } catch (e) {
    console.error(e)
    toast.error('Error cargando datos', { description: e.message })
  } finally {
    loadingGrades.value = false
  }
}

const ensureDefinitions = async (courseSubjectId) => {
  const { count, error } = await supabase
    .from('grade_definitions')
    .select('*', { count: 'exact', head: true })
    .eq('course_subject_id', courseSubjectId)
    .eq('quarter_id', selectedQuarter.value)
  if (error) {
    toast.error('Error verificando columnas', { description: error.message })
    return false
  }
  
  if (count === 0) {
    const newDefs = DEFAULT_DEFINITIONS.map(d => ({
      course_subject_id: courseSubjectId,
      quarter_id: selectedQuarter.value,
      name: d.name,
      category: d.category,
      sort_order: d.sort_order
    }))
    const { error } = await supabase.from('grade_definitions').insert(newDefs)
    if (error) {
      toast.error('Error creando columnas', { description: error.message })
      return false
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
  const pv = getProjectValue(studentId, subjectId)
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
  const cleaned = sanitizeScoreInput(event.target.value)
  grades.value[studentId][defId] = cleaned
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
      const val = parseFloat(grades.value[stu.id]?.[def.id])
      if (!isNaN(val)) {
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

    const deleteGrades = async (items) => {
      if (items.length === 0) return null
      const chunkSize = 50
      for (let i = 0; i < items.length; i += chunkSize) {
        const chunk = items.slice(i, i + chunkSize)
        const orFilter = chunk
          .map(item => `and(student_id.eq.${item.student_id},grade_definition_id.eq.${item.grade_definition_id})`)
          .join(',')
        const { error } = await supabase.from('grades').delete().or(orFilter)
        if (error) return error
      }
      return null
    }

    const deleteError = await deleteGrades(toDelete)
    const upsertError = upserts.length > 0
      ? (await supabase.from('grades').upsert(upserts, { onConflict: 'student_id, grade_definition_id' })).error
      : null

    if (!deleteError && !upsertError) {
      toDelete.forEach(item => existingGradeKeys.value.delete(`${item.student_id}:${item.grade_definition_id}`))
      upserts.forEach(item => existingGradeKeys.value.add(`${item.student_id}:${item.grade_definition_id}`))
      toast.success('Calificaciones guardadas')
    } else {
      toast.error('Error al guardar', { description: translateError(deleteError || upsertError) })
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

  const deleteGrades = async (items) => {
    if (items.length === 0) return null
    const chunkSize = 50
    for (let i = 0; i < items.length; i += chunkSize) {
      const chunk = items.slice(i, i + chunkSize)
      const orFilter = chunk
        .map(item => `and(student_id.eq.${item.student_id},course_subject_id.eq.${activeSubjectId.value},quarter_id.eq.${selectedQuarter.value})`)
        .join(',')
      const { error } = await supabase.from('qualitative_grades').delete().or(orFilter)
      if (error) return error
    }
    return null
  }

  const deleteError = await deleteGrades(toDelete)
  const upsertError = upserts.length > 0
    ? (await supabase
        .from('qualitative_grades')
        .upsert(upserts, { onConflict: 'student_id, course_subject_id, quarter_id' })).error
    : null

  if (!deleteError && !upsertError) {
    qualitativeExistingKeys.value = new Set(
      upserts.map(u => `${u.student_id}`)
    )
    toast.success('Notas guardadas')
  } else {
    toast.error('Error al guardar', { description: translateError(deleteError || upsertError) })
  }
  saving.value = false
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
    loadingGrades,
    message,
    onGradeInput,
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
