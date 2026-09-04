/**
 * Composable Principal para el Módulo de Planificación Educativa con IA (Ecuador)
 * Gestiona el asistente de 5 pasos, generación con IA (Demo/Gemini), edición granular,
 * creación de recursos, seguimiento estudiantil y exportación formal.
 */

import { ref, computed, reactive } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { toast } from 'vue-sonner'
import { EducationAIGateway } from '../lib/ai/EducationAIGateway'
import { getCurriculumItems, getSuggestedAgeForGrade } from '../lib/ecuadorCurriculumCatalog'

export function useAIPlanning() {
  const authStore = useAuthStore()

  // Estados de Carga y Acceso
  const loading = ref(false)
  const generating = ref(false)
  const saving = ref(false)
  const moduleAccess = ref({
    module_enabled: true,
    subscription_status: 'active',
    mode: 'managed',
    provider: 'gemini',
    ai_status: 'active',
    monthly_quota: 200,
    monthly_usage: 0,
    is_limit_reached: false
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
      const matchesSearch = !searchQuery.value ||
        plan.title.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
        plan.topic_title.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
        plan.subject_name.toLowerCase().includes(searchQuery.value.toLowerCase())

      const matchesCourse = !selectedCourseFilter.value || plan.course_id === selectedCourseFilter.value
      const matchesSubject = !selectedSubjectFilter.value || plan.subject_name.toLowerCase() === selectedSubjectFilter.value.toLowerCase()
      const matchesStatus = selectedStatusFilter.value === 'all' || plan.status === selectedStatusFilter.value

      return matchesSearch && matchesCourse && matchesSubject && matchesStatus
    })
  })

  // Verificación de Acceso al Módulo
  const checkAccess = async () => {
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!schoolId) return

    try {
      const { data, error } = await supabase.rpc('check_ai_planning_access', { p_school_id: schoolId })
      if (!error && data) {
        moduleAccess.value = data
      }
    } catch (err) {
      console.warn('Fallback al verificar acceso de IA:', err)
    }
  }

  // Carga de Cursos, Asignaturas, Estudiantes y Planes
  const fetchInitialData = async () => {
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!schoolId) return

    loading.value = true
    try {
      await checkAccess()

      const [coursesRes, subjectsRes, plansRes, cfgRes, resRes, suppRes] = await Promise.all([
        supabase.from('courses').select('id, name, level, parallel, academic_year').eq('school_id', schoolId).order('name'),
        supabase.from('subjects').select('id, name').eq('school_id', schoolId).order('name'),
        supabase.from('lesson_plans').select('*').eq('school_id', schoolId).order('created_at', { ascending: false }),
        supabase.from('system_config').select('key, value').eq('school_id', schoolId),
        supabase.from('lesson_plan_resources').select('*').eq('school_id', schoolId),
        supabase.from('student_support_plans').select('*').eq('school_id', schoolId)
      ])

      courses.value = coursesRes.data || []
      subjects.value = subjectsRes.data || []
      lessonPlans.value = plansRes.data || []
      activeResources.value = resRes.data || []
      activeSupportPlans.value = suppRes.data || []

      if (cfgRes.data) {
        institutionConfig.value = Object.fromEntries(cfgRes.data.map(i => [i.key, i.value]))
      }

      // Si no hay cursos en DB, precargar cursos demostrativos
      if (courses.value.length === 0) {
        courses.value = [
          { id: 'demo-c1', name: '6to Año EGB - Paralelo A', level: 'basica_media', parallel: 'A' },
          { id: 'demo-c2', name: '3ro Año EGB - Paralelo B', level: 'basica_elemental', parallel: 'B' },
          { id: 'demo-c3', name: '10mo Año EGB - Paralelo A', level: 'basica_superior', parallel: 'A' },
          { id: 'demo-c4', name: '1ro BGU - Paralelo A', level: 'bachillerato_general', parallel: 'A' }
        ]
      }
    } catch (err) {
      toast.error('Error cargando planificaciones: ' + err.message)
    } finally {
      loading.value = false
    }
  }

  // Carga de estudiantes de un curso
  const fetchStudentsForCourse = async (courseId) => {
    if (!courseId) {
      students.value = []
      return
    }

    try {
      const { data, error } = await supabase
        .from('students')
        .select('id, full_name, email, phone, is_active')
        .eq('course_id', courseId)
        .order('full_name')

      if (!error && data && data.length > 0) {
        students.value = data
      } else {
        // Fallback demostrativo contextualizado
        students.value = [
          { id: 'st-1', full_name: 'Alvarado Mendoza Carlos Andrés', status: 'normal' },
          { id: 'st-2', full_name: 'Baque Zambrano Elena Sofía', status: 'refuerzo_requerido' },
          { id: 'st-3', full_name: 'Cedeño Moreira Jonathan David', status: 'normal' },
          { id: 'st-4', full_name: 'García Loor Doménica Valentina', status: 'adecuacion_activa' },
          { id: 'st-5', full_name: 'Paredes Intriago Mateo Alexander', status: 'recuperacion_pendiente' },
          { id: 'st-6', full_name: 'Vera Quimi Ariana Nicole', status: 'normal' }
        ]
      }
    } catch {
      students.value = []
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
    wizardStep.value = 1
    showWizardModal.value = true
  }

  const nextStep = () => {
    if (wizardStep.value < 5) wizardStep.value++
  }

  const prevStep = () => {
    if (wizardStep.value > 1) wizardStep.value--
  }

  // Inicialización del Gateway de IA
  const createAIGateway = async () => {
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
    let apiKey = null
    let mode = 'managed'
    let provider = 'gemini'
    let configuredModel = 'auto'

    try {
      const { data } = await supabase
        .from('institution_ai_settings')
        .select('*')
        .eq('school_id', schoolId)
        .maybeSingle()

      if (data) {
        mode = data.mode
        provider = data.provider || 'gemini'
        configuredModel = data.model_id || 'auto'
        apiKey = data.encrypted_api_key
      }
    } catch (e) {
      console.warn('Usando gateway default:', e)
    }

    // Resolver modelo según calidad elegida por el docente
    let effectiveModel = configuredModel
    const quality = wizardData.generation_quality || 'automatica'

    if (quality === 'economica') {
      effectiveModel = provider === 'openai' ? 'gpt-5.6-luna' : 'gemini-2.5-flash-lite'
    } else if (quality === 'alta_calidad') {
      effectiveModel = provider === 'openai' ? 'gpt-4o' : 'gemini-3.7-flash'
    } else {
      // Automática: Si está en 'auto', asignar modelo equilibrado por defecto
      if (effectiveModel === 'auto' || !effectiveModel) {
        effectiveModel = provider === 'openai' ? 'gpt-5.6-luna' : 'gemini-2.5-flash'
      }
    }

    return new EducationAIGateway({
      schoolId,
      userId: authStore.user?.id,
      providerType: provider,
      apiKey,
      model: effectiveModel,
      isDemo: mode === 'demo' || !apiKey
    })
  }

  // Generación de la Planificación con IA
  const generatePlanWithAI = async () => {
    generating.value = true
    try {
      let adaptedStudents = []
      if (wizardData.course_id) {
        try {
          const { data: stData } = await supabase
            .from('students')
            .select('id, full_name, has_adaptation, adaptation_grade, adaptation_details')
            .eq('course_id', wizardData.course_id)
            .eq('has_adaptation', true)
          if (stData && stData.length > 0) {
            adaptedStudents = stData
          }
        } catch (e) {
          console.warn('Error fetching adapted students for plan:', e)
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

      const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
      const newPlanPayload = {
        school_id: schoolId,
        teacher_id: authStore.user?.id || '00000000-0000-0000-0000-000000000000',
        course_id: wizardData.course_id || null,
        subject_id: wizardData.subject_id || null,
        academic_year: '2025-2026',
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

      // Guardar en Supabase o en memoria local
      const { data, error } = await supabase
        .from('lesson_plans')
        .insert(newPlanPayload)
        .select()
        .single()

      const savedPlan = data || { id: `local-${Date.now()}`, ...newPlanPayload, created_at: new Date().toISOString() }

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
    if (!activePlan.value) return
    saving.value = true

    try {
      const nextVersion = (activePlan.value.version || 1) + 1
      const updatePayload = {
        ...activePlan.value,
        version: nextVersion,
        updated_at: new Date().toISOString()
      }

      const { error } = await supabase
        .from('lesson_plans')
        .update(updatePayload)
        .eq('id', activePlan.value.id)

      if (!error) {
        // Registrar versión en historial
        await supabase.from('lesson_plan_versions').insert({
          lesson_plan_id: activePlan.value.id,
          version_number: nextVersion,
          snapshot_content: activePlan.value,
          change_summary: `Actualización manual de bloques pedagógicos (v${nextVersion})`,
          created_by: authStore.user?.id
        }).catch(() => {})

        // Si la planificación fue aprobada o marcada como lista, registrar diff como candidato a conocimiento
        if (activePlan.value.status === 'aprobada' || activePlan.value.status === 'lista') {
          try {
            const gateway = await createAIGateway()
            const studentNames = students.value.map(s => s.full_name).filter(Boolean)
            await gateway.submitFeedback({
              targetType: 'lesson_plan',
              targetId: activePlan.value.id,
              rating: 5,
              category: 'pedagogical',
              tags: ['aprobada_coordinacion', 'correccion_docente'],
              comment: `Plan v${nextVersion} consolidado y validado en aula.`,
              diffContent: {
                version: nextVersion,
                title: activePlan.value.title,
                topic: activePlan.value.topic_title,
                status: activePlan.value.status
              },
              knownStudentNames: studentNames
            }).catch(() => {})
          } catch {
            // No bloquear el guardado si falla el feedback asíncrono
          }
        }
      }

      activePlan.value.version = nextVersion
      const idx = lessonPlans.value.findIndex(p => p.id === activePlan.value.id)
      if (idx !== -1) lessonPlans.value[idx] = { ...activePlan.value }

      if (!silent) toast.success('Planificación guardada con éxito (v' + nextVersion + ')')
    } catch (err) {
      if (!silent) toast.error('Error guardando planificación: ' + err.message)
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
      await saveActivePlan(true)
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
        teacher_id: authStore.user?.id || '00000000-0000-0000-0000-000000000000',
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

      const saved = data || { id: `res-${Date.now()}`, ...payload }
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
        school_id: schoolId,
        lesson_plan_id: activePlan.value.id,
        student_id: studentId,
        teacher_id: authStore.user?.id || '00000000-0000-0000-0000-000000000000',
        course_id: activePlan.value.course_id,
        subject_id: activePlan.value.subject_id,
        support_type: supportData.supportType || 'refuerzo',
        observed_difficulty: supportData.observedDifficulty,
        evidence_type: supportData.evidenceType,
        intensity: supportData.intensity,
        duration_weeks: supportData.durationWeeks,
        proposed_actions: proposalResult,
        status: 'aprobado_docente',
        target_date: supportData.targetDate || new Date(Date.now() + 14 * 86400000).toISOString().slice(0, 10),
        approved_at: new Date().toISOString(),
        observations: supportData.observations || null,
        created_at: new Date().toISOString()
      }

      const { data, error } = await supabase
        .from('student_support_plans')
        .insert(payload)
        .select()
        .single()

      const saved = data || { id: `supp-${Date.now()}`, ...payload }
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
      await supabase.from('lesson_plans').delete().eq('id', planId)
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

      const { data } = await supabase.from('lesson_plans').insert(copy).select().single()
      const saved = data || { id: `local-${Date.now()}`, ...copy }
      lessonPlans.value.unshift(saved)
      toast.success('Planificación duplicada correctamente.')
    } catch (err) {
      toast.error('Error al duplicar: ' + err.message)
    }
  }

  return {
    loading,
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
