import { ref, reactive, computed, watch, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useAcademicYearStore } from '../stores/academicYear'
import { isInstitutionAdmin } from '../lib/permissions'
import { translateError } from '../lib/errorDictionary'
import { toast } from 'vue-sonner'
import { 
  ATTENDANCE_STATUSES, 
  HOUR_BLOCKS, 
  calculateStudentAttendanceStats, 
  buildAttendanceWhatsAppMessage 
} from '../lib/attendanceConstants'
import { normalizeStoragePath, resolvePrivateImageUrl } from '../lib/storageUtils'
import { institutionalDateKey } from '../lib/civilDate'

export function useAttendance() {
  const authStore = useAuthStore()
  const academicYearStore = useAcademicYearStore()

  // General State
  const activeTab = ref('roll_call') // 'roll_call' | 'justifications' | 'monthly_grid' | 'alerts'
  const loading = ref(false)
  const saving = ref(false)
  const courses = ref([])
  const quarters = ref([])
  const availableSubjects = ref([])
  const institutionConfig = ref({})

  // Roll-Call Filters & Form
  const selectedCourse = ref('')
  const selectedSubject = ref('')
  const initialDate = institutionalDateKey()
  const selectedDate = ref(initialDate)
  const selectedHourBlock = ref('jornada_completa')

  // Roll-Call Data
  const students = ref([])
  let rollCallRequest = 0
  let loadedRollCallKey = null
  const rollCallContextKey = () => JSON.stringify([
    authStore.activeSchoolId || authStore.profile?.school_id, authStore.user?.id,
    academicYearStore.selectedYearName, selectedCourse.value, selectedSubject.value,
    selectedDate.value, selectedHourBlock.value,
  ])
  const rollCallState = reactive({}) // { [studentId]: { status: 'presente', observations: '' } }

  // Justifications State
  const justificationSearch = ref('')
  const selectedJustificationStudent = ref(null)
  const studentUnexcusedAbsences = ref([])
  const selectedDatesToJustify = ref([])
  const justificationReason = ref('')
  const justifyingLoading = ref(false)

  // Monthly Grid State
  const gridMonth = ref(initialDate.slice(0, 7)) // YYYY-MM
  const gridCourseId = ref('')
  const gridDays = ref([])
  const gridMatrix = ref([]) // array of { student, daysMap: { 'YYYY-MM-DD': status }, stats }
  const gridLoading = ref(false)

  // Alerts State
  const atRiskStudents = ref([])
  const alertsLoading = ref(false)

  const isAdmin = computed(() => isInstitutionAdmin(authStore.accessContext))

  // Live Roll-Call Stats
  const rollCallStats = computed(() => {
    let present = 0
    let late = 0
    let unexcused = 0
    let excused = 0
    let truant = 0

    students.value.forEach(s => {
      const entry = rollCallState[s.id]
      const status = entry?.status || 'presente'
      if (status === 'presente') present++
      else if (status === 'atraso') late++
      else if (status === 'falta_injustificada') unexcused++
      else if (status === 'falta_justificada') excused++
      else if (status === 'fuga') truant++
    })

    return {
      total: students.value.length,
      present,
      late,
      unexcused,
      excused,
      truant
    }
  })

  // Data Fetching
  const fetchInstitutionConfig = async () => {
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!sId) return
    const [{ data }, { data: school }] = await Promise.all([
      supabase.from('system_config').select('key, value').eq('school_id', sId)
        .in('key', ['institution_name', 'institution_logo_url']),
      supabase.from('schools').select('timezone').eq('id', sId).maybeSingle(),
    ])

    const map = Object.fromEntries((data || []).map(i => [i.key, i.value]))
    map.timezone = school?.timezone
    const institutionToday = institutionalDateKey(new Date(), map.timezone)
    // Keep a date/month already selected by the teacher while config was loading.
    if (selectedDate.value === initialDate) selectedDate.value = institutionToday
    if (gridMonth.value === initialDate.slice(0, 7)) gridMonth.value = institutionToday.slice(0, 7)
    map.institution_logo_url = await resolvePrivateImageUrl(
      supabase,
      'institution-assets',
      normalizeStoragePath(map.institution_logo_url, 'institution-assets')
    ).catch(() => '')
    institutionConfig.value = map
  }

  const fetchCourses = async () => {
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!sId) {
      courses.value = []
      selectedCourse.value = ''
      gridCourseId.value = ''
      return
    }
    let query = supabase.from('courses').select('id, name, level, track, academic_year').order('name')
    query = query.eq('school_id', sId)
    const yearName = academicYearStore.selectedYearName
    if (yearName) {
      query = query.eq('academic_year', yearName)
    }
    const { data, error } = await query
    if (error) throw error
    let filteredCourses = data || []

    const userIds = [authStore.user?.id, authStore.profile?.id].filter(Boolean)
    if (!isAdmin.value && userIds.length > 0) {
      const { data: assignedLinks, error: assignedLinksError } = await supabase
        .from('course_subjects')
        .select('course_id')
        .eq('school_id', sId)
        .in('teacher_id', userIds)

      if (assignedLinksError) throw assignedLinksError

      const assignedCourseIds = new Set((assignedLinks || []).map(l => l.course_id).filter(Boolean))
      filteredCourses = filteredCourses.filter(c => assignedCourseIds.has(c.id))
    }

    courses.value = filteredCourses
    if (filteredCourses.length > 0 && !selectedCourse.value) {
      selectedCourse.value = filteredCourses[0].id
      gridCourseId.value = filteredCourses[0].id
    }
  }

  const fetchSubjectsForCourse = async (courseId) => {
    if (!courseId) {
      availableSubjects.value = []
      selectedSubject.value = ''
      return
    }
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!sId) {
      availableSubjects.value = []
      selectedSubject.value = ''
      return
    }
    let query = supabase
      .from('course_subjects')
      .select('id, subject_id, teacher_id, subjects(id, name)')
      .eq('course_id', courseId)
    query = query.eq('school_id', sId)

    const userIds = [authStore.user?.id, authStore.profile?.id].filter(Boolean)
    if (!isAdmin.value && userIds.length > 0) {
      query = query.in('teacher_id', userIds)
    }

    const { data, error } = await query
    if (error) throw error
    availableSubjects.value = (data || []).map(cs => ({
      course_subject_id: cs.id,
      id: cs.subject_id,
      name: cs.subjects?.name || 'Materia'
    })).sort((a, b) => a.name.localeCompare(b.name))
  }

  const fetchRollCallData = async () => {
    const version = ++rollCallRequest
    const key = rollCallContextKey()
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
    const courseId = selectedCourse.value
    const subjectId = selectedSubject.value
    const date = selectedDate.value
    const hourBlock = selectedHourBlock.value
    loadedRollCallKey = null
    students.value = []
    Object.keys(rollCallState).forEach(id => delete rollCallState[id])
    loading.value = false
    if (!schoolId || !courseId || !date) return
    loading.value = true
    const isCurrent = () => version === rollCallRequest && key === rollCallContextKey()
    try {
      const { data: stuData, error: stuError } = await supabase.from('students')
        .select('id, full_name, student_cedula, representative_name, representative_phone')
        .eq('school_id', schoolId).eq('course_id', courseId).order('full_name')
      if (!isCurrent()) return
      if (stuError) throw stuError
      if (!Array.isArray(stuData)) throw new Error('No se confirmó la lista de estudiantes.')

      let query = supabase.from('attendance_records')
        .select('id, student_id, status, observations, hour_block, subject_id')
        .eq('school_id', schoolId).eq('course_id', courseId)
        .eq('attendance_date', date).eq('hour_block', hourBlock)
      query = subjectId ? query.eq('subject_id', subjectId) : query.is('subject_id', null)
      const { data: attData, error: attError } = await query
      if (!isCurrent()) return
      if (attError) throw attError
      if (!Array.isArray(attData)) throw new Error('No se confirmó la carga de asistencia.')

      const existingMap = new Map(attData.map(record => [record.student_id, record]))
      stuData.forEach(student => {
        const existing = existingMap.get(student.id)
        rollCallState[student.id] = {
          status: existing?.status || 'presente',
          observations: existing?.observations || '',
        }
      })
      students.value = stuData
      loadedRollCallKey = key
    } catch (err) {
      if (isCurrent()) toast.error('Error al cargar la lista de asistencia', { description: translateError(err) })
    } finally {
      if (version === rollCallRequest) loading.value = false
    }
  }

  // Roll-Call Actions
  const markAllPresent = () => {
    students.value.forEach(s => {
      if (!rollCallState[s.id]) {
        rollCallState[s.id] = { status: 'presente', observations: '' }
      } else {
        rollCallState[s.id].status = 'presente'
      }
    })
    toast.info('Se han marcado todos los estudiantes como Presentes')
  }

  const setStudentStatus = (studentId, status) => {
    if (!rollCallState[studentId]) {
      rollCallState[studentId] = { status: 'presente', observations: '' }
    }
    rollCallState[studentId].status = status
  }

  const setStudentObservation = (studentId, obs) => {
    if (!rollCallState[studentId]) {
      rollCallState[studentId] = { status: 'presente', observations: '' }
    }
    rollCallState[studentId].observations = obs
  }

  const saveAttendanceRollCall = async () => {
    if (!selectedCourse.value || !selectedDate.value) {
      toast.error('Selecciona el curso y la fecha')
      return
    }

    if (saving.value || loading.value || !students.value.length || loadedRollCallKey !== rollCallContextKey()) {
      toast.error('Espera a que se cargue correctamente la asistencia antes de guardar.')
      return
    }
    const saveContext = rollCallContextKey()
    saving.value = true
    try {
      const records = students.value.map(s => ({
        student_id: s.id,
        status: rollCallState[s.id]?.status || 'presente',
        observations: rollCallState[s.id]?.observations || null,
      }))

      const { data, error } = await supabase.rpc('save_attendance_batch', {
        p_course_id: selectedCourse.value,
        p_subject_id: selectedSubject.value || null,
        p_date: selectedDate.value,
        p_hour_block: selectedHourBlock.value,
        p_records: records
      })

      if (error) throw error
      if (data?.success !== true || data.saved_count !== records.length) {
        throw new Error('El servidor no confirmó el guardado completo de asistencia.')
      }
      if (saveContext !== rollCallContextKey()) return

      toast.success('Asistencia guardada correctamente')
      await fetchRollCallData()
    } catch (err) {
      console.error('Error saving attendance:', err)
      toast.error('Error al guardar asistencia', { description: translateError(err) })
    } finally {
      saving.value = false
    }
  }

  // Justifications Methods
  const searchStudentAbsences = async (student) => {
    selectedJustificationStudent.value = student
    studentUnexcusedAbsences.value = []
    selectedDatesToJustify.value = []

    try {
      const { data, error } = await supabase
        .from('attendance_records')
        .select('id, attendance_date, hour_block, status, observations, subjects(name), courses(name)')
        .eq('student_id', student.id)
        .in('status', ['falta_injustificada', 'atraso'])
        .order('attendance_date', { ascending: false })

      if (error) throw error
      studentUnexcusedAbsences.value = data || []
    } catch (err) {
      toast.error('Error al buscar faltas del estudiante')
    }
  }

  const submitJustification = async () => {
    if (!selectedJustificationStudent.value || selectedDatesToJustify.value.length === 0) {
      toast.error('Selecciona al menos una fecha a justificar')
      return
    }
    if (!justificationReason.value.trim()) {
      toast.error('Ingresa el motivo de la justificación')
      return
    }

    justifyingLoading.value = true
    try {
      const { data, error } = await supabase.rpc('justify_attendance_records', {
        p_student_id: selectedJustificationStudent.value.id,
        p_dates: selectedDatesToJustify.value,
        p_reason: justificationReason.value.trim()
      })

      if (error) throw error
      if (data?.success !== true || !Number.isInteger(data.updated_count) || data.updated_count < 1) {
        throw new Error('No se confirmó ninguna falta justificada. Actualiza la consulta.')
      }

      toast.success('Faltas justificadas exitosamente')
      justificationReason.value = ''
      selectedDatesToJustify.value = []
      await searchStudentAbsences(selectedJustificationStudent.value)
    } catch (err) {
      toast.error('Error al procesar la justificación', { description: translateError(err) })
    } finally {
      justifyingLoading.value = false
    }
  }

  // Monthly Grid Data
  const loadMonthlyGridData = async () => {
    if (!gridCourseId.value || !gridMonth.value) return
    gridLoading.value = true

    try {
      const [yearStr, monthStr] = gridMonth.value.split('-')
      const year = parseInt(yearStr, 10)
      const month = parseInt(monthStr, 10)

      // Determinar días del mes
      const totalDaysInMonth = new Date(year, month, 0).getDate()
      const days = []
      for (let d = 1; d <= totalDaysInMonth; d++) {
        const dayStr = String(d).padStart(2, '0')
        const fullDate = `${gridMonth.value}-${dayStr}`
        const dateObj = new Date(year, month - 1, d)
        const dayOfWeek = dateObj.getDay() // 0 = Dom, 6 = Sáb
        // Excluir fines de semana de la visualización
        if (dayOfWeek !== 0 && dayOfWeek !== 6) {
          days.push({
            dayNumber: d,
            date: fullDate,
            dayName: ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'][dayOfWeek]
          })
        }
      }
      gridDays.value = days

      // Cargar estudiantes del curso
      const sId = authStore.activeSchoolId || authStore.profile?.school_id
      if (!sId) throw new Error('No hay una institución activa seleccionada.')
      let stuQuery = supabase
        .from('students')
        .select('id, full_name, student_cedula, representative_phone')
        .eq('course_id', gridCourseId.value)
        .order('full_name')
      stuQuery = stuQuery.eq('school_id', sId)
      const { data: stuData, error: studentsError } = await stuQuery
      if (studentsError) throw studentsError
      const studentList = stuData || []

      // Cargar registros de asistencia del mes
      const startDate = `${gridMonth.value}-01`
      const endDate = `${gridMonth.value}-${String(totalDaysInMonth).padStart(2, '0')}`

      const { data: attData, error: attendanceError } = await supabase
        .from('attendance_records')
        .select('student_id, attendance_date, status')
        .eq('course_id', gridCourseId.value)
        .gte('attendance_date', startDate)
        .lte('attendance_date', endDate)

      if (attendanceError) throw attendanceError

      // Agrupar por estudiante
      const mapByStudent = new Map()
      studentList.forEach(s => {
        mapByStudent.set(s.id, { student: s, records: [], daysMap: {} })
      })

      ;(attData || []).forEach(r => {
        const item = mapByStudent.get(r.student_id)
        if (item) {
          item.records.push(r)
          item.daysMap[r.attendance_date] = r.status
        }
      })

      // Calcular estadísticas acumuladas
      gridMatrix.value = Array.from(mapByStudent.values()).map(item => ({
        student: item.student,
        daysMap: item.daysMap,
        stats: calculateStudentAttendanceStats(item.records)
      }))

    } catch (err) {
      console.error('Error loading monthly grid:', err)
      toast.error('Error al generar la sábana mensual de asistencia')
    } finally {
      gridLoading.value = false
    }
  }

  // Alerts & Risk Detection
  const loadAttendanceAlerts = async () => {
    alertsLoading.value = true
    try {
      const sId = authStore.activeSchoolId || authStore.profile?.school_id
      if (!sId) {
        atRiskStudents.value = []
        return
      }
      let query = supabase
        .from('attendance_records')
        .select(`
          id, attendance_date, status, observations, student_id, course_id,
          students(id, full_name, student_cedula, representative_name, representative_phone),
          courses(id, name)
        `)
        .in('status', ['falta_injustificada', 'atraso', 'fuga'])
        .order('attendance_date', { ascending: false })
        .limit(100)

      query = query.eq('school_id', sId)

      const { data, error } = await query
      if (error) throw error

      atRiskStudents.value = data || []
    } catch (err) {
      console.error('Error loading alerts:', err)
    } finally {
      alertsLoading.value = false
    }
  }

  // WhatsApp Notification
  const sendWhatsAppNotification = (student, status = 'falta_injustificada', date = selectedDate.value, observations = '') => {
    const phone = (student?.representative_phone || '').replace(/\D/g, '')
    if (!phone || phone.length < 7) {
      toast.error('El estudiante no tiene registrado un número de teléfono de representante válido.')
      return
    }

    let fullPhone = phone
    if (fullPhone.startsWith('09') && fullPhone.length === 10) {
      fullPhone = `593${fullPhone.slice(1)}`
    } else if (fullPhone.length === 9 && !fullPhone.startsWith('593')) {
      fullPhone = `593${fullPhone}`
    }

    const courseObj = courses.value.find(c => c.id === selectedCourse.value) || { name: 'Curso' }
    const subObj = availableSubjects.value.find(s => s.id === selectedSubject.value)

    const message = buildAttendanceWhatsAppMessage({
      institutionName: institutionConfig.value?.institution_name || 'Institución Educativa',
      studentName: student?.full_name || 'Estudiante',
      courseName: courseObj.name,
      subjectName: subObj?.name || '',
      date,
      status,
      observations,
      representativeName: student?.representative_name || ''
    })

    const url = `https://wa.me/${fullPhone}?text=${encodeURIComponent(message)}`
    window.open(url, '_blank')
  }

  // Watchers & Lifecycle
  watch([selectedCourse, selectedSubject, selectedDate, selectedHourBlock], () => {
    if (activeTab.value === 'roll_call') {
      fetchRollCallData()
    }
  })

  watch(selectedCourse, (newVal) => {
    fetchSubjectsForCourse(newVal)
  })

  watch([gridCourseId, gridMonth], () => {
    if (activeTab.value === 'monthly_grid') {
      loadMonthlyGridData()
    }
  })

  watch(activeTab, (tab) => {
    if (tab === 'roll_call') fetchRollCallData()
    else if (tab === 'monthly_grid') loadMonthlyGridData()
    else if (tab === 'alerts') loadAttendanceAlerts()
  })

  onMounted(async () => {
    await Promise.all([
      fetchInstitutionConfig(),
      fetchCourses()
    ])
    if (selectedCourse.value) {
      await fetchSubjectsForCourse(selectedCourse.value)
      await fetchRollCallData()
    }
  })

  return {
    // State
    activeTab,
    loading,
    saving,
    courses,
    quarters,
    availableSubjects,
    institutionConfig,
    isAdmin,
    // Roll Call
    selectedCourse,
    selectedSubject,
    selectedDate,
    selectedHourBlock,
    students,
    rollCallState,
    rollCallStats,
    // Justifications
    justificationSearch,
    selectedJustificationStudent,
    studentUnexcusedAbsences,
    selectedDatesToJustify,
    justificationReason,
    justifyingLoading,
    // Monthly Grid
    gridMonth,
    gridCourseId,
    gridDays,
    gridMatrix,
    gridLoading,
    // Alerts
    atRiskStudents,
    alertsLoading,
    // Actions
    fetchRollCallData,
    markAllPresent,
    setStudentStatus,
    setStudentObservation,
    saveAttendanceRollCall,
    searchStudentAbsences,
    submitJustification,
    loadMonthlyGridData,
    loadAttendanceAlerts,
    sendWhatsAppNotification
  }
}
