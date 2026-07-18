<script setup>
import { ref, onMounted, watch, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useStudentsQuery, useCoursesQuery, useQuartersQuery, useInstitutionConfigQuery } from '../composables/useQueries'
import { useNetwork } from '../composables/useNetwork'
import { computeProjectAverage, computeSubjectTotal, getQuarterOrder, computeTrimesterObservation } from '../lib/reporting'
import { loadHtml2Pdf } from '../lib/pdf'
import { translateError } from '../lib/errorDictionary'
import { 
    validateStudentForm, 
    isStudentComplete, 
    getFileExt, 
    uploadPhoto, 
    createPhotoPreview 
} from '../lib/studentUtils'

const searchTerm = ref('')
const searchDebounce = ref(null)
const page = ref(1)
const pageSize = 50
const { isOnline } = useNetwork()

const { data: studentsData, isLoading: loading, refetch: fetchStudents } = useStudentsQuery(searchTerm, page, pageSize)
const students = computed(() => studentsData.value?.data || [])
const totalCount = computed(() => studentsData.value?.count || 0)

const { data: coursesData, refetch: fetchCourses } = useCoursesQuery()
const courses = computed(() => coursesData.value || [])

const { data: quartersData, refetch: fetchQuarters } = useQuartersQuery()
const quarters = computed(() => (quartersData.value || []).slice().sort((a, b) => getQuarterOrder(a.name) - getQuarterOrder(b.name)))

const { data: configData, refetch: fetchInstitutionConfig } = useInstitutionConfigQuery()
const selectedStudentIds = ref(new Set())
const showModal = ref(false)
const editingStudent = ref(null)
const saving = ref(false)
const saveError = ref('')
const validationErrors = ref([])
const showReportModal = ref(false)
const reportStudent = ref(null)
const reportQuarterId = ref(null)
const reportLoading = ref(false)
const reportError = ref('')
const reportSubjects = ref([])
const reportAverage = ref(null)
const projectAverage = ref(null)
const institutionName = computed(() => configData.value?.institution_name || '')
const institutionLogoUrl = computed(() => configData.value?.institution_logo_url || '')
const institutionTutorName = computed(() => configData.value?.institution_tutor_name || '')
const institutionRectorName = computed(() => configData.value?.institution_rector_name || '')
const academicPeriods = computed(() => configData.value?.academic_periods || 'TRIMESTRE')
const reportRef = ref(null)
const isQualitativeReport = computed(() => reportSubjects.value.some(r => r.qualitative !== undefined))

const reportGradeClass = (val) => {
  if (val === null || val === undefined || isNaN(val)) return 'text-slate-900'
  const n = Number(val)
  if (n >= 9) return 'text-emerald-700 font-bold'
  if (n >= 7) return 'text-teal-700 font-semibold'
  if (n >= 5) return 'text-amber-700 font-semibold'
  return 'text-rose-700 font-bold'
}

const reportGradeBg = (val) => {
  if (val === null || val === undefined || isNaN(val)) return ''
  const n = Number(val)
  if (n >= 9) return 'bg-emerald-50'
  if (n >= 7) return 'bg-teal-50'
  if (n >= 5) return 'bg-amber-50'
  return 'bg-rose-50'
}

const studentPhotoFile = ref(null)
const representativePhotoFile = ref(null)
const studentPhotoPreview = ref('')
const representativePhotoPreview = ref('')

const form = ref({
  full_name: '',
  course_id: null,
  student_cedula: '',
  student_birthdate: '',
  student_phone: '',
  student_address: '',
  representative_name: '',
  representative_cedula: '',
  representative_phone: '',
  representative_alt_phone: '',
  student_photo_url: '',
  representative_photo_url: ''
})

// fetchStudents is handled by useStudentsQuery now

const toggleStudentSelection = (id) => {
  const next = new Set(selectedStudentIds.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  selectedStudentIds.value = next
}

const isAllStudentsSelected = () => {
  return students.value.length > 0 && selectedStudentIds.value.size === students.value.length
}

const toggleAllStudents = () => {
  if (isAllStudentsSelected()) {
    selectedStudentIds.value = new Set()
  } else {
    selectedStudentIds.value = new Set(students.value.map(s => s.id))
  }
}

const confirmModal = ref({
  show: false,
  title: '',
  message: '',
  action: null,
  processing: false
})

const closeConfirmModal = () => {
  confirmModal.value.show = false
}

const executeConfirmAction = async () => {
  if (confirmModal.value.action) {
    confirmModal.value.processing = true
    await confirmModal.value.action()
    confirmModal.value.processing = false
    confirmModal.value.show = false
  }
}

const deleteSelectedStudents = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (selectedStudentIds.value.size === 0) {
    alert('No hay estudiantes seleccionados.')
    return
  }
  
  confirmModal.value = {
    show: true,
    title: 'Eliminar Seleccionados',
    message: '¿Eliminar estudiantes seleccionados? Esta accion no se puede deshacer y borrara sus calificaciones.',
    processing: false,
    action: async () => {
      const ids = Array.from(selectedStudentIds.value)
      try {
        const chunkSize = 50
        for (let i = 0; i < ids.length; i += chunkSize) {
          const chunk = ids.slice(i, i + chunkSize)
          const { error } = await supabase.from('students').delete().in('id', chunk)
          if (error) throw error
        }
        selectedStudentIds.value = new Set()
        await fetchStudents()
      } catch (error) {
        confirmModal.value = {
          show: true,
          title: 'Error',
          message: 'Error eliminando estudiantes: ' + translateError(error),
          processing: false,
          action: null
        }
      }
    }
  }
}

