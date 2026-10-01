<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useCoursesQuery, useQuartersQuery } from '../composables/useQueries'
import { computeProjectAverage, computeSubjectTotal, getQuarterOrder, truncate2, computeFinalAnnual, computeFinalObservation, getPeriodLabel, computeTrimesterObservation } from '../lib/reporting'
import { normalizeStoragePath, resolvePrivateImageUrl } from '../lib/storageUtils'
import { useAuthStore } from '../stores/auth'
import { useAcademicYearStore } from '../stores/academicYear'
import { isInstitutionAdmin } from '../lib/permissions'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'
import StudentRecoveryModal from '../components/grades/StudentRecoveryModal.vue'
import IndividualReportSheet from '../components/reports/IndividualReportSheet.vue'
import {
  FileText,
  Download,
  Printer,
  Calendar,
  Building2,
  CheckCircle2,
  AlertTriangle,
  Sparkles,
  MessageCircle
} from 'lucide-vue-next'

const route = useRoute()
const authStore = useAuthStore()
const academicYearStore = useAcademicYearStore()

const { data: coursesData, refetch: refetchCourses } = useCoursesQuery(computed(() => academicYearStore.selectedYearName))
const courses = computed(() => coursesData.value || [])

const { data: quartersData, refetch: refetchQuarters } = useQuartersQuery()
const quarters = computed(() => (quartersData.value || []).slice().sort((a, b) => getQuarterOrder(a.name) - getQuarterOrder(b.name)))
const students = ref([])
const courseSubjects = ref([])

const reportMode = ref('GENERAL')

const selectedStudentId = ref(null)
const individualLoading = ref(false)
const individualError = ref('')
const individualSubjects = ref([])
const individualAverage = ref(null)
const individualProjectAverage = ref(null)
const qualitativeGradesByStudent = ref({})

const selectedCourse = ref(null)
const selectedQuarter = ref(null)
const loading = ref(false)
const error = ref('')
const isMissingProjectTableError = (queryError) => (
  queryError?.code === 'PGRST205'
  || queryError?.message?.includes('Could not find the table')
)

watch(courses, (newCourses) => {
  if (selectedCourse.value && !newCourses.some(c => c.id === selectedCourse.value)) {
    selectedCourse.value = null
  }
})

const configData = ref({})

const fetchInstitutionConfig = async () => {
  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!sId) return
  const { data, error: cfgErr } = await supabase
    .from('system_config')
    .select('key, value')
    .eq('school_id', sId)
    .in('key', ['institution_name', 'institution_logo_url', 'institution_tutor_name', 'institution_rector_name', 'academic_periods', 'regimen'])
  
  if (cfgErr) {
    console.error('Error fetching institution config:', cfgErr.message)
  } else {
    const map = Object.fromEntries((data || []).map(item => [item.key, item.value]))
    map.institution_logo_url = await resolvePrivateImageUrl(
      supabase,
      'institution-assets',
      normalizeStoragePath(map.institution_logo_url, 'institution-assets'),
    ).catch(() => '')
    configData.value = map || {}
  }
}
const institutionName = computed(() => configData.value?.institution_name || '')
const institutionLogoUrl = computed(() => configData.value?.institution_logo_url || '')
const institutionTutorName = computed(() => configData.value?.institution_tutor_name || '')
const institutionRectorName = computed(() => configData.value?.institution_rector_name || '')
const academicPeriods = computed(() => configData.value?.academic_periods || 'TRIMESTRE')
const regime = computed(() => configData.value?.regimen || 'COSTA_GALAPAGOS')

const definitionsByQuarter = ref({})
const gradesByStudent = ref({})
const projectSettingsByQuarter = ref({})
const projectGradesByQuarter = ref({})
const projectAvailable = ref(true)
const supplementaryScores = ref({})
const supplementaryExistingKeys = ref(new Set())
const supplementaryEditing = ref(false)
const supplementarySaving = ref(false)
const supplementaryMessage = ref('')
const reportsRef = ref(null)
const showWhatsappPreview = ref(false)
const whatsappPreviewText = ref('')
const whatsappPreviewStudent = ref('')

const showRecoveryModal = ref(false)
const selectedStudentForRecovery = ref(null)
const selectedScoreForRecovery = ref(0)

const openStudentRecovery = (row) => {
  selectedStudentForRecovery.value = row.student
  selectedScoreForRecovery.value = row.average || 0
  showRecoveryModal.value = true
}

const isQualitativeCourse = computed(() => {
  const level = courses.value.find(c => c.id === selectedCourse.value)?.level || ''
  return ['INICIAL', 'PREPARATORIA', 'ELEMENTAL'].includes(level)
})

const fetchCourseData = async () => {
  if (!selectedCourse.value) return
  loading.value = true
  error.value = ''
  projectAvailable.value = true
  qualitativeGradesByStudent.value = {}
  try {
    const courseId = selectedCourse.value
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!sId) throw new Error('No hay una institución activa seleccionada.')

    let stusQuery = supabase
      .from('students')
      .select('id, full_name, representative_name, representative_phone, has_adaptation, adaptation_grade, adaptation_details, school_id')
      .eq('course_id', courseId)
      .order('full_name')
    stusQuery = stusQuery.eq('school_id', sId)
    const { data: stus, error: stusError } = await stusQuery
    if (stusError) throw stusError
    students.value = stus || []

    let csQuery = supabase
      .from('course_subjects')
      .select('id, subject_id, teacher_id, subjects (name)')
      .eq('course_id', courseId)
    csQuery = csQuery.eq('school_id', sId)
    const userId = authStore.user?.id || authStore.profile?.id
    const isAdmin = isInstitutionAdmin(authStore.accessContext)
    if (!isAdmin && userId) {
      csQuery = csQuery.eq('teacher_id', userId)
    }
    const { data: cs, error: csError } = await csQuery
    if (csError) throw csError
    courseSubjects.value = cs || []

    const courseSubjectIds = (cs || []).map(x => x.id)
    if (courseSubjectIds.length === 0) {
      definitionsByQuarter.value = {}
      gradesByStudent.value = {}
      projectSettingsByQuarter.value = {}
      projectGradesByQuarter.value = {}
      qualitativeGradesByStudent.value = {}
      loading.value = false
      return
    }

    let defsQuery = supabase
      .from('grade_definitions')
      .select('id, course_subject_id, quarter_id, name, category, sort_order')
      .in('course_subject_id', courseSubjectIds)
    defsQuery = defsQuery.eq('school_id', sId)
    const { data: defs, error: defsError } = await defsQuery
    if (defsError) throw defsError

    const defIds = (defs || []).map(d => d.id)
    let grades = []
    if (defIds.length > 0) {
      const { data, error: gradesError } = await supabase
        .from('grades')
        .select('student_id, grade_definition_id, score')
        .in('grade_definition_id', defIds)
      if (gradesError) throw gradesError
      grades = data || []
    }

    const defsByQuarterMap = {}
    ;(defs || []).forEach(d => {
      if (!defsByQuarterMap[d.quarter_id]) defsByQuarterMap[d.quarter_id] = {}
      if (!defsByQuarterMap[d.quarter_id][d.course_subject_id]) defsByQuarterMap[d.quarter_id][d.course_subject_id] = []
      defsByQuarterMap[d.quarter_id][d.course_subject_id].push(d)
    })
    Object.keys(defsByQuarterMap).forEach(qid => {
      Object.keys(defsByQuarterMap[qid]).forEach(csId => {
        defsByQuarterMap[qid][csId].sort((a, b) => a.sort_order - b.sort_order)
      })
    })
    definitionsByQuarter.value = defsByQuarterMap

    const gradesMap = {}
    ;(grades || []).forEach(g => {
      if (!gradesMap[g.student_id]) gradesMap[g.student_id] = {}
      gradesMap[g.student_id][g.grade_definition_id] = g.score
    })
    gradesByStudent.value = gradesMap

    const projectSettingsMap = {}
    const projectGradesMap = {}
    for (const q of quarters.value) {
      const { data: ps, error: psError } = await supabase
        .from('project_settings')
        .select('subject_id')
        .eq('course_id', courseId)
        .eq('quarter_id', q.id)
      if (psError && !isMissingProjectTableError(psError)) throw psError
      if (isMissingProjectTableError(psError)) projectAvailable.value = false
      projectSettingsMap[q.id] = (ps || []).map(p => p.subject_id)

      const { data: pg, error: pgError } = await supabase
        .from('project_subject_grades')
        .select('student_id, subject_id, score')
        .eq('course_id', courseId)
        .eq('quarter_id', q.id)
      if (pgError && !isMissingProjectTableError(pgError)) throw pgError
      if (isMissingProjectTableError(pgError)) projectAvailable.value = false
      if ((projectSettingsMap[q.id] || []).length === 0 && (pg || []).length > 0) {
        const inferred = [...new Set((pg || []).map(row => row.subject_id))]
        projectSettingsMap[q.id] = inferred
      }
      const byStudent = {}
      ;(pg || []).forEach(g => {
        if (!byStudent[g.student_id]) byStudent[g.student_id] = {}
        byStudent[g.student_id][g.subject_id] = g.score
      })
      projectGradesMap[q.id] = byStudent
    }
    projectSettingsByQuarter.value = projectSettingsMap
    projectGradesByQuarter.value = projectGradesMap

    const { data: supData, error: supError } = await supabase
      .from('supplementary_exams')
      .select('student_id, course_subject_id, score')
      .in('course_subject_id', courseSubjectIds)
    if (supError) throw supError
    const supMap = {}
    const supKeys = new Set()
    ;(supData || []).forEach(s => {
      if (!supMap[s.student_id]) supMap[s.student_id] = {}
      supMap[s.student_id][s.course_subject_id] = s.score
      supKeys.add(`${s.student_id}:${s.course_subject_id}`)
    })
    supplementaryScores.value = supMap
    supplementaryExistingKeys.value = supKeys

    if (isQualitativeCourse.value && selectedQuarter.value) {
      const { data: qGrades, error: qError } = await supabase
        .from('qualitative_grades')
        .select('student_id, course_subject_id, score_text')
        .in('course_subject_id', courseSubjectIds)
        .eq('quarter_id', selectedQuarter.value)
      if (qError) throw qError
      const qMap = {}
      ;(qGrades || []).forEach(g => {
        if (!qMap[g.student_id]) qMap[g.student_id] = {}
        qMap[g.student_id][g.course_subject_id] = g.score_text
      })
      qualitativeGradesByStudent.value = qMap
    }
  } catch (e) {
    error.value = 'Error cargando reportes: ' + e.message
  }
  loading.value = false
}

