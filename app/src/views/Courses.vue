<script setup>
import { ref, onMounted, nextTick, computed, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAcademicYearsQuery, useCoursesQuery } from '../composables/useQueries'
import { useNetwork } from '../composables/useNetwork'
import { useQueryClient } from '@tanstack/vue-query'
import { translateError } from '../lib/errorDictionary'
import { downloadStudentsTemplate } from '../lib/exportUtils'
import { useAuthStore } from '../stores/auth'
import { useAcademicYearStore } from '../stores/academicYear'
import { canManageAcademicYearLock } from '../lib/permissions'
import { toast } from 'vue-sonner'
import SkeletonTable from '../components/ui/SkeletonTable.vue'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'
import {
    validateStudentForm,
    isStudentComplete,
    getFileExt,
    uploadPhoto,
    createPhotoPreview
} from '../lib/studentUtils'

const queryClient = useQueryClient()
const authStore = useAuthStore()
const academicYearStore = useAcademicYearStore()
const { isOnline } = useNetwork()

const isYearLocked = computed(() => academicYearStore.isLocked)
const canManageLock = computed(() => canManageAcademicYearLock(authStore.accessContext, authStore.profile))

// Queries handled by composables, definitions below
const showModal = ref(false)
const showSubjectsModal = ref(false)
const editingCourse = ref(null)
const courseSaving = ref(false)
const courseSaveError = ref('')
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
  { value: 'BASICA', label: 'Básica' },
  { value: 'CIENCIAS', label: 'Ciencias' },
  { value: 'TECNICO', label: 'Técnico' }
]

const form = ref({
  name: '',
  academic_year: '',
  level: 'MEDIA',
  track: 'BASICA'
})

const academicYears = computed(() => academicYearStore.academicYears)
const selectedAcademicYear = computed({
  get: () => academicYearStore.selectedYearId,
  set: (val) => academicYearStore.setSelectedYearId(val)
})
const selectedAcademicYearName = computed(() => academicYearStore.selectedYearName)

const { data: coursesData, isLoading: loading, refetch: fetchCourses } = useCoursesQuery(selectedAcademicYearName)

const courses = computed(() => coursesData.value || [])

watch(selectedAcademicYearName, (newYearName) => {
  if (newYearName) {
    form.value.academic_year = newYearName
  }
}, { immediate: true })

const onAcademicYearChange = async () => {
  if (selectedAcademicYearName.value) {
    form.value.academic_year = selectedAcademicYearName.value
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
    toast.error('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (!newYearName.value?.trim()) {
    toast.error('Ingresa el nombre del año lectivo.')
    return
  }

  const nameStr = newYearName.value.trim()

  try {
    const newYear = await academicYearStore.createAcademicYear(nameStr)
    form.value.academic_year = nameStr
    closeNewYearModal()
    toast.success('Año lectivo creado. Ahora puedes copiar cursos del año anterior.')
    showCopyCoursesModal.value = true
    copyFromYear.value = academicYears.value.find(y => y.name !== nameStr)?.id || null
    await fetchCourses()
  } catch (error) {
    toast.error('Error creando año lectivo', { description: translateError(error) })
  }
}

const openCopyCoursesModal = () => {
  if (isYearLocked.value && !canManageLock.value) {
    toast.error('Año lectivo bloqueado', {
      description: 'Este año lectivo está protegido contra modificaciones. Solo el Rector o Administrador puede gestionarlo.'
    })
    return
  }
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
    toast.error('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (isYearLocked.value && !canManageLock.value) {
    toast.error('Año lectivo bloqueado', {
      description: 'No se pueden copiar cursos a un año lectivo protegido.'
    })
    return
  }
  if (!copyFromYear.value || !selectedAcademicYear.value) {
    toast.error('Selecciona el año lectivo de origen.')
    return
  }

  if (copyFromYear.value === selectedAcademicYear.value) {
    toast.error('El año lectivo de origen debe ser diferente al año lectivo actual.')
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

    copyResult.value = data || []
    await fetchCourses()
    await fetchAcademicYears()
    toast.success(`Se procesaron ${(data || []).length} curso(s) al nuevo año lectivo exitosamente.`)
  } catch (error) {
    toast.error('Error copiando cursos', { description: translateError(error) })
  } finally {
    copyingCourses.value = false
  }
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
  if (isYearLocked.value && !canManageLock.value) {
    toast.error('Año lectivo protegido', {
      description: 'No se pueden eliminar cursos en un ciclo bloqueado.'
    })
    return
  }
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
  if (isYearLocked.value && !canManageLock.value) {
    toast.error('Año lectivo protegido', {
      description: 'No se pueden eliminar cursos en un ciclo bloqueado.'
    })
    return
  }
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
  if (!courses.value || courses.value.length === 0) {
    showHeaderWarning('Crea los cursos primero con el botón "+ Nuevo Curso" para poder asignarles estudiantes.')
    return
  }
  let course = courses.value.find(c => c.id === importCourseId.value)
  if (!course) {
    course = courses.value[0]
    importCourseId.value = course.id
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

const sanitizeDate = (val) => {
  if (!val) return null
  if (val instanceof Date && !isNaN(val)) {
    return val.toISOString().split('T')[0]
  }
  const str = String(val).trim()
  if (!str) return null
  // Match YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) return str
  // Match DD/MM/YYYY or DD-MM-YYYY
  const parts = str.split(/[/.-]/)
  if (parts.length === 3) {
    if (parts[0].length === 4) {
      return `${parts[0]}-${parts[1].padStart(2, '0')}-${parts[2].padStart(2, '0')}`
    } else if (parts[2].length === 4) {
      return `${parts[2]}-${parts[1].padStart(2, '0')}-${parts[0].padStart(2, '0')}`
    }
  }
  return null
}

const triggerStudentImport = () => {
  importErrors.value = []
  importMessage.value = ''
  if (importFileInput.value) {
    importFileInput.value.value = ''
    importFileInput.value.click()
  }
}

const parseStudentExcel = async (file) => {
  let rawRows = []
  const fileName = file.name.toLowerCase()

  if (fileName.endsWith('.csv') || fileName.endsWith('.txt')) {
    const text = await file.text()
    // Remove UTF-8 BOM if present
    const cleanText = text.replace(/^\uFEFF/, '')
    const lines = cleanText.split(/\r\n|\n|\r/).filter(l => l.trim().length > 0)
    
    if (lines.length === 0) {
      return { entries: [], errors: ['El archivo CSV está vacío.'] }
    }

    // Auto-detect delimiter
    const sample = lines.slice(0, Math.min(5, lines.length)).join('\n')
    let delimiter = ','
    const commaCount = (sample.match(/,/g) || []).length
    const semiCount = (sample.match(/;/g) || []).length
    const tabCount = (sample.match(/\t/g) || []).length
    const pipeCount = (sample.match(/\|/g) || []).length
    if (semiCount > commaCount && semiCount > tabCount) delimiter = ';'
    else if (tabCount > commaCount && tabCount > semiCount) delimiter = '\t'
    else if (pipeCount > commaCount) delimiter = '|'

    rawRows = lines.map(line => {
      const row = []
      let current = ''
      let inQuotes = false
      for (let i = 0; i < line.length; i++) {
        const char = line[i]
        if (char === '"') {
          if (inQuotes && line[i + 1] === '"') {
            current += '"'
            i++
          } else {
            inQuotes = !inQuotes
          }
        } else if (char === delimiter && !inQuotes) {
          row.push(current.trim().replace(/^["']|["']$/g, ''))
          current = ''
        } else {
          current += char
        }
      }
      row.push(current.trim().replace(/^["']|["']$/g, ''))
      return row
    })
  } else {
    const { default: readXlsxFile } = await import('read-excel-file/browser')
    const result = await readXlsxFile(file)
    if (Array.isArray(result) && result.length > 0 && result[0] && typeof result[0] === 'object' && 'data' in result[0]) {
      rawRows = result[0].data || []
    } else if (Array.isArray(result)) {
      rawRows = result
    }
  }

  if (!rawRows || rawRows.length === 0) {
    return { entries: [], errors: ['El archivo seleccionado está vacío o no tiene formato válido.'] }
  }

  let headerIdx = -1
  let colName = -1, colCedula = -1, colBirth = -1, colPhone = -1, colAddress = -1
  let colRepName = -1, colRepCedula = -1, colRepPhone = -1, colRepAltPhone = -1

  for (let r = 0; r < Math.min(rawRows.length, 10); r++) {
    const row = rawRows[r]
    if (!Array.isArray(row)) continue
    
    let foundNameCol = false
    row.forEach((cell, cIdx) => {
      const h = normalizeHeader(cell)
      if (!h) return

      // Representative columns first
      if (h.includes('REPRESENTANTE') || h.includes('APODERADO') || h.includes('TUTOR') || h.includes('PADRE') || h.includes('MADRE')) {
        if (h.includes('CEDULA') || h.includes('DNI') || h.includes('IDENTIFICACION') || h.includes('DOC')) {
          colRepCedula = cIdx
        } else if (h.includes('ALT') || h.includes('OTRO') || h.includes('FIJO') || h.includes('CONVENCIONAL')) {
          colRepAltPhone = cIdx
        } else if (h.includes('TEL') || h.includes('CEL') || h.includes('MOVIL') || h.includes('WHATSAPP')) {
          colRepPhone = cIdx
        } else if (h.includes('NOMBRE') || h.includes('APELLIDO') || h.includes('COMPLETO')) {
          colRepName = cIdx
        }
      } else {
        // Student columns (MUTUALLY EXCLUSIVE via else-if!)
        if (h.includes('CEDULA') || h.includes('DNI') || h.includes('IDENTIFICACION') || h.includes('DOC')) {
          colCedula = cIdx
        } else if (h.includes('NACIMIENTO') || h.includes('FECHA') || h.includes('CUMPLE')) {
          colBirth = cIdx
        } else if (h.includes('TELEFONO') || h.includes('CELULAR') || h.includes('MOVIL') || h.includes('WHATSAPP') || h.includes('TEL')) {
          colPhone = cIdx
        } else if (h.includes('DIRECCION') || h.includes('DOMICILIO') || h.includes('RESIDENCIA') || h.includes('UBICACION')) {
          colAddress = cIdx
        } else if (h.includes('NOMBRE') || h.includes('APELLIDO') || h.includes('ESTUDIANTE') || h.includes('ALUMNO')) {
          colName = cIdx
          foundNameCol = true
        }
      }
    })

    if (foundNameCol || colName !== -1) {
      headerIdx = r
      break
    }
  }

  // Fallback: If no column named 'NOMBRE', scan rows for the column containing text with spaces (names)
  if (colName === -1) {
    for (let r = 0; r < rawRows.length; r++) {
      const row = rawRows[r]
      if (!Array.isArray(row)) continue
      for (let c = 0; c < row.length; c++) {
        const val = String(row[c] || '').trim()
        if (val && isNaN(Number(val)) && val.length > 5 && val.includes(' ')) {
          colName = c
          headerIdx = r > 0 ? r - 1 : 0
          break
        }
      }
      if (colName !== -1) break
    }
  }

  if (colName === -1) {
    return { entries: [], errors: ['No se encontró columna de NOMBRES COMPLETOS de estudiantes en el archivo.'] }
  }

  const entries = []
  const errors = []
  const startRow = headerIdx !== -1 ? headerIdx + 1 : 0

  for (let i = startRow; i < rawRows.length; i++) {
    const row = rawRows[i]
    if (!Array.isArray(row)) continue

    const name = colName !== -1 && row[colName] != null ? String(row[colName]).trim() : ''
    const cedula = colCedula !== -1 && row[colCedula] != null ? String(row[colCedula]).trim() : ''
    const birth = colBirth !== -1 && row[colBirth] != null ? sanitizeDate(row[colBirth]) : null
    const phone = colPhone !== -1 && row[colPhone] != null ? String(row[colPhone]).trim() : ''
    const address = colAddress !== -1 && row[colAddress] != null ? String(row[colAddress]).trim() : ''
    const repName = colRepName !== -1 && row[colRepName] != null ? String(row[colRepName]).trim() : ''
    const repCedula = colRepCedula !== -1 && row[colRepCedula] != null ? String(row[colRepCedula]).trim() : ''
    const repPhone = colRepPhone !== -1 && row[colRepPhone] != null ? String(row[colRepPhone]).trim() : ''
    const repAltPhone = colRepAltPhone !== -1 && row[colRepAltPhone] != null ? String(row[colRepAltPhone]).trim() : ''

    // Skip empty lines or pure index numbers
    if (!name || name.length < 2) continue
    if (!isNaN(Number(name)) && !name.includes(' ')) continue

    const upper = normalizeHeader(name)
    if (['NOMBRES', 'APELLIDOS', 'NOMBRES COMPLETOS', 'NOMBRES Y APELLIDOS', 'NO.', 'N°', 'NOMBRE', 'ESTUDIANTE'].includes(upper)) continue

    entries.push({
      full_name: name,
      student_cedula: cedula || null,
      student_birthdate: birth || null,
      student_phone: phone || '',
      student_address: address || '',
      representative_name: repName || '',
      representative_cedula: repCedula || '',
      representative_phone: repPhone || '',
      representative_alt_phone: repAltPhone || ''
    })
  }

  if (entries.length === 0) {
    return { entries: [], errors: ['No se detectaron filas de estudiantes válidas en el archivo.'] }
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
  if (file.size > 5 * 1024 * 1024) {
    importErrors.value = ['El archivo supera el límite de 5 MB.']
    return
  }
  try {
    const { entries, errors } = await parseStudentExcel(file)
    importPreview.value = entries || []
    importErrors.value = errors || []
    if (entries && entries.length > 0) {
      toast.info('Archivo procesado', { description: `Se detectaron ${entries.length} estudiantes listos para importar.` })
    }
  } catch (err) {
    importErrors.value = ['Error leyendo el archivo: ' + (err.message || 'Verifica el formato del archivo.')]
  }
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
    let sId = authStore.activeSchoolId || authStore.profile?.school_id || managingStudentsCourse.value?.school_id
    if (!sId) {
      const { data: cRow } = await supabase.from('courses').select('school_id').eq('id', courseId).single()
      if (cRow?.school_id) sId = cRow.school_id
    }
    const entries = importPreview.value

    // 1. Try atomic transactional RPC first
    const { data: rpcRes, error: rpcErr } = await supabase.rpc('import_students_batch', {
      p_course_id: courseId,
      p_entries: entries
    })

    if (!rpcErr && rpcRes) {
      await fetchCourseStudents(courseId)
      await queryClient.invalidateQueries({ queryKey: ['students'] })
      const count = rpcRes.inserted_count || entries.length
      importMessage.value = `¡Éxito! ${count} estudiantes procesados correctamente.`
      toast.success('Importación exitosa', { description: `Se importaron ${count} estudiantes.` })
      setTimeout(() => {
        importPreview.value = []
        importFile.value = null
      }, 1500)
      return
    }

    // 2. Fallback to direct batch upsert
    const cedulas = entries.map(e => e.student_cedula).filter(Boolean)
    let existingMap = new Map()

    if (cedulas.length > 0) {
      let checkQ = supabase
        .from('students')
        .select('id, student_cedula')
        .eq('course_id', courseId)
        .in('student_cedula', cedulas)
      if (sId) checkQ = checkQ.eq('school_id', sId)
      const { data, error } = await checkQ
      if (error) throw error
      ;(data || []).forEach(s => {
        existingMap.set(s.student_cedula, s.id)
      })
    }

    const toInsert = []
    const toUpdate = []
    entries.forEach(e => {
      if (e.student_cedula && existingMap.has(e.student_cedula)) {
        toUpdate.push({
          id: existingMap.get(e.student_cedula),
          full_name: e.full_name,
          student_birthdate: e.student_birthdate,
          student_phone: e.student_phone,
          student_address: e.student_address,
          representative_name: e.representative_name,
          representative_cedula: e.representative_cedula,
          representative_phone: e.representative_phone,
          representative_alt_phone: e.representative_alt_phone
        })
      } else {
        toInsert.push({
          full_name: e.full_name,
          student_cedula: e.student_cedula,
          student_birthdate: e.student_birthdate,
          student_phone: e.student_phone,
          student_address: e.student_address,
          representative_name: e.representative_name,
          representative_cedula: e.representative_cedula,
          representative_phone: e.representative_phone,
          representative_alt_phone: e.representative_alt_phone,
          course_id: courseId,
          school_id: sId
        })
      }
    })

    if (toInsert.length > 0) {
      const { error } = await supabase.from('students').insert(toInsert)
      if (error) throw error
    }

    for (const upd of toUpdate) {
      const { id, ...rest } = upd
      const { error } = await supabase.from('students').update(rest).eq('id', id)
      if (error) throw error
    }

    await fetchCourseStudents(courseId)
    await queryClient.invalidateQueries({ queryKey: ['students'] })
    importMessage.value = `¡Éxito! ${toInsert.length} estudiantes nuevos creados y ${toUpdate.length} actualizados.`
    toast.success('Importación completada', { description: `${toInsert.length} creados, ${toUpdate.length} actualizados.` })
    setTimeout(() => {
      importPreview.value = []
      importFile.value = null
    }, 1500)
  } catch (err) {
    importMessage.value = 'Error al importar estudiantes: ' + err.message
    toast.error('Error en importación', { description: err.message })
  } finally {
    importing.value = false
  }
}

// --- Course CRUD ---
const isDuplicateCourseName = computed(() => {
  const trimmed = form.value.name?.trim().toLowerCase()
  if (!trimmed) return false
  const targetYear = form.value.academic_year
  return (courses.value || []).some(c => 
    c.name?.trim().toLowerCase() === trimmed &&
    c.academic_year === targetYear &&
    (!editingCourse.value || c.id !== editingCourse.value.id)
  )
})

const openModal = (course = null) => {
  if (isYearLocked.value && !canManageLock.value) {
    toast.error('Año lectivo bloqueado', {
      description: 'Este año lectivo está protegido contra modificaciones. Solo el Rector o Administrador puede gestionarlo.'
    })
    return
  }
  showModal.value = true
  editingCourse.value = course
  courseSaveError.value = ''
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
  courseSaveError.value = ''
}

const saveCourse = async () => {
  if (!isOnline.value) {
    toast.error('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (isYearLocked.value && !canManageLock.value) {
    toast.error('Año lectivo bloqueado', {
      description: 'No se pueden guardar cursos en un año lectivo protegido.'
    })
    return
  }
  const trimmedName = form.value.name?.trim()
  if (!trimmedName) {
    courseSaveError.value = 'El nombre del curso es obligatorio.'
    toast.error('El nombre del curso es obligatorio.')
    return
  }

  const targetAcademicYear = form.value.academic_year
  if (!targetAcademicYear) {
    courseSaveError.value = 'El año lectivo es obligatorio.'
    toast.error('El año lectivo es obligatorio.')
    return
  }

  // 1. Verificación en memoria
  if (isDuplicateCourseName.value) {
    const friendlyMsg = `Ya existe un curso registrado con el nombre "${trimmedName}" en el año lectivo ${targetAcademicYear}. Por favor, elige un nombre diferente.`
    courseSaveError.value = friendlyMsg
    toast.error('Curso ya existente', { description: friendlyMsg })
    return
  }

  courseSaving.value = true
  courseSaveError.value = ''

  try {
    const sId = authStore.activeSchoolId || authStore.profile?.school_id

    // 2. Verificación defensiva en base de datos
    let dupQuery = supabase
      .from('courses')
      .select('id, name')
      .ilike('name', trimmedName)
      .eq('academic_year', targetAcademicYear)

    if (sId) {
      dupQuery = dupQuery.eq('school_id', sId)
    }
    if (editingCourse.value) {
      dupQuery = dupQuery.neq('id', editingCourse.value.id)
    }

    const { data: duplicateDb, error: dupCheckErr } = await dupQuery
    if (dupCheckErr) throw dupCheckErr

    if (duplicateDb && duplicateDb.length > 0) {
      const friendlyMsg = `Ya existe un curso registrado con el nombre "${duplicateDb[0].name}" en el año lectivo ${targetAcademicYear}.`
      courseSaveError.value = friendlyMsg
      toast.error('Curso ya existente', { description: friendlyMsg })
      return
    }

    if (editingCourse.value) {
      const { error } = await supabase
        .from('courses')
        .update({
          name: trimmedName,
          academic_year: form.value.academic_year,
          level: form.value.level,
          track: form.value.track
        })
        .eq('id', editingCourse.value.id)
      if (error) throw error
      toast.success('Curso actualizado correctamente.')
      await fetchCourses()
      closeModal()
    } else {
      const { data, error } = await supabase
        .from('courses')
        .insert({
          name: trimmedName,
          academic_year: form.value.academic_year,
          level: form.value.level,
          track: form.value.track,
          school_id: sId
        })
        .select()
        .single()
      if (error) throw error
      await fetchCourses()
      closeModal()
      toast.success(`Curso "${data.name}" creado con éxito. Ya puedes cargar o registrar sus estudiantes.`)
      // Abrir automáticamente la gestión de estudiantes para el curso recién creado
      openStudentsModal(data)
    }
  } catch (e) {
    const friendlyMsg = translateError(e)
    courseSaveError.value = friendlyMsg
    toast.error('Error guardando curso', { description: friendlyMsg })
  } finally {
    courseSaving.value = false
  }
}

const deleteCourse = async (id) => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (isYearLocked.value && !canManageLock.value) {
    toast.error('Año lectivo protegido', {
      description: 'No se pueden eliminar cursos en un ciclo bloqueado.'
    })
    return
  }
  if (!confirm('¿Estás seguro de eliminar este curso? Se eliminarán también sus materias asociadas y estudiantes.')) return
  try {
    const { error } = await supabase.from('courses').delete().eq('id', id)
    if (error) throw error
    await fetchCourses()
  } catch (e) {
    alert('Error eliminando curso: ' + e.message)
  }
}

// --- Manage Subjects Logic ---
const subjectsLoading = ref(false)
const creatingBaseSubjects = ref(false)

const fetchAllSubjects = async () => {
  subjectsLoading.value = true
  subjectsMessage.value = ''
  try {
    let sId = authStore.activeSchoolId || authStore.profile?.school_id || managingCourse.value?.school_id
    if (!sId && managingCourse.value?.id) {
      const { data: cData } = await supabase.from('courses').select('school_id').eq('id', managingCourse.value.id).single()
      if (cData?.school_id) sId = cData.school_id
    }

    let query = supabase
      .from('subjects')
      .select('*')
      .order('name', { ascending: true })

    if (sId) {
      query = query.or(`school_id.eq.${sId},school_id.is.null`)
    }

    const { data, error } = await query
    if (error) throw error
    allSubjects.value = data || []
  } catch (err) {
    subjectsMessage.value = 'Error al cargar asignaturas: ' + err.message
    allSubjects.value = []
  } finally {
    subjectsLoading.value = false
  }
}

const createDefaultSubjectsForInstitution = async () => {
  let sId = authStore.activeSchoolId || authStore.profile?.school_id || managingCourse.value?.school_id
  if (!sId && managingCourse.value?.id) {
    const { data: cData } = await supabase.from('courses').select('school_id').eq('id', managingCourse.value.id).single()
    if (cData?.school_id) sId = cData.school_id
  }
  if (!sId) {
    subjectsMessage.value = 'Error: no se detectó el identificador de la institución.'
    return
  }

  creatingBaseSubjects.value = true
  subjectsMessage.value = ''

  const baseSubjects = [
    'Lengua y Literatura',
    'Matemática',
    'Ciencias Naturales',
    'Estudios Sociales',
    'Educación Cultural y Artística',
    'Educación Física',
    'Inglés',
    'Proyectos Escolares / Interdisciplinarios'
  ]

  try {
    const toInsert = baseSubjects.map(name => ({
      name,
      school_id: sId
    }))

    const { error } = await supabase.from('subjects').insert(toInsert)
    if (error) throw error

    await queryClient.invalidateQueries({ queryKey: ['subjects'] })
    await fetchAllSubjects()
    selectedCourseSubjects.value = new Set(allSubjects.value.map(s => s.id))
    toast.success('Asignaturas base creadas', { description: 'Se han creado las asignaturas estándar para la institución.' })
  } catch (err) {
    subjectsMessage.value = 'Error creando asignaturas: ' + err.message
    toast.error('Error al crear materias', { description: err.message })
  } finally {
    creatingBaseSubjects.value = false
  }
}

const selectAllSubjects = () => {
  allSubjects.value.forEach(s => selectedCourseSubjects.value.add(s.id))
}

const institutionTeachers = ref([])
const courseSubjectTeachers = ref({})

const fetchInstitutionTeachers = async () => {
  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!sId) return
  const { data } = await supabase
    .from('profiles')
    .select('id, full_name, email, role')
    .eq('school_id', sId)
    .in('role', ['teacher', 'docente'])
    .order('full_name')
  institutionTeachers.value = data || []
}

const deselectAllSubjects = () => {
  selectedCourseSubjects.value.clear()
}

const openSubjectsModal = async (course) => {
  if (isYearLocked.value && !canManageLock.value) {
    toast.error('Año lectivo protegido', {
      description: 'No se pueden reasignar materias o docentes en un ciclo lectivo bloqueado.'
    })
    return
  }
  managingCourse.value = course
  showSubjectsModal.value = true
  subjectsMessage.value = ''
  selectedCourseSubjects.value = new Set()
  courseSubjectTeachers.value = {}

  await Promise.all([
    fetchAllSubjects(),
    fetchInstitutionTeachers()
  ])

  try {
    const { data, error } = await supabase
      .from('course_subjects')
      .select('subject_id, teacher_id')
      .eq('course_id', course.id)
    if (error) throw error
    selectedCourseSubjects.value = new Set(data?.map(cs => cs.subject_id) || [])
    const map = {}
    ;(data || []).forEach(cs => {
      if (cs.teacher_id) {
        map[cs.subject_id] = cs.teacher_id
      }
    })
    courseSubjectTeachers.value = map
  } catch (err) {
    subjectsMessage.value = 'Error al cargar asignaciones: ' + err.message
  }
}

const toggleSubject = (subjectId) => {
  if (selectedCourseSubjects.value.has(subjectId)) {
    selectedCourseSubjects.value.delete(subjectId)
    delete courseSubjectTeachers.value[subjectId]
  } else {
    selectedCourseSubjects.value.add(subjectId)
  }
}

const saveCourseSubjects = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  if (isYearLocked.value && !canManageLock.value) {
    toast.error('Año lectivo protegido', {
      description: 'No se pueden modificar asignaciones en un ciclo bloqueado.'
    })
    return
  }
  if (!managingCourse.value?.id) return
  subjectsSaving.value = true
  subjectsMessage.value = ''

  try {
    const courseId = managingCourse.value.id
    const sId = authStore.activeSchoolId || authStore.profile?.school_id || managingCourse.value?.school_id
    const assignmentsPayload = Array.from(selectedCourseSubjects.value).map(sid => ({
      subject_id: sid,
      teacher_id: courseSubjectTeachers.value[sid] || null
    }))

    const { error: rpcErr } = await supabase.rpc('save_course_subject_assignments', {
      p_course_id: courseId,
      p_assignments: assignmentsPayload
    })

    if (rpcErr) {
      const { error: syncErr } = await supabase.rpc('sync_course_subject_assignments', {
        p_course_id: courseId,
        p_assignments: assignmentsPayload
      })
      if (syncErr) {
        const insertData = assignmentsPayload.map(a => ({
          course_id: courseId,
          subject_id: a.subject_id,
          teacher_id: a.teacher_id,
          school_id: sId || null
        }))
        const { error } = await supabase.from('course_subjects').upsert(insertData, { onConflict: 'course_id, subject_id' })
        if (error) throw error
      }
    }

    await queryClient.invalidateQueries({ queryKey: ['courses'] })
    await queryClient.invalidateQueries({ queryKey: ['subjects'] })
    toast.success('Asignaciones guardadas', {
      description: `Se han configurado ${assignmentsPayload.length} materias con sus docentes en el curso.`
    })
    showSubjectsModal.value = false
  } catch (err) {
    subjectsMessage.value = 'Error guardando materias: ' + err.message
    toast.error('Error al guardar', { description: err.message })
  } finally {
    subjectsSaving.value = false
  }
}
</script>

<template>
  <div class="app-shell">
    <main class="app-container">
      <div class="px-2 sm:px-0">
        <!-- Academic Year Banner -->
        <AcademicYearBanner module-name="Cursos" />

        <div class="flex justify-between items-center mb-6 flex-wrap gap-4">
          <h1 class="app-title">Gestión de Cursos</h1>
          <div class="flex flex-wrap gap-2 items-center">
            <select v-model="selectedAcademicYear" @change="onAcademicYearChange" class="app-input w-48">
              <option v-for="year in academicYears" :key="year.id" :value="year.id">
                {{ year.name }} {{ year.is_current ? '(Actual)' : '' }}
              </option>
            </select>

            <template v-if="isAdmin">
              <button 
                @click="openNewYearModal" 
                :disabled="isYearLocked && !canManageLock"
                class="app-btn app-btn-ghost text-sm disabled:opacity-50 disabled:cursor-not-allowed"
              >
                + Nuevo Año
              </button>
              <button 
                @click="openCopyCoursesModal" 
                :disabled="isYearLocked && !canManageLock"
                class="app-btn app-btn-ghost text-sm disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Copiar Cursos
              </button>

              <span class="border-l border-slate-300 dark:border-slate-700 h-6"></span>

              <button 
                type="button" 
                @click="downloadStudentsTemplate" 
                class="app-btn app-btn-ghost text-sm flex items-center gap-1.5"
                title="Descargar plantilla oficial en formato CSV para registrar estudiantes"
              >
                📥 Plantilla Estudiantes (.CSV)
              </button>
              <button 
                @click="deleteSelectedCourses" 
                :disabled="isYearLocked && !canManageLock"
                class="app-btn app-btn-ghost text-sm disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Eliminar Seleccionados
              </button>
              <button 
                @click="deleteAllCourses" 
                :disabled="isYearLocked && !canManageLock"
                class="app-btn app-btn-ghost text-sm disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Eliminar Todos
              </button>
              <button 
                @click="openModal()" 
                :disabled="isYearLocked && !canManageLock"
                class="app-btn app-btn-primary text-sm disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1.5"
              >
                <span v-if="isYearLocked">🔒</span>
                <span>+ Nuevo Curso</span>
              </button>
            </template>
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
                <th v-if="isAdmin" class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                  <input type="checkbox" :checked="isAllCoursesSelected()" @change="toggleAllCourses" :disabled="isYearLocked && !canManageLock" />
                </th>
                <th class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Nombre</th>
                <th class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Año Lectivo</th>
                <th class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Nivel</th>
                <th class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Itinerario</th>
                <th class="text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">Acciones</th>
              </tr>
            </thead>
            <TransitionGroup name="list" tag="tbody">
              <tr v-if="loading" key="loading" class="!bg-transparent">
                <td :colspan="isAdmin ? 6 : 5" class="p-0 border-0">
                  <SkeletonTable :rows="4" :columns="isAdmin ? 6 : 5" class="border-0 rounded-none shadow-none" />
                </td>
              </tr>
              <tr v-else-if="courses.length === 0" key="empty">
                <td :colspan="isAdmin ? 6 : 5" class="text-center text-sm text-slate-500 py-12">
                  No hay cursos asignados en este año lectivo.
                  <button v-if="isAdmin" @click="openCopyCoursesModal" class="text-teal-600 hover:text-teal-800 ml-2 font-medium">
                    Copiar cursos de otro año
                  </button>
                </td>
              </tr>
              <tr v-else v-for="course in courses" :key="course.id" class="hover:bg-slate-100 dark:hover:bg-slate-800/50 transition-colors">
                <td v-if="isAdmin">
                  <input type="checkbox" :checked="selectedCourseIds.has(course.id)" @change="toggleCourseSelection(course.id)" :disabled="isYearLocked && !canManageLock" />
                </td>
                <td class="text-sm font-semibold text-slate-900">{{ course.name }}</td>
                <td class="text-sm text-slate-600">{{ course.academic_year }}</td>
                <td class="text-sm text-slate-600">{{ course.level || '-' }}</td>
                <td class="text-sm text-slate-600">{{ course.track || '-' }}</td>
                <td class="text-right text-sm font-medium whitespace-nowrap">
                  <button @click="openStudentsModal(course)" class="text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 mr-4 transition-colors font-semibold">
                    Estudiantes
                  </button>
                  <template v-if="isAdmin">
                    <button 
                      @click="openImportModal(course)" 
                      :disabled="isYearLocked && !canManageLock"
                      class="text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 mr-4 transition-colors font-semibold disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      📥 Importar Estudiantes (.CSV)
                    </button>
                    <button 
                      @click="openSubjectsModal(course)" 
                      :disabled="isYearLocked && !canManageLock"
                      class="text-emerald-600 hover:text-emerald-800 dark:text-emerald-400 dark:hover:text-emerald-300 mr-4 transition-colors font-semibold disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      Asignar Materias
                    </button>
                    <button 
                      @click="openModal(course)" 
                      :disabled="isYearLocked && !canManageLock"
                      class="text-amber-600 hover:text-amber-800 dark:text-amber-400 dark:hover:text-amber-300 mr-4 transition-colors font-semibold disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      Editar
                    </button>
                    <button 
                      @click="deleteCourse(course.id)" 
                      :disabled="isYearLocked && !canManageLock"
                      class="text-rose-600 hover:text-rose-800 dark:text-rose-400 dark:hover:text-rose-300 transition-colors font-semibold disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      Eliminar
                    </button>
                  </template>
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
              Crear Nuevo Año Lectivo
            </h3>
            <div class="mt-4">
              <p class="text-sm text-slate-500 mb-4">
                Los años lectivos permiten mantener un historial de todos los cursos y calificaciones.
                Cada año es independiente de los demás.
              </p>
              <input v-model="newYearName" type="text" class="app-input w-full" placeholder="Ej: 2026-2027" />
              <p class="text-xs text-slate-400 mt-2">
                Formato: YYYY-YYYY (Año inicio - Año fin)
              </p>
            </div>
          </div>
          <div class="modal-footer">
            <button @click="createNewAcademicYear" class="app-btn app-btn-primary w-full sm:w-auto">
              Crear Año Lectivo
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
              Copiar Cursos de Otro Año Lectivo
            </h3>
            <div class="mt-4">
              <p class="text-sm text-slate-500 mb-4">
                Copia los cursos de un año lectivo anterior al año actual.
                Las materias de cada curso también se copian.
              </p>
              <select v-model="copyFromYear" class="app-input w-full">
                <option :value="null">Selecciona el año lectivo de origen</option>
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
          <div v-if="courseSaveError" class="mb-4 p-3 bg-rose-50 border border-rose-200 rounded-xl text-xs text-rose-700 font-medium flex items-center gap-2 shadow-sm">
            <span class="text-rose-500 font-bold shrink-0">⚠</span>
            <span>{{ courseSaveError }}</span>
          </div>

          <div class="modal-field">
            <label class="modal-label">Nombre del Curso *</label>
            <input 
              v-model="form.name" 
              type="text" 
              class="app-input"
              :class="{ 'border-rose-400 focus:border-rose-500 focus:ring-rose-500': isDuplicateCourseName }"
              placeholder="Ej: 1ro Bachillerato A"
              @input="courseSaveError = ''"
            >
            <p v-if="isDuplicateCourseName" class="text-xs text-rose-600 font-semibold mt-1">
              ⚠ Ya existe un curso registrado con este nombre en este año lectivo.
            </p>
          </div>
          <div class="modal-field">
            <label class="modal-label">Año Lectivo</label>
            <input v-model="form.academic_year" type="text" class="app-input bg-slate-100 dark:bg-slate-800/80 cursor-not-allowed" readonly>
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
          <button @click="closeModal" :disabled="courseSaving" class="app-btn app-btn-ghost">Cancelar</button>
          <button @click="saveCourse" :disabled="courseSaving || isDuplicateCourseName" class="app-btn app-btn-primary disabled:opacity-50">
            <svg v-if="!courseSaving" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
            {{ courseSaving ? 'Guardando...' : 'Guardar' }}
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
          <div class="flex flex-wrap gap-2 mb-4 items-center justify-between">
            <div class="flex flex-wrap gap-2 items-center">
              <button @click="openStudentModal()" class="app-btn app-btn-primary text-sm">+ Nuevo Estudiante</button>
              <button @click="triggerStudentImport" class="app-btn app-btn-ghost text-sm flex items-center gap-1.5">
                📥 Subir Estudiantes (.CSV)
              </button>
              <input 
                ref="importFileInput" 
                type="file" 
                accept=".csv,.xlsx,.xls,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel" 
                @change="onImportFileChange" 
                class="sr-only" 
                style="position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0)"
              >
            </div>
            <button 
              type="button" 
              @click="downloadStudentsTemplate" 
              class="px-3 py-1.5 text-xs font-bold bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg transition-colors flex items-center gap-1.5 cursor-pointer shadow-sm"
              title="Descargar plantilla oficial de estudiantes con formato CSV"
            >
              📥 Descargar Plantilla CSV
            </button>
          </div>

          <!-- Import Preview -->
          <div v-if="importPreview.length > 0" class="mb-4 p-4 bg-indigo-50 dark:bg-indigo-950/40 border border-indigo-200 dark:border-indigo-800/60 rounded-xl shadow-sm">
            <div class="flex items-center justify-between mb-2">
              <p class="text-sm font-bold text-indigo-950 dark:text-indigo-200">
                Vista previa: {{ importPreview.length }} estudiantes detectados
              </p>
              <span class="text-xs px-2.5 py-0.5 rounded-full font-bold bg-indigo-100 dark:bg-indigo-900 text-indigo-700 dark:text-indigo-300">
                Listo para procesar
              </span>
            </div>

            <div class="max-h-36 overflow-y-auto mb-3 text-xs divide-y divide-indigo-100 dark:divide-indigo-900/50 bg-white/80 dark:bg-slate-900/80 rounded-lg p-2.5 border border-indigo-100 dark:border-indigo-900/40">
              <div v-for="(stu, idx) in importPreview.slice(0, 8)" :key="idx" class="py-1 flex items-center justify-between gap-2">
                <span class="font-medium text-slate-800 dark:text-slate-200">{{ idx + 1 }}. {{ stu.full_name }}</span>
                <span class="text-slate-500 font-mono text-[11px]">{{ stu.student_cedula || 'Sin cédula' }}</span>
              </div>
              <div v-if="importPreview.length > 8" class="pt-1.5 text-center text-slate-400 font-medium italic">
                ... y {{ importPreview.length - 8 }} estudiantes más
              </div>
            </div>

            <div v-if="importErrors.length > 0" class="text-xs text-rose-600 dark:text-rose-400 mb-2">
              <p v-for="(err, i) in importErrors" :key="i">⚠ {{ err }}</p>
            </div>

            <div class="flex gap-2">
              <button @click="importStudentsFromExcel" :disabled="importing" class="app-btn app-btn-primary text-sm flex items-center gap-1.5">
                <span v-if="importing" class="app-spinner w-3.5 h-3.5"></span>
                <span>{{ importing ? 'Importando...' : 'Confirmar Importación' }}</span>
              </button>
              <button @click="importFile = null; importPreview = []; importErrors = []; importMessage = ''" class="app-btn app-btn-ghost text-sm">
                Cancelar
              </button>
            </div>
            <p v-if="importMessage" class="text-xs mt-2 font-medium" :class="importMessage.includes('Error') ? 'text-rose-600 dark:text-rose-400' : 'text-emerald-600 dark:text-emerald-400'">
              {{ importMessage }}
            </p>
          </div>

          <div v-else-if="importErrors.length > 0" class="mb-4 p-3 bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800/60 rounded-xl text-xs text-rose-600 dark:text-rose-400 space-y-1">
            <p v-for="(err, i) in importErrors" :key="i" class="font-medium">⚠ {{ err }}</p>
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
              <img v-if="studentPhotoPreview" :src="studentPhotoPreview" alt="Foto del estudiante" class="h-16 w-16 rounded-lg object-cover mt-2 border">
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
              <img v-if="representativePhotoPreview" :src="representativePhotoPreview" alt="Foto del representante" class="h-16 w-16 rounded-lg object-cover mt-2 border">
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
      <div class="modal-panel modal-panel-lg">
        <div class="modal-header modal-header-accent">
          <h3 class="modal-title" style="color:#fff">Asignar Materias - {{ managingCourse?.name }}</h3>
          <p class="modal-subtitle">Selecciona las materias que forman parte de la malla de este curso.</p>
        </div>
        <div class="modal-body" style="max-height:55vh;overflow-y:auto">
          <!-- Selection Controls Bar -->
          <div v-if="allSubjects.length > 0" class="flex flex-wrap items-center justify-between gap-2 pb-3 mb-3 border-b border-slate-200 dark:border-slate-800">
            <span class="text-xs font-semibold text-slate-600 dark:text-slate-400">
              {{ selectedCourseSubjects.size }} de {{ allSubjects.length }} materias seleccionadas
            </span>
            <div class="flex items-center gap-2">
              <button 
                type="button" 
                @click="selectAllSubjects" 
                class="px-2.5 py-1 text-xs font-medium text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 rounded-lg hover:bg-teal-100 transition-colors"
              >
                Seleccionar Todas
              </button>
              <button 
                type="button" 
                @click="deselectAllSubjects" 
                class="px-2.5 py-1 text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-100 dark:bg-slate-800 rounded-lg hover:bg-slate-200 transition-colors"
              >
                Deseleccionar
              </button>
            </div>
          </div>

          <p v-if="subjectsMessage" class="text-sm mb-3 font-medium" :class="subjectsMessage.includes('Error') ? 'text-rose-600 dark:text-rose-400' : 'text-emerald-600 dark:text-emerald-400'">
            {{ subjectsMessage }}
          </p>

          <div v-if="subjectsLoading" class="text-center py-8">
            <span class="app-spinner mr-2"></span>
            <span class="text-sm text-slate-500">Cargando asignaturas disponibles...</span>
          </div>

          <div v-else-if="allSubjects.length === 0" class="text-center py-6 px-4 bg-slate-50 dark:bg-slate-900/60 rounded-2xl border border-slate-200 dark:border-slate-800 space-y-3">
            <div class="w-12 h-12 rounded-2xl bg-amber-100 dark:bg-amber-900/40 text-amber-600 dark:text-amber-300 mx-auto flex items-center justify-center text-xl font-bold">
              📚
            </div>
            <div>
              <p class="text-sm font-bold text-slate-800 dark:text-slate-200">No hay asignaturas registradas en la institución</p>
              <p class="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
                Puedes generar las 8 materias base del currículo ecuatoriano en un clic o gestionarlas en la sección de Asignaturas.
              </p>
            </div>
            <div class="pt-2">
              <button 
                type="button" 
                @click="createDefaultSubjectsForInstitution" 
                :disabled="creatingBaseSubjects"
                class="app-btn app-btn-primary text-xs font-bold px-4 py-2"
              >
                <span v-if="creatingBaseSubjects" class="app-spinner w-3.5 h-3.5 mr-1.5"></span>
                <span>{{ creatingBaseSubjects ? 'Creando materias...' : '⚡ Crear 8 Asignaturas Base Automáticas' }}</span>
              </button>
            </div>
          </div>

          <div v-else class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div 
              v-for="subject in allSubjects" 
              :key="subject.id"
              class="flex flex-col p-3 rounded-xl border border-slate-200 dark:border-slate-800 transition-all shadow-sm"
              :class="{ 'bg-teal-50/80 dark:bg-teal-950/40 border-teal-300 dark:border-teal-800/80 ring-1 ring-teal-500/20': selectedCourseSubjects.has(subject.id), 'hover:bg-slate-50 dark:hover:bg-slate-800/60': !selectedCourseSubjects.has(subject.id) }"
            >
              <label class="flex items-center gap-3 cursor-pointer select-none">
                <input 
                  type="checkbox" 
                  :checked="selectedCourseSubjects.has(subject.id)" 
                  @change="toggleSubject(subject.id)"
                  class="h-4 w-4 text-teal-600 rounded border-slate-300 focus:ring-teal-500 cursor-pointer"
                >
                <div class="flex-1 min-w-0">
                  <span class="text-sm font-semibold text-slate-900 dark:text-slate-100 block truncate">{{ subject.name }}</span>
                  <span v-if="subject.is_project_subject" class="text-[10px] font-bold uppercase tracking-wider text-indigo-600 dark:text-indigo-400">
                    Interdisciplinario
                  </span>
                </div>
              </label>

              <!-- Asignación de Docente -->
              <div v-if="selectedCourseSubjects.has(subject.id)" class="mt-2.5 pt-2 border-t border-teal-200/80 dark:border-teal-800/60 flex items-center gap-2">
                <span class="text-[11px] font-bold text-slate-500 dark:text-slate-400 shrink-0">Docente:</span>
                <select 
                  v-model="courseSubjectTeachers[subject.id]"
                  class="text-xs py-1 px-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 flex-1 focus:ring-1 focus:ring-teal-500 shadow-sm"
                >
                  <option :value="null">-- Sin docente asignado --</option>
                  <option v-for="t in institutionTeachers" :key="t.id" :value="t.id">
                    {{ t.full_name || t.email }}
                  </option>
                </select>
              </div>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button @click="showSubjectsModal = false" class="app-btn app-btn-ghost">Cancelar</button>
          <button @click="saveCourseSubjects" :disabled="subjectsSaving || subjectsLoading" class="app-btn app-btn-primary flex items-center gap-1.5">
            <span v-if="subjectsSaving" class="app-spinner w-3.5 h-3.5"></span>
            <span>{{ subjectsSaving ? 'Guardando...' : 'Guardar Materias' }}</span>
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