const deleteAllStudents = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  confirmModal.value = {
    show: true,
    title: 'Eliminar Todos',
    message: '¿Eliminar TODOS los estudiantes del sistema? Esta accion no se puede deshacer y borrara por completo las calificaciones.',
    processing: false,
    action: async () => {
      try {
        const { error } = await supabase
          .from('students')
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000')
        if (error) throw error
        selectedStudentIds.value = new Set()
        await fetchStudents()
      } catch (error) {
        confirmModal.value = {
          show: true,
          title: 'Error',
          message: 'Error eliminando estudiantes: ' + translateError(error),
          processing: false,
          action: null
        }
      }
    }
  }
}

// fetchCourses is handled by Vue Query
const openModal = (student = null) => {
  editingStudent.value = student
  if (student) {
    form.value = { 
      full_name: student.full_name,
      course_id: student.course_id,
      student_cedula: student.student_cedula || '',
      student_birthdate: student.student_birthdate || '',
      student_phone: student.student_phone || '',
      student_address: student.student_address || '',
      representative_name: student.representative_name || '',
      representative_cedula: student.representative_cedula || '',
      representative_phone: student.representative_phone || '',
      representative_alt_phone: student.representative_alt_phone || '',
      student_photo_url: student.student_photo_url || '',
      representative_photo_url: student.representative_photo_url || ''
    }
    studentPhotoPreview.value = form.value.student_photo_url || ''
    representativePhotoPreview.value = form.value.representative_photo_url || ''
  } else {
    form.value = {
      full_name: '',
      course_id: null,
      student_cedula: '',
      student_birthdate: '',
      student_phone: '',
      student_address: '',
      representative_name: '',
      representative_cedula: '',
      representative_phone: '',
      representative_alt_phone: '',
      student_photo_url: '',
      representative_photo_url: ''
    }
    studentPhotoPreview.value = ''
    representativePhotoPreview.value = ''
  }
  studentPhotoFile.value = null
  representativePhotoFile.value = null
  saveError.value = ''
  validationErrors.value = []
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editingStudent.value = null
  studentPhotoFile.value = null
  representativePhotoFile.value = null
  studentPhotoPreview.value = ''
  representativePhotoPreview.value = ''
  saveError.value = ''
  validationErrors.value = []
}

const uploadPhotoToStorage = async (file, path) => {
  return await uploadPhoto(supabase, file, path)
}

const validateForm = () => {
  const errors = validateStudentForm(form.value)
  validationErrors.value = errors
  return errors.length === 0
}

const onStudentPhotoChange = (event) => {
  const file = event.target.files?.[0] || null
  studentPhotoFile.value = file
  studentPhotoPreview.value = createPhotoPreview(file, form.value.student_photo_url || '')
}

const onRepresentativePhotoChange = (event) => {
  const file = event.target.files?.[0] || null
  representativePhotoFile.value = file
  representativePhotoPreview.value = createPhotoPreview(file, form.value.representative_photo_url || '')
}

const saveStudent = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  saving.value = true
  saveError.value = ''
  if (!validateForm()) {
    saving.value = false
    return
  }
  try {
    let studentId = editingStudent.value?.id || null
    const basePayload = {
      full_name: form.value.full_name,
      course_id: form.value.course_id,
      student_cedula: form.value.student_cedula,
      student_birthdate: form.value.student_birthdate || null,
      student_phone: form.value.student_phone,
      student_address: form.value.student_address,
      representative_name: form.value.representative_name,
      representative_cedula: form.value.representative_cedula,
      representative_phone: form.value.representative_phone,
      representative_alt_phone: form.value.representative_alt_phone,
      student_photo_url: form.value.student_photo_url,
      representative_photo_url: form.value.representative_photo_url
    }

    if (editingStudent.value) {
      const { error } = await supabase
        .from('students')
        .update(basePayload)
        .eq('id', editingStudent.value.id)
      if (error) throw error
    } else {
      const { data, error } = await supabase
        .from('students')
        .insert(basePayload)
        .select('id')
        .single()
      if (error) throw error
      studentId = data.id
    }

    const uploads = {}
    if (studentPhotoFile.value) {
      const ext = getFileExt(studentPhotoFile.value)
      const path = `students/${studentId}/student-${Date.now()}.${ext}`
      uploads.student_photo_url = await uploadPhotoToStorage(studentPhotoFile.value, path)
    }
    if (representativePhotoFile.value) {
      const ext = getFileExt(representativePhotoFile.value)
      const path = `students/${studentId}/representative-${Date.now()}.${ext}`
      uploads.representative_photo_url = await uploadPhotoToStorage(representativePhotoFile.value, path)
    }

    if (Object.keys(uploads).length > 0) {
      const { error } = await supabase
        .from('students')
        .update(uploads)
        .eq('id', studentId)
    
      if (error) throw error
    }

    await fetchStudents()
    closeModal()
  } catch (error) {
    saveError.value = 'Error guardando estudiante: ' + translateError(error)
  }
  saving.value = false
}

