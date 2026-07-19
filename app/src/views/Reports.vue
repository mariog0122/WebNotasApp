<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useCoursesQuery, useQuartersQuery, useInstitutionConfigQuery } from '../composables/useQueries'
import { computeProjectAverage, computeSubjectTotal, getQuarterOrder, truncate2, computeFinalAnnual, computeFinalObservation, getPeriodLabel, computeTrimesterObservation } from '../lib/reporting'
import { loadHtml2Pdf } from '../lib/pdf'

const route = useRoute()

const { data: coursesData } = useCoursesQuery()
const courses = computed(() => coursesData.value || [])

const { data: quartersData } = useQuartersQuery()
const quarters = computed(() => (quartersData.value || []).slice().sort((a, b) => getQuarterOrder(a.name) - getQuarterOrder(b.name)))
const students = ref([])
const courseSubjects = ref([])

const reportMode = ref('GENERAL')
const isExportingPdf = ref(false)
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

const configData = ref({})

const fetchInstitutionConfig = async () => {
  const { data, error } = await supabase
    .from('system_config')
    .select('key, value')
    .in('key', ['institution_name', 'institution_logo_url', 'institution_tutor_name', 'institution_rector_name', 'academic_periods', 'regimen'])
  
  if (error) {
    console.error('Error fetching institution config:', error.message)
  } else {
    const map = Object.fromEntries((data || []).map(item => [item.key, item.value]))
    configData.value = map || {}
  }
}
const institutionName = computed(() => configData.value?.institution_name || '')
const institutionLogoUrl = computed(() => configData.value?.institution_logo_url || '')
const institutionTutorName = computed(() => configData.value?.institution_tutor_name || '')
const institutionRectorName = computed(() => configData.value?.institution_rector_name || '')
const academicPeriods = computed(() => configData.value?.academic_periods || 'TRIMESTRE')
const regime = computed(() => configData.value?.regimen || 'SIERRA_AMAZONIA')

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

// Data is now fetched by Vue Query
watch(quarters, (newVal) => {
  if (newVal && newVal.length > 0 && !selectedQuarter.value) {
    const active = newVal.find(q => q.is_active) || newVal[0]
    selectedQuarter.value = active?.id || null
  }
}, { immediate: true })

const fetchCourseData = async () => {
  if (!selectedCourse.value) return
  loading.value = true
  error.value = ''
  projectAvailable.value = true
  qualitativeGradesByStudent.value = {}
  try {
    const courseId = selectedCourse.value
    const { data: stus, error: stusError } = await supabase
      .from('students')
      .select('id, full_name, representative_name, representative_phone')
      .eq('course_id', courseId)
      .order('full_name')
    if (stusError) throw stusError
    students.value = stus || []

    const { data: cs, error: csError } = await supabase
      .from('course_subjects')
      .select('id, subject_id, subjects (name)')
      .eq('course_id', courseId)
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

    const { data: defs, error: defsError } = await supabase
      .from('grade_definitions')
      .select('id, course_subject_id, quarter_id, name, category, sort_order')
      .in('course_subject_id', courseSubjectIds)
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
  const courseName = courses.value.find(c => c.id === selectedCourse.value)?.name || 'curso'
  const quarterName = quarters.value.find(q => q.id === selectedQuarter.value)?.name || 'trimestre'
  const studentName = students.value.find(s => s.id === selectedStudentId.value)?.full_name || ''
  const base = reportMode.value === 'INDIVIDUAL' && studentName
    ? `Reporte_${studentName}_${quarterName}`
    : `Reportes_${courseName}_${quarterName}`
  const filename = `${base}.pdf`.replace(/\s+/g, '_')
  try {
    isExportingPdf.value = true
    // Wait for DOM to update with the header before capturing
    await new Promise(resolve => setTimeout(resolve, 100))
    const html2pdf = await loadHtml2Pdf()
    await html2pdf()
    .set({
      margin: 8,
      filename,
      image: { type: 'jpeg', quality: 0.98 },
      html2canvas: { scale: 2, useCORS: true },
      jsPDF: { unit: 'mm', format: 'a4', orientation: reportMode.value === 'INDIVIDUAL' ? 'portrait' : 'landscape' }
    })
    .from(reportsRef.value)
    .save()
  } catch (e) {
    alert('No se pudo generar el PDF. Usa Imprimir y guarda como PDF.')
  } finally {
    isExportingPdf.value = false
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
    if (upserts.length > 0) {
      const { error } = await supabase
        .from('supplementary_exams')
        .upsert(upserts, { onConflict: 'student_id, course_subject_id' })
      if (error) throw error
    }

    if (toDelete.length > 0) {
      const chunkSize = 50
      for (let i = 0; i < toDelete.length; i += chunkSize) {
        const chunk = toDelete.slice(i, i + chunkSize)
        const orFilter = chunk
          .map(item => `and(student_id.eq.${item.student_id},course_subject_id.eq.${item.course_subject_id})`)
          .join(',')
        const { error } = await supabase.from('supplementary_exams').delete().or(orFilter)
        if (error) throw error
      }
    }

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
            generateIndividualReportPdf()
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
      <header class="report-hero">
        <div class="report-hero-row">
          <div class="report-brand">
            <div class="report-logo">
              <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo institucion" />
              <span v-else>Logo</span>
            </div>
            <div>
              <p class="report-kicker">Sistema de Notas</p>
              <h2 class="report-title">{{ institutionName || 'Institucion' }}</h2>
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
              <span class="report-meta-value">Informe academico</span>
            </div>
            <div>
              <span class="report-meta-label">Curso</span>
              <span class="report-meta-value">{{ courses.find(c => c.id === selectedCourse)?.name || '-' }}</span>
            </div>
            <div>
              <span class="report-meta-label">Regimen</span>
              <span class="report-meta-value">{{ regime === 'COSTA_GALAPAGOS' ? 'Costa-Galapagos' : 'Sierra-Amazonia' }}</span>
            </div>
            <div>
              <span class="report-meta-label">Periodos</span>
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
            <label class="report-label">Periodo</label>
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
      <div v-if="!projectAvailable" class="report-alert report-alert-warn">
        Modulo de Proyecto no instalado. Ejecuta el SQL `project_global_schema.sql` en la base (InsForge).
      </div>
      <div v-if="loading" class="report-loading">Cargando reportes...</div>

      <div ref="reportsRef" v-else-if="selectedCourse && students.length > 0 && reportMode === 'GENERAL'" class="report-stack">
        <!-- CABECERA PARA PDF (OCULTA EN PANTALLA, VISIBLE AL EXPORTAR) -->
        <div v-if="isExportingPdf" class="pdf-export-header">
          <div class="pdf-header-content">
            <div class="pdf-logo-placeholder">
              <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo" class="pdf-logo" />
              <div v-else class="pdf-logo-fallback">Logo</div>
            </div>
            <div class="pdf-header-text">
              <h1 class="pdf-institution">{{ institutionName || 'Unidad Educativa' }}</h1>
              <h2 class="pdf-title">Reporte Consolidado de Calificaciones</h2>
              <p class="pdf-subtitle">
                Periodo: {{ getQuarterName(selectedQuarter) }} | Curso: {{ courses.find(c => c.id === selectedCourse)?.name || '-' }}
              </p>
              <p class="pdf-date">Generado el: {{ new Date().toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' }) }}</p>
            </div>
          </div>
          <hr class="pdf-divider" />
        </div>

        <!-- PROYECTO INTERDISCIPLINARIO -->
        <section class="report-section print-page">
          <div class="report-section-head">
            <div>
              <p class="report-pill">Proyecto Interdisciplinario</p>
              <h3>Proyecto Interdisciplinario - {{ getQuarterName(selectedQuarter) }}</h3>
              <p class="report-section-note">Curso: {{ courses.find(c => c.id === selectedCourse)?.name || '-' }}</p>
            </div>
            <p class="report-section-note">Promedio por asignaturas seleccionadas</p>
          </div>
          <div v-if="(projectSettingsByQuarter[selectedQuarter] || []).length === 0" class="report-empty">
            No hay asignaturas seleccionadas para proyecto en este trimestre.
          </div>
          <div v-else class="report-table-wrap">
            <table class="report-table">
              <thead>
                <tr>
                  <th>Estudiante</th>
                  <th class="text-right">Promedio Proyecto</th>
                  <th class="text-right">Total Trimestre (15%)</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="stu in students" :key="stu.id">
                  <td>{{ stu.full_name }}</td>
                  <td class="text-right">{{ getProjectAverageForStudent(stu.id)?.toFixed(2) || '-' }}</td>
                  <td class="text-right">{{ getProjectTotalForStudent(stu.id)?.toFixed(2) || '-' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <!-- SABANA POR TRIMESTRE -->
        <section class="report-section print-page">
          <div class="report-section-head">
            <div>
              <p class="report-pill">Sabana</p>
              <h3>Sabana de Calificaciones - {{ getQuarterName(selectedQuarter) }}</h3>
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
              <p class="report-section-note">Envia un mensaje al representante con el detalle de notas.</p>
            </div>
          </div>
          <div v-if="isQualitativeCourse" class="report-empty">
            Este reporte no aplica para cursos cualitativos.
          </div>
          <div v-else-if="underperformingStudents.length === 0" class="report-empty">
            No hay estudiantes con promedio menor a 7 en este periodo.
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
              Nota: el numero del representante debe incluir codigo de pais (ej. 593XXXXXXXXX).
            </p>
          </div>
        </section>

        <!-- CONSISTENCIA DE NOTAS -->
        <section class="report-section no-print">
          <div class="report-section-head">
            <div>
              <p class="report-pill">Verificacion</p>
              <h3>Consistencia de Notas</h3>
              <p class="report-section-note">Estudiantes con asignaturas sin promedio en el periodo seleccionado.</p>
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
          </div>
        </section>
      </div>

      <div ref="reportsRef" v-else-if="selectedCourse && reportMode === 'INDIVIDUAL'" class="report-stack">
        <!-- CABECERA PARA PDF (OCULTA EN PANTALLA, VISIBLE AL EXPORTAR) -->
        <div v-if="isExportingPdf" class="pdf-export-header">
          <div class="pdf-header-content">
            <div class="pdf-logo-placeholder">
              <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo" class="pdf-logo" />
              <div v-else class="pdf-logo-fallback">Logo</div>
            </div>
            <div class="pdf-header-text">
              <h1 class="pdf-institution">{{ institutionName || 'Unidad Educativa' }}</h1>
              <h2 class="pdf-title">Reporte Individual de Calificaciones</h2>
              <p class="pdf-subtitle">
                Periodo: {{ getQuarterName(selectedQuarter) }} | Curso: {{ courses.find(c => c.id === selectedCourse)?.name || '-' }} | Estudiante: {{ students.find(s => s.id === selectedStudentId)?.full_name || '-' }}
              </p>
              <p class="pdf-date">Generado el: {{ new Date().toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' }) }}</p>
            </div>
          </div>
          <hr class="pdf-divider" />
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
@import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600;700&family=Source+Sans+3:wght@400;600;700&display=swap');

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
  display: grid;
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

/* ============================================
   PDF EXPORT HEADER
   ============================================ */
.pdf-export-header {
  margin-bottom: 24px;
  color: #0f172a;
  background: white;
  padding: 10px 0;
}

.pdf-header-content {
  display: flex;
  align-items: center;
  gap: 20px;
}

.pdf-logo-placeholder {
  width: 80px;
  height: 80px;
  border-radius: 12px;
  overflow: hidden;
  background: #f1f5f9;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  border: 1px solid #e2e8f0;
}

.pdf-logo {
  width: 100%;
  height: 100%;
  object-fit: contain;
  padding: 4px;
}

.pdf-logo-fallback {
  color: #94a3b8;
  font-size: 14px;
  font-weight: 600;
  text-transform: uppercase;
}

.pdf-header-text {
  flex: 1;
}

.pdf-institution {
  font-size: 24px;
  font-weight: 800;
  margin: 0 0 4px;
  color: #0f172a;
  text-transform: uppercase;
  letter-spacing: -0.5px;
}

.pdf-title {
  font-size: 16px;
  font-weight: 600;
  color: #0f766e;
  margin: 0 0 4px;
}

.pdf-subtitle, .pdf-date {
  font-size: 13px;
  color: #475569;
  margin: 0 0 2px;
}

.pdf-divider {
  margin-top: 16px;
  border: none;
  border-top: 3px solid #0f766e;
  border-bottom: 1px solid #e2e8f0;
  height: 5px;
  background: transparent;
}

@media print {
  nav,
  button,
  select,
  .no-print {
    display: none !important;
  }

  body,
  html {
    background: white !important;
  }

  table {
    font-size: 10px;
    border-collapse: collapse !important;
  }

  th,
  td {
    border: 1px solid #d1d5db !important;
    padding: 4px !important;
  }

  .print-page {
    page-break-after: auto !important;
    break-after: auto !important;
  }

  .print-page:last-of-type {
    page-break-after: auto;
    break-after: auto;
  }

  .report-shell,
  .report-section,
  .report-hero,
  .report-card {
    box-shadow: none !important;
    background: white !important;
    border-color: #e5e7eb !important;
  }

  .report-title,
  .report-section h3 {
    color: #111827 !important;
  }

  .report-pill {
    background: #e5f4f2 !important;
    color: #0f766e !important;
  }

  .report-section {
    padding: 10px 12px !important;
  }

  .report-hero,
  .report-card {
    padding: 10px 12px !important;
  }

  .report-stack {
    gap: 10px !important;
  }

  .report-table-compact th,
  .report-table-compact td {
    padding: 4px 6px !important;
    font-size: 10px !important;
  }
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