watch(() => authStore.activeSchoolId, async () => {
  selectedCourse.value = null
  await fetchInstitutionConfig()
  await refetchCourses()
  await refetchQuarters()
})

// Auto-select first course when courses data is loaded
watch(courses, (newCourses) => {
  if (newCourses && newCourses.length > 0) {
    if (!selectedCourse.value || !newCourses.some(c => c.id === selectedCourse.value)) {
      const qCourse = route.query.course_id
      if (qCourse && newCourses.some(c => c.id === qCourse)) {
        selectedCourse.value = qCourse
      } else {
        selectedCourse.value = newCourses[0].id
      }
    }
  } else {
    selectedCourse.value = null
    students.value = []
  }
}, { immediate: true })

watch(quarters, (newVal) => {
  if (newVal && newVal.length > 0) {
    if (!selectedQuarter.value || !newVal.some(q => q.id === selectedQuarter.value)) {
      const active = newVal.find(q => q.is_active) || newVal[0]
      selectedQuarter.value = active?.id || null
    }
  }
}, { immediate: true })

watch(selectedCourse, (newVal) => {
  if (newVal) {
    fetchCourseData()
  }
})

onMounted(async () => {
  await fetchInstitutionConfig()
  if (courses.value && courses.value.length > 0 && !selectedCourse.value) {
    selectedCourse.value = courses.value[0].id
  }
  if (selectedCourse.value) {
    fetchCourseData()
  }
})

const getQuarterName = (id) => quarters.value.find(q => q.id === id)?.name || ''
const orderedQuarters = computed(() => quarters.value.slice().sort((a, b) => getQuarterOrder(a.name) - getQuarterOrder(b.name)))
const orderedPeriodLabels = computed(() => orderedQuarters.value.map(q => getPeriodLabel(q.name)))

const formatScore = (value) => {
  if (value === null || value === undefined || isNaN(value)) return '-'
  return Number(value).toFixed(2)
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

const buildWhatsappMessage = (entry) => {
  const courseName = courses.value.find(c => c.id === selectedCourse.value)?.name || 'Curso'
  const periodName = getQuarterName(selectedQuarter.value) || 'Periodo'
  const repName = entry.student.representative_name || 'representante'
  const avgText = formatScore(entry.average)
  const obs = computeTrimesterObservation(entry.average)
  const subjectLines = entry.subjects.map(s => `- ${s.subject}: ${formatScore(s.total)}`).join('\n')
  return [
    `Estimado/a ${repName},`,
    `Le informamos el rendimiento de ${entry.student.full_name} en ${courseName} (${periodName}).`,
    `Promedio actual: ${avgText}${obs ? ` · ${obs}` : ''}`,
    'Detalle por asignatura:',
    subjectLines || 'Sin calificaciones registradas.',
    'Quedamos atentos para cualquier consulta.'
  ].join('\n')
}

const sendWhatsappMessage = (entry) => {
  const phone = normalizeWhatsappPhone(entry.student.representative_phone)
  if (!phone) {
    alert('El telefono del representante no es valido o no tiene codigo de pais. Verifica el numero.')
    return
  }
  const message = buildWhatsappMessage(entry)
  const url = `https://wa.me/${phone}?text=${encodeURIComponent(message)}`
  window.open(url, '_blank')
}

const previewWhatsappMessage = (entry) => {
  whatsappPreviewStudent.value = entry.student.full_name
  whatsappPreviewText.value = buildWhatsappMessage(entry)
  showWhatsappPreview.value = true
}

const copyWhatsappMessage = async () => {
  try {
    await navigator.clipboard.writeText(whatsappPreviewText.value)
    alert('Mensaje copiado.')
  } catch (e) {
    alert('No se pudo copiar el mensaje.')
  }
}

const computeQuarterTotalsForStudent = (quarterId, studentId) => {
  const defsByCourseSubject = definitionsByQuarter.value[quarterId] || {}
  const projectSubjects = projectSettingsByQuarter.value[quarterId] || []
  const projectGrades = projectGradesByQuarter.value[quarterId] || {}
  const projectAvg = computeProjectAverage(projectGrades, projectSubjects, studentId)

  return courseSubjects.value.map(cs => {
    const defs = defsByCourseSubject[cs.id] || []
    const subjectIsProject = projectSubjects.includes(cs.subject_id)
    const totals = computeSubjectTotal(defs, gradesByStudent.value[studentId], projectAvg, subjectIsProject)
    return {
      subjectId: cs.subject_id,
      courseSubjectId: cs.id,
      subject: cs.subjects?.name || 'Sin nombre',
      total: totals.total
    }
  })
}

const getStudentQuarterAverage = (quarterId, studentId) => {
  const rows = computeQuarterTotalsForStudent(quarterId, studentId)
  const valid = rows.filter(r => r.total !== null && r.total !== undefined && !isNaN(r.total))
  if (valid.length === 0) return null
  return valid.reduce((sum, r) => sum + r.total, 0) / valid.length
}

const underperformingStudents = computed(() => {
  if (!selectedCourse.value || !selectedQuarter.value || isQualitativeCourse.value) return []
  return students.value
    .map(student => {
      const average = getStudentQuarterAverage(selectedQuarter.value, student.id)
      if (average === null || average === undefined || isNaN(average) || average >= 7) return null
      const subjects = computeQuarterTotalsForStudent(selectedQuarter.value, student.id)
      return { student, average, subjects }
    })
    .filter(Boolean)
})

const studentsWithMissingGrades = computed(() => {
  if (!selectedCourse.value || !selectedQuarter.value || isQualitativeCourse.value) return []
  return students.value
    .map(student => {
      const subjects = computeQuarterTotalsForStudent(selectedQuarter.value, student.id)
      const missing = subjects.filter(s => s.total === null || s.total === undefined || isNaN(s.total))
      if (missing.length === 0) return null
      return {
        student,
        missingCount: missing.length,
        subjectsMissing: missing.map(s => s.subject)
      }
    })
    .filter(Boolean)
})

const actaFinalRows = computed(() => {
  const periodIds = orderedQuarters.value.map(q => q.id).filter(Boolean)
  if (periodIds.length === 0) return []

  return students.value.map(stu => {
    const bySubject = {}
    periodIds.forEach((pid, idx) => {
      const rows = computeQuarterTotalsForStudent(pid, stu.id)
      rows.forEach(r => {
        if (!bySubject[r.subjectId]) {
          bySubject[r.subjectId] = { subject: r.subject, courseSubjectId: r.courseSubjectId, periods: [] }
        }
        bySubject[r.subjectId].periods[idx] = r.total
      })
    })

    const subjects = courseSubjects.value.map(cs => {
      const entry = bySubject[cs.subject_id] || { subject: cs.subjects?.name || 'Sin nombre' }
      const values = (entry.periods || []).map(v => v ?? null)
      const avg = values.filter(v => v !== null && v !== undefined && !isNaN(v))
      const p = avg.length ? truncate2(avg.reduce((s, v) => s + v, 0) / avg.length) : null
      const rawS = supplementaryScores.value?.[stu.id]?.[entry.courseSubjectId]
      const sVal = rawS === '' || rawS === null || rawS === undefined ? null : parseFloat(rawS)
      const pf = (p !== null && p !== undefined)
        ? (sVal !== null && !isNaN(sVal) ? Math.max(p, sVal) : p)
        : (sVal !== null && !isNaN(sVal) ? sVal : null)
      const finalAnnual = computeFinalAnnual(p, sVal)
      const finalObs = computeFinalObservation(p, sVal, finalAnnual)
      const allowSuplet = p !== null && p >= 4.01 && p < 7
      const supletMessage = p === null ? '' : (p >= 7 ? 'No rinde supletorio' : (p < 4.01 ? 'No puede rendir supletorio' : 'Habilitado'))
      return {
        subject: entry.subject,
        courseSubjectId: entry.courseSubjectId,
        periods: values,
        p,
        s: sVal,
        pf,
        finalAnnual,
        finalObs,
        allowSuplet,
        supletMessage
      }
    })

    return {
      student: stu,
      subjects
    }
  })
})

const resumenFinalRows = computed(() => {
  return students.value.map(stu => {
    const subjectFinals = courseSubjects.value.map(cs => {
      const subjectName = cs.subjects?.name || 'Sin nombre'
      const periodIds = orderedQuarters.value.map(q => q.id).filter(Boolean)
      const periodValues = periodIds.map(pid => computeQuarterTotalsForStudent(pid, stu.id).find(r => r.subjectId === cs.subject_id)?.total ?? null)
      const avg = periodValues.filter(v => v !== null && v !== undefined && !isNaN(v))
      const p = avg.length ? truncate2(avg.reduce((s, v) => s + v, 0) / avg.length) : null
      const rawS = supplementaryScores.value?.[stu.id]?.[cs.id]
      const sVal = rawS === '' || rawS === null || rawS === undefined ? null : parseFloat(rawS)
      const pf = (p !== null && p !== undefined)
        ? (sVal !== null && !isNaN(sVal) ? Math.max(p, sVal) : p)
        : (sVal !== null && !isNaN(sVal) ? sVal : null)
      const finalAnnual = computeFinalAnnual(p, sVal)
      const finalObs = computeFinalObservation(p, sVal, finalAnnual)
      return { subject: subjectName, pf, finalAnnual, finalObs }
    })
    const valid = subjectFinals.filter(s => s.pf !== null && !isNaN(s.pf))
    const promedioAnual = valid.length ? (valid.reduce((s, v) => s + v.pf, 0) / valid.length) : null
    const validFinalAnnual = subjectFinals.filter(s => s.finalAnnual !== null && !isNaN(s.finalAnnual))
    const promedioFinalAnnual = validFinalAnnual.length
      ? (validFinalAnnual.reduce((s, v) => s + v.finalAnnual, 0) / validFinalAnnual.length)
      : null
    const hasFailedSubjects = subjectFinals.some(s => s.finalAnnual !== null && s.finalAnnual < 7)
    const promocionEstado = validFinalAnnual.length === 0
      ? '-'
      : (!hasFailedSubjects && promedioFinalAnnual !== null && promedioFinalAnnual >= 7 ? 'PROMOVIDO' : 'NO PROMOVIDO')

    return { student: stu, subjectFinals, promedioAnual, promedioFinalAnnual, hasFailedSubjects, promocionEstado }
  })
})

const handlePrint = () => {
  window.print()
}

const downloadReportsPdf = async () => {
  if (!reportsRef.value) return
  try {
    // Inject @page rule dynamically to handle landscape vs portrait
    let styleEl = document.getElementById('print-page-style')
    if (!styleEl) {
      styleEl = document.createElement('style')
      styleEl.id = 'print-page-style'
      document.head.appendChild(styleEl)
    }
    const orientation = reportMode.value === 'GENERAL' ? 'landscape' : 'portrait'
    styleEl.innerHTML = `@page { size: A4 ${orientation}; margin: 12mm 10mm 14mm 10mm; }`

    window.print()
  } catch (e) {
    alert('No se pudo generar el PDF. Hubo un error inesperado.')
  }
}

const toggleSupplementaryEdit = () => {
  supplementaryEditing.value = !supplementaryEditing.value
  supplementaryMessage.value = ''
}

const updateSupplementaryScore = (studentId, courseSubjectId, value) => {
  if (!supplementaryScores.value[studentId]) supplementaryScores.value[studentId] = {}
  supplementaryScores.value[studentId][courseSubjectId] = value
}

const saveSupplementary = async () => {
  supplementarySaving.value = true
  supplementaryMessage.value = ''
  const upserts = []
  const toDelete = []
  const existing = supplementaryExistingKeys.value
  const invalid = []

  const eligibility = new Map()
  actaFinalRows.value.forEach(row => {
    row.subjects.forEach(sub => {
      eligibility.set(`${row.student.id}:${sub.courseSubjectId}`, sub.allowSuplet)
    })
  })

  students.value.forEach(stu => {
    courseSubjects.value.forEach(cs => {
      const val = supplementaryScores.value?.[stu.id]?.[cs.id]
      const key = `${stu.id}:${cs.id}`
      const canSuplet = eligibility.get(key)
      if (val !== null && val !== undefined && val !== '') {
        if (!canSuplet) {
          invalid.push(key)
          return
        }
        upserts.push({ student_id: stu.id, course_subject_id: cs.id, score: val })
      } else if (existing.has(key)) {
        toDelete.push({ student_id: stu.id, course_subject_id: cs.id })
      }
    })
  })

  try {
    const { error } = await supabase.rpc('save_supplementary_batch', {
      p_upserts: upserts,
      p_deletes: toDelete
    })
    if (error) throw error

    supplementaryExistingKeys.value = new Set(
      upserts.map(u => `${u.student_id}:${u.course_subject_id}`)
    )
    supplementaryMessage.value = invalid.length > 0
      ? 'Algunos supletorios no se guardaron por no estar habilitados.'
      : 'Supletorios guardados'
    supplementaryEditing.value = false
  } catch (e) {
    supplementaryMessage.value = 'Error guardando supletorio: ' + e.message
  }
  supplementarySaving.value = false
}

const getProjectAverageForStudent = (studentId) => {
  const subjectIds = projectSettingsByQuarter.value[selectedQuarter.value] || []
  const grades = projectGradesByQuarter.value[selectedQuarter.value] || {}
  return computeProjectAverage(grades, subjectIds, studentId)
}

const getProjectTotalForStudent = (studentId) => {
  const avg = getProjectAverageForStudent(studentId)
  if (avg === null || avg === undefined || isNaN(avg)) return null
  return truncate2(avg * 0.15)
}

const loadIndividualReport = async () => {
  if (!selectedStudentId.value || !selectedCourse.value || !selectedQuarter.value) return
  individualLoading.value = true
  individualError.value = ''
  individualSubjects.value = []
  individualAverage.value = null
  individualProjectAverage.value = null
  try {
    const studentId = selectedStudentId.value
    if (isQualitativeCourse.value) {
      const map = qualitativeGradesByStudent.value[studentId] || {}
      individualSubjects.value = courseSubjects.value.map(cs => ({
        subject: cs.subjects?.name || 'Sin nombre',
        qualitative: map[cs.id] || '-'
      }))
      individualLoading.value = false
      return
    }

    const defsByCourseSubject = definitionsByQuarter.value[selectedQuarter.value] || {}
    const projectSubjects = projectSettingsByQuarter.value[selectedQuarter.value] || []
    const projectGrades = projectGradesByQuarter.value[selectedQuarter.value] || {}
    const projectAvg = computeProjectAverage(projectGrades, projectSubjects, studentId)
    individualProjectAverage.value = projectAvg

    const rows = courseSubjects.value.map(cs => {
      const defs = (defsByCourseSubject[cs.id] || []).slice().sort((a, b) => a.sort_order - b.sort_order)
      const subjectIsProject = projectSubjects.includes(cs.subject_id)
      const totals = computeSubjectTotal(defs, gradesByStudent.value[studentId], projectAvg, subjectIsProject)
      return {
        subject: cs.subjects?.name || 'Sin nombre',
        total: totals.total
      }
    })
    individualSubjects.value = rows
    const valid = rows.filter(r => r.total !== null && r.total !== undefined && !isNaN(r.total))
    individualAverage.value = valid.length > 0
      ? (valid.reduce((sum, r) => sum + r.total, 0) / valid.length)
      : null
  } catch (e) {
    individualError.value = 'Error cargando reporte individual: ' + e.message
  }
  individualLoading.value = false
}

onMounted(async () => {
  await fetchInstitutionConfig()
  // Config, courses, quarters fetched automatically by Vue Query

  // Catch Deep-Links from Families Dashboard
  if (route.query.course_id && route.query.student_id) {
    selectedCourse.value = route.query.course_id
    selectedStudentId.value = route.query.student_id
    reportMode.value = 'INDIVIDUAL'
    
    // Give time to ensure fetchCourseData triggers via watch
    setTimeout(() => {
       loadIndividualReport()
       if (route.query.download === '1') {
         setTimeout(() => {
            downloadReportsPdf()
         }, 500)
       }
    }, 1500)
  }
})

watch([selectedCourse, selectedQuarter], async ([courseId]) => {
  if (!courseId) return
  await fetchCourseData()
  if (reportMode.value === 'INDIVIDUAL') {
    await loadIndividualReport()
  }
})

watch([selectedStudentId, reportMode], async () => {
  if (reportMode.value === 'INDIVIDUAL') {
    await loadIndividualReport()
  }
})
</script>

<template>
  <div class="w-full max-w-[1600px] mx-auto min-w-0 flex flex-col space-y-5 pb-24 sm:pb-20 report-shell">
    <main class="w-full min-w-0 flex flex-col space-y-5 report-page">
      <!-- Academic Year Banner (oculto al imprimir) -->
      <AcademicYearBanner module-name="Reportes y Boletines" :compact="true" class="no-print" />

      <!-- Page Header Principal -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 no-print">
        <div class="flex items-start sm:items-center gap-3.5 min-w-0">
          <div class="p-2.5 sm:p-3 rounded-2xl bg-teal-500/10 text-teal-600 dark:text-teal-400 border border-teal-500/20 shadow-sm shrink-0">
            <FileText class="w-6 h-6 sm:w-7 sm:h-7" />
          </div>
          <div class="min-w-0">
            <h1 class="text-xl sm:text-2xl lg:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight leading-tight">
              Reportes Académicos
            </h1>
            <p class="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
              Consulta, analiza, imprime y descarga información académica de tus cursos.
            </p>
          </div>
        </div>

        <div class="hidden sm:flex items-center gap-2.5 shrink-0">
          <div class="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-xs font-semibold text-slate-600 dark:text-slate-300 shadow-sm">
            <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
            <span>Ciclo {{ academicYearStore.selectedYearName || 'Activo' }}</span>
          </div>
        </div>
      </div>

      <!-- Report Summary Card Compacta (no-print) -->
      <section class="rounded-2xl border border-slate-200/90 dark:border-slate-800/90 bg-white dark:bg-slate-900/80 p-4 sm:p-5 shadow-sm no-print">
        <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          <!-- Logo e Institución -->
          <div class="flex items-center gap-3.5 min-w-0">
            <div class="w-12 h-12 sm:w-14 sm:h-14 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 overflow-hidden flex items-center justify-center shrink-0 shadow-sm p-1">
              <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo institucional" class="h-full w-full object-contain" />
              <Building2 v-else class="w-6 h-6 text-slate-400" />
            </div>
            <div class="min-w-0">
              <span class="text-[10px] sm:text-[11px] font-bold tracking-wider text-teal-600 dark:text-teal-400 uppercase block">
                LOGREVA · Gestión Académica
              </span>
              <h2 class="text-base sm:text-lg font-bold text-slate-900 dark:text-white truncate mt-0.5">
                {{ institutionName || 'Institución Educativa' }}
              </h2>
              <p class="text-xs text-slate-500 dark:text-slate-400 flex items-center gap-1.5 mt-0.5">
                <span>Informe Académico</span>
                <span>·</span>
                <span class="font-medium text-slate-700 dark:text-slate-300">
                  {{ getQuarterName(selectedQuarter) || 'General' }}
                </span>
              </p>
            </div>
          </div>

          <!-- Matriz compacta de metadatos -->
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-3 shrink-0 pt-3 lg:pt-0 border-t lg:border-t-0 border-slate-100 dark:border-slate-800 text-xs">
            <div class="px-3 py-2 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-100 dark:border-slate-800/80">
              <span class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider block">Curso</span>
              <span class="font-bold text-slate-800 dark:text-slate-200 truncate block mt-0.5">
                {{ courses.find(c => c.id === selectedCourse)?.name || 'Sin seleccionar' }}
              </span>
            </div>
            <div class="px-3 py-2 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-100 dark:border-slate-800/80">
              <span class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider block">Régimen</span>
              <span class="font-bold text-slate-800 dark:text-slate-200 truncate block mt-0.5">
                {{ regime === 'COSTA_GALAPAGOS' ? 'Costa-Galápagos' : 'Sierra-Amazonía' }}
              </span>
            </div>
            <div class="px-3 py-2 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-100 dark:border-slate-800/80">
              <span class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider block">Período</span>
              <span class="font-bold text-slate-800 dark:text-slate-200 truncate block mt-0.5">
                {{ academicPeriods === 'QUIMESTRE' ? 'Quimestral' : 'Trimestral' }}
              </span>
            </div>
            <div class="px-3 py-2 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-100 dark:border-slate-800/80">
              <span class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider block">Fecha</span>
              <span class="font-bold text-slate-800 dark:text-slate-200 truncate block mt-0.5">
                {{ new Date().toLocaleDateString('es-EC') }}
              </span>
            </div>
          </div>
        </div>
      </section>

      <!-- Barra de Filtros y Acciones Administrativa (no-print) -->
      <section class="rounded-2xl border border-slate-200/90 dark:border-slate-800/90 bg-white dark:bg-slate-900/80 p-4 sm:p-5 shadow-sm no-print">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-12 gap-3.5 items-end">
          <!-- Selector de Curso -->
          <div :class="reportMode === 'INDIVIDUAL' ? 'lg:col-span-3' : 'lg:col-span-3'">
            <label class="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">Curso</label>
            <div class="relative">
              <select
                v-model="selectedCourse"
                @change="fetchCourseData"
                class="w-full h-10 px-3 text-xs sm:text-sm font-semibold rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-colors cursor-pointer"
              >
                <option :value="null">Seleccionar curso…</option>
                <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
              </select>
            </div>
          </div>

          <!-- Selector de Período -->
          <div :class="reportMode === 'INDIVIDUAL' ? 'lg:col-span-3' : 'lg:col-span-3'">
            <label class="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">Período</label>
            <div class="relative">
              <select
                v-model="selectedQuarter"
                class="w-full h-10 px-3 text-xs sm:text-sm font-semibold rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-colors cursor-pointer"
              >
                <option v-for="q in quarters" :key="q.id" :value="q.id">{{ q.name }}</option>
              </select>
            </div>
          </div>

          <!-- Tipo de Reporte -->
          <div :class="reportMode === 'INDIVIDUAL' ? 'lg:col-span-2' : 'lg:col-span-2'">
            <label class="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">Tipo de reporte</label>
            <div class="relative">
              <select
                v-model="reportMode"
                class="w-full h-10 px-3 text-xs sm:text-sm font-semibold rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-colors cursor-pointer"
              >
                <option value="GENERAL">General (Sábana)</option>
                <option value="INDIVIDUAL">Individual (Boletín)</option>
              </select>
            </div>
          </div>

          <!-- Selector de Estudiante (Modo Individual) -->
          <div v-if="reportMode === 'INDIVIDUAL'" class="lg:col-span-4">
            <label class="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">Estudiante</label>
            <div class="relative">
              <select
                v-model="selectedStudentId"
                class="w-full h-10 px-3 text-xs sm:text-sm font-semibold rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-colors cursor-pointer"
              >
                <option :value="null">Seleccionar estudiante…</option>
                <option v-for="s in students" :key="s.id" :value="s.id">{{ s.full_name }}</option>
              </select>
            </div>
          </div>

          <!-- Acciones: Descargar PDF + Imprimir -->
          <div :class="[reportMode === 'INDIVIDUAL' ? 'lg:col-span-12 sm:col-span-2' : 'lg:col-span-4', 'flex items-center justify-end gap-2.5 pt-2 sm:pt-0']">
            <button
              @click="downloadReportsPdf"
              type="button"
              class="flex-1 sm:flex-initial h-10 px-4 rounded-xl bg-gradient-to-r from-teal-600 to-teal-500 hover:from-teal-500 hover:to-teal-400 text-white font-bold text-xs sm:text-sm shadow-sm shadow-teal-900/10 transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-[0.98]"
              title="Descargar versión en PDF"
            >
              <Download class="w-4 h-4" />
              <span>Descargar PDF</span>
            </button>
            <button
              @click="handlePrint"
              type="button"
              class="flex-1 sm:flex-initial h-10 px-4 rounded-xl bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-700 font-semibold text-xs sm:text-sm shadow-sm transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-[0.98]"
              title="Imprimir documento oficial"
            >
              <Printer class="w-4 h-4" />
              <span>Imprimir</span>
            </button>
          </div>
        </div>
      </section>

      <!-- Error Alert -->
      <div
        v-if="error"
        class="rounded-xl border border-rose-200 dark:border-rose-900/60 bg-rose-50 dark:bg-rose-950/40 p-4 text-xs sm:text-sm text-rose-800 dark:text-rose-300 flex items-center gap-2 shadow-sm"
        role="alert"
      >
        <AlertTriangle class="w-4 h-4 shrink-0 text-rose-600 dark:text-rose-400" />
        <span>{{ error }}</span>
      </div>

      <!-- Loading State -->
      <div
        v-if="loading"
        class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/80 p-8 text-center shadow-sm"
      >
        <div class="inline-flex items-center justify-center w-10 h-10 rounded-full bg-teal-50 dark:bg-teal-950/60 text-teal-600 dark:text-teal-400 mb-3 animate-spin">
          <span class="inline-block h-5 w-5 rounded-full border-2 border-teal-600 border-t-transparent"></span>
        </div>
        <p class="text-sm font-semibold text-slate-700 dark:text-slate-300">Cargando reportes académicos…</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Sincronizando calificaciones y promedios</p>
      </div>

      <!-- Report Stack (General) -->
      <div ref="reportsRef" v-else-if="selectedCourse && students.length > 0 && reportMode === 'GENERAL'" class="flex flex-col space-y-6 report-stack">
        <!-- CABECERA PARA PDF (VISIBLE AL EXPORTAR O IMPRIMIR) -->
        <div class="report-header screen-hidden">
          <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo" class="report-logo" />
          <div v-else style="width: 70px; height: 70px; background: #e2e8f0; display:flex; align-items:center; justify-content:center; flex-shrink:0;">Logo</div>
          <div class="report-header-content">
            <h1 style="margin: 0; color: #0f172a; font-size: 20px; font-weight: 800; text-transform: uppercase;">{{ institutionName || 'Unidad Educativa' }}</h1>
            <h2 style="margin: 0; color: #0f766e; font-size: 14px; font-weight: 700; margin-top: 2px;">Reporte Consolidado de Calificaciones</h2>
            <p style="margin: 0; color: #475569; font-size: 11px; margin-top: 4px;">
              Período: {{ getQuarterName(selectedQuarter) }} | Curso: {{ courses.find(c => c.id === selectedCourse)?.name || '-' }}
            </p>
            <p style="margin: 0; color: #475569; font-size: 10px; margin-top: 2px;">Generado el: {{ new Date().toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' }) }}</p>
          </div>
        </div>

        <!-- SÁBANA POR TRIMESTRE -->
        <section class="rounded-2xl border border-slate-200/90 dark:border-slate-800/90 bg-white dark:bg-slate-900/80 p-4 sm:p-5 shadow-sm report-section print-page">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4 report-section-head">
            <div>
              <div class="flex items-center gap-2 mb-1">
                <span class="inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-teal-50 text-teal-700 dark:bg-teal-950/60 dark:text-teal-300 border border-teal-200 dark:border-teal-800/60 report-pill">
                  Sábana
                </span>
              </div>
              <h3 class="text-base sm:text-lg font-bold text-slate-900 dark:text-white">
                Sábana de Calificaciones — {{ getQuarterName(selectedQuarter) }}
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 report-section-note">
                Consolidado académico general y detalle de notas por asignatura para el curso seleccionado.
              </p>
            </div>
          </div>

          <div v-if="isQualitativeCourse" class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-800 report-table-wrap">
            <div class="p-3 bg-slate-50 dark:bg-slate-800/50 border-b border-slate-200 dark:border-slate-800 text-xs text-slate-600 dark:text-slate-400 report-legend">
              Escala cualitativa: A+/A- (alcanzado), B+/B-/C+/C- (en proceso), D+/D-/E+/E- (iniciado).
            </div>
            <table class="w-full text-left border-collapse report-table report-table-compact">
              <thead>
                <tr class="bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 text-[11px] font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300">
                  <th class="py-2.5 px-3">Estudiante</th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="py-2.5 px-3 text-center">
                    {{ cs.subjects?.name }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60 text-xs">
                <tr v-for="stu in students" :key="stu.id" class="hover:bg-teal-50/30 dark:hover:bg-slate-800/50 transition-colors">
                  <td class="py-2.5 px-3 font-semibold text-slate-800 dark:text-slate-200">{{ stu.full_name }}</td>
                  <td v-for="cs in courseSubjects" :key="cs.id" class="py-2.5 px-3 text-center text-slate-600 dark:text-slate-300">
                    {{ qualitativeGradesByStudent?.[stu.id]?.[cs.id] || '-' }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div v-else class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-800 report-table-wrap">
            <table class="w-full text-left border-collapse report-table report-table-compact">
              <thead>
                <tr class="bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 text-[11px] font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300">
                  <th class="py-2.5 px-3">Estudiante</th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="py-2.5 px-3 text-right">
                    {{ cs.subjects?.name }}
                  </th>
                  <th class="py-2.5 px-3 text-right text-teal-700 dark:text-teal-400 bg-teal-50/50 dark:bg-teal-950/30">
                    Promedio Trimestre
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60 text-xs">
                <tr v-for="stu in students" :key="stu.id" class="hover:bg-teal-50/30 dark:hover:bg-slate-800/50 transition-colors">
                  <td class="py-2.5 px-3 font-semibold text-slate-800 dark:text-slate-200">{{ stu.full_name }}</td>
                  <td v-for="cs in courseSubjects" :key="cs.id" class="py-2.5 px-3 text-right tabular-nums text-slate-600 dark:text-slate-300">
                    {{
                      computeQuarterTotalsForStudent(selectedQuarter, stu.id)
                        .find(r => r.subjectId === cs.subject_id)?.total?.toFixed(2) || '-'
                    }}
                  </td>
                  <td class="py-2.5 px-3 text-right font-bold tabular-nums text-teal-700 dark:text-teal-300 bg-teal-50/30 dark:bg-teal-950/20 strong">
                    {{ getStudentQuarterAverage(selectedQuarter, stu.id)?.toFixed(2) || '-' }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- ALERTAS WHATSAPP -->
        <section class="rounded-2xl border border-slate-200/90 dark:border-slate-800/90 bg-white dark:bg-slate-900/80 p-4 sm:p-5 shadow-sm report-section no-print">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4 report-section-head">
            <div>
              <div class="flex items-center gap-2 mb-1">
                <span class="inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-amber-50 text-amber-700 dark:bg-amber-950/60 dark:text-amber-300 border border-amber-200 dark:border-amber-800/60 report-pill">
                  Alertas
                </span>
              </div>
              <h3 class="text-base sm:text-lg font-bold text-slate-900 dark:text-white">
                Rendimiento Bajo (Promedio &lt; 7)
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 report-section-note">
                Envía un mensaje al representante legal con el desglose de calificaciones.
              </p>
            </div>
          </div>

          <div v-if="isQualitativeCourse" class="py-4 text-center text-xs text-slate-500 dark:text-slate-400 report-empty">
            Este reporte no aplica para cursos cualitativos.
          </div>
          <div v-else-if="underperformingStudents.length === 0" class="py-6 text-center text-xs text-slate-500 dark:text-slate-400 flex items-center justify-center gap-2 report-empty">
            <CheckCircle2 class="w-4 h-4 text-emerald-500" />
            <span>No hay estudiantes con promedio menor a 7 en este período. ¡Excelente rendimiento!</span>
          </div>
          <div v-else class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-800 report-table-wrap">
            <table class="w-full text-left border-collapse report-table report-table-compact">
              <thead>
                <tr class="bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 text-[11px] font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300">
                  <th class="py-2.5 px-3">Estudiante</th>
                  <th class="py-2.5 px-3 text-right">Promedio</th>
                  <th class="py-2.5 px-3">Representante</th>
                  <th class="py-2.5 px-3 text-right">Acciones</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60 text-xs">
                <tr v-for="row in underperformingStudents" :key="row.student.id" class="hover:bg-amber-50/30 dark:hover:bg-slate-800/50 transition-colors">
                  <td class="py-2.5 px-3 font-semibold text-slate-800 dark:text-slate-200">{{ row.student.full_name }}</td>
                  <td class="py-2.5 px-3 text-right font-bold tabular-nums text-rose-600 dark:text-rose-400 strong">
                    {{ formatScore(row.average) }}
                  </td>
                  <td class="py-2.5 px-3 text-slate-600 dark:text-slate-400">
                    {{ row.student.representative_name || 'Sin representante' }}
                  </td>
                  <td class="py-2.5 px-3 text-right">
                    <div class="flex items-center justify-end gap-1.5 report-inline-actions">
                      <button
                        @click="openStudentRecovery(row)"
                        type="button"
                        class="px-2.5 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs transition-colors flex items-center gap-1 cursor-pointer"
                        title="Generar tarea individualizada o plan de recuperación con IA"
                      >
                        <Sparkles class="w-3.5 h-3.5" />
                        <span>Recuperación IA</span>
                      </button>
                      <button
                        @click="previewWhatsappMessage(row)"
                        type="button"
                        class="px-2.5 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 border border-slate-200 dark:border-slate-700 font-semibold text-xs transition-colors cursor-pointer"
                      >
                        Previsualizar
                      </button>
                      <button
                        @click="sendWhatsappMessage(row)"
                        :disabled="!normalizeWhatsappPhone(row.student.representative_phone)"
                        type="button"
                        class="px-2.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-xs transition-colors flex items-center gap-1 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        <MessageCircle class="w-3.5 h-3.5" />
                        <span>WhatsApp</span>
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
            <p class="p-3 text-[11px] text-slate-500 dark:text-slate-400 bg-slate-50/50 dark:bg-slate-800/30 border-t border-slate-200 dark:border-slate-800 report-hint">
              Nota: el número de WhatsApp del representante debe incluir código de país (ej. 593XXXXXXXXX).
            </p>
          </div>
        </section>

        <!-- CONSISTENCIA DE NOTAS -->
        <section class="rounded-2xl border border-slate-200/90 dark:border-slate-800/90 bg-white dark:bg-slate-900/80 p-4 sm:p-5 shadow-sm report-section no-print">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4 report-section-head">
            <div>
              <div class="flex items-center gap-2 mb-1">
                <span class="inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-blue-50 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300 border border-blue-200 dark:border-blue-800/60 report-pill">
                  Verificación
                </span>
              </div>
              <h3 class="text-base sm:text-lg font-bold text-slate-900 dark:text-white">
                Consistencia de Calificaciones
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 report-section-note">
                Estudiantes con asignaturas sin promedio registrado en el período seleccionado.
              </p>
            </div>
          </div>

          <div v-if="isQualitativeCourse" class="py-4 text-center text-xs text-slate-500 dark:text-slate-400 report-empty">
            Este reporte no aplica para cursos cualitativos.
          </div>
          <div v-else-if="studentsWithMissingGrades.length === 0" class="py-6 text-center text-xs text-slate-500 dark:text-slate-400 flex items-center justify-center gap-2 report-empty">
            <CheckCircle2 class="w-4 h-4 text-emerald-500" />
            <span>Todas las notas del período están completas y consistentes.</span>
          </div>
          <div v-else class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-800 report-table-wrap">
            <table class="w-full text-left border-collapse report-table report-table-compact">
              <thead>
                <tr class="bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 text-[11px] font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300">
                  <th class="py-2.5 px-3">Estudiante</th>
                  <th class="py-2.5 px-3 text-right">Asignaturas sin promedio</th>
                  <th class="py-2.5 px-3">Detalle de materias pendientes</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60 text-xs">
                <tr v-for="row in studentsWithMissingGrades" :key="row.student.id" class="hover:bg-blue-50/30 dark:hover:bg-slate-800/50 transition-colors">
                  <td class="py-2.5 px-3 font-semibold text-slate-800 dark:text-slate-200">{{ row.student.full_name }}</td>
                  <td class="py-2.5 px-3 text-right font-bold tabular-nums text-amber-600 dark:text-amber-400 strong">
                    {{ row.missingCount }}
                  </td>
                  <td class="py-2.5 px-3 text-slate-600 dark:text-slate-400">
                    {{ row.subjectsMissing.join(', ') }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- ACTA FINAL -->
        <section class="rounded-2xl border border-slate-200/90 dark:border-slate-800/90 bg-white dark:bg-slate-900/80 p-4 sm:p-5 shadow-sm report-section print-page" v-if="!isQualitativeCourse">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4 report-section-head">
            <div>
              <div class="flex items-center gap-2 mb-1">
                <span class="inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-purple-50 text-purple-700 dark:bg-purple-950/60 dark:text-purple-300 border border-purple-200 dark:border-purple-800/60 report-pill">
                  Acta Final
                </span>
              </div>
              <h3 class="text-base sm:text-lg font-bold text-slate-900 dark:text-white">
                Acta Final y Calificación de Supletorio
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 report-section-note">
                Registro anual consolidado con habilitación de examen supletorio (Normativa MINEDEC).
              </p>
            </div>
            <div class="flex items-center gap-2 no-print report-inline-actions">
              <button
                @click="toggleSupplementaryEdit"
                type="button"
                class="px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 border border-slate-200 dark:border-slate-700 font-semibold text-xs transition-colors cursor-pointer"
              >
                {{ supplementaryEditing ? 'Cancelar' : 'Editar Supletorio' }}
              </button>
              <button
                @click="saveSupplementary"
                :disabled="supplementarySaving"
                type="button"
                class="px-3.5 py-1.5 rounded-xl bg-teal-600 hover:bg-teal-500 text-white font-bold text-xs transition-colors flex items-center gap-1.5 cursor-pointer disabled:opacity-50"
              >
                <span>{{ supplementarySaving ? 'Guardando...' : 'Guardar Supletorio' }}</span>
              </button>
              <span v-if="supplementaryMessage" class="text-xs text-teal-600 dark:text-teal-400 font-medium report-hint">
                {{ supplementaryMessage }}
              </span>
            </div>
          </div>

          <div class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-800 report-table-wrap">
            <table class="w-full text-left border-collapse report-table report-table-compact">
              <thead>
                <tr class="bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 text-[11px] font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300">
                  <th class="py-2.5 px-3">Estudiante</th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="py-2.5 px-3 text-center">
                    {{ cs.subjects?.name }}
                  </th>
                </tr>
                <tr class="bg-slate-100/60 dark:bg-slate-800/40 border-b border-slate-200 dark:border-slate-700 text-[10px] text-slate-500 dark:text-slate-400">
                  <th class="py-1.5 px-3 subhead"></th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="py-1.5 px-3 subhead text-center font-medium">
                    {{ orderedPeriodLabels.join(' | ') }} | P | S | PF | FA | OBS
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60 text-xs">
                <tr v-for="row in actaFinalRows" :key="row.student.id" class="hover:bg-slate-50/50 dark:hover:bg-slate-800/50 transition-colors">
                  <td class="py-2.5 px-3 font-semibold text-slate-800 dark:text-slate-200">{{ row.student.full_name }}</td>
                  <td v-for="sub in row.subjects" :key="sub.subject" class="py-2.5 px-3 text-center tabular-nums text-slate-600 dark:text-slate-300">
                    <span v-for="(val, idx) in sub.periods" :key="idx">
                      {{ val?.toFixed(2) || '-' }}<span v-if="idx < sub.periods.length - 1" class="text-slate-300 dark:text-slate-700"> | </span>
                    </span>
                    <span class="text-slate-300 dark:text-slate-700"> | </span>
                    <span class="font-semibold">{{ sub.p?.toFixed(2) || '-' }}</span>
                    <span class="text-slate-300 dark:text-slate-700"> | </span>
                    <template v-if="supplementaryEditing">
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        max="10"
                        :value="supplementaryScores?.[row.student.id]?.[sub.courseSubjectId] ?? ''"
                        @input="(e) => updateSupplementaryScore(row.student.id, sub.courseSubjectId, e.target.value)"
                        :disabled="!sub.allowSuplet"
                        class="w-14 py-0.5 px-1 rounded-md border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-center text-xs font-semibold focus:ring-1 focus:ring-teal-500 focus:outline-none disabled:opacity-40 disabled:bg-slate-100 dark:disabled:bg-slate-900 report-input-small"
                      />
                    </template>
                    <template v-else>
                      <span class="font-semibold" :class="sub.s ? 'text-amber-600 dark:text-amber-400' : ''">{{ sub.s ?? '-' }}</span>
                    </template>
                    <span class="text-slate-300 dark:text-slate-700"> | </span>
                    <span class="font-bold text-teal-700 dark:text-teal-400">{{ sub.pf?.toFixed(2) || '-' }}</span>
                    <span class="text-slate-300 dark:text-slate-700"> | </span>
                    <span class="font-bold">{{ sub.finalAnnual?.toFixed(2) || '-' }}</span>
                    <span class="text-slate-300 dark:text-slate-700"> | </span>
                    <span class="text-[10px] uppercase font-semibold subtle text-slate-500 dark:text-slate-400">{{ sub.finalObs || '-' }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- RESUMEN FINAL -->
        <section class="rounded-2xl border border-slate-200/90 dark:border-slate-800/90 bg-white dark:bg-slate-900/80 p-4 sm:p-5 shadow-sm report-section print-page" v-if="!isQualitativeCourse">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4 report-section-head">
            <div>
              <div class="flex items-center gap-2 mb-1">
                <span class="inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-emerald-50 text-emerald-700 dark:bg-emerald-950/60 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800/60 report-pill">
                  Resumen Final
                </span>
              </div>
              <h3 class="text-base sm:text-lg font-bold text-slate-900 dark:text-white">
                Resumen Final y Promoción Anual
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 report-section-note">
                Consolidado final de promedios anuales y estado de promoción escolar.
              </p>
            </div>
          </div>

          <div class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-800 report-table-wrap">
            <table class="w-full text-left border-collapse report-table report-table-compact">
              <thead>
                <tr class="bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 text-[11px] font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300">
                  <th class="py-2.5 px-3">Estudiante</th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="py-2.5 px-3 text-right">
                    {{ cs.subjects?.name }}
                  </th>
                  <th class="py-2.5 px-3 text-right">Promedio Anual (PF)</th>
                  <th class="py-2.5 px-3 text-right text-teal-700 dark:text-teal-400 bg-teal-50/50 dark:bg-teal-950/30">Final Anual (Cap 7)</th>
                  <th class="py-2.5 px-3">Observación / Estado</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60 text-xs">
                <tr v-for="row in resumenFinalRows" :key="row.student.id" class="hover:bg-slate-50/50 dark:hover:bg-slate-800/50 transition-colors">
                  <td class="py-2.5 px-3 font-semibold text-slate-800 dark:text-slate-200">{{ row.student.full_name }}</td>
                  <td v-for="sub in row.subjectFinals" :key="sub.subject" class="py-2.5 px-3 text-right tabular-nums text-slate-600 dark:text-slate-300">
                    {{ sub.pf?.toFixed(2) || '-' }}
                  </td>
                  <td class="py-2.5 px-3 text-right font-bold tabular-nums text-slate-800 dark:text-slate-200 strong">
                    {{ row.promedioAnual?.toFixed(2) || '-' }}
                  </td>
                  <td class="py-2.5 px-3 text-right font-bold tabular-nums text-teal-700 dark:text-teal-300 bg-teal-50/30 dark:bg-teal-950/20">
                    {{ row.promedioFinalAnnual?.toFixed(2) || '-' }}
                  </td>
                  <td class="py-2.5 px-3 font-semibold">
                    <span
                      class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold"
                      :class="row.promocionEstado === 'PROMOVIDO' ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950/80 dark:text-emerald-300' : 'bg-rose-100 text-rose-800 dark:bg-rose-950/80 dark:text-rose-300'"
                    >
                      {{ row.promocionEstado || '-' }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- FIRMAS -->
        <section class="rounded-2xl border border-slate-200/90 dark:border-slate-800/90 bg-white dark:bg-slate-900/80 p-6 shadow-sm report-section print-page">
          <div class="report-signatures">
            <div class="signature-date mb-8">
              <span class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider report-meta-label">Fecha de Emisión: </span>
              <span class="text-xs font-bold text-slate-800 dark:text-slate-200 report-meta-value">{{ new Date().toLocaleDateString('es-EC') }}</span>
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-6 signature-grid">
              <div class="border-t border-slate-300 dark:border-slate-700 pt-3 text-center report-signature-line">
                <span class="text-xs font-bold text-slate-800 dark:text-slate-200 block uppercase signature-name">{{ institutionTutorName || 'Docente Tutor' }}</span>
                <span class="text-[11px] text-slate-500 dark:text-slate-400 block mt-0.5 uppercase tracking-wider signature-role">Docente Tutor</span>
              </div>
              <div class="border-t border-slate-300 dark:border-slate-700 pt-3 text-center report-signature-line">
                <span class="text-xs font-bold text-slate-800 dark:text-slate-200 block uppercase signature-name">{{ institutionRectorName || 'Rector/a' }}</span>
                <span class="text-[11px] text-slate-500 dark:text-slate-400 block mt-0.5 uppercase tracking-wider signature-role">Rector/a</span>
              </div>
              <div class="border-t border-slate-300 dark:border-slate-700 pt-3 text-center report-signature-line">
                <span class="text-xs font-bold text-slate-800 dark:text-slate-200 block uppercase signature-name">Secretario/a</span>
                <span class="text-[11px] text-slate-500 dark:text-slate-400 block mt-0.5 uppercase tracking-wider signature-role">Secretario/a</span>
              </div>
            </div>
            <div class="mt-8 pt-4 border-t border-dashed border-slate-200 dark:border-slate-800 text-[11px] text-slate-500 dark:text-slate-400 text-justify leading-relaxed report-legal-note">
              <strong>Nota Legal:</strong> El presente documento tiene un fin estrictamente informativo para comunicar los resultados académicos obtenidos por el estudiante. Las calificaciones aquí reflejadas podrían presentar variaciones mínimas respecto al sistema oficial. La validez legal y definitiva de las notas está sujeta a la información registrada y emitida por la plataforma educativa del Ministerio de Educación (MINEDEC).
            </div>
          </div>
        </section>
      </div>

      <!-- MODO INDIVIDUAL -->
      <div ref="reportsRef" v-else-if="selectedCourse && reportMode === 'INDIVIDUAL'">
        <IndividualReportSheet
          :institution-logo-url="institutionLogoUrl"
          :institution-name="institutionName"
          :institution-tutor-name="institutionTutorName"
          :institution-rector-name="institutionRectorName"
          :quarter-name="getQuarterName(selectedQuarter)"
          :course-name="courses.find(c => c.id === selectedCourse)?.name || '-'"
          :student-name="students.find(s => s.id === selectedStudentId)?.full_name || ''"
          :has-students="students.length > 0"
          :has-selected-student="!!selectedStudentId"
          :individual-loading="individualLoading"
          :individual-error="individualError"
          :is-qualitative-course="isQualitativeCourse"
          :individual-subjects="individualSubjects"
          :individual-project-average="individualProjectAverage"
          :individual-average="individualAverage"
        />
      </div>

      <!-- Empty States -->
      <div
        v-else-if="selectedCourse"
        class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/80 p-8 text-center shadow-sm text-slate-500 dark:text-slate-400 text-sm report-empty"
      >
        No hay estudiantes registrados en este curso.
      </div>
      <div
        v-else
        class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/80 p-12 text-center shadow-sm text-slate-500 dark:text-slate-400 text-sm report-empty"
      >
        <div class="w-12 h-12 rounded-2xl bg-teal-50 dark:bg-teal-950/60 text-teal-600 dark:text-teal-400 mx-auto flex items-center justify-center mb-3">
          <FileText class="w-6 h-6" />
        </div>
        <p class="font-semibold text-slate-700 dark:text-slate-300">Selecciona un curso y período académico</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Elige los filtros superiores para visualizar la sábana o generar boletines individuales.</p>
      </div>
    </main>

    <!-- WhatsApp Preview Modal -->
    <div v-if="showWhatsappPreview" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm modal-container" role="dialog" aria-modal="true">
      <div class="fixed inset-0 modal-backdrop" @click="showWhatsappPreview = false"></div>
      <div class="relative w-full max-w-2xl bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl overflow-hidden p-6 z-10 modal-panel">
        <h3 class="text-base sm:text-lg font-bold text-slate-900 dark:text-white">
          Mensaje de WhatsApp para {{ whatsappPreviewStudent }}
        </h3>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 mb-4">
          Previsualización del texto a enviar al representante legal.
        </p>
        <textarea
          class="w-full h-64 p-3 font-mono text-xs rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500/20 resize-none app-input"
          readonly
          :value="whatsappPreviewText"
        ></textarea>
        <div class="flex items-center justify-end gap-2.5 mt-5 modal-footer">
          <button
            @click="copyWhatsappMessage"
            type="button"
            class="px-4 py-2 rounded-xl bg-teal-600 hover:bg-teal-500 text-white font-bold text-xs shadow-sm transition-colors cursor-pointer app-btn app-btn-primary"
          >
            Copiar Mensaje
          </button>
          <button
            @click="showWhatsappPreview = false"
            type="button"
            class="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 border border-slate-200 dark:border-slate-700 font-semibold text-xs transition-colors cursor-pointer app-btn app-btn-ghost"
          >
            Cerrar
          </button>
        </div>
      </div>
    </div>

    <!-- Modal de Recuperación Pedagógica con IA -->
    <StudentRecoveryModal
      v-if="showRecoveryModal && selectedStudentForRecovery"
      :student="{ ...selectedStudentForRecovery, course_id: selectedCourse }"
      subject-name="Rendimiento General"
      :score="selectedScoreForRecovery"
      :course-name="courses.find(c => c.id === selectedCourse)?.name || ''"
      :on-close="() => { showRecoveryModal = false }"
    />
  </div>
</template>

<style scoped>
/* Estilos utilitarios y transiciones */
select:focus,
input:focus {
  outline: none;
}
</style>

<!-- =============================================
     PRINT STYLES — NON-SCOPED so they can reach
     parent containers (sidebar, header, main, body)
     ============================================= -->
<style>
/* Hide the report-header on screen; show only when printing */
.report-header.screen-hidden {
  display: none !important;
}

@media print {
  /* ── Reset the entire page ── */
  @page {
    size: A4;
    margin: 12mm 10mm 14mm 10mm;
  }

  html, body {
    width: 100% !important;
    height: auto !important;
    margin: 0 !important;
    padding: 0 !important;
    overflow: visible !important;
    background: #fff !important;
    min-height: 0 !important;
  }

  * {
    box-sizing: border-box;
    print-color-adjust: exact;
    -webkit-print-color-adjust: exact;
  }

  /* ── Kill the app shell (sidebar, top header, wrappers) ── */
  aside,
  nav,
  header,
  .content-layout-wrapper > header,
  button,
  select,
  label,
  .no-print,
  .report-hero,
  .report-card,
  .report-controls,
  .report-actions,
  .report-inline-actions,
  .modal-container,
  .modal-backdrop {
    display: none !important;
  }

  /* ── Unwrap ALL layout containers ── */
  .content-layout-wrapper,
  .flex.min-h-screen,
  main,
  .report-shell,
  .report-page,
  .report-stack {
    display: block !important;
    overflow: visible !important;
    width: 100% !important;
    max-width: none !important;
    min-height: 0 !important;
    height: auto !important;
    margin: 0 !important;
    padding: 0 !important;
    box-shadow: none !important;
    background: transparent !important;
    border: none !important;
    border-radius: 0 !important;
    position: static !important;
  }

  /* ── Show the print-only header ── */
  .report-header.screen-hidden {
    display: flex !important;
    align-items: center;
    gap: 14px;
    margin: 0 0 10px 0;
    padding-bottom: 8px;
    border-bottom: 2.5px solid #0f766e;
    page-break-inside: avoid;
    break-inside: avoid;
  }

  .report-header .report-logo,
  .report-header img {
    width: 55px !important;
    height: 55px !important;
    object-fit: contain;
    flex-shrink: 0;
    border-radius: 6px;
    border: 1px solid #cbd5e1;
    padding: 3px;
  }

  .report-header-content {
    flex: 1;
    min-width: 0;
  }

  /* ── Sections: flat document style, no cards ── */
  .report-section {
    margin-top: 14px !important;
    padding: 0 !important;
    border: none !important;
    border-radius: 0 !important;
    box-shadow: none !important;
    background: transparent !important;
    break-inside: auto;
    page-break-inside: auto;
  }

  .report-section-head {
    break-after: avoid;
    page-break-after: avoid;
    break-inside: avoid;
    page-break-inside: avoid;
    margin-bottom: 6px !important;
  }

  .report-pill {
    background: #f1f5f9 !important;
    color: #334155 !important;
    border: 1px solid #94a3b8 !important;
    font-size: 8px !important;
    padding: 1px 6px !important;
    border-radius: 3px !important;
    font-weight: 700 !important;
    display: inline-block;
    margin-bottom: 3px !important;
  }

  .report-section h3 {
    color: #0f172a !important;
    font-weight: 700 !important;
    font-size: 13px !important;
    margin: 2px 0 4px !important;
  }

  .report-section-note {
    font-size: 9px !important;
    color: #64748b !important;
  }

  /* ── Tables: tight, bordered, professional ── */
  table,
  .report-table {
    width: 100% !important;
    border-collapse: collapse !important;
    table-layout: auto !important;
    margin-top: 4px !important;
    font-size: 8.5px !important;
    line-height: 1.3;
  }

  .report-table th,
  .report-table td {
    border: 1px solid #94a3b8 !important;
    padding: 4px 5px !important;
    vertical-align: middle;
    overflow-wrap: anywhere;
    word-break: normal;
    color: #0f172a !important;
  }

  .report-table th {
    background: #e2e8f0 !important;
    font-weight: 700 !important;
    text-align: left;
    font-size: 8px !important;
    text-transform: uppercase;
    letter-spacing: 0.02em;
  }

  .report-table tr {
    break-inside: avoid !important;
    page-break-inside: avoid !important;
    background-color: transparent !important;
  }

  .report-table tbody tr:nth-child(even) {
    background: #f8fafc !important;
  }

  .report-table thead {
    display: table-header-group !important;
    background-color: transparent !important;
  }

  .report-table tfoot {
    display: table-footer-group !important;
  }

  .report-table .subhead {
    font-size: 7px !important;
    color: #475569 !important;
  }

  .report-table-wrap {
    overflow: visible !important;
  }

  /* ── Signatures ── */
  .report-signatures {
    break-inside: avoid !important;
    page-break-inside: avoid !important;
    margin-top: 30px !important;
  }

  .signature-grid {
    gap: 16px !important;
  }

  .report-signature-line {
    border-top: 1px solid #1e293b !important;
    padding-top: 6px !important;
  }

  .signature-name {
    font-size: 10px !important;
  }

  .signature-role {
    font-size: 8px !important;
  }

  .report-legal-note {
    margin-top: 24px !important;
    font-size: 8px !important;
    color: #64748b !important;
  }

  /* ── Misc ── */
  .report-title {
    font-size: 14px !important;
    color: #0f172a !important;
  }

  .report-legend {
    font-size: 8px !important;
  }

  .report-empty {
    font-size: 10px !important;
  }

  .report-table-compact th,
  .report-table-compact td {
    padding: 3px 4px !important;
    font-size: 8px !important;
  }
}
</style>