const deleteStudent = async (id) => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  confirmModal.value = {
    show: true,
    title: 'Eliminar Estudiante',
    message: '¿Estas seguro de eliminar este estudiante? Se borraran permanentemente todas sus calificaciones.',
    processing: false,
    action: async () => {
      try {
        const { error } = await supabase
          .from('students')
          .delete()
          .eq('id', id)
        if (error) throw error
        await fetchStudents()
      } catch (error) {
        confirmModal.value = {
          show: true,
          title: 'Error',
          message: 'Error eliminando estudiante: ' + translateError(error),
          processing: false,
          action: null
        }
      }
    }
  }
}

// fetchQuarters and fetchInstitutionConfig are handled by composables

const openReportModal = async (student) => {
  reportStudent.value = student
  showReportModal.value = true
  reportError.value = ''
  if (quarters.value.length === 0) {
    await fetchQuarters()
  }
  const active = quarters.value.find(q => q.is_active) || quarters.value[0]
  reportQuarterId.value = active?.id || null
  await loadStudentReport()
}

const closeReportModal = () => {
  showReportModal.value = false
  reportStudent.value = null
  reportQuarterId.value = null
  reportSubjects.value = []
  reportAverage.value = null
  projectAverage.value = null
  reportError.value = ''
}

const loadStudentReport = async () => {
  if (!reportStudent.value?.course_id || !reportQuarterId.value) return
  reportLoading.value = true
  reportError.value = ''
  try {
    const courseId = reportStudent.value.course_id
    const studentId = reportStudent.value.id
    const level = reportStudent.value?.courses?.level || ''
    const isQualitativeCourse = ['INICIAL', 'PREPARATORIA', 'ELEMENTAL'].includes(level)

    const { data: courseSubjects, error: courseSubjectsError } = await supabase
      .from('course_subjects')
      .select('id, subject_id, subjects (name)')
      .eq('course_id', courseId)
    if (courseSubjectsError) throw courseSubjectsError

    const courseSubjectIds = (courseSubjects || []).map(cs => cs.id)
    if (courseSubjectIds.length === 0) {
      reportSubjects.value = []
      reportAverage.value = null
      reportLoading.value = false
      return
    }

    if (isQualitativeCourse) {
      const { data: qGrades, error: qError } = await supabase
        .from('qualitative_grades')
        .select('course_subject_id, score_text')
        .eq('student_id', studentId)
        .eq('quarter_id', reportQuarterId.value)
        .in('course_subject_id', courseSubjectIds)
      if (qError) throw qError

      const qMap = {}
      ;(qGrades || []).forEach(g => {
        qMap[g.course_subject_id] = g.score_text
      })

      reportSubjects.value = (courseSubjects || []).map(cs => ({
        subject: cs.subjects?.name || 'Sin nombre',
        qualitative: qMap[cs.id] || '-'
      }))
      reportAverage.value = null
      projectAverage.value = null
      reportLoading.value = false
      return
    }

    const { data: definitions, error: defError } = await supabase
      .from('grade_definitions')
      .select('id, course_subject_id, quarter_id, name, category, sort_order')
      .in('course_subject_id', courseSubjectIds)
      .eq('quarter_id', reportQuarterId.value)
    if (defError) throw defError

    const defIds = (definitions || []).map(d => d.id)
    let gradesData = []
    if (defIds.length > 0) {
      const { data, error: gradesError } = await supabase
        .from('grades')
        .select('student_id, grade_definition_id, score')
        .eq('student_id', studentId)
        .in('grade_definition_id', defIds)
      if (gradesError) throw gradesError
      gradesData = data || []
    }

    const { data: projectSettings, error: projectSettingsError } = await supabase
      .from('project_settings')
      .select('subject_id')
      .eq('course_id', courseId)
      .eq('quarter_id', reportQuarterId.value)
    if (projectSettingsError) {
      if (projectSettingsError.message && projectSettingsError.message.includes('Could not find the table')) {
        reportError.value = 'Modulo de Proyecto no instalado. Ejecuta el SQL project_global_schema.sql en la base (InsForge).'
        reportLoading.value = false
        return
      }
      throw projectSettingsError
    }
    const selectedProjectSubjectIds = (projectSettings || []).map(p => p.subject_id)

    const { data: projectGrades, error: projectGradesError } = await supabase
      .from('project_subject_grades')
      .select('student_id, subject_id, score')
      .eq('student_id', studentId)
      .eq('course_id', courseId)
      .eq('quarter_id', reportQuarterId.value)
    if (projectGradesError) {
      if (projectGradesError.message && projectGradesError.message.includes('Could not find the table')) {
        reportError.value = 'Modulo de Proyecto no instalado. Ejecuta el SQL project_global_schema.sql en la base (InsForge).'
        reportLoading.value = false
        return
      }
      throw projectGradesError
    }

    const gradesByDef = {}
    ;(gradesData || []).forEach(g => {
      gradesByDef[g.grade_definition_id] = g.score
    })

    const defsByCourseSubject = {}
    ;(definitions || []).forEach(d => {
      if (!defsByCourseSubject[d.course_subject_id]) defsByCourseSubject[d.course_subject_id] = []
      defsByCourseSubject[d.course_subject_id].push(d)
    })

    const projectGradesByStudent = {}
    ;(projectGrades || []).forEach(g => {
      if (!projectGradesByStudent[g.student_id]) projectGradesByStudent[g.student_id] = {}
      projectGradesByStudent[g.student_id][g.subject_id] = g.score
    })

    projectAverage.value = computeProjectAverage(projectGradesByStudent, selectedProjectSubjectIds, studentId)

    const rows = (courseSubjects || []).map(cs => {
      const defs = (defsByCourseSubject[cs.id] || []).sort((a, b) => a.sort_order - b.sort_order)
      const subjectIsProject = selectedProjectSubjectIds.includes(cs.subject_id)
      const totals = computeSubjectTotal(defs, gradesByDef, projectAverage.value, subjectIsProject)
      return {
        subject: cs.subjects?.name || 'Sin nombre',
        total: totals.total,
        obs: computeTrimesterObservation(totals.total)
      }
    })

    reportSubjects.value = rows
    const valid = rows.filter(r => r.total !== null && r.total !== undefined && !isNaN(r.total))
    reportAverage.value = valid.length > 0
      ? (valid.reduce((sum, r) => sum + r.total, 0) / valid.length)
      : null
  } catch (e) {
    reportError.value = 'Error cargando libreta: ' + e.message
  }
  reportLoading.value = false
}

