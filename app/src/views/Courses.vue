<script setup>
import { ref, onMounted, nextTick, computed, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAcademicYearsQuery, useCoursesQuery } from '../composables/useQueries'
import { useNetwork } from '../composables/useNetwork'
import { useQueryClient } from '@tanstack/vue-query'
import { translateError } from '../lib/errorDictionary'
import * as XLSX from 'xlsx'
import SkeletonTable from '../components/ui/SkeletonTable.vue'
import {
    validateStudentForm,
    isStudentComplete,
    getFileExt,
    uploadPhoto,
    createPhotoPreview
} from '../lib/studentUtils'

const queryClient = useQueryClient()
const { isOnline } = useNetwork()

// Queries handled by composables, definitions below
const showModal = ref(false)
const showSubjectsModal = ref(false)
const editingCourse = ref(null)
const subjectsSaving = ref(false)
const subjectsMessage = ref('')
const showStudentsModal = ref(false)
const courseStudents = ref([])
const studentsLoading = ref(false)
const studentsMessage = ref('')
const managingStudentsCourse = ref(null)
const headerMessage = ref('')
let headerMessageTimer = null
const importCourseId = ref(null)
const selectedCourseIds = ref(new Set())
const importFile = ref(null)
const importPreview = ref([])
const importErrors = ref([])
const importing = ref(false)
const importMessage = ref('')
const importFileInput = ref(null)

const showStudentModal = ref(false)
const editingStudent = ref(null)
const studentSaving = ref(false)
const studentSaveError = ref('')
const studentValidationErrors = ref([])
const studentPhotoFile = ref(null)
const representativePhotoFile = ref(null)
const studentPhotoPreview = ref('')
const representativePhotoPreview = ref('')
const studentForm = ref({
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

// Manage Subjects State
const allSubjects = ref([])
const selectedCourseSubjects = ref(new Set())
const managingCourse = ref(null)

// Academic Years State
const selectedAcademicYear = ref(null)
const showNewYearModal = ref(false)
const showCopyCoursesModal = ref(false)
const newYearName = ref('')
const copyFromYear = ref(null)
const copyingCourses = ref(false)
const copyResult = ref(null)

const LEVEL_OPTIONS = [
  { value: 'INICIAL', label: 'Inicial' },
  { value: 'PREPARATORIA', label: 'Preparatoria' },
  { value: 'ELEMENTAL', label: 'EGB Elemental' },
  { value: 'MEDIA', label: 'EGB Media' },
  { value: 'SUPERIOR', label: 'EGB Superior' },
  { value: 'BACHILLERATO', label: 'Bachillerato' }
]

const TRACK_OPTIONS = [
  { value: 'BASICA', label: 'Basica' },
  { value: 'CIENCIAS', label: 'Ciencias' },
  { value: 'TECNICO', label: 'Tecnico' }
]

const form = ref({
  name: '',
  academic_year: '',
  level: 'MEDIA',
  track: 'BASICA'
})

const { data: academicYears, refetch: fetchAcademicYears } = useAcademicYearsQuery()

const selectedAcademicYearName = computed(() => {
  return academicYears.value?.find(y => y.id === selectedAcademicYear.value)?.name || null
})

const { data: coursesData, isLoading: loading, refetch: fetchCourses } = useCoursesQuery(selectedAcademicYearName)

const courses = computed(() => coursesData.value || [])

watch(academicYears, (newVal) => {
  if (newVal && newVal.length > 0 && !selectedAcademicYear.value) {
    const current = newVal.find(y => y.is_current) || newVal[0]
    selectedAcademicYear.value = current.id
    form.value.academic_year = current.name
  }
}, { immediate: true })

const onAcademicYearChange = async () => {
  const selectedYear = academicYears.value.find(y => y.id === selectedAcademicYear.value)
  if (selectedYear) {
    form.value.academic_year = selectedYear.name
  }
  await fetchCourses()
}

const openNewYearModal = () => {
  const currentYear = new Date().getFullYear()
  newYearName.value = `${currentYear}-${currentYear + 1}`
  showNewYearModal.value = true
  copyResult.value = null
}

const closeNewYearModal = () => {
  showNewYearModal.value = false
  newYearName.value = ''
  copyResult.value = null
}

const createNewAcademicYear = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (!newYearName.value) {
    alert('Ingresa el nombre del ano lectivo')
    return
  }

  try {
    const { error } = await supabase
      .from('academic_years')
      .insert({ name: newYearName.value, is_active: false, is_current: false })

    if (error) throw error

    await fetchAcademicYears()
    const newYear = academicYears.value.find(y => y.name === newYearName.value)
    if (newYear) {
      selectedAcademicYear.value = newYear.id
      form.value.academic_year = newYear.name
    }
    closeNewYearModal()
    alert('Ano lectivo creado. Ahora puedes copiar cursos del ano anterior.')
    showCopyCoursesModal.value = true
    copyFromYear.value = academicYears.value.find(y => y.name !== newYearName.value)?.id || null
  } catch (error) {
    alert('Error creando ano lectivo: ' + error.message)
  }
}

const openCopyCoursesModal = () => {
  copyFromYear.value = null
  copyResult.value = null
  showCopyCoursesModal.value = true
}

const closeCopyCoursesModal = () => {
  showCopyCoursesModal.value = false
  copyFromYear.value = null
  copyResult.value = null
}

const copyCoursesFromYear = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (!copyFromYear.value || !selectedAcademicYear.value) {
    alert('Selecciona el ano lectivo de origen')
    return
  }

  copyingCourses.value = true
  copyResult.value = null

  try {
    const { data, error } = await supabase
      .rpc('copy_courses_to_academic_year', {
        source_year_id: copyFromYear.value,
        target_year_id: selectedAcademicYear.value,
        include_subjects: true
      })

    if (error) throw error

    copyResult.value = data
    await fetchCourses()
    await fetchAcademicYears()
  } catch (error) {
    alert('Error copiando cursos: ' + error.message)
  }

  copyingCourses.value = false
}

const toggleCourseSelection = (id) => {
  const next = new Set(selectedCourseIds.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  selectedCourseIds.value = next
}

const isAllCoursesSelected = () => {
  return courses.value.length > 0 && selectedCourseIds.value.size === courses.value.length
}

const toggleAllCourses = () => {
  if (isAllCoursesSelected()) {
    selectedCourseIds.value = new Set()
  } else {
    selectedCourseIds.value = new Set(courses.value.map(c => c.id))
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

const deleteSelectedCourses = async () => {
  if (selectedCourseIds.value.size === 0) {
    confirmModal.value = {
      show: true,
      title: 'Aviso',
      message: 'No hay cursos seleccionados.',
      processing: false,
      action: null
    }
    return
  }

  confirmModal.value = {
    show: true,
    title: 'Eliminar Seleccionados',
    message: '¿Eliminar cursos seleccionados? Esta accion no se puede deshacer.',
    processing: false,
    action: async () => {
      const ids = Array.from(selectedCourseIds.value)
      try {
        const chunkSize = 50
        for (let i = 0; i < ids.length; i += chunkSize) {
          const chunk = ids.slice(i, i + chunkSize)
          const { error } = await supabase.from('courses').delete().in('id', chunk)
          if (error) throw error
        }
        selectedCourseIds.value = new Set()
        await fetchCourses()
      } catch (error) {
        confirmModal.value = {
          show: true,
          title: 'Error',
          message: 'Error: ' + translateError(error),
          processing: false,
          action: null
        }
      }
    }
  }
}

const deleteAllCourses = async () => {
  confirmModal.value = {
    show: true,
    title: 'Eliminar Todos',
    message: '¿Eliminar TODOS los cursos? Esta accion no se puede deshacer.',
    processing: false,
    action: async () => {
      try {
        const { error } = await supabase
          .from('courses')
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000')
        if (error) throw error
        selectedCourseIds.value = new Set()
        await fetchCourses()
      } catch (error) {
        confirmModal.value = {
          show: true,
          title: 'Error',
          message: 'Error: ' + translateError(error),
          processing: false,
          action: null
        }
      }
    }
  }
}

const fetchCourseStudents = async (courseId) => {
  if (!courseId) return
  studentsLoading.value = true
  studentsMessage.value = ''
  const { data, error } = await supabase
    .from('students')
    .select('id, full_name, course_id, student_cedula, student_birthdate, student_phone, student_address, representative_name, representative_cedula, representative_phone, representative_alt_phone, student_photo_url, representative_photo_url, created_at')
    .eq('course_id', courseId)
    .order('full_name')
  if (error) {
    studentsMessage.value = 'Error cargando estudiantes: ' + error.message
    courseStudents.value = []
  } else {
    courseStudents.value = data || []
  }
  studentsLoading.value = false
}

const openStudentsModal = async (course) => {
  managingStudentsCourse.value = course
  showStudentsModal.value = true
  await fetchCourseStudents(course.id)
}

const openImportModal = async (course) => {
  managingStudentsCourse.value = course
  showStudentsModal.value = true
  await fetchCourseStudents(course.id)
  await nextTick()
  importFileInput.value?.click()
}

const showHeaderWarning = (msg) => {
  headerMessage.value = msg
  clearTimeout(headerMessageTimer)
  headerMessageTimer = setTimeout(() => { headerMessage.value = '' }, 4000)
}

const handleHeaderImport = () => {
  if (!importCourseId.value) {
    showHeaderWarning('⚠ Debes seleccionar un curso antes de importar.')
    return
  }
  const course = courses.value.find(c => c.id === importCourseId.value)
  if (!course) {
    showHeaderWarning('⚠ Curso no encontrado.')
    return
  }
  headerMessage.value = ''
  openImportModal(course)
}

const closeStudentsModal = () => {
  showStudentsModal.value = false
  managingStudentsCourse.value = null
  courseStudents.value = []
  studentsMessage.value = ''
  importFile.value = null
  importPreview.value = []
  importErrors.value = []
  importMessage.value = ''
}

const validateStudentFormLocal = () => {
  const errors = validateStudentForm(studentForm.value)
  studentValidationErrors.value = errors
  return errors.length === 0
}

const uploadPhotoToStorage = async (file, path) => {
  return await uploadPhoto(supabase, file, path)
}

const onStudentPhotoChange = (event) => {
  const file = event.target.files?.[0] || null
  studentPhotoFile.value = file
  studentPhotoPreview.value = createPhotoPreview(file, studentForm.value.student_photo_url || '')
}

const onRepresentativePhotoChange = (event) => {
  const file = event.target.files?.[0] || null
  representativePhotoFile.value = file
  representativePhotoPreview.value = createPhotoPreview(file, studentForm.value.representative_photo_url || '')
}

const openStudentModal = (student = null) => {
  editingStudent.value = student
  if (student) {
    studentForm.value = {
      full_name: student.full_name,
      course_id: student.course_id || managingStudentsCourse.value?.id,
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
    studentPhotoPreview.value = studentForm.value.student_photo_url || ''
    representativePhotoPreview.value = studentForm.value.representative_photo_url || ''
  } else {
    studentForm.value = {
      full_name: '',
      course_id: managingStudentsCourse.value?.id || null,
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
  studentSaveError.value = ''
  studentValidationErrors.value = []
  showStudentModal.value = true
}

const closeStudentModal = () => {
  showStudentModal.value = false
  editingStudent.value = null
  studentPhotoFile.value = null
  representativePhotoFile.value = null
  studentPhotoPreview.value = ''
  representativePhotoPreview.value = ''
  studentSaveError.value = ''
  studentValidationErrors.value = []
}

const saveStudent = async () => {
  studentSaving.value = true
  studentSaveError.value = ''
  if (!validateStudentFormLocal()) {
    studentSaving.value = false
    return
  }
  try {
    let studentId = editingStudent.value?.id || null
    const basePayload = {
      full_name: studentForm.value.full_name,
      course_id: studentForm.value.course_id,
      student_cedula: studentForm.value.student_cedula,
      student_birthdate: studentForm.value.student_birthdate || null,
      student_phone: studentForm.value.student_phone,
      student_address: studentForm.value.student_address,
      representative_name: studentForm.value.representative_name,
      representative_cedula: studentForm.value.representative_cedula,
      representative_phone: studentForm.value.representative_phone,
      representative_alt_phone: studentForm.value.representative_alt_phone,
      student_photo_url: studentForm.value.student_photo_url,
      representative_photo_url: studentForm.value.representative_photo_url
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

    await fetchCourseStudents(managingStudentsCourse.value.id)
    closeStudentModal()
  } catch (error) {
    studentSaveError.value = 'Error guardando estudiante: ' + error.message
  }
  studentSaving.value = false
}

const deleteStudent = async (id) => {
  if (!confirm('Estas seguro de eliminar este estudiante? Se borraran sus calificaciones.')) return
  try {
    const { error } = await supabase
      .from('students')
      .delete()
      .eq('id', id)
    if (error) throw error
    await fetchCourseStudents(managingStudentsCourse.value.id)
  } catch (error) {
    studentsMessage.value = 'Error eliminando estudiante: ' + error.message
  }
}

const normalizeHeader = (value) => {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .toUpperCase()
    .trim()
}

const parseStudentExcel = async (file) => {
  const buf = await file.arrayBuffer()
  const workbook = XLSX.read(buf, { type: 'array' })
  const sheetName = workbook.SheetNames[0]
  const sheet = workbook.Sheets[sheetName]
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, blankrows: false, raw: false })

  let headerRow = -1
  let colCedula = -1
  let colName = -1

  rows.forEach((row, idx) => {
    if (headerRow !== -1) return
    row.forEach((cell, cidx) => {
      const h = normalizeHeader(cell)
      if (h.includes('CEDULA')) colCedula = cidx
      if (h.includes('NOMBRES') || h.includes('APELLIDOS')) colName = cidx
    })
    if (colCedula !== -1 && colName !== -1) headerRow = idx
  })

  if (headerRow === -1) {
    let found = false
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i]
      const ced = row?.[3] ? String(row[3]).trim() : ''
      const name = row?.[5] ? String(row[5]).trim() : ''
      if (ced && name) {
        colCedula = 3
        colName = 5
        headerRow = i - 1
        found = true
        break
      }
    }
    if (!found) {
      return { errors: ['No se encontro encabezado con CEDULA y NOMBRES COMPLETOS.'] }
    }
  }

  const entries = []
  const errors = []
  for (let i = headerRow + 1; i < rows.length; i++) {
    const row = rows[i]
    const cedula = row[colCedula] ? String(row[colCedula]).trim() : ''
    const name = row[colName] ? String(row[colName]).trim() : ''
    if (!cedula && !name) continue
    if (!name) errors.push(`Fila ${i + 1}: falta NOMBRES COMPLETOS`)
    entries.push({
      full_name: name || 'SIN NOMBRE',
      student_cedula: cedula || null
    })
  }

  return { entries, errors }
}

const onImportFileChange = async (event) => {
  const file = event.target.files?.[0] || null
  importFile.value = file
  importPreview.value = []
  importErrors.value = []
  importMessage.value = ''
  if (!file) return
  const { entries, errors } = await parseStudentExcel(file)
  importPreview.value = entries || []
  importErrors.value = errors || []
  if (!importPreview.value.length && !importErrors.value.length) {
    importErrors.value = ['No se detectaron estudiantes en el archivo.']
  }
}

const importStudentsFromExcel = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (!importPreview.value.length || !managingStudentsCourse.value?.id) return
  importing.value = true
  importMessage.value = ''

  try {
    const courseId = managingStudentsCourse.value.id
    const entries = importPreview.value
    const cedulas = entries.map(e => e.student_cedula).filter(Boolean)
    let existingMap = new Map()

    if (cedulas.length > 0) {
      const { data, error } = await supabase
        .from('students')
        .select('id, student_cedula')
        .eq('course_id', courseId)
        .in('student_cedula', cedulas)
      if (error) throw error
      ;(data || []).forEach(s => {
        existingMap.set(s.student_cedula, s.id)
      })
    }

    const toInsert = []
    const toUpdate = []
    entries.forEach(e => {
      if (e.student_cedula && existingMap.has(e.student_cedula)) {
        toUpdate.push({ id: existingMap.get(e.student_cedula), full_name: e.full_name })
      } else {
        toInsert.push({
          full_name: e.full_name,
          student_cedula: e.student_cedula,
          course_id: courseId
        })
      }
    })

    if (toInsert.length > 0) {
      const { error } = await supabase.from('students').insert(toInsert)
      if (error) throw error
    }

    for (const upd of toUpdate) {
      const { error } = await supabase.from('students').update({ full_name: upd.full_name }).eq('id', upd.id)
      if (error) throw error
    }

    importMessage.value = `Importados ${toInsert.length} nuevos, actualizados ${toUpdate.length}.`
    await fetchCourseStudents(courseId)
  } catch (e) {
    importMessage.value = 'Error importando: ' + e.message
  }

  importing.value = false
}

// --- Course CRUD ---
const openModal = (course = null) => {
  showModal.value = true
  editingCourse.value = course
  if (course) {
    form.value = { ...course }
  } else {
    const selectedYear = academicYears.value.find(y => y.id === selectedAcademicYear.value)
    form.value = {
      name: '',
      academic_year: selectedYear?.name || '',
      level: 'MEDIA',
      track: 'BASICA'
    }
  }
}

const closeModal = () => {
  showModal.value = false
  editingCourse.value = null
}

const saveCourse = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  try {
    if (editingCourse.value) {
      const { error } = await supabase.from('courses').update(form.value).eq('id', editingCourse.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('courses').insert(form.value)
      if (error) throw error
    }
    await fetchCourses()
    closeModal()
  } catch (error) {
    alert('Error saving course: ' + error.message)
  }
}

const deleteCourse = async (id) => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  confirmModal.value = {
    show: true,
    title: 'Eliminar Curso',
    message: '¿Estas seguro de eliminar este curso? Se borraran permanentemente los estudiantes y calificaciones asociados a el.',
    processing: false,
    action: async () => {
      try {
        const { error } = await supabase.from('courses').delete().eq('id', id)
        if (error) throw error
        await fetchCourses()
      } catch (error) {
        confirmModal.value = {
          show: true,
          title: 'Error',
          message: 'Error eliminando curso: ' + translateError(error),
          processing: false,
          action: null
        }
      }
    }
  }
}

// --- Manage Subjects Logic ---
const openSubjectsModal = async (course) => {
  managingCourse.value = course
  showSubjectsModal.value = true
  subjectsMessage.value = ''

  const { data: subjects } = await supabase.from('subjects').select('id, name').order('name')
  allSubjects.value = subjects || []

  const { data: assigned } = await supabase
    .from('course_subjects')
    .select('subject_id')
    .eq('course_id', course.id)

  selectedCourseSubjects.value = new Set(assigned?.map(a => a.subject_id) || [])
}

const toggleSubject = (subjectId) => {
  if (selectedCourseSubjects.value.has(subjectId)) {
    selectedCourseSubjects.value.delete(subjectId)
  } else {
    selectedCourseSubjects.value.add(subjectId)
  }
}

const saveCourseSubjects = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  subjectsSaving.value = true
  subjectsMessage.value = ''
  try {
    const courseId = managingCourse.value.id

    const { data: currentLinks } = await supabase
      .from('course_subjects')
      .select('subject_id')
      .eq('course_id', courseId)

    const currentSet = new Set(currentLinks?.map(x => x.subject_id) || [])
    const newSet = selectedCourseSubjects.value

    const toAdd = [...newSet].filter(x => !currentSet.has(x))
    const toRemove = [...currentSet].filter(x => !newSet.has(x))

    if (toAdd.length > 0) {
      const insertData = toAdd.map(sid => ({ course_id: courseId, subject_id: sid }))
      const { error } = await supabase.from('course_subjects')
        .upsert(insertData, { onConflict: 'course_id, subject_id' })
      if (error) throw error
    }

    if (toRemove.length > 0) {
      const { error } = await supabase
        .from('course_subjects')
        .delete()
        .eq('course_id', courseId)
        .in('subject_id', toRemove)
      if (error) throw error
    }

    const { data: assigned } = await supabase
      .from('course_subjects')
      .select('subject_id')
      .eq('course_id', courseId)
    selectedCourseSubjects.value = new Set(assigned?.map(a => a.subject_id) || [])

    subjectsMessage.value = 'Materias asignadas correctamente'
    showSubjectsModal.value = false
  } catch (e) {
    subjectsMessage.value = 'Error actualizando materias: ' + e.message
  } finally {
    subjectsSaving.value = false
  }
}
</script>

