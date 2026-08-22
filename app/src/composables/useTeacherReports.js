import { ref, reactive, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useAcademicYearStore } from '../stores/academicYear'
import { isInstitutionAdmin } from '../lib/permissions'
import { translateError } from '../lib/errorDictionary'
import { toast } from 'vue-sonner'
import { normalizeStoragePath, resolvePrivateImageUrl } from '../lib/storageUtils'
import { 
  REPORT_TEMPLATES, 
  REPORT_STATUSES, 
  TEMPLATE_CONFIGS, 
  getTemplateConfig, 
  buildTeacherReportWhatsAppMessage 
} from '../lib/teacherReportTemplates'

export function useTeacherReports() {
  const authStore = useAuthStore()
  const academicYearStore = useAcademicYearStore()

  // State
  const loading = ref(false)
  const saving = ref(false)
  const reports = ref([])
  const totalCount = ref(0)
  const courses = ref([])
  const quarters = ref([])
  const availableStudents = ref([])
  const availableSubjects = ref([])
  const institutionConfig = ref({})

  // Filters
  const searchQuery = ref('')
  const selectedCourseFilter = ref('')
  const selectedTemplateFilter = ref('')
  const selectedStatusFilter = ref('')
  const selectedQuarterFilter = ref('')
  const page = ref(1)
  const pageSize = 25

  // Modals state
  const showEditorModal = ref(false)
  const showPrintModal = ref(false)
  const showDigitalSignModal = ref(false)
  const activeReport = ref(null)

  // Form State
  const formData = reactive({
    id: null,
    template_type: REPORT_TEMPLATES.CITACION_REPRESENTANTE,
    title: '',
    course_id: '',
    subject_id: '',
    student_id: '',
    academic_year: '',
    quarter_id: '',
    recipient_role: 'representante_legal',
    recipient_name: '',
    status: 'borrador',
    priority: 'normal',
    citation_date: '',
    citation_time: '08:00',
    citation_location: 'Instalaciones del plantel educativo',
    reason: '',
    academic_score: null,
    observations: '',
    agreements_commitments: '',
    recommendations: '',
    custom_payload: {},
    signature_data: null,
    // Transient Auto-filled display properties
    student_name: '',
    student_cedula: '',
    representative_name: '',
    representative_cedula: '',
    representative_phone: '',
    student_address: '',
    course_name: '',
    subject_name: '',
    teacher_name: '',
    teacher_email: '',
  })

  const isAdmin = computed(() => isInstitutionAdmin(authStore.accessContext))
  const isYearLocked = computed(() => academicYearStore.isLocked)

  // Summary Metrics
  const stats = computed(() => {
    const list = reports.value || []
    return {
      total: totalCount.value || list.length,
      citaciones: list.filter(r => r.template_type === REPORT_TEMPLATES.CITACION_REPRESENTANTE).length,
      rendimiento: list.filter(r => r.template_type === REPORT_TEMPLATES.INFORME_RENDIMIENTO).length,
      enviados: list.filter(r => ['enviado', 'atendido'].includes(r.status)).length,
      borradores: list.filter(r => r.status === 'borrador').length,
    }
  })

  // Data Fetching
  const fetchInstitutionConfig = async () => {
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!sId) return
    const { data } = await supabase
      .from('system_config')
      .select('key, value')
      .eq('school_id', sId)
      .in('key', ['institution_name', 'institution_logo_url', 'institution_tutor_name', 'institution_rector_name', 'academic_periods'])

    const map = Object.fromEntries((data || []).map(i => [i.key, i.value]))
    map.institution_logo_url = await resolvePrivateImageUrl(
      supabase,
      'institution-assets',
      normalizeStoragePath(map.institution_logo_url, 'institution-assets')
    ).catch(() => '')
    institutionConfig.value = map
  }

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
    if (!isAdmin.value && userIds.length > 0) {
      const { data: assignedLinks } = await supabase
        .from('course_subjects')
        .select('course_id')
        .in('teacher_id', userIds)

      const assignedCourseIds = new Set((assignedLinks || []).map(l => l.course_id).filter(Boolean))
      filteredCourses = filteredCourses.filter(c => assignedCourseIds.has(c.id))
    }

    courses.value = filteredCourses
  }

  const fetchQuarters = async () => {
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    let query = supabase.from('quarters').select('id, name, is_active, is_locked').order('created_at')
    if (sId) {
      query = query.or(`school_id.eq.${sId},school_id.is.null`)
    }
    const { data } = await query
    quarters.value = (data || []).filter(q => q.name !== 'test_q')
  }

  const fetchStudentsForCourse = async (courseId) => {
    if (!courseId) {
      availableStudents.value = []
      return
    }
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    let query = supabase
      .from('students')
      .select('id, full_name, student_cedula, representative_name, representative_cedula, representative_phone, student_address, course_id')
      .eq('course_id', courseId)
      .order('full_name')
    if (sId) {
      query = query.or(`school_id.eq.${sId},school_id.is.null`)
    }
    const { data } = await query
    availableStudents.value = data || []
  }

  const fetchSubjectsForCourse = async (courseId) => {
    if (!courseId) {
      availableSubjects.value = []
      return
    }
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    let query = supabase
      .from('course_subjects')
      .select('id, subject_id, teacher_id, subjects(id, name)')
      .eq('course_id', courseId)
    if (sId) {
      query = query.or(`school_id.eq.${sId},school_id.is.null`)
    }

    const userIds = [authStore.user?.id, authStore.profile?.id].filter(Boolean)
    if (!isAdmin.value && userIds.length > 0) {
      query = query.in('teacher_id', userIds)
    }

    const { data } = await query
    availableSubjects.value = (data || []).map(cs => ({
      course_subject_id: cs.id,
      id: cs.subject_id,
      name: cs.subjects?.name || 'Materia'
    })).sort((a, b) => a.name.localeCompare(b.name))
  }

  const fetchReports = async () => {
    loading.value = true
    try {
      const sId = authStore.activeSchoolId || authStore.profile?.school_id
      const userIds = [authStore.user?.id, authStore.profile?.id].filter(Boolean)
      const from = (page.value - 1) * pageSize
      const to = from + pageSize - 1

      let query = supabase
        .from('teacher_reports')
        .select(`
          id, school_id, course_id, subject_id, student_id, teacher_id,
          academic_year, quarter_id, template_type, title, recipient_role,
          recipient_name, status, priority, citation_date, citation_time,
          citation_location, reason, academic_score, observations,
          agreements_commitments, recommendations, custom_payload, signature_data,
          created_at, updated_at,
          students (id, full_name, student_cedula, representative_name, representative_cedula, representative_phone, student_address),
          courses (id, name, level, track, academic_year),
          subjects (id, name),
          profiles:teacher_id (id, full_name, email, role)
        `, { count: 'exact' })
        .order('created_at', { ascending: false })
        .range(from, to)

      if (sId) {
        query = query.or(`school_id.eq.${sId},school_id.is.null`)
      }

      if (!isAdmin.value && userIds.length > 0) {
        query = query.in('teacher_id', userIds)
      }

      if (selectedCourseFilter.value) {
        query = query.eq('course_id', selectedCourseFilter.value)
      }

      if (selectedTemplateFilter.value) {
        query = query.eq('template_type', selectedTemplateFilter.value)
      }

      if (selectedStatusFilter.value) {
        query = query.eq('status', selectedStatusFilter.value)
      }

      if (selectedQuarterFilter.value) {
        query = query.eq('quarter_id', selectedQuarterFilter.value)
      }

      const term = (searchQuery.value || '').trim()
      if (term) {
        query = query.or(`title.ilike.%${term}%,reason.ilike.%${term}%`)
      }

      const { data, error, count } = await query
      if (error) throw error

      reports.value = data || []
      totalCount.value = count || 0
    } catch (err) {
      console.error('Error fetching teacher reports:', err)
      toast.error('Error al cargar informes docentes', { description: translateError(err) })
    } finally {
      loading.value = false
    }
  }

  // Sincronización reactiva al cambiar estudiante o curso en el formulario
  const onCourseSelected = async (courseId) => {
    formData.course_id = courseId
    formData.student_id = ''
    formData.subject_id = ''
    clearStudentDetails()

    const foundCourse = courses.value.find(c => c.id === courseId)
    formData.course_name = foundCourse?.name || ''
    formData.academic_year = foundCourse?.academic_year || academicYearStore.selectedYearName || ''

    await Promise.all([
      fetchStudentsForCourse(courseId),
      fetchSubjectsForCourse(courseId)
    ])
  }

  const onStudentSelected = (studentId) => {
    formData.student_id = studentId
    const s = availableStudents.value.find(st => st.id === studentId)
    if (s) {
      formData.student_name = s.full_name || ''
      formData.student_cedula = s.student_cedula || ''
      formData.representative_name = s.representative_name || ''
      formData.representative_cedula = s.representative_cedula || ''
      formData.representative_phone = s.representative_phone || ''
      formData.student_address = s.student_address || ''
    } else {
      clearStudentDetails()
    }
  }

  const onSubjectSelected = (subjectId) => {
    formData.subject_id = subjectId
    const sub = availableSubjects.value.find(s => s.id === subjectId)
    formData.subject_name = sub?.name || ''
  }

  const onTemplateSelected = (type) => {
    formData.template_type = type
    const cfg = getTemplateConfig(type)
    formData.title = cfg.title
    formData.recipient_role = cfg.defaultRecipientRole
    if (!formData.reason) formData.reason = cfg.defaultReason
    if (!formData.observations) formData.observations = cfg.defaultObservations
    if (!formData.agreements_commitments) formData.agreements_commitments = cfg.defaultAgreements
    if (!formData.recommendations) formData.recommendations = cfg.defaultRecommendations
  }

  const clearStudentDetails = () => {
    formData.student_name = ''
    formData.student_cedula = ''
    formData.representative_name = ''
    formData.representative_cedula = ''
    formData.representative_phone = ''
    formData.student_address = ''
  }

  // Modal open handlers
  const openCreateModal = async (initialTemplate = REPORT_TEMPLATES.CITACION_REPRESENTANTE, preselectedCourseId = null, preselectedStudentId = null) => {
    const defaultQuarter = quarters.value.find(q => q.is_active)?.id || quarters.value[0]?.id || null
    const cfg = getTemplateConfig(initialTemplate)

    Object.assign(formData, {
      id: null,
      template_type: initialTemplate,
      title: cfg.title,
      course_id: preselectedCourseId || (courses.value[0]?.id || ''),
      subject_id: '',
      student_id: '',
      academic_year: academicYearStore.selectedYearName || '',
      quarter_id: defaultQuarter || '',
      recipient_role: cfg.defaultRecipientRole,
      recipient_name: '',
      status: 'borrador',
      priority: 'normal',
      citation_date: new Date().toISOString().split('T')[0],
      citation_time: '08:00',
      citation_location: 'Instalaciones del plantel educativo',
      reason: cfg.defaultReason,
      academic_score: null,
      observations: cfg.defaultObservations,
      agreements_commitments: cfg.defaultAgreements,
      recommendations: cfg.defaultRecommendations,
      custom_payload: {},
      signature_data: null,
      student_name: '',
      student_cedula: '',
      representative_name: '',
      representative_cedula: '',
      representative_phone: '',
      student_address: '',
      course_name: '',
      subject_name: '',
      teacher_name: authStore.profile?.full_name || 'Docente',
      teacher_email: authStore.profile?.email || authStore.user?.email || '',
    })

    if (formData.course_id) {
      await onCourseSelected(formData.course_id)
      if (preselectedStudentId) {
        onStudentSelected(preselectedStudentId)
      }
    }

    showEditorModal.value = true
  }

  const openEditModal = async (report) => {
    if (!report) return
    activeReport.value = report

    await Promise.all([
      fetchStudentsForCourse(report.course_id),
      fetchSubjectsForCourse(report.course_id)
    ])

    const stu = report.students || availableStudents.value.find(s => s.id === report.student_id)

    Object.assign(formData, {
      id: report.id,
      template_type: report.template_type,
      title: report.title,
      course_id: report.course_id,
      subject_id: report.subject_id || '',
      student_id: report.student_id,
      academic_year: report.academic_year || '',
      quarter_id: report.quarter_id || '',
      recipient_role: report.recipient_role,
      recipient_name: report.recipient_name || '',
      status: report.status || 'borrador',
      priority: report.priority || 'normal',
      citation_date: report.citation_date || '',
      citation_time: report.citation_time || '08:00',
      citation_location: report.citation_location || 'Instalaciones del plantel',
      reason: report.reason || '',
      academic_score: report.academic_score,
      observations: report.observations || '',
      agreements_commitments: report.agreements_commitments || '',
      recommendations: report.recommendations || '',
      custom_payload: report.custom_payload || {},
      signature_data: report.signature_data || null,
      student_name: stu?.full_name || '',
      student_cedula: stu?.student_cedula || '',
      representative_name: stu?.representative_name || '',
      representative_cedula: stu?.representative_cedula || '',
      representative_phone: stu?.representative_phone || '',
      student_address: stu?.student_address || '',
      course_name: report.courses?.name || '',
      subject_name: report.subjects?.name || '',
      teacher_name: report.profiles?.full_name || authStore.profile?.full_name || '',
      teacher_email: report.profiles?.email || authStore.profile?.email || '',
    })

    showEditorModal.value = true
  }

  const openPrintModal = (report) => {
    activeReport.value = report
    showPrintModal.value = true
  }

  const openDigitalSignModal = (report) => {
    activeReport.value = report
    showDigitalSignModal.value = true
  }

  const saveReport = async (asSent = false) => {
    if (!formData.course_id || !formData.student_id) {
      toast.error('Debes seleccionar el curso y el estudiante.')
      return false
    }
    if (!formData.reason.trim()) {
      toast.error('El motivo o descripción del informe es requerido.')
      return false
    }

    saving.value = true
    try {
      const payload = {
        id: formData.id || undefined,
        course_id: formData.course_id,
        subject_id: formData.subject_id || null,
        student_id: formData.student_id,
        academic_year: formData.academic_year || academicYearStore.selectedYearName || null,
        quarter_id: formData.quarter_id || null,
        template_type: formData.template_type,
        title: formData.title || getTemplateConfig(formData.template_type).title,
        recipient_role: formData.recipient_role,
        recipient_name: formData.recipient_name || null,
        status: asSent ? 'enviado' : formData.status,
        priority: formData.priority,
        citation_date: formData.citation_date || null,
        citation_time: formData.citation_time || null,
        citation_location: formData.citation_location || null,
        reason: formData.reason,
        academic_score: formData.academic_score !== null && formData.academic_score !== '' ? Number(formData.academic_score) : null,
        observations: formData.observations || null,
        agreements_commitments: formData.agreements_commitments || null,
        recommendations: formData.recommendations || null,
        custom_payload: formData.custom_payload || {},
        signature_data: formData.signature_data || null,
      }

      // Try RPC first for atomic transaction
      const { data, error } = await supabase.rpc('save_teacher_report', { p_report: payload })
      if (error) {
        // Direct table fallback
        const sId = authStore.activeSchoolId || authStore.profile?.school_id
        if (formData.id) {
          const { error: updErr } = await supabase.from('teacher_reports').update({
            ...payload,
            updated_at: new Date().toISOString()
          }).eq('id', formData.id)
          if (updErr) throw updErr
        } else {
          const { error: insErr } = await supabase.from('teacher_reports').insert([{
            ...payload,
            school_id: sId,
            teacher_id: authStore.user?.id
          }])
          if (insErr) throw insErr
        }
      }

      toast.success(asSent ? 'Informe enviado exitosamente' : 'Informe guardado como borrador')
      showEditorModal.value = false
      await fetchReports()
      return true
    } catch (err) {
      console.error('Error saving teacher report:', err)
      toast.error('Error al guardar informe', { description: translateError(err) })
      return false
    } finally {
      saving.value = false
    }
  }

  const deleteReport = async (reportId) => {
    if (!confirm('¿Estás seguro de eliminar este informe o citación?')) return
    try {
      const { error } = await supabase.from('teacher_reports').delete().eq('id', reportId)
      if (error) throw error
      toast.success('Informe eliminado')
      await fetchReports()
    } catch (err) {
      toast.error('Error al eliminar', { description: translateError(err) })
    }
  }

  const updateStatus = async (reportId, newStatus) => {
    try {
      const { error } = await supabase
        .from('teacher_reports')
        .update({ status: newStatus, updated_at: new Date().toISOString() })
        .eq('id', reportId)
      if (error) throw error
      toast.success(`Estado actualizado a: ${REPORT_STATUSES[newStatus]?.label || newStatus}`)
      await fetchReports()
    } catch (err) {
      toast.error('Error al actualizar estado', { description: translateError(err) })
    }
  }

  const sendWhatsAppNotification = (report) => {
    const student = report.students
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

    const message = buildTeacherReportWhatsAppMessage({
      institutionName: institutionConfig.value?.institution_name || 'Institución Educativa',
      studentName: student?.full_name || '',
      courseName: report.courses?.name || '',
      subjectName: report.subjects?.name || '',
      teacherName: report.profiles?.full_name || authStore.profile?.full_name || '',
      templateType: report.template_type,
      citationDate: report.citation_date || '',
      citationTime: report.citation_time || '',
      citationLocation: report.citation_location || '',
      reason: report.reason || '',
      representativeName: student?.representative_name || ''
    })

    const url = `https://wa.me/${fullPhone}?text=${encodeURIComponent(message)}`
    window.open(url, '_blank')
  }

  // Watchers & Lifecycle
  watch([selectedCourseFilter, selectedTemplateFilter, selectedStatusFilter, selectedQuarterFilter, searchQuery], () => {
    page.value = 1
    fetchReports()
  })

  watch(() => academicYearStore.selectedYearName, () => {
    fetchCourses()
    fetchReports()
  })

  onMounted(async () => {
    await Promise.all([
      fetchInstitutionConfig(),
      fetchCourses(),
      fetchQuarters()
    ])
    await fetchReports()
  })

  return {
    // State
    loading,
    saving,
    reports,
    totalCount,
    courses,
    quarters,
    availableStudents,
    availableSubjects,
    institutionConfig,
    stats,
    isAdmin,
    isYearLocked,
    // Filters
    searchQuery,
    selectedCourseFilter,
    selectedTemplateFilter,
    selectedStatusFilter,
    selectedQuarterFilter,
    page,
    pageSize,
    // Modals
    showEditorModal,
    showPrintModal,
    showDigitalSignModal,
    activeReport,
    formData,
    // Actions
    fetchReports,
    fetchStudentsForCourse,
    fetchSubjectsForCourse,
    onCourseSelected,
    onStudentSelected,
    onSubjectSelected,
    onTemplateSelected,
    openCreateModal,
    openEditModal,
    openPrintModal,
    openDigitalSignModal,
    saveReport,
    deleteReport,
    updateStatus,
    sendWhatsAppNotification,
  }
}
