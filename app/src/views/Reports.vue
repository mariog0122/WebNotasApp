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

    let stusQuery = supabase
      .from('students')
      .select('id, full_name, representative_name, representative_phone')
      .eq('course_id', courseId)
      .order('full_name')
    if (sId) {
      stusQuery = stusQuery.or(`school_id.eq.${sId},school_id.is.null`)
    }
    const { data: stus, error: stusError } = await stusQuery
    if (stusError) throw stusError
    students.value = stus || []

    let csQuery = supabase
      .from('course_subjects')
      .select('id, subject_id, teacher_id, subjects (name)')
      .eq('course_id', courseId)
    if (sId) {
      csQuery = csQuery.or(`school_id.eq.${sId},school_id.is.null`)
    }
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
    if (sId) {
      defsQuery = defsQuery.or(`school_id.eq.${sId},school_id.is.null`)
    }
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
      if (psError?.message?.includes('Could not find the table')) {
        projectAvailable.value = false
      }
      projectSettingsMap[q.id] = (ps || []).map(p => p.subject_id)

      const { data: pg, error: pgError } = await supabase
        .from('project_subject_grades')
        .select('student_id, subject_id, score')
        .eq('course_id', courseId)
        .eq('quarter_id', q.id)
      if (pgError?.message?.includes('Could not find the table')) {
        projectAvailable.value = false
      }
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
      const allowSuplet = p !== null && p >= 5 && p < 7
      const supletMessage = p === null ? '' : (p >= 7 ? 'No rinde supletorio' : (p < 5 ? 'No puede rendir supletorio' : 'Habilitado'))
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
    return { student: stu, subjectFinals, promedioAnual, promedioFinalAnnual }
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
  <div class="min-h-screen report-shell">
    <main class="report-page">
      <!-- Academic Year Banner (oculto al imprimir) -->
      <AcademicYearBanner module-name="Reportes y Boletines" class="no-print mb-6" />

      <header class="report-hero">
        <div class="report-hero-row">
          <div class="report-brand">
            <div class="report-logo">
              <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo institucional" />
              <span v-else>Logo</span>
            </div>
            <div>
              <p class="report-kicker">LOGREVA · Gestión Académica</p>
              <h2 class="report-title">{{ institutionName || 'Institución' }}</h2>
              <p class="report-subtitle">Reportes Trimestrales y Finales</p>
            </div>
          </div>
          <div class="report-meta">
            <div>
              <span class="report-meta-label">Fecha</span>
              <span class="report-meta-value">{{ new Date().toLocaleDateString('es-EC') }}</span>
            </div>
            <div>
              <span class="report-meta-label">Documento</span>
              <span class="report-meta-value">Informe académico</span>
            </div>
            <div>
              <span class="report-meta-label">Curso</span>
              <span class="report-meta-value">{{ courses.find(c => c.id === selectedCourse)?.name || '-' }}</span>
            </div>
            <div>
              <span class="report-meta-label">Régimen</span>
              <span class="report-meta-value">{{ regime === 'COSTA_GALAPAGOS' ? 'Costa-Galápagos' : 'Sierra-Amazonía' }}</span>
            </div>
            <div>
              <span class="report-meta-label">Períodos</span>
              <span class="report-meta-value">{{ academicPeriods === 'QUIMESTRE' ? 'Quimestres' : 'Trimestres' }}</span>
            </div>
          </div>
        </div>
      </header>

      <section class="report-card">
        <div class="report-controls">
          <div>
            <label class="report-label">Curso</label>
            <select v-model="selectedCourse" @change="fetchCourseData" class="report-select">
              <option :value="null">Seleccionar</option>
              <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
          </div>
          <div>
            <label class="report-label">Período</label>
            <select v-model="selectedQuarter" class="report-select">
              <option v-for="q in quarters" :key="q.id" :value="q.id">{{ q.name }}</option>
            </select>
          </div>
          <div>
            <label class="report-label">Tipo de reporte</label>
            <select v-model="reportMode" class="report-select">
              <option value="GENERAL">General</option>
              <option value="INDIVIDUAL">Individual</option>
            </select>
          </div>
          <div v-if="reportMode === 'INDIVIDUAL'">
            <label class="report-label">Estudiante</label>
            <select v-model="selectedStudentId" class="report-select">
              <option :value="null">Seleccionar</option>
              <option v-for="s in students" :key="s.id" :value="s.id">{{ s.full_name }}</option>
            </select>
          </div>
          <div class="report-actions">
            <button @click="downloadReportsPdf" class="report-btn report-btn-primary">
              Descargar PDF
            </button>
            <button @click="handlePrint" class="report-btn report-btn-ghost">
              Imprimir
            </button>
          </div>
        </div>
      </section>

      <div v-if="error" class="report-alert report-alert-error">{{ error }}</div>
      <div v-if="loading" class="report-loading">Cargando reportes...</div>

      <div ref="reportsRef" v-else-if="selectedCourse && students.length > 0 && reportMode === 'GENERAL'" class="report-stack">
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
        <section class="report-section print-page">
          <div class="report-section-head">
            <div>
              <p class="report-pill">Sábana</p>
              <h3>Sábana de Calificaciones - {{ getQuarterName(selectedQuarter) }}</h3>
            </div>
          </div>
          <div v-if="isQualitativeCourse" class="report-table-wrap">
            <div class="report-legend">
              Escala cualitativa: A+/A- (alcanzado), B+/B-/C+/C- (en proceso), D+/D-/E+/E- (iniciado).
            </div>
            <table class="report-table report-table-compact">
              <thead>
                <tr>
                  <th>Estudiante</th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="text-center">
                    {{ cs.subjects?.name }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="stu in students" :key="stu.id">
                  <td>{{ stu.full_name }}</td>
                  <td v-for="cs in courseSubjects" :key="cs.id" class="text-center">
                    {{ qualitativeGradesByStudent?.[stu.id]?.[cs.id] || '-' }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-else class="report-table-wrap">
            <table class="report-table report-table-compact">
              <thead>
                <tr>
                  <th>Estudiante</th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="text-right">
                    {{ cs.subjects?.name }}
                  </th>
                  <th class="text-right">Promedio Trimestre</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="stu in students" :key="stu.id">
                  <td>{{ stu.full_name }}</td>
                  <td v-for="cs in courseSubjects" :key="cs.id" class="text-right">
                    {{
                      computeQuarterTotalsForStudent(selectedQuarter, stu.id)
                        .find(r => r.subjectId === cs.subject_id)?.total?.toFixed(2) || '-'
                    }}
                  </td>
                  <td class="text-right strong">
                    {{ getStudentQuarterAverage(selectedQuarter, stu.id)?.toFixed(2) || '-' }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- ALERTAS WHATSAPP -->
        <section class="report-section no-print">
          <div class="report-section-head">
            <div>
              <p class="report-pill">Alertas</p>
              <h3>Rendimiento Bajo (Promedio &lt; 7)</h3>
              <p class="report-section-note">Envía un mensaje al representante con el detalle de notas.</p>
            </div>
          </div>
          <div v-if="isQualitativeCourse" class="report-empty">
            Este reporte no aplica para cursos cualitativos.
          </div>
          <div v-else-if="underperformingStudents.length === 0" class="report-empty">
            No hay estudiantes con promedio menor a 7 en este período.
          </div>
          <div v-else class="report-table-wrap">
            <table class="report-table report-table-compact">
              <thead>
                <tr>
                  <th>Estudiante</th>
                  <th class="text-right">Promedio</th>
                  <th>Representante</th>
                  <th class="text-right">WhatsApp</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in underperformingStudents" :key="row.student.id">
                  <td>{{ row.student.full_name }}</td>
                  <td class="text-right strong">{{ formatScore(row.average) }}</td>
                  <td>{{ row.student.representative_name || 'Sin representante' }}</td>
                  <td class="text-right">
                    <div class="report-inline-actions" style="justify-content:flex-end;">
                      <button
                        @click="previewWhatsappMessage(row)"
                        class="report-btn report-btn-ghost"
                      >
                        Previsualizar
                      </button>
                      <button
                        @click="sendWhatsappMessage(row)"
                        :disabled="!normalizeWhatsappPhone(row.student.representative_phone)"
                        class="report-btn report-btn-whatsapp"
                      >
                        Enviar WhatsApp
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
            <p class="report-hint mt-3">
              Nota: el número del representante debe incluir código de país (ej. 593XXXXXXXXX).
            </p>
          </div>
        </section>

        <!-- CONSISTENCIA DE NOTAS -->
        <section class="report-section no-print">
          <div class="report-section-head">
            <div>
              <p class="report-pill">Verificación</p>
              <h3>Consistencia de Notas</h3>
              <p class="report-section-note">Estudiantes con asignaturas sin promedio en el período seleccionado.</p>
            </div>
          </div>
          <div v-if="isQualitativeCourse" class="report-empty">
            Este reporte no aplica para cursos cualitativos.
          </div>
          <div v-else-if="studentsWithMissingGrades.length === 0" class="report-empty">
            No hay inconsistencias de notas detectadas.
          </div>
          <div v-else class="report-table-wrap">
            <table class="report-table report-table-compact">
              <thead>
                <tr>
                  <th>Estudiante</th>
                  <th class="text-right">Asignaturas sin promedio</th>
                  <th>Detalle</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in studentsWithMissingGrades" :key="row.student.id">
                  <td>{{ row.student.full_name }}</td>
                  <td class="text-right strong">{{ row.missingCount }}</td>
                  <td>{{ row.subjectsMissing.join(', ') }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- ACTA FINAL -->
        <section class="report-section print-page" v-if="!isQualitativeCourse">
          <div class="report-section-head">
            <div>
              <p class="report-pill">Acta Final</p>
              <h3>Acta Final</h3>
            </div>
            <div class="report-inline-actions no-print">
              <button @click="toggleSupplementaryEdit" class="report-btn report-btn-ghost">
                {{ supplementaryEditing ? 'Cancelar' : 'Editar Supletorio' }}
              </button>
              <button @click="saveSupplementary" :disabled="supplementarySaving" class="report-btn report-btn-primary">
                {{ supplementarySaving ? 'Guardando...' : 'Guardar Supletorio' }}
              </button>
              <span v-if="supplementaryMessage" class="report-hint">{{ supplementaryMessage }}</span>
            </div>
          </div>
          <div class="report-table-wrap">
            <table class="report-table report-table-compact">
              <thead>
                <tr>
                  <th>Estudiante</th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="text-center">
                    {{ cs.subjects?.name }}
                  </th>
                </tr>
                <tr>
                  <th class="subhead"></th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="subhead text-center">
                    {{ orderedPeriodLabels.join(' | ') }} | P | S | PF | FA | OBS
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in actaFinalRows" :key="row.student.id">
                  <td>{{ row.student.full_name }}</td>
                  <td v-for="sub in row.subjects" :key="sub.subject" class="text-center">
                    <span v-for="(val, idx) in sub.periods" :key="idx">
                      {{ val?.toFixed(2) || '-' }}<span v-if="idx < sub.periods.length - 1"> | </span>
                    </span>
                    | <span>{{ sub.p?.toFixed(2) || '-' }}</span> |
                    <template v-if="supplementaryEditing">
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        max="10"
                        :value="supplementaryScores?.[row.student.id]?.[sub.courseSubjectId] ?? ''"
                        @input="(e) => updateSupplementaryScore(row.student.id, sub.courseSubjectId, e.target.value)"
                        :disabled="!sub.allowSuplet"
                        class="report-input-small"
                      />
                    </template>
                    <template v-else>
                      <span>{{ sub.s ?? '-' }}</span>
                    </template>
                    | <span>{{ sub.pf?.toFixed(2) || '-' }}</span>
                    | <span>{{ sub.finalAnnual?.toFixed(2) || '-' }}</span>
                    | <span class="subtle">{{ sub.finalObs || '-' }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- RESUMEN FINAL -->
        <section class="report-section print-page" v-if="!isQualitativeCourse">
          <div class="report-section-head">
            <div>
              <p class="report-pill">Resumen Final</p>
              <h3>Resumen Final</h3>
            </div>
          </div>
          <div class="report-table-wrap">
            <table class="report-table report-table-compact">
              <thead>
                <tr>
                  <th>Estudiante</th>
                  <th v-for="cs in courseSubjects" :key="cs.id" class="text-right">
                    {{ cs.subjects?.name }}
                  </th>
                  <th class="text-right">Promedio Anual (PF)</th>
                  <th class="text-right">Final Anual (Cap 7)</th>
                  <th>Observacion</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in resumenFinalRows" :key="row.student.id">
                  <td>{{ row.student.full_name }}</td>
                  <td v-for="sub in row.subjectFinals" :key="sub.subject" class="text-right">
                    {{ sub.pf?.toFixed(2) || '-' }}
                  </td>
                  <td class="text-right strong">
                    {{ row.promedioAnual?.toFixed(2) || '-' }}
                  </td>
                  <td class="text-right">
                    {{ row.promedioFinalAnnual?.toFixed(2) || '-' }}
                  </td>
                  <td>
                    {{
                      (row.promedioAnual !== null && row.promedioAnual >= 7) ? 'PROMOVIDO' : (row.promedioAnual !== null ? 'NO PROMOVIDO' : '-')
                    }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- Firmas -->
        <section class="report-section print-page">
          <div class="report-signatures">
            <div class="signature-date">
              <span class="report-meta-label">Fecha de Emisión:</span>
              <span class="report-meta-value">{{ new Date().toLocaleDateString('es-EC') }}</span>
            </div>
            <div class="signature-grid">
              <div class="report-signature-line">
                <span class="signature-name">{{ institutionTutorName || 'Tutor' }}</span>
                <span class="signature-role">DOCENTE TUTOR</span>
              </div>
              <div class="report-signature-line">
                <span class="signature-name">{{ institutionRectorName || 'Rector/a' }}</span>
                <span class="signature-role">RECTOR/A</span>
              </div>
              <div class="report-signature-line">
                <span class="signature-name">Secretario/a</span>
                <span class="signature-role">SECRETARIO/A</span>
              </div>
            </div>
            <div class="report-legal-note">
              <strong>Nota Legal:</strong> El presente documento tiene un fin estrictamente informativo para comunicar los resultados académicos obtenidos por el estudiante. Las calificaciones aquí reflejadas podrían presentar variaciones mínimas respecto al sistema oficial. La validez legal y definitiva de las notas está sujeta a la información registrada y emitida por la plataforma educativa del Ministerio de Educación (MINEDUC).
            </div>
          </div>
        </section>
      </div>

      <div ref="reportsRef" v-else-if="selectedCourse && reportMode === 'INDIVIDUAL'" class="report-stack">
        <!-- CABECERA PARA PDF (VISIBLE AL EXPORTAR O IMPRIMIR) -->
        <div class="report-header screen-hidden">
          <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo" class="report-logo" />
          <div v-else style="width: 70px; height: 70px; background: #e2e8f0; display:flex; align-items:center; justify-content:center; flex-shrink:0;">Logo</div>
          <div class="report-header-content">
            <h1 style="margin: 0; color: #0f172a; font-size: 20px; font-weight: 800; text-transform: uppercase;">{{ institutionName || 'Unidad Educativa' }}</h1>
            <h2 style="margin: 0; color: #0f766e; font-size: 14px; font-weight: 700; margin-top: 2px;">Reporte Individual de Calificaciones</h2>
            <p style="margin: 0; color: #475569; font-size: 11px; margin-top: 4px;">
              Periodo: {{ getQuarterName(selectedQuarter) }} | Curso: {{ courses.find(c => c.id === selectedCourse)?.name || '-' }} | Estudiante: {{ students.find(s => s.id === selectedStudentId)?.full_name || '-' }}
            </p>
            <p style="margin: 0; color: #475569; font-size: 10px; margin-top: 2px;">Generado el: {{ new Date().toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' }) }}</p>
          </div>
        </div>

        <section class="report-section print-page">
          <div v-if="students.length === 0" class="report-empty">No hay estudiantes en el curso.</div>
          <div v-else>
            <div class="report-section-head">
              <div>
                <p class="report-pill">Reporte Individual</p>
                <h3>{{ students.find(s => s.id === selectedStudentId)?.full_name || 'Seleccione un estudiante' }}</h3>
                <p class="report-section-note">
                  Curso: {{ courses.find(c => c.id === selectedCourse)?.name || '-' }} ·
                  {{ getQuarterName(selectedQuarter) }}
                </p>
              </div>
            </div>

            <div v-if="!selectedStudentId" class="report-empty">
              Selecciona un estudiante para ver su reporte.
            </div>
            <div v-else-if="individualLoading" class="report-loading">Cargando reporte individual...</div>
            <div v-else-if="individualError" class="report-alert report-alert-error">{{ individualError }}</div>
            <div v-else class="report-table-wrap">
              <div v-if="isQualitativeCourse" class="report-legend">
                Escala cualitativa: A+/A- (alcanzado), B+/B-/C+/C- (en proceso), D+/D-/E+/E- (iniciado).
              </div>
              <table class="report-table report-table-compact">
                <thead>
                  <tr>
                    <th>Asignatura</th>
                    <th class="text-right" v-if="!isQualitativeCourse">Promedio</th>
                    <th class="text-center" v-else>Calificacion</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="row in individualSubjects" :key="row.subject">
                    <td>{{ row.subject }}</td>
                    <td v-if="!isQualitativeCourse" class="text-right">{{ row.total?.toFixed(2) || '-' }}</td>
                    <td v-else class="text-center">{{ row.qualitative || '-' }}</td>
                  </tr>
                  <tr v-if="!isQualitativeCourse && individualProjectAverage !== null && individualProjectAverage !== undefined">
                    <td>Proyecto Interdisciplinario</td>
                    <td class="text-right">{{ individualProjectAverage?.toFixed(2) || '-' }}</td>
                  </tr>
                </tbody>
                <tfoot v-if="!isQualitativeCourse">
                  <tr class="bg-gray-50">
                    <td class="strong">Promedio General del Trimestre</td>
                    <td class="text-right strong">{{ individualAverage !== null ? individualAverage.toFixed(2) : '-' }}</td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>
        </section>

        <!-- Firmas -->
        <section class="report-section print-page">
          <div class="report-signatures">
            <div class="signature-date">
              <span class="report-meta-label">Fecha de Emisión:</span>
              <span class="report-meta-value">{{ new Date().toLocaleDateString('es-EC') }}</span>
            </div>
            <div class="signature-grid">
              <div class="report-signature-line">
                <span class="signature-name">{{ institutionTutorName || 'Tutor' }}</span>
                <span class="signature-role">DOCENTE TUTOR</span>
              </div>
              <div class="report-signature-line">
                <span class="signature-name">{{ institutionRectorName || 'Rector/a' }}</span>
                <span class="signature-role">RECTOR/A</span>
              </div>
              <div class="report-signature-line">
                <span class="signature-name">Secretario/a</span>
                <span class="signature-role">SECRETARIO/A</span>
              </div>
            </div>
            <div class="report-legal-note">
              <strong>Nota Legal:</strong> El presente documento tiene un fin estrictamente informativo para comunicar los resultados académicos obtenidos por el estudiante. Las calificaciones aquí reflejadas podrían presentar variaciones mínimas respecto al sistema oficial. La validez legal y definitiva de las notas está sujeta a la información registrada y emitida por la plataforma educativa del Ministerio de Educación (MINEDUC).
            </div>
          </div>
        </section>
      </div>

      <div v-else-if="selectedCourse" class="report-empty">No hay estudiantes en el curso.</div>
      <div v-else class="report-empty">Selecciona un curso para ver reportes.</div>
    </main>

    <!-- WhatsApp Preview Modal -->
    <div v-if="showWhatsappPreview" class="modal-container" role="dialog" aria-modal="true">
        <div class="modal-backdrop" @click="showWhatsappPreview = false"></div>
        <div class="modal-panel sm:max-w-2xl w-full">
          <div class="modal-body">
            <h3 class="text-lg leading-6 font-semibold text-slate-900">Mensaje para {{ whatsappPreviewStudent }}</h3>
            <textarea
              class="app-input mt-4 w-full h-64 font-mono text-xs"
              readonly
              :value="whatsappPreviewText"
            ></textarea>
          </div>
          <div class="modal-footer">
            <button @click="copyWhatsappMessage" class="app-btn app-btn-primary w-full sm:w-auto">Copiar</button>
            <button @click="showWhatsappPreview = false" class="app-btn app-btn-ghost w-full sm:w-auto mt-3 sm:mt-0">Cerrar</button>
          </div>
        </div>
    </div>
  </div>
</template>

<style scoped>

:global(.report-shell) {
  --paper: #f6f1ea;
  --paper-strong: #fdfaf6;
  --ink: #1f2937;
  --muted: #6b7280;
  --line: #e6e0d8;
  --accent: #0f766e;
  --accent-ink: #0b4d47;
  --shadow: 0 18px 45px rgba(15, 23, 42, 0.08);
  background: radial-gradient(circle at top, #f9f6f1 0%, #efe7dc 60%, #e8e0d6 100%);
  color: var(--ink);
}

.report-page {
  max-width: 1240px;
  margin: 0 auto;
  padding: 28px 20px 64px;
  font-family: 'Source Sans 3', sans-serif;
}

.report-hero {
  background: var(--paper-strong);
  border: 1px solid var(--line);
  border-radius: 20px;
  padding: 22px 24px;
  box-shadow: var(--shadow);
}

.report-hero-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 20px;
  flex-wrap: wrap;
}

.report-brand {
  display: flex;
  align-items: center;
  gap: 16px;
}

.report-logo {
  width: 64px;
  height: 64px;
  border-radius: 16px;
  border: 1px solid var(--line);
  background: #fff;
  display: grid;
  place-items: center;
  overflow: hidden;
  color: var(--muted);
  font-size: 12px;
}

.report-logo img {
  width: 100%;
  height: 100%;
  object-fit: contain;
  padding: 8px;
}

.report-kicker {
  text-transform: uppercase;
  letter-spacing: 0.12em;
  font-size: 11px;
  color: var(--accent-ink);
  margin: 0;
}

.report-title {
  font-family: 'Playfair Display', serif;
  font-size: 26px;
  margin: 4px 0;
}

.report-subtitle {
  color: var(--muted);
  margin: 0;
}

.report-meta {
  display: grid;
  gap: 10px;
  min-width: 180px;
  text-align: right;
}

.report-meta-label {
  display: block;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  font-size: 10px;
  color: var(--muted);
}

.report-meta-value {
  font-weight: 600;
}

.report-card {
  margin-top: 18px;
  background: var(--paper-strong);
  border: 1px solid var(--line);
  border-radius: 18px;
  padding: 18px 20px;
  box-shadow: var(--shadow);
}

.report-controls {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 14px;
  align-items: end;
}

.report-label {
  display: block;
  font-size: 12px;
  color: var(--muted);
  margin-bottom: 6px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.report-select {
  width: 100%;
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: 10px 12px;
  background: #fff;
  color: var(--ink);
}

.report-actions {
  display: flex;
  gap: 10px;
  justify-content: flex-end;
  flex-wrap: wrap;
}

.report-btn {
  border-radius: 12px;
  padding: 10px 16px;
  font-weight: 600;
  border: 1px solid transparent;
  cursor: pointer;
  transition: all 0.2s ease;
  font-family: 'Source Sans 3', sans-serif;
}

.report-btn-primary {
  background: var(--accent);
  color: #fff;
  border-color: var(--accent);
}

.report-btn-primary:hover {
  filter: brightness(0.95);
}

.report-btn-ghost {
  background: #fff;
  color: var(--ink);
  border-color: var(--line);
}

.report-btn-ghost:hover {
  border-color: var(--accent);
  color: var(--accent-ink);
}

.report-btn-whatsapp {
  background: #16a34a;
  color: #fff;
  border-color: #16a34a;
}

.report-btn-whatsapp:hover {
  filter: brightness(0.95);
}

.report-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.report-alert {
  margin: 16px 0;
  padding: 12px 14px;
  border-radius: 12px;
  font-weight: 600;
}

.report-alert-error {
  background: #fee2e2;
  color: #991b1b;
}

.report-alert-warn {
  background: #fef3c7;
  color: #92400e;
}

.report-loading {
  color: var(--muted);
  margin-top: 12px;
}

.report-stack {
  display: flex;
  flex-direction: column;
  gap: 26px;
  margin-top: 22px;
}

.report-section {
  background: var(--paper-strong);
  border: 1px solid var(--line);
  border-radius: 18px;
  padding: 18px 20px;
  box-shadow: var(--shadow);
}

.report-section-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  margin-bottom: 14px;
  flex-wrap: wrap;
}

.report-section h3 {
  font-size: 18px;
  margin: 6px 0 0;
}

.report-section-note {
  color: var(--muted);
  font-size: 13px;
}

.report-pill {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 999px;
  background: #e0f2f1;
  color: var(--accent-ink);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  font-weight: 700;
}

.report-empty {
  color: var(--muted);
  padding: 12px 0;
}

.report-table-wrap {
  overflow-x: auto;
}

.report-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.report-table thead {
  background: #f0ebe3;
}

.report-table th,
.report-table td {
  padding: 10px 12px;
  border-bottom: 1px solid var(--line);
  text-align: left;
  vertical-align: middle;
}

.report-table tbody tr:nth-child(even) {
  background: #fbf8f3;
}

.report-table-compact th,
.report-table-compact td {
  padding: 8px 10px;
  font-size: 12px;
}

.report-table .subhead {
  font-size: 11px;
  color: var(--muted);
  font-weight: 600;
}

.report-table .strong {
  font-weight: 700;
}

.report-table .subtle {
  color: var(--muted);
  font-size: 11px;
}

.report-inline-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.report-legend {
  font-size: 11px;
  color: var(--muted);
  margin-bottom: 8px;
}

.report-hint {
  color: var(--muted);
  font-size: 12px;
}

.report-input-small {
  width: 52px;
  padding: 2px 6px;
  border-radius: 8px;
  border: 1px solid var(--line);
  background: #fff;
  color: var(--ink);
  font-size: 11px;
  text-align: center;
  margin: 0 4px;
}

.report-signatures {
  margin-top: 50px;
  page-break-inside: avoid;
  break-inside: avoid;
}

.signature-date {
  margin-bottom: 40px;
  text-align: left;
}

.signature-grid {
  display: flex;
  justify-content: space-between;
  gap: 24px;
}

.report-signature-line {
  flex: 1;
  border-top: 1px solid #1e293b;
  padding-top: 8px;
  text-align: center;
  display: flex;
  flex-direction: column;
}

.signature-name {
  font-size: 13px;
  font-weight: 600;
  color: #0f172a;
  text-transform: uppercase;
}

.signature-role {
  font-size: 11px;
  color: #64748b;
  margin-top: 2px;
}

.report-legal-note {
  margin-top: 40px;
  font-size: 10.5px;
  color: #64748b;
  text-align: justify;
  line-height: 1.4;
  border-top: 1px dashed #cbd5e1;
  padding-top: 12px;
}

.dark .report-hero,
.dark .report-card,
.dark .report-section {
  background: #0f172a;
  border-color: #1e293b;
  color: #f8fafc;
}

.dark .report-logo {
  background: #1e293b;
  border-color: #334155;
}

.dark .report-select {
  background: #1e293b;
  border-color: #334155;
  color: #f8fafc;
}

.dark .report-btn-ghost {
  background: #1e293b;
  border-color: #334155;
  color: #f8fafc;
}

.dark .report-table thead {
  background: #1e293b;
  color: #f8fafc;
}

.dark .report-table th,
.dark .report-table td {
  border-bottom-color: #1e293b;
  color: #f8fafc;
}

.dark .report-table tbody tr:nth-child(even) {
  background: rgba(255, 255, 255, 0.03);
}

.dark .report-table tbody tr:hover {
  background: rgba(255, 255, 255, 0.07);
}

.dark .report-pill {
  background: #042f2e;
  color: #5eead4;
}

.dark .report-input-small {
  background: #1e293b;
  border-color: #334155;
  color: #f8fafc;
}

.dark .signature-name {
  color: #f8fafc;
}

@media (max-width: 900px) {
  .report-controls {
    grid-template-columns: 1fr;
  }

  .report-meta {
    text-align: left;
    width: 100%;
  }
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
