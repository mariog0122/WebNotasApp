/**
 * Composable Principal para el Módulo de Planificación Educativa con IA (Ecuador)
 * Gestiona el asistente de 5 pasos, generación con IA (Demo/Gemini), edición granular,
 * creación de recursos, seguimiento estudiantil y exportación formal.
 */

import { ref, computed, reactive } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useAcademicYearStore } from '../stores/academicYear'
import { toast } from 'vue-sonner'
import { EducationAIGateway } from '../lib/ai/EducationAIGateway'
import { AI_SETTINGS_COLUMNS } from '../lib/ai/RemoteEducationAIProvider'
import { getCurriculumItems, getSuggestedAgeForGrade } from '../lib/ecuadorCurriculumCatalog'

export function useAIPlanning() {
  const authStore = useAuthStore()
  const academicYearStore = useAcademicYearStore()

  // Estados de Carga y Acceso
  // Nace en true: el módulo carga al montarse y no debe mostrar avisos de "desactivado" antes de saber el estado real.
  const loading = ref(true)
  const loadError = ref('')
  const generating = ref(false)
  const saving = ref(false)
  const moduleAccess = ref({
    module_enabled: false,
    subscription_status: 'unknown',
    mode: 'unavailable',
    provider: null,
    ai_status: 'unavailable',
    is_demo: false,
    monthly_quota: 0,
    monthly_usage: 0,
    is_limit_reached: false,
    is_teacher_limit_reached: false,
  })

  // Listados y Datos de Contexto
  const lessonPlans = ref([])
  const courses = ref([])
  const subjects = ref([])
  const students = ref([])
  const institutionConfig = ref({})

  // Filtros
  const searchQuery = ref('')
  const selectedCourseFilter = ref('')
  const selectedSubjectFilter = ref('')
  const selectedStatusFilter = ref('all')

  // Modales
  const showWizardModal = ref(false)
  const showViewerModal = ref(false)
  const showResourceModal = ref(false)
  const showSupportModal = ref(false)
  const showPrintModal = ref(false)
  const showSettingsModal = ref(false)

  // Plan Activo y Recursos Activos
  const activePlan = ref(null)
  const activeResources = ref([])
  const activeSupportPlans = ref([])
  const selectedStudentForSupport = ref(null)

  // Asistente de 5 Pasos
  const wizardStep = ref(1)
  const wizardData = reactive({
    regime: 'costa_galapagos',
    level: 'basica_media',
    grade_year: '6to_egb',
    parallel: 'A',
    target_age_min: 10,
    target_age_max: 11,
    subject_name: 'Matemáticas',
    course_id: '',
    subject_id: '',
    unit_title: 'Unidad 1: Números y Operaciones en mi Entorno',
    topic_title: 'Operaciones combinadas con números decimales y redondeo comercial',
    students_count: 30,
    duration_minutes: 45,
    session_count: 2,
    estimated_date: new Date().toISOString().slice(0, 10),
    competencies: ['matematicas', 'comunicacionales'],
    dcd_codes: ['M.3.1.28'],
    dcd_descriptions: ['Calcular, aplicando algoritmos y la tecnología, sumas, restas, multiplicaciones y divisiones con números decimales.'],
    evaluation_criteria_codes: ['CE.M.3.5'],
    evaluation_criteria_descriptions: ['Plantea problemas numéricos en los que intervienen números naturales, decimales o fraccionarios.'],
    evaluation_indicators: ['Aplica las propiedades de las operaciones y estrategias de cálculo mental o escrito para resolver problemas con números decimales.'],
    learning_objectives: ['Resolver problemas cotidianos utilizando operaciones combinadas con números decimales.'],
    bloom_level: 'aplicar',
    evidence_type: 'desempeno_y_producto',
    methodology_primary: 'ERCA',
    methodology_secondary: ['DUA_PURO'],
    modality: 'presencial',
    group_organization: 'equipos',
    available_resources: ['pizarra', 'proyector', 'texto_escolar'],
    context_type: 'urbano',
    evaluation_focus: ['formativa', 'sumativa'],
    dua_principles: ['implicacion', 'representacion', 'accion_expresion'],
    pacing_type: 'estandar',
    learning_barriers: [],
    adaptations_needed: false,
    adaptations_degree: 'grado_1',
    support_strategies: [],
    output_format: 'estandar',
    output_language: 'es',
    include_dua: true,
    include_evaluation: true,
    include_resources: true,
    include_adaptations: true,
    generation_quality: 'automatica'
  })

  // Estadísticas del Módulo
  const stats = computed(() => {
    const total = lessonPlans.value.length
    const drafts = lessonPlans.value.filter(p => p.status === 'borrador').length
    const ready = lessonPlans.value.filter(p => p.status === 'lista' || p.status === 'aprobada').length
    const resourcesCount = activeResources.value.length
    const supportCount = activeSupportPlans.value.length

    return {
      total,
      drafts,
      ready,
      resourcesCount,
      supportCount
    }
  })

  // Planes Filtrados
  const filteredLessonPlans = computed(() => {
    return lessonPlans.value.filter(plan => {
      const normalizedSearch = searchQuery.value.trim().toLocaleLowerCase('es')
      const matchesSearch = !normalizedSearch || [plan.title, plan.topic_title, plan.subject_name]
        .some(value => String(value || '').toLocaleLowerCase('es').includes(normalizedSearch))

      const matchesCourse = !selectedCourseFilter.value || plan.course_id === selectedCourseFilter.value
      const matchesSubject = !selectedSubjectFilter.value || String(plan.subject_name || '').toLocaleLowerCase('es') === selectedSubjectFilter.value.toLocaleLowerCase('es')
      const matchesStatus = selectedStatusFilter.value === 'all' || plan.status === selectedStatusFilter.value

      return matchesSearch && matchesCourse && matchesSubject && matchesStatus
    })
  })

  const requireActiveSchoolId = () => {
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!schoolId) throw new Error('Selecciona una institución antes de usar la planificación curricular.')
    return schoolId
  }

  // Verificación de Acceso al Módulo
  const checkAccess = async () => {
    const schoolId = requireActiveSchoolId()
    const { data, error } = await supabase.rpc('check_ai_planning_access', { p_school_id: schoolId })
    if (error) throw error
    if (!data || typeof data.module_enabled !== 'boolean') {
      throw new Error('El servidor no devolvió un estado válido para el módulo de IA.')
    }
    moduleAccess.value = data
    return data
  }

  // Carga de Cursos, Asignaturas, Estudiantes y Planes
  const fetchInitialData = async () => {
    loading.value = true
    loadError.value = ''
    courses.value = []
    subjects.value = []
    lessonPlans.value = []
    activeResources.value = []
    activeSupportPlans.value = []
    institutionConfig.value = {}
    try {
      const schoolId = requireActiveSchoolId()
      const access = await checkAccess()
      if (!access.module_enabled) return

      const [coursesRes, subjectsRes, plansRes, cfgRes, resRes, suppRes, aiSettingsRes] = await Promise.all([
        supabase.from('courses').select('id, name, level, academic_year').eq('school_id', schoolId).order('name'),
        supabase.from('subjects').select('id, name').eq('school_id', schoolId).order('name'),
        supabase.from('lesson_plans').select('*').eq('school_id', schoolId).order('created_at', { ascending: false }),
        supabase.from('system_config').select('key, value').eq('school_id', schoolId),
        supabase.from('lesson_plan_resources').select('*').eq('school_id', schoolId),
        supabase.from('student_support_plans').select('*').eq('school_id', schoolId),
        supabase.from('institution_ai_settings').select(AI_SETTINGS_COLUMNS).eq('school_id', schoolId).maybeSingle()
      ])

      for (const result of [coursesRes, subjectsRes, plansRes, cfgRes, resRes, suppRes, aiSettingsRes]) {
        if (result.error) throw result.error
      }

      moduleAccess.value = {
        ...moduleAccess.value,
        is_demo: aiSettingsRes.data?.mode === 'demo' || !aiSettingsRes.data?.has_api_key,
      }

      courses.value = coursesRes.data || []
      subjects.value = subjectsRes.data || []
      lessonPlans.value = plansRes.data || []
      activeResources.value = resRes.data || []
      activeSupportPlans.value = suppRes.data || []

      if (cfgRes.data) {
        institutionConfig.value = Object.fromEntries(cfgRes.data.map(i => [i.key, i.value]))
      }
    } catch (err) {
      moduleAccess.value = {
        ...moduleAccess.value,
        module_enabled: false,
        ai_status: 'unavailable',
      }
      loadError.value = err?.message || 'No se pudo conectar con el servidor.'
      toast.error('Error cargando planificaciones: ' + loadError.value)
    } finally {
      loading.value = false
    }
  }

  // Carga de estudiantes de un curso
  const fetchStudentsForCourse = async (courseId) => {
    students.value = []
    if (!courseId) {
      return true
    }

    try {
      const schoolId = requireActiveSchoolId()
      const { data, error } = await supabase
        .from('students')
        .select('id, full_name, email, phone, is_active')
        .eq('school_id', schoolId)
        .eq('course_id', courseId)
        .order('full_name')

      if (error) throw error
      students.value = data || []
      return true
    } catch (err) {
      toast.error('No se pudieron cargar los estudiantes del curso: ' + err.message)
      return false
    }
  }

  // Actualizar edad sugerida al cambiar de grado en el Asistente
  const onGradeChange = (newGradeId) => {
    wizardData.grade_year = newGradeId
    const ages = getSuggestedAgeForGrade(newGradeId)
    wizardData.target_age_min = ages.min
    wizardData.target_age_max = ages.max

    // Buscar sugerencias curriculares
    const items = getCurriculumItems({ level: wizardData.level, gradeYear: newGradeId, subjectName: wizardData.subject_name })
    if (items.length > 0) {
      wizardData.unit_title = items[0].unit_title
      wizardData.topic_title = items[0].topic_title
      wizardData.dcd_codes = [items[0].dcd_code]
      wizardData.dcd_descriptions = [items[0].dcd_description]
      wizardData.evaluation_criteria_codes = [items[0].evaluation_criteria_code]
      wizardData.evaluation_criteria_descriptions = [items[0].evaluation_criteria_description]
      wizardData.evaluation_indicators = [items[0].evaluation_indicator_description]
      wizardData.learning_objectives = [items[0].learning_objective_description]
    }
  }

  // Navegación del Asistente
  const openWizard = () => {
    if (!moduleAccess.value.module_enabled || moduleAccess.value.is_limit_reached || moduleAccess.value.is_teacher_limit_reached) {
      toast.error(moduleAccess.value.is_teacher_limit_reached
        ? 'Alcanzaste el límite diario de generación asignado a docentes.'
        : moduleAccess.value.is_limit_reached
          ? 'La institución alcanzó el límite mensual de generación.'
        : 'La planificación con IA no está habilitada para esta institución.')
      return false
    }
    wizardStep.value = 1
    showWizardModal.value = true
    return true
  }

  const nextStep = () => {
    if (wizardStep.value < 5) wizardStep.value++
  }

  const prevStep = () => {
    if (wizardStep.value > 1) wizardStep.value--
  }

  // Inicialización del Gateway de IA
  const createAIGateway = async () => {
    const schoolId = requireActiveSchoolId()
    let hasApiKey = false
    let mode = 'managed'
    let provider = 'gemini'
    let configuredModel = 'auto'

    try {
      const { data, error } = await supabase
        .from('institution_ai_settings')
        .select(AI_SETTINGS_COLUMNS)
        .eq('school_id', schoolId)
        .maybeSingle()

      if (error) throw error
      if (data) {
        mode = data.mode
        provider = data.provider || 'gemini'
        configuredModel = data.model_id || 'auto'
        hasApiKey = !!data.has_api_key
      }
    } catch (e) {
      throw new Error('No se pudo cargar la configuración de IA. Inténtalo nuevamente.')
    }

    // Resolver modelo según calidad elegida por el docente
    let effectiveModel = configuredModel
    const quality = wizardData.generation_quality || 'automatica'

    if (quality === 'economica') {
      effectiveModel = provider === 'openai' ? 'gpt-5-nano' : 'gemini-2.5-flash-lite'
    } else if (quality === 'alta_calidad') {
      effectiveModel = provider === 'openai' ? 'gpt-5' : 'gemini-3.7-flash'
    } else {
      // Automática: Si está en 'auto', asignar modelo equilibrado por defecto
      if (effectiveModel === 'auto' || !effectiveModel) {
        effectiveModel = provider === 'openai' ? 'gpt-5-mini' : 'gemini-2.5-flash'
      }
    }

    return new EducationAIGateway({
      schoolId,
      userId: authStore.user?.id,
      providerType: provider,
      quality,
      model: effectiveModel,
      isDemo: mode === 'demo' || !hasApiKey
    })
  }

  // Generación de la Planificación con IA
  const generatePlanWithAI = async () => {
    if (generating.value) return false
    if (!moduleAccess.value.module_enabled || moduleAccess.value.is_limit_reached || moduleAccess.value.is_teacher_limit_reached) {
      toast.error('La generación de planificaciones no está disponible en este momento.')
      return false
    }
    generating.value = true
    try {
      const schoolId = requireActiveSchoolId()
      let adaptedStudents = []
      if (wizardData.course_id) {
        const { data: stData, error: studentError } = await supabase
          .from('students')
          .select('id, full_name, has_adaptation, adaptation_grade, adaptation_details')
          .eq('school_id', schoolId)
          .eq('course_id', wizardData.course_id)
          .eq('has_adaptation', true)
        if (studentError) throw studentError
        if (stData && stData.length > 0) {
          adaptedStudents = stData
        }
      }

      const gateway = await createAIGateway()
      const aiResult = await gateway.generatePlan({
        topicTitle: wizardData.topic_title,
        unitTitle: wizardData.unit_title,
        subjectName: wizardData.subject_name,
        gradeYear: wizardData.grade_year,
        level: wizardData.level,
        regime: wizardData.regime,
        durationMinutes: wizardData.duration_minutes,
        sessionCount: wizardData.session_count,
        dcdCodes: wizardData.dcd_codes,
        dcdDescriptions: wizardData.dcd_descriptions,
        evaluationCriteriaDescriptions: wizardData.evaluation_criteria_descriptions,
        evaluationIndicators: wizardData.evaluation_indicators,
        learningObjectives: wizardData.learning_objectives,
        methodologyPrimary: wizardData.methodology_primary,
        bloomLevel: wizardData.bloom_level,
        duaPrinciples: wizardData.dua_principles,
        adaptedStudents
      })

      const newPlanPayload = {
        school_id: schoolId,
        teacher_id: authStore.user?.id,
        course_id: wizardData.course_id || null,
        subject_id: wizardData.subject_id || null,
        academic_year: academicYearStore.selectedYearName || courses.value.find(course => course.id === wizardData.course_id)?.academic_year || null,
        title: aiResult.summary?.title || `Plan de Clase: ${wizardData.topic_title}`,
        regime: wizardData.regime,
        level: wizardData.level,
        grade_year: wizardData.grade_year,
        parallel: wizardData.parallel,
        target_age_min: wizardData.target_age_min,
        target_age_max: wizardData.target_age_max,
        students_count: wizardData.students_count,
        duration_minutes: wizardData.duration_minutes,
        session_count: wizardData.session_count,
        estimated_date: wizardData.estimated_date,
        subject_name: wizardData.subject_name,
        unit_title: wizardData.unit_title,
        topic_title: wizardData.topic_title,
        competencies: wizardData.competencies,
        dcd_codes: wizardData.dcd_codes,
        dcd_descriptions: wizardData.dcd_descriptions,
        evaluation_criteria_codes: wizardData.evaluation_criteria_codes,
        evaluation_criteria_descriptions: wizardData.evaluation_criteria_descriptions,
        evaluation_indicators: wizardData.evaluation_indicators,
        learning_objectives: wizardData.learning_objectives,
        bloom_level: wizardData.bloom_level,
        evidence_type: wizardData.evidence_type,
        methodology_primary: wizardData.methodology_primary,
        methodology_secondary: wizardData.methodology_secondary,
        modality: wizardData.modality,
        group_organization: wizardData.group_organization,
        available_resources: wizardData.available_resources,
        context_type: wizardData.context_type,
        evaluation_focus: wizardData.evaluation_focus,
        dua_principles: wizardData.dua_principles,
        pacing_type: wizardData.pacing_type,
        learning_barriers: wizardData.learning_barriers,
        adaptations_needed: wizardData.adaptations_needed,
        adaptations_degree: wizardData.adaptations_degree,
        support_strategies: wizardData.support_strategies,
        content_summary: JSON.stringify(aiResult.summary),
        didactic_sequence: aiResult.didactic_sequence || {},
        evaluation_plan: aiResult.evaluation_plan || {},
        inclusion_dua_plan: aiResult.inclusion_dua_plan || {},
        resources_plan: aiResult.resources_plan || {},
        status: 'borrador',
        version: 1,
        is_demo: aiResult._meta?.isDemo ?? true,
        ai_metadata: aiResult._meta || {}
      }

      // Mostrar como guardado únicamente después de confirmar la persistencia.
      const { data, error } = await supabase
        .from('lesson_plans')
        .insert(newPlanPayload)
        .select()
        .single()

      if (error) throw error
      if (!data?.id) throw new Error('No se confirmó el guardado de la planificación.')
      const savedPlan = data

      lessonPlans.value.unshift(savedPlan)
      activePlan.value = savedPlan
      showWizardModal.value = false
      showViewerModal.value = true

      if (savedPlan.course_id) {
        await fetchStudentsForCourse(savedPlan.course_id)
      }

      toast.success('¡Planificación didáctica generada exitosamente!')
    } catch (err) {
      toast.error('Error al generar planificación: ' + err.message)
    } finally {
      generating.value = false
    }
  }

  // Guardar Planificación Actualizada (con historial de versiones)
  const saveActivePlan = async (silent = false) => {
    if (!activePlan.value || saving.value) return false
    saving.value = true

    try {
      const planBeingSaved = activePlan.value
      const nextVersion = (planBeingSaved.version || 1) + 1
      const updatePayload = {
        ...JSON.parse(JSON.stringify(planBeingSaved)),
        version: nextVersion,
        updated_at: new Date().toISOString()
      }

      const { data, error } = await supabase.rpc('save_lesson_plan_version', {
        p_plan_id: planBeingSaved.id,
        p_payload: updatePayload,
        p_expected_version: planBeingSaved.version || 1,
      })

      if (error) throw error
      const confirmedPlan = data?.plan
      if (!data?.success || data.history_saved !== true
        || data.version !== nextVersion
        || !confirmedPlan?.id
        || confirmedPlan.id !== planBeingSaved.id
        || confirmedPlan.version !== nextVersion) {
        throw new Error('No se confirmó el guardado completo de la planificación y su historial.')
      }
      {
        // Si la planificación fue aprobada o marcada como lista, registrar diff como candidato a conocimiento
        if (confirmedPlan.status === 'aprobada' || confirmedPlan.status === 'lista') {
          try {
            const gateway = await createAIGateway()
            const studentNames = students.value.map(s => s.full_name).filter(Boolean)
            await gateway.submitFeedback({
              targetType: 'lesson_plan',
              targetId: planBeingSaved.id,
              rating: 5,
              category: 'pedagogical',
              tags: ['aprobada_coordinacion', 'correccion_docente'],
              comment: `Plan v${nextVersion} consolidado y validado en aula.`,
              diffContent: {
                version: nextVersion,
                title: confirmedPlan.title,
                topic: confirmedPlan.topic_title,
                status: confirmedPlan.status
              },
              knownStudentNames: studentNames
            }).catch(error => {
              console.warn('No se pudo registrar el aprendizaje de la planificación:', error)
            })
          } catch (error) {
            console.warn('No se pudo preparar el aprendizaje de la planificación:', error)
          }
        }
      }

      Object.assign(planBeingSaved, confirmedPlan)
      const idx = lessonPlans.value.findIndex(p => p.id === planBeingSaved.id)
      if (idx !== -1) lessonPlans.value[idx] = { ...planBeingSaved }

      if (!silent) toast.success('Planificación guardada con éxito (v' + nextVersion + ')')
      return true
    } catch (err) {
      if (!silent) toast.error('Error guardando planificación: ' + err.message)
      return false
    } finally {
      saving.value = false
    }
  }

  // Registrar retroalimentación docente explícita (👍 Útil, 👎 Necesita mejora, ✏️ Corrección)
  const submitFeedback = async (payload) => {
    try {
      const gateway = await createAIGateway()
      const studentNames = students.value.map(s => s.full_name).filter(Boolean)
      const res = await gateway.submitFeedback({
        ...payload,
        knownStudentNames: studentNames
      })
      toast.success('¡Gracias! Tu retroalimentación ayuda a mejorar las próximas recomendaciones.')
      return res
    } catch (err) {
      toast.error('Error al registrar retroalimentación: ' + err.message)
      throw err
    }
  }

  // Regenerar solo una sección específica
  const regenerateSingleSection = async (sectionKey) => {
    if (!activePlan.value) return
    generating.value = true
    const previousContent = activePlan.value[sectionKey]

    try {
      const gateway = await createAIGateway()
      const regeneratedContent = await gateway.regenerateSection({
        topicTitle: activePlan.value.topic_title,
        unitTitle: activePlan.value.unit_title,
        subjectName: activePlan.value.subject_name,
        gradeYear: activePlan.value.grade_year,
        methodologyPrimary: activePlan.value.methodology_primary,
        dcdDescriptions: activePlan.value.dcd_descriptions,
        duaPrinciples: activePlan.value.dua_principles
      }, sectionKey)

      activePlan.value[sectionKey] = regeneratedContent
      if (!await saveActivePlan(true)) {
        activePlan.value[sectionKey] = previousContent
        throw new Error('La sección se generó, pero no se pudo guardar. Reintenta el guardado.')
      }
      toast.success(`Sección "${sectionKey}" regenerada exitosamente con IA.`)
    } catch (err) {
      toast.error('Error al regenerar sección: ' + err.message)
    } finally {
      generating.value = false
    }
  }

  // Crear Recurso Didáctico Vinculado
  const createResource = async (resourceType, difficultyLevel = 'medio') => {
    if (!activePlan.value) return
    generating.value = true

    try {
      const gateway = await createAIGateway()
      const resourceResult = await gateway.generateResource({
        resourceType,
        difficultyLevel,
        topicTitle: activePlan.value.topic_title,
        subjectName: activePlan.value.subject_name,
        gradeYear: activePlan.value.grade_year,
        learningObjectives: activePlan.value.learning_objectives,
        dcdDescriptions: activePlan.value.dcd_descriptions
      })

      const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
      const payload = {
        school_id: schoolId,
        lesson_plan_id: activePlan.value.id,
        teacher_id: authStore.user?.id,
        resource_type: resourceType,
        title: resourceResult.title || `Recurso: ${activePlan.value.topic_title}`,
        content: resourceResult,
        difficulty_level: difficultyLevel,
        status: 'listo',
        created_at: new Date().toISOString()
      }

      const { data, error } = await supabase
        .from('lesson_plan_resources')
        .insert(payload)
        .select()
        .single()

      if (error) throw error
      if (!data?.id) throw new Error('No se confirmó el guardado del recurso.')
      const saved = data
      activeResources.value.unshift(saved)
      showResourceModal.value = false
      toast.success(`Recurso "${resourceResult.title || resourceType}" creado y asociado a la planificación.`)
    } catch (err) {
      toast.error('Error generando recurso: ' + err.message)
    } finally {
      generating.value = false
    }
  }

  // Crear Plan de Apoyo Estudiantil Individual
  const createStudentSupport = async (studentId, supportData) => {
    if (!activePlan.value) return
    generating.value = true

    try {
      const gateway = await createAIGateway()
      const targetStudent = students.value.find(s => s.id === studentId)

      const proposalResult = await gateway.generateStudentSupport({
        studentName: targetStudent?.full_name || 'Estudiante',
        studentId: studentId,
        observedDifficulty: supportData.observedDifficulty,
        evidenceType: supportData.evidenceType,
        intensity: supportData.intensity,
        durationWeeks: supportData.durationWeeks,
        topicTitle: activePlan.value.topic_title,
        subjectName: activePlan.value.subject_name
      })

      const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
      const payload = {
        support_type: supportData.supportType || 'refuerzo',
        observed_difficulty: supportData.observedDifficulty,
        evidence_type: supportData.evidenceType,
        intensity: supportData.intensity,
        duration_weeks: supportData.durationWeeks,
        proposed_actions: proposalResult,
        status: 'aprobado_docente',
        target_date: supportData.targetDate || new Date(Date.now() + 14 * 86400000).toISOString().slice(0, 10),
        observations: supportData.observations || null,
      }

      const { data, error } = await supabase.rpc('create_student_support_plan', {
        p_school_id: schoolId,
        p_student_id: studentId,
        p_course_id: activePlan.value.course_id,
        p_subject_id: activePlan.value.subject_id,
        p_lesson_plan_id: activePlan.value.id,
        p_payload: payload,
      })

      if (error) throw error
      const saved = data?.plan
      if (!data?.success || !saved?.id
        || saved.school_id !== schoolId
        || saved.student_id !== studentId
        || saved.lesson_plan_id !== activePlan.value.id) {
        throw new Error('No se confirmó el guardado del plan de apoyo.')
      }
      activeSupportPlans.value.unshift(saved)
      showSupportModal.value = false
      toast.success(`Plan de apoyo pedagógico para ${targetStudent?.full_name || 'el estudiante'} registrado.`)
    } catch (err) {
      toast.error('Error generando plan de apoyo: ' + err.message)
    } finally {
      generating.value = false
    }
  }

  // Acciones en Documentos
  const openPlanViewer = async (plan) => {
    activePlan.value = { ...plan }
    showViewerModal.value = true
    if (plan.course_id) {
      await fetchStudentsForCourse(plan.course_id)
    }
  }

  const deletePlan = async (planId) => {
    try {
      const { data, error } = await supabase.from('lesson_plans').delete().eq('id', planId).select('id')
      if (error) throw error
      if (!data?.some(plan => plan.id === planId)) throw new Error('No se confirmó la eliminación de la planificación.')
      lessonPlans.value = lessonPlans.value.filter(p => p.id !== planId)
      if (activePlan.value?.id === planId) {
        showViewerModal.value = false
        activePlan.value = null
      }
      toast.success('Planificación eliminada.')
    } catch (err) {
      toast.error('Error al eliminar: ' + err.message)
    }
  }

  const duplicatePlan = async (plan) => {
    try {
      const copy = {
        ...plan,
        title: `${plan.title} (Copia)`,
        status: 'borrador',
        version: 1,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
      delete copy.id

      const { data, error } = await supabase.from('lesson_plans').insert(copy).select().single()
      if (error) throw error
      if (!data?.id) throw new Error('No se confirmó la duplicación de la planificación.')
      const saved = data
      lessonPlans.value.unshift(saved)
      toast.success('Planificación duplicada correctamente.')
    } catch (err) {
      toast.error('Error al duplicar: ' + err.message)
    }
  }

  return {
    loading,
    loadError,
    generating,
    saving,
    moduleAccess,
    lessonPlans,
    filteredLessonPlans,
    courses,
    subjects,
    students,
    institutionConfig,
    stats,
    searchQuery,
    selectedCourseFilter,
    selectedSubjectFilter,
    selectedStatusFilter,
    showWizardModal,
    showViewerModal,
    showResourceModal,
    showSupportModal,
    showPrintModal,
    showSettingsModal,
    activePlan,
    activeResources,
    activeSupportPlans,
    selectedStudentForSupport,
    wizardStep,
    wizardData,
    fetchInitialData,
    fetchStudentsForCourse,
    onGradeChange,
    openWizard,
    nextStep,
    prevStep,
    generatePlanWithAI,
    saveActivePlan,
    regenerateSingleSection,
    createResource,
    createStudentSupport,
    openPlanViewer,
    deletePlan,
    duplicatePlan,
    submitFeedback
  }
}