<template>
  <div class="app-shell">
    <main class="app-container">
      <div class="px-2 sm:px-0">
        <div class="flex justify-between items-center mb-6">
          <h1 class="app-title">Gestion de Cursos</h1>
          <div class="flex flex-wrap gap-2 items-center">
            <select v-model="selectedAcademicYear" @change="onAcademicYearChange" class="app-input w-48">
              <option v-for="year in academicYears" :key="year.id" :value="year.id">
                {{ year.name }} {{ year.is_current ? '(Actual)' : '' }}
              </option>
            </select>

            <button @click="openNewYearModal" class="app-btn app-btn-ghost text-sm">
              + Nuevo Año
            </button>
            <button @click="openCopyCoursesModal" class="app-btn app-btn-ghost text-sm">
              Copiar Cursos
            </button>

            <span class="border-l border-slate-300 h-6"></span>

            <select v-model="importCourseId" class="app-input w-56">
              <option :value="null">Selecciona curso</option>
              <option v-for="course in courses" :key="course.id" :value="course.id">
                {{ course.name }}
              </option>
            </select>
            <button @click="handleHeaderImport" class="app-btn app-btn-ghost">
              Importar Excel
            </button>
            <button @click="deleteSelectedCourses" class="app-btn app-btn-ghost">
              Eliminar Seleccionados
            </button>
            <button @click="deleteAllCourses" class="app-btn app-btn-ghost">
              Eliminar Todos
            </button>
            <button @click="openModal()" class="app-btn app-btn-primary">
              + Nuevo Curso
            </button>
          </div>
        </div>

        <!-- Warning Banner -->
        <transition name="fade-slide">
          <div v-if="headerMessage" class="mb-4 px-4 py-3 rounded-xl bg-amber-50 border border-amber-300 text-amber-800 text-sm font-medium flex items-center gap-2 shadow-sm">
            <span>{{ headerMessage }}</span>
            <button @click="headerMessage = ''" class="ml-auto text-amber-500 hover:text-amber-700 text-lg leading-none">&times;</button>
          </div>
        </transition>
        <div class="app-card overflow-hidden">
          <table class="app-table">
            <thead>
              <tr>
                <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                  <input type="checkbox" :checked="isAllCoursesSelected()" @change="toggleAllCourses" />
                </th>
                <th class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Nombre</th>
                <th class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Ano Lectivo</th>
                <th class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Nivel</th>
                <th class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Itinerario</th>
                <th class="text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">Acciones</th>
              </tr>
            </thead>
            <TransitionGroup name="list" tag="tbody">
              <tr v-if="loading" key="loading" class="!bg-transparent">
                <td colspan="6" class="p-0 border-0">
                  <SkeletonTable :rows="4" :columns="6" class="border-0 rounded-none shadow-none" />
                </td>
              </tr>
              <tr v-else-if="courses.length === 0" key="empty">
                <td colspan="6" class="text-center text-sm text-slate-500 py-12">
                  No hay cursos en este ano lectivo.
                  <button @click="openCopyCoursesModal" class="text-teal-600 hover:text-teal-800 ml-2 font-medium">
                    Copiar cursos de otro ano
                  </button>
                </td>
              </tr>
              <tr v-else v-for="course in courses" :key="course.id" class="hover:bg-slate-100 dark:hover:bg-slate-800/50 transition-colors">
                <td>
                  <input type="checkbox" :checked="selectedCourseIds.has(course.id)" @change="toggleCourseSelection(course.id)" />
                </td>
                <td class="text-sm font-semibold text-slate-900">{{ course.name }}</td>
                <td class="text-sm text-slate-600">{{ course.academic_year }}</td>
                <td class="text-sm text-slate-600">{{ course.level || '-' }}</td>
                <td class="text-sm text-slate-600">{{ course.track || '-' }}</td>
                <td class="text-right text-sm font-medium">
                  <button @click="openStudentsModal(course)" class="text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 mr-4 transition-colors font-semibold">Estudiantes</button>
                  <button @click="openImportModal(course)" class="text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 mr-4 transition-colors font-semibold">Importar Excel</button>
                  <button @click="openSubjectsModal(course)" class="text-emerald-600 hover:text-emerald-800 dark:text-emerald-400 dark:hover:text-emerald-300 mr-4 transition-colors font-semibold">Asignar Materias</button>
                  <button @click="openModal(course)" class="text-amber-600 hover:text-amber-800 dark:text-amber-400 dark:hover:text-amber-300 mr-4 transition-colors font-semibold">Editar</button>
                  <button @click="deleteCourse(course.id)" class="text-rose-600 hover:text-rose-800 dark:text-rose-400 dark:hover:text-rose-300 transition-colors font-semibold">Eliminar</button>
                </td>
              </tr>
            </TransitionGroup>
          </table>
        </div>
      </div>
    </main>

    <!-- New Academic Year Modal -->
    <div v-if="showNewYearModal" class="modal-container" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="modal-backdrop" aria-hidden="true" @click="closeNewYearModal"></div>
        <div class="modal-panel sm:max-w-lg w-full">
          <div class="modal-body">
            <h3 class="text-lg leading-6 font-medium text-slate-900" id="modal-title">
              Crear Nuevo Ano Lectivo
            </h3>
            <div class="mt-4">
              <p class="text-sm text-slate-500 mb-4">
                Los anos lectivos permiten mantener un historial de todos los cursos y calificaciones.
                Cada ano es independiente de los demas.
              </p>
              <input v-model="newYearName" type="text" class="app-input w-full" placeholder="Ej: 2026-2027" />
              <p class="text-xs text-slate-400 mt-2">
                Formato: YYYY-YYYY (Ano inicio - Ano fin)
              </p>
            </div>
          </div>
          <div class="modal-footer">
            <button @click="createNewAcademicYear" class="app-btn app-btn-primary w-full sm:w-auto">
              Crear Ano Lectivo
            </button>
            <button @click="closeNewYearModal" class="app-btn app-btn-ghost w-full sm:w-auto mt-3 sm:mt-0">
              Cancelar
            </button>
          </div>
        </div>
    </div>

    <!-- Copy Courses Modal -->
    <div v-if="showCopyCoursesModal" class="modal-container" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="modal-backdrop" aria-hidden="true" @click="closeCopyCoursesModal"></div>
        <div class="modal-panel sm:max-w-lg w-full">
          <div class="modal-body">
            <h3 class="text-lg leading-6 font-medium text-slate-900" id="modal-title">
              Copiar Cursos de Otro Ano Lectivo
            </h3>
            <div class="mt-4">
              <p class="text-sm text-slate-500 mb-4">
                Copia los cursos de un ano lectivo anterior al ano actual.
                Las materias de cada curso tambien se copian.
              </p>
              <select v-model="copyFromYear" class="app-input w-full">
                <option :value="null">Selecciona el ano lectivo de origen</option>
                <option v-for="year in academicYears.filter(y => y.id !== selectedAcademicYear)" :key="year.id" :value="year.id">
                  {{ year.name }}
                </option>
              </select>
              <div v-if="copyResult && copyResult.length > 0" class="mt-4 p-3 bg-emerald-50 border border-emerald-200 rounded-md">
                <p class="text-sm text-emerald-700">
                  Se copiaron {{ copyResult.length }} cursos exitosamente.
                </p>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button @click="copyCoursesFromYear" :disabled="!copyFromYear || copyingCourses" class="app-btn app-btn-primary w-full sm:w-auto">
              {{ copyingCourses ? 'Copiando...' : 'Copiar Cursos' }}
            </button>
            <button @click="closeCopyCoursesModal" class="app-btn app-btn-ghost w-full sm:w-auto mt-3 sm:mt-0">
              Cerrar
            </button>
          </div>
        </div>
    </div>

    <!-- Create/Edit Course Modal -->
    <div v-if="showModal" class="modal-container" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeModal"></div>
      <div class="modal-panel">
        <div class="modal-header modal-header-accent">
          <h3 class="modal-title" style="color:#fff">{{ editingCourse ? 'Editar Curso' : 'Nuevo Curso' }}</h3>
          <p class="modal-subtitle">{{ editingCourse ? 'Modifica los datos del curso.' : 'Ingresa los datos del nuevo curso.' }}</p>
        </div>
        <div class="modal-body">
          <div class="modal-field">
            <label class="modal-label">Nombre del Curso</label>
            <input v-model="form.name" type="text" class="app-input" placeholder="Ej: 1ro Bachillerato A">
          </div>
          <div class="modal-field">
            <label class="modal-label">Año Lectivo</label>
            <input v-model="form.academic_year" type="text" class="app-input" readonly>
          </div>
          <div class="modal-field">
            <label class="modal-label">Nivel</label>
            <select v-model="form.level" class="app-input">
              <option v-for="opt in LEVEL_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
            </select>
          </div>
          <div class="modal-field">
            <label class="modal-label">Itinerario</label>
            <select v-model="form.track" class="app-input">
              <option v-for="opt in TRACK_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
            </select>
          </div>
        </div>
        <div class="modal-footer">
          <button @click="closeModal" class="app-btn app-btn-ghost">Cancelar</button>
          <button @click="saveCourse" class="app-btn app-btn-primary">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
            Guardar
          </button>
        </div>
      </div>
    </div>

    <!-- Students Modal -->
    <div v-if="showStudentsModal" class="modal-container" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeStudentsModal"></div>
      <div class="modal-panel modal-panel-xl">
        <div class="modal-header modal-header-accent">
          <h3 class="modal-title" style="color:#fff">Estudiantes - {{ managingStudentsCourse?.name }}</h3>
          <p class="modal-subtitle">Gestiona los estudiantes de este curso.</p>
        </div>
        <div class="modal-body" style="max-height:60vh;overflow-y:auto">
          <div class="flex flex-wrap gap-2 mb-4 items-center">
            <button @click="openStudentModal()" class="app-btn app-btn-primary text-sm">+ Nuevo Estudiante</button>
            <button @click="$refs.importFileInput?.click()" class="app-btn app-btn-ghost text-sm">Importar Excel</button>
            <input ref="importFileInput" type="file" accept=".xlsx,.xls" @change="onImportFileChange" class="sr-only" style="position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0)">
          </div>

          <!-- Import Preview -->
          <div v-if="importPreview.length > 0" class="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
            <p class="text-sm font-semibold text-blue-700 mb-2">Vista previa: {{ importPreview.length }} estudiantes detectados</p>
            <div v-if="importErrors.length > 0" class="text-xs text-rose-600 mb-2">
              <p v-for="(err, i) in importErrors" :key="i">⚠ {{ err }}</p>
            </div>
            <div class="flex gap-2">
              <button @click="importStudentsFromExcel" :disabled="importing" class="app-btn app-btn-primary text-sm">
                {{ importing ? 'Importando...' : 'Confirmar Importación' }}
              </button>
              <button @click="importFile = null; importPreview = []; importErrors = []" class="app-btn app-btn-ghost text-sm">Cancelar</button>
            </div>
            <p v-if="importMessage" class="text-xs mt-2" :class="importMessage.includes('Error') ? 'text-rose-600' : 'text-emerald-600'">{{ importMessage }}</p>
          </div>

          <p v-if="studentsMessage" class="text-sm mb-3" :class="studentsMessage.includes('Error') ? 'text-rose-600' : 'text-emerald-600'">{{ studentsMessage }}</p>

          <div v-if="studentsLoading" class="text-center py-6">
            <span class="app-spinner mr-2"></span>
            <span class="text-sm text-slate-500">Cargando estudiantes...</span>
          </div>
          <table v-else-if="courseStudents.length > 0" class="app-table w-full">
            <thead>
              <tr>
                <th class="text-xs font-semibold text-slate-500 uppercase">Nombre</th>
                <th class="text-xs font-semibold text-slate-500 uppercase">Cédula</th>
                <th class="text-right text-xs font-semibold text-slate-500 uppercase">Acciones</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="student in courseStudents" :key="student.id" class="hover:bg-slate-50">
                <td class="text-sm font-semibold text-slate-900">{{ student.full_name }}</td>
                <td class="text-sm text-slate-600">{{ student.student_cedula || '-' }}</td>
                <td class="text-right text-sm">
                  <button @click="openStudentModal(student)" class="text-amber-600 hover:text-amber-800 dark:text-amber-400 dark:hover:text-amber-300 mr-3 transition-colors font-semibold">Editar</button>
                  <button @click="deleteStudent(student.id)" class="text-rose-600 hover:text-rose-800 dark:text-rose-400 dark:hover:text-rose-300 transition-colors font-semibold">Eliminar</button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-else class="text-sm text-slate-500 text-center py-6">No hay estudiantes en este curso.</p>
        </div>
        <div class="modal-footer">
          <button @click="closeStudentsModal" class="app-btn app-btn-ghost">Cerrar</button>
        </div>
      </div>
    </div>

    <!-- Create/Edit Student Modal -->
    <div v-if="showStudentModal" class="modal-container" style="z-index:60" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeStudentModal"></div>
      <div class="modal-panel modal-panel-lg">
        <div class="modal-header modal-header-accent">
          <h3 class="modal-title" style="color:#fff">{{ editingStudent ? 'Editar Estudiante' : 'Nuevo Estudiante' }}</h3>
          <p class="modal-subtitle">{{ editingStudent ? 'Modifica los datos del estudiante.' : 'Completa la ficha del nuevo estudiante.' }}</p>
        </div>
        <div class="modal-body" style="max-height:60vh;overflow-y:auto">
          <div v-if="studentValidationErrors.length > 0" class="mb-4 p-3 bg-rose-50 border border-rose-200 rounded-lg">
            <p v-for="(err, i) in studentValidationErrors" :key="i" class="text-xs text-rose-600">⚠ {{ err }}</p>
          </div>
          <p v-if="studentSaveError" class="text-sm text-rose-600 mb-3">{{ studentSaveError }}</p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="modal-field">
              <label class="modal-label">Nombre Completo *</label>
              <input v-model="studentForm.full_name" type="text" class="app-input" placeholder="Nombres y Apellidos">
            </div>
            <div class="modal-field">
              <label class="modal-label">Cédula del Estudiante</label>
              <input v-model="studentForm.student_cedula" type="text" class="app-input" placeholder="Ej: 0912345678">
            </div>
            <div class="modal-field">
              <label class="modal-label">Fecha de Nacimiento</label>
              <input v-model="studentForm.student_birthdate" type="date" class="app-input">
            </div>
            <div class="modal-field">
              <label class="modal-label">Teléfono del Estudiante</label>
              <input v-model="studentForm.student_phone" type="tel" class="app-input" placeholder="Ej: 0991234567">
            </div>
            <div class="modal-field md:col-span-2">
              <label class="modal-label">Dirección</label>
              <input v-model="studentForm.student_address" type="text" class="app-input" placeholder="Dirección domiciliaria">
            </div>
            <div class="modal-field">
              <label class="modal-label">Foto del Estudiante</label>
              <input type="file" accept="image/*" @change="onStudentPhotoChange" class="app-input text-sm">
              <img v-if="studentPhotoPreview" :src="studentPhotoPreview" class="h-16 w-16 rounded-lg object-cover mt-2 border">
            </div>
          </div>

          <hr class="my-4 border-slate-200">
          <h4 class="text-sm font-bold text-slate-700 mb-3">Datos del Representante</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="modal-field">
              <label class="modal-label">Nombre del Representante</label>
              <input v-model="studentForm.representative_name" type="text" class="app-input">
            </div>
            <div class="modal-field">
              <label class="modal-label">Cédula del Representante</label>
              <input v-model="studentForm.representative_cedula" type="text" class="app-input">
            </div>
            <div class="modal-field">
              <label class="modal-label">Teléfono del Representante</label>
              <input v-model="studentForm.representative_phone" type="tel" class="app-input">
            </div>
            <div class="modal-field">
              <label class="modal-label">Teléfono Alternativo</label>
              <input v-model="studentForm.representative_alt_phone" type="tel" class="app-input">
            </div>
            <div class="modal-field">
              <label class="modal-label">Foto del Representante</label>
              <input type="file" accept="image/*" @change="onRepresentativePhotoChange" class="app-input text-sm">
              <img v-if="representativePhotoPreview" :src="representativePhotoPreview" class="h-16 w-16 rounded-lg object-cover mt-2 border">
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button @click="closeStudentModal" :disabled="studentSaving" class="app-btn app-btn-ghost">Cancelar</button>
          <button @click="saveStudent" :disabled="studentSaving" class="app-btn app-btn-primary">
            {{ studentSaving ? 'Guardando...' : 'Guardar Estudiante' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Assign Subjects Modal -->
    <div v-if="showSubjectsModal" class="modal-container" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="showSubjectsModal = false"></div>
      <div class="modal-panel">
        <div class="modal-header modal-header-accent">
          <h3 class="modal-title" style="color:#fff">Asignar Materias - {{ managingCourse?.name }}</h3>
          <p class="modal-subtitle">Selecciona las materias para este curso.</p>
        </div>
        <div class="modal-body" style="max-height:50vh;overflow-y:auto">
          <p v-if="subjectsMessage" class="text-sm mb-3" :class="subjectsMessage.includes('Error') ? 'text-rose-600' : 'text-emerald-600'">{{ subjectsMessage }}</p>
          <div v-if="allSubjects.length === 0" class="text-sm text-slate-500 text-center py-4">No hay asignaturas registradas. Crea asignaturas primero.</div>
          <div v-else class="space-y-2">
            <label v-for="subject in allSubjects" :key="subject.id"
              class="flex items-center gap-3 p-3 rounded-lg border border-slate-200 hover:bg-slate-50 cursor-pointer transition-colors"
              :class="{ 'bg-teal-50 border-teal-300': selectedCourseSubjects.has(subject.id) }">
              <input type="checkbox" :checked="selectedCourseSubjects.has(subject.id)" @change="toggleSubject(subject.id)"
                class="h-4 w-4 text-teal-600 rounded">
              <span class="text-sm font-medium text-slate-800">{{ subject.name }}</span>
            </label>
          </div>
        </div>
        <div class="modal-footer">
          <button @click="showSubjectsModal = false" class="app-btn app-btn-ghost">Cancelar</button>
          <button @click="saveCourseSubjects" :disabled="subjectsSaving" class="app-btn app-btn-primary">
            {{ subjectsSaving ? 'Guardando...' : 'Guardar Materias' }}
          </button>
        </div>
      </div>
    </div>

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