watch(reportQuarterId, async () => {
  if (showReportModal.value) {
    await loadStudentReport()
  }
})

watch(searchTerm, () => {
  if (searchDebounce.value) clearTimeout(searchDebounce.value)
  searchDebounce.value = setTimeout(() => {
    page.value = 1
  }, 300)
})

watch(page, () => {
  fetchStudents()
})

const totalPages = computed(() => {
  const pages = Math.ceil((totalCount.value || 0) / pageSize)
  return pages > 0 ? pages : 1
})

const goToPage = (next) => {
  if (next < 1 || next > totalPages.value) return
  page.value = next
}



// --- STUDENT CARD LOGIC ---
const showCardModal = ref(false)
const cardStudent = ref(null)
const cardRef = ref(null)

const openCardModal = (student) => {
  cardStudent.value = student
  showCardModal.value = true
}

const downloadCardPdf = async () => {
  if (!cardRef.value || !cardStudent.value) return
  const studentName = cardStudent.value.full_name?.replace(/\s+/g, '_') || 'estudiante'
  const filename = `Ficha_${studentName}.pdf`
  const element = cardRef.value
  
  try {
    // Wait for images to load
    const images = element.getElementsByTagName('img')
    if (images.length > 0) {
       await Promise.all(Array.from(images).map(img => {
          if (img.complete) return Promise.resolve()
          return new Promise((resolve) => {
             img.onload = resolve
             img.onerror = resolve
          })
       }))
    }

    const html2pdf = await loadHtml2Pdf()
    await html2pdf()
    .set({
      margin: 10,
      filename,
      image: { type: 'jpeg', quality: 0.98 },
      html2canvas: { 
        scale: 2, 
        useCORS: true,
        allowTaint: true,
        logging: true 
      },
      jsPDF: { unit: 'mm', format: 'a4', orientation: 'portrait' }
    })
    .from(element)
    .save()
  } catch (e) {
    alert('No se pudo generar el PDF. Intenta nuevamente.')
    console.error(e)
  }
}

const closeCardModal = () => {
  showCardModal.value = false
  setTimeout(() => {
    cardStudent.value = null
  }, 300)
}

const downloadReportPdf = async () => {
  if (!reportRef.value) return
  const studentName = reportStudent.value?.full_name?.replace(/\s+/g, '_') || 'estudiante'
  const quarterName = quarters.value.find(q => q.id === reportQuarterId.value)?.name || 'trimestre'
  const filename = `Libreta_${studentName}_${quarterName}.pdf`
  const element = reportRef.value
  try {
    const html2pdf = await loadHtml2Pdf()
    await html2pdf()
    .set({
      margin: 8,
      filename,
      image: { type: 'jpeg', quality: 0.98 },
      html2canvas: { scale: 2, useCORS: true },
      jsPDF: { unit: 'mm', format: 'a4', orientation: 'portrait' }
    })
    .from(element)
    .save()
  } catch (e) {
    alert('No se pudo generar el PDF. Usa Imprimir y guarda como PDF.')
  }
}

onMounted(() => {
  // Queries auto-fetch on mount.
})
</script>

<template>
  <div class="app-shell">
    <main class="app-container">
      <div class="px-2 sm:px-0">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between mb-6">
          <div>
            <h1 class="app-title">Gestión de Estudiantes</h1>
            <p class="app-subtitle">Busca por cédula o apellidos y nombre.</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button @click="deleteSelectedStudents" class="app-btn app-btn-ghost">
              Eliminar Seleccionados
            </button>
            <button @click="deleteAllStudents" class="app-btn app-btn-ghost">
              Eliminar Todos
            </button>
            <button @click="openModal()" class="app-btn app-btn-primary">
              + Nuevo Estudiante
            </button>
          </div>
        </div>

        <div class="mb-4 app-card p-4">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div class="flex-1">
              <label class="block text-xs uppercase tracking-wider text-slate-500 mb-2">Buscar estudiante</label>
              <input
                v-model="searchTerm"
                type="text"
                placeholder="Cedula o apellidos y nombre"
                class="app-input"
              />
            </div>
            <div class="text-xs text-slate-500">
              Mostrando {{ students.length }} de {{ totalCount }} estudiantes
            </div>
          </div>
          <div class="mt-3 flex items-center gap-2 text-xs text-slate-500">
            <button
              @click="goToPage(page - 1)"
              :disabled="page === 1"
              class="px-2 py-1 rounded border border-slate-200 disabled:opacity-40 hover:bg-slate-100"
            >
              Anterior
            </button>
            <span>Pagina {{ page }} de {{ totalPages }}</span>
            <button
              @click="goToPage(page + 1)"
              :disabled="page === totalPages"
              class="px-2 py-1 rounded border border-slate-200 disabled:opacity-40 hover:bg-slate-100"
            >
              Siguiente
            </button>
          </div>
        </div>

        <!-- Table -->
        <div class="app-card overflow-hidden">
          <table class="app-table">
            <thead>
              <tr>
                <th class="w-10">
                  <input type="checkbox" :checked="isAllStudentsSelected()" @change="toggleAllStudents" class="accent-teal-600" />
                </th>
                <th>Nombre Completo</th>
                <th>Estado</th>
                <th>Curso Asignado</th>
                <th class="text-right">Acciones</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="loading">
                <td colspan="5" class="text-center py-8">
                  <span class="app-spinner mr-2"></span>
                  <span class="text-sm text-slate-500">Cargando...</span>
                </td>
              </tr>
              <tr v-else-if="students.length === 0">
                <td colspan="5" class="text-center text-sm text-slate-500 py-8">No hay estudiantes registrados.</td>
              </tr>
              <tr v-else v-for="student in students" :key="student.id">
                <td>
                  <input type="checkbox" :checked="selectedStudentIds.has(student.id)" @change="toggleStudentSelection(student.id)" class="accent-teal-600" />
                </td>
                <td class="text-sm font-semibold text-slate-900">{{ student.full_name }}</td>
                <td class="whitespace-nowrap text-sm">
                  <span v-if="isStudentComplete(student)" class="app-badge app-badge-ok">Completo</span>
                  <span v-else class="app-badge app-badge-warn">Pendiente</span>
                </td>
                <td class="whitespace-nowrap text-sm text-slate-600">
                  <span v-if="student.courses" class="app-badge app-badge-info">{{ student.courses.name }}</span>
                  <span v-else class="text-rose-500 text-xs font-medium">Sin asignar</span>
                </td>
                <td class="text-right">
                  <button @click="openCardModal(student)" class="action-link action-link-teal" title="Ficha">Ficha</button>
                  <button @click="openModal(student)" class="action-link action-link-slate" title="Editar">Editar</button>
                  <button @click="deleteStudent(student.id)" class="action-link action-link-rose" title="Eliminar">Eliminar</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </main>

    <!-- Modal -->
    <div v-if="showModal" class="modal-container" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeModal"></div>
      <div class="modal-panel modal-panel-lg" style="max-height:85vh;display:flex;flex-direction:column;">
        <div class="modal-header modal-header-accent shrink-0">
          <h3 class="modal-title" style="color:#fff">{{ editingStudent ? 'Editar Estudiante' : 'Nuevo Estudiante' }}</h3>
          <p class="modal-subtitle">{{ editingStudent ? 'Actualiza los datos del estudiante.' : 'Completa los datos del nuevo estudiante.' }}</p>
        </div>
        <div class="modal-body overflow-y-auto flex-1">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-slate-600">Nombre Completo</label>
                <input v-model="form.full_name" type="text" class="app-input mt-1">
              </div>
              <div>
                <label class="block text-sm font-medium text-slate-600">Curso</label>
                <select v-model="form.course_id" class="app-input mt-1">
                  <option :value="null">Seleccionar Curso</option>
                  <option v-for="course in courses" :key="course.id" :value="course.id">
                    {{ course.name }}
                  </option>
                </select>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-slate-600">Cedula del Estudiante</label>
                  <input v-model="form.student_cedula" type="text" class="app-input mt-1">
                </div>
                <div>
                  <label class="block text-sm font-medium text-slate-600">Fecha de Nacimiento</label>
                  <input v-model="form.student_birthdate" type="date" class="app-input mt-1">
                </div>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-slate-600">Telefono del Estudiante</label>
                  <input v-model="form.student_phone" type="text" class="app-input mt-1">
                </div>
                <div>
                  <label class="block text-sm font-medium text-slate-600">Direccion</label>
                  <input v-model="form.student_address" type="text" class="app-input mt-1">
                </div>
              </div>

              <div class="border-t border-slate-200 pt-4">
                <h4 class="text-sm font-semibold text-slate-700">Datos del Representante</h4>
                <div class="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-slate-600">Nombre del Representante</label>
                    <input v-model="form.representative_name" type="text" class="app-input mt-1">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600">Cedula del Representante</label>
                    <input v-model="form.representative_cedula" type="text" class="app-input mt-1">
                  </div>
                </div>
                <div class="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-slate-600">Telefono Principal</label>
                    <input v-model="form.representative_phone" type="text" class="app-input mt-1">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600">Telefono Alterno</label>
                    <input v-model="form.representative_alt_phone" type="text" class="app-input mt-1">
                  </div>
                </div>
              </div>

              <div class="border-t border-slate-200 pt-4">
                <h4 class="text-sm font-semibold text-slate-700">Fotos</h4>
                <div class="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-slate-600">Foto del Estudiante</label>
                    <input type="file" accept="image/*" @change="onStudentPhotoChange" class="mt-1 block w-full text-sm text-slate-500" />
                    <div v-if="studentPhotoPreview" class="mt-2">
                      <img :src="studentPhotoPreview" alt="Foto del estudiante" class="h-24 w-24 rounded-md object-cover border border-slate-200" />
                    </div>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600">Foto del Representante</label>
                    <input type="file" accept="image/*" @change="onRepresentativePhotoChange" class="mt-1 block w-full text-sm text-slate-500" />
                    <div v-if="representativePhotoPreview" class="mt-2">
                      <img :src="representativePhotoPreview" alt="Foto del representante" class="h-24 w-24 rounded-md object-cover border border-slate-200" />
                    </div>
                  </div>
                </div>
              </div>

              <div v-if="validationErrors.length > 0" class="text-sm text-amber-700 space-y-1">
                <div v-for="err in validationErrors" :key="err">{{ err }}</div>
              </div>
              <div v-if="saveError" class="text-sm text-rose-600">{{ saveError }}</div>
            </div>
          </div>

        <div class="modal-footer shrink-0">
          <button @click="closeModal" class="app-btn app-btn-ghost">Cancelar</button>
          <button @click="saveStudent" :disabled="saving" class="app-btn app-btn-primary disabled:opacity-50">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
            {{ saving ? 'Guardando...' : 'Guardar' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Libreta Modal -->
    <div v-if="showReportModal" class="modal-container" style="z-index:60" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeReportModal"></div>
      <div class="modal-panel modal-panel-xl" style="max-height:90vh;display:flex;flex-direction:column;">
        <div class="modal-header modal-header-accent shrink-0 no-print">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="modal-title" style="color:#fff">Libreta de Calificaciones</h3>
              <p class="modal-subtitle">Reporte trimestral del estudiante.</p>
            </div>
            <div class="flex items-center gap-2">
              <button @click="downloadReportPdf" class="app-btn app-btn-ghost" style="color:#fff;border-color:rgba(255,255,255,0.3)">PDF</button>
              <button @click="closeReportModal" class="app-btn app-btn-ghost" style="color:#fff;border-color:rgba(255,255,255,0.3)">Cerrar</button>
            </div>
          </div>
          <div class="mt-3 flex flex-wrap gap-2">
            <button v-for="q in quarters" :key="q.id"
              @click="reportQuarterId = q.id"
              :class="['px-3 py-1.5 rounded-lg text-xs font-bold border transition-all', reportQuarterId === q.id ? 'bg-white text-teal-700 border-white shadow' : 'text-white/80 border-white/30 hover:bg-white/10']">
              {{ q.name }}
            </button>
          </div>
        </div>

          <!-- Scrollable Body -->
          <div class="p-6 overflow-y-auto flex-1 bg-slate-50">
            <div ref="reportRef" class="app-card p-8 bg-white shadow-sm border border-slate-200">
              <div class="flex items-center gap-4 mb-6">
                <div class="h-16 w-16 rounded-xl border border-slate-200 bg-white overflow-hidden flex items-center justify-center">
                  <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo institucion" class="h-full w-full object-contain p-1" />
                  <span v-else class="text-xs text-slate-500">Logo</span>
                </div>
                <div>
                  <div class="text-lg font-semibold text-slate-900">{{ institutionName || 'Institucion' }}</div>
                  <div class="text-xs text-slate-500">
                    LIBRETA {{ academicPeriods === 'QUIMESTRE' ? 'QUIMESTRAL' : 'TRIMESTRAL' }} ·
                    {{ reportStudent?.full_name }} · {{ quarters.find(q => q.id === reportQuarterId)?.name || '' }}
                  </div>
                  <div class="text-xs text-slate-500 mt-1">
                    Cedula: {{ reportStudent?.student_cedula || '-' }} · Curso: {{ reportStudent?.courses?.name || 'Sin asignar' }}
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-4">
              <div v-if="reportLoading" class="text-center py-6 text-slate-500">Cargando libreta...</div>
              <div v-else-if="reportError" class="text-center py-6 text-red-400">{{ reportError }}</div>
              <div v-else>
                <div class="overflow-x-auto">
                  <table class="app-table">
                    <thead>
                      <tr>
                        <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">Asignatura</th>
                        <th v-if="!isQualitativeReport" class="text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">Promedio Trimestre</th>
                        <th v-if="!isQualitativeReport" class="text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">Observacion</th>
                        <th v-else class="text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">Calificacion</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr v-for="row in reportSubjects" :key="row.subject" :class="reportGradeBg(row.total)">
                        <td class="text-sm text-slate-900">{{ row.subject }}</td>
                        <td v-if="!isQualitativeReport" class="text-sm text-right tabular-nums" :class="reportGradeClass(row.total)">{{ row.total?.toFixed(2) }}</td>
                        <td v-if="!isQualitativeReport" class="text-xs text-right" :class="row.total !== null && row.total >= 7 ? 'text-emerald-600' : 'text-rose-600'">{{ row.obs }}</td>
                        <td v-else class="text-sm text-slate-900 text-right">{{ row.qualitative || '-' }}</td>
                      </tr>
                      <tr v-if="!isQualitativeReport && projectAverage !== null && projectAverage !== undefined">
                        <td class="text-sm text-slate-900">Proyecto Interdisciplinario</td>
                        <td class="text-sm text-slate-900 text-right">{{ projectAverage.toFixed(2) }}</td>
                        <td class="text-xs text-slate-500 text-right">-</td>
                      </tr>
                      <tr v-if="reportSubjects.length === 0">
                        <td :colspan="isQualitativeReport ? 2 : 3" class="text-center text-sm text-slate-500 py-6">No hay datos para este trimestre.</td>
                      </tr>
                    </tbody>
                    <tfoot>
                      <tr v-if="!isQualitativeReport" :class="reportGradeBg(reportAverage)" class="border-t-2 border-slate-300">
                        <td class="text-sm font-semibold text-slate-700">Promedio General del Trimestre</td>
                        <td class="text-sm text-right tabular-nums" :class="reportGradeClass(reportAverage)">
                          {{ reportAverage !== null ? reportAverage.toFixed(2) : '-' }}
                        </td>
                        <td></td>
                      </tr>
                    </tfoot>
                  </table>
                </div>
                <div v-if="isQualitativeReport" class="mt-3 text-xs text-slate-500">
                  Escala cualitativa: A+/A- (alcanzado), B+/B-/C+/C- (en proceso), D+/D-/E+/E- (iniciado).
                </div>

                <div class="mt-6 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-6">
                  <div class="text-sm text-slate-600">
                    Fecha: <span class="font-semibold text-slate-900">{{ new Date().toLocaleDateString('es-EC') }}</span>
                  </div>
                  <div class="flex flex-1 gap-6">
                    <div class="flex-1">
                      <div class="border-t border-slate-200 pt-2 text-xs text-slate-500 text-center">
                        {{ institutionTutorName || 'Tutor' }}
                      </div>
                    </div>
                    <div class="flex-1">
                      <div class="border-t border-slate-200 pt-2 text-xs text-slate-500 text-center">
                        {{ institutionRectorName || 'Rector/a' }}
                      </div>
                    </div>
                  </div>
                </div>

              </div><!-- v-else -->
            </div><!-- .mt-4 -->
          </div><!-- body -->
        </div><!-- modal-panel -->
      </div><!-- modal-container -->
    <!-- Student Card Modal -->
    <div v-if="showCardModal" class="modal-container" style="z-index:60" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeCardModal"></div>
      <div class="modal-panel" style="max-width:42rem;max-height:90vh;display:flex;flex-direction:column;">
        <div class="modal-header modal-header-accent shrink-0 no-print">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="modal-title" style="color:#fff">Ficha Estudiantil</h3>
              <p class="modal-subtitle">Datos completos del estudiante.</p>
            </div>
            <div class="flex gap-2">
              <button @click="downloadCardPdf" class="px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white font-medium transition-colors shadow-sm">PDF</button>
              <button @click="closeCardModal" class="px-4 py-2 rounded-lg bg-rose-600 hover:bg-rose-700 text-white font-medium transition-colors shadow-sm">Cerrar</button>
            </div>
          </div>
        </div>

          <!-- Body (Preview) -->
          <div class="p-6 overflow-y-auto flex-1 bg-slate-50">
            <div ref="cardRef" class="bg-white p-8 shadow-sm border border-slate-200 mx-auto max-w-xl" style="min-height: 800px;">
              <!-- Card Header -->
              <div class="text-center border-b border-slate-200 pb-6 mb-6">
                 <div class="flex justify-center mb-4">
                    <div class="h-20 w-20 rounded-full bg-slate-100 flex items-center justify-center overflow-hidden border border-slate-200">
                       <img v-if="institutionLogoUrl" :src="institutionLogoUrl" class="h-full w-full object-contain" />
                       <span v-else class="text-xs text-slate-400">Logo</span>
                    </div>
                 </div>
                 <h2 class="text-xl font-bold text-slate-900 uppercase tracking-wide">{{ institutionName || 'INSTITUCION EDUCATIVA' }}</h2>
                 <p class="text-sm text-slate-500 mt-1">Ficha de Datos del Estudiante</p>
              </div>

              <!-- Card Content -->
              <div class="flex flex-col items-center mb-8">
                 <div class="h-32 w-32 rounded-lg bg-slate-100 border border-slate-300 shadow-sm overflow-hidden mb-4 flex items-center justify-center relative">
                     <img v-if="cardStudent?.student_photo_url" :src="cardStudent.student_photo_url" class="h-full w-full object-cover" />
                    <svg v-else xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                 </div>
                 <h3 class="text-xl font-bold text-slate-800">{{ cardStudent?.full_name }}</h3>
                 <p class="text-slate-500 font-medium">{{ courses.find(c => c.id === cardStudent?.course_id)?.name || 'Sin Asignar' }}</p>
              </div>

              <div class="grid grid-cols-1 gap-6">
                 <!-- Personal Data -->
                 <div class="bg-slate-50 p-4 rounded-lg border border-slate-100">
                    <h4 class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-3 border-b border-slate-200 pb-1">Datos Personales</h4>
                    <div class="grid grid-cols-2 gap-y-3 gap-x-4 text-sm">
                       <div>
                          <span class="block text-xs text-slate-500">Cedula</span>
                          <span class="font-medium text-slate-800">{{ cardStudent?.student_cedula || '---' }}</span>
                       </div>
                       <div>
                          <span class="block text-xs text-slate-500">Fecha Nacimiento</span>
                          <span class="font-medium text-slate-800">{{ cardStudent?.student_birthdate || '---' }}</span>
                       </div>
                       <div class="col-span-2">
                          <span class="block text-xs text-slate-500">Direccion</span>
                          <span class="font-medium text-slate-800">{{ cardStudent?.student_address || '---' }}</span>
                       </div>
                       <div class="col-span-2">
                          <span class="block text-xs text-slate-500">Telefono</span>
                          <span class="font-medium text-slate-800">{{ cardStudent?.student_phone || '---' }}</span>
                       </div>
                    </div>
                 </div>

                 <!-- Representative Data -->
                 <div class="bg-slate-50 p-4 rounded-lg border border-slate-100">
                    <h4 class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-3 border-b border-slate-200 pb-1">Representante Legal</h4>
                     <div class="grid grid-cols-2 gap-y-3 gap-x-4 text-sm">
                        <div class="col-span-2 flex items-center gap-4 mb-2">
                           <div class="h-16 w-16 rounded-full bg-slate-100 border border-slate-200 overflow-hidden flex-shrink-0">
                              <img v-if="cardStudent?.representative_photo_url" :src="cardStudent.representative_photo_url" class="h-full w-full object-cover" />
                              <svg v-else class="h-full w-full text-slate-300" fill="currentColor" viewBox="0 0 24 24">
                                 <path d="M24 20.993V24H0v-2.996A14.977 14.977 0 0112.004 15c4.904 0 9.26 2.354 11.996 5.993zM16.002 8.999a4 4 0 11-8 0 4 4 0 018 0z" />
                              </svg>
                           </div>
                           <div>
                              <span class="block text-xs text-slate-500">Nombre</span>
                              <span class="font-medium text-slate-800">{{ cardStudent?.representative_name || '---' }}</span>
                           </div>
                        </div>
                        <div>
                           <span class="block text-xs text-slate-500">Cedula</span>
                           <span class="font-medium text-slate-800">{{ cardStudent?.representative_cedula || '---' }}</span>
                        </div>
                        <div>
                           <span class="block text-xs text-slate-500">Telefono</span>
                           <span class="font-medium text-slate-800">{{ cardStudent?.representative_phone || '---' }}</span>
                        </div>
                     </div>
                 </div>
              </div>

              <!-- Footer -->
              <div class="mt-12 pt-8 border-t border-slate-200 text-center">
                 <div class="flex justify-between px-8">
                    <div class="flex flex-col items-center">
                       <div class="w-32 h-px bg-slate-300 mb-2"></div>
                       <span class="text-xs text-slate-500">Firma Secretaria</span>
                    </div>
                    <div class="flex flex-col items-center">
                       <div class="w-32 h-px bg-slate-300 mb-2"></div>
                       <span class="text-xs text-slate-500">Firma Rectorado</span>
                    </div>
                 </div>
              </div>
            </div><!-- cardRef -->
          </div><!-- body -->
        </div><!-- modal-panel -->
      </div><!-- modal-container -->

    <!-- Confirm Modal -->
    <div v-if="confirmModal.show" class="modal-container" style="z-index:70" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeConfirmModal"></div>
      <div class="modal-panel" style="max-width:28rem;">
        <div class="modal-body text-center" style="padding:32px 24px;">
          <div class="confirm-icon-ring" :class="confirmModal.action ? 'danger' : 'warning'">
            <svg class="h-7 w-7" :class="confirmModal.action ? 'text-rose-600' : 'text-amber-600'" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <h3 class="modal-title text-center">{{ confirmModal.title }}</h3>
          <p class="text-sm text-slate-500 mt-2">{{ confirmModal.message }}</p>
        </div>
        <div class="modal-footer justify-center">
          <button @click="closeConfirmModal" :disabled="confirmModal.processing" class="app-btn app-btn-ghost">
            {{ confirmModal.action ? 'Cancelar' : 'Cerrar' }}
          </button>
          <button v-if="confirmModal.action" @click="executeConfirmAction" :disabled="confirmModal.processing" class="app-btn app-btn-danger disabled:opacity-50">
            {{ confirmModal.processing ? 'Procesando...' : 'Confirmar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
@media print {
  nav,
  .no-print,
  button {
    display: none !important;
  }

  body,
  html {
    background: white !important;
  }

  .bg-gray-900,
  .bg-gray-800,
  .bg-gray-700 {
    background: white !important;
  }

  .text-white,
  .text-gray-400,
  .text-gray-300,
  .text-gray-200,
  .text-gray-500 {
    color: #111827 !important;
  }

  table {
    font-size: 11px;
    border-collapse: collapse !important;
  }

  th,
  td {
    border: 1px solid #d1d5db !important;
    padding: 4px !important;
  }

  .rounded,
  .rounded-lg,
  .rounded-md {
    border-radius: 0 !important;
  }
}
</style>

