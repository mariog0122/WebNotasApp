import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { 
  EDUCATIONAL_REGIMES, 
  EDUCATIONAL_LEVELS, 
  MINEDUC_SUBJECTS, 
  BLOOM_LEVELS, 
  PEDAGOGICAL_METHODOLOGIES, 
  RESOURCE_TYPES, 
  STUDENT_SUPPORT_CATEGORIES, 
  getCurriculumItems, 
  getSuggestedAgeForGrade 
} from '../src/lib/ecuadorCurriculumCatalog'
import { DemoEducationAIProvider } from '../src/lib/ai/DemoEducationAIProvider'
import { EducationAIGateway } from '../src/lib/ai/EducationAIGateway'

describe('Módulo de Planificación Educativa con IA (Currículo Ecuador)', () => {
  const routerSource = readFileSync(resolve(__dirname, '../src/router/index.js'), 'utf8')
  const sidebarSource = readFileSync(resolve(__dirname, '../src/components/Sidebar.vue'), 'utf8')
  const migrationSource = readFileSync(resolve(__dirname, '../../migrations/49_ai_lesson_planning_module.sql'), 'utf8')
  const tenantsTabSource = readFileSync(resolve(__dirname, '../src/views/superadmin/TenantsTab.vue'), 'utf8')
  const wizardSource = readFileSync(resolve(__dirname, '../src/components/planning/PlanningWizardModal.vue'), 'utf8')
  const viewerSource = readFileSync(resolve(__dirname, '../src/components/planning/PlanningDocumentViewer.vue'), 'utf8')
  const mainViewSource = readFileSync(resolve(__dirname, '../src/views/AIPlanning.vue'), 'utf8')

  it('verifies Ecuadorian educational catalog structure and query filters', () => {
    expect(EDUCATIONAL_REGIMES).toHaveLength(2)
    expect(EDUCATIONAL_LEVELS.length).toBeGreaterThanOrEqual(5)
    expect(RESOURCE_TYPES).toHaveLength(19)
    expect(STUDENT_SUPPORT_CATEGORIES.length).toBeGreaterThanOrEqual(7)

    const items = getCurriculumItems({ level: 'basica_media', gradeYear: '6to_egb', subjectName: 'Matemáticas' })
    expect(items.length).toBeGreaterThan(0)
    expect(items[0].dcd_code).toMatch(/^M\./)
    expect(items[0].evaluation_criteria_code).toMatch(/^CE\.M\./)
    expect(items[0].evaluation_indicator_code).toMatch(/^I\.M\./)

    const ages = getSuggestedAgeForGrade('6to_egb')
    expect(ages.min).toBe(10)
    expect(ages.max).toBe(11)
  })

  it('generates rich deterministic ERCA and DUA plan with DemoEducationAIProvider', async () => {
    const demoProvider = new DemoEducationAIProvider()
    const plan = await demoProvider.generatePlan({
      topicTitle: 'Operaciones con Decimales',
      unitTitle: 'Unidad 1',
      subjectName: 'Matemáticas',
      gradeYear: '6to Año EGB',
      level: 'basica_media',
      durationMinutes: 45,
      sessionCount: 2,
      dcdCodes: ['M.3.1.28'],
      dcdDescriptions: ['Calcular operaciones con números decimales'],
      methodologyPrimary: 'ERCA'
    })

    expect(plan.summary).toBeDefined()
    expect(plan.didactic_sequence.methodology).toBe('ERCA')
    expect(plan.didactic_sequence.phases).toHaveLength(4)
    expect(plan.didactic_sequence.phases[0].phase_id).toBe('experiencia')
    expect(plan.didactic_sequence.phases[1].phase_id).toBe('reflexion')
    expect(plan.didactic_sequence.phases[2].phase_id).toBe('conceptualizacion')
    expect(plan.didactic_sequence.phases[3].phase_id).toBe('aplicacion')

    expect(plan.evaluation_plan.rubric.length).toBeGreaterThanOrEqual(3)
    expect(plan.inclusion_dua_plan.accommodations.length).toBeGreaterThanOrEqual(3)
  })

  it('regenerates single sections without modifying the full plan', async () => {
    const demoProvider = new DemoEducationAIProvider()
    const seq = await demoProvider.regenerateSection({
      topicTitle: 'Ecosistemas del Ecuador',
      subjectName: 'Ciencias Naturales',
      methodologyPrimary: 'ERCA'
    }, 'didactic_sequence')

    expect(seq.phases).toBeDefined()
    expect(seq.phases.length).toBe(4)
  })

  it('generates classroom resources and student support plans inheriting academic context', async () => {
    const demoProvider = new DemoEducationAIProvider()
    
    // Recurso: Ficha de trabajo
    const ficha = await demoProvider.generateResource({
      resourceType: 'ficha_trabajo',
      topicTitle: 'Fracciones y Decimales',
      subjectName: 'Matemáticas',
      difficultyLevel: 'medio'
    })
    expect(ficha.type).toBe('ficha_trabajo')
    expect(ficha.sections.length).toBeGreaterThanOrEqual(3)

    // Plan de apoyo individual
    const support = await demoProvider.generateStudentSupport({
      observedDifficulty: 'Cálculo de divisiones con decimales',
      evidenceType: 'calificacion',
      intensity: 'moderada',
      durationWeeks: 2
    })
    expect(support.weekly_plan).toHaveLength(2)
    expect(support.pedagogical_goals.length).toBeGreaterThan(0)
  })

  it('enforces student data anonymization before processing with AI Gateway', async () => {
    const gateway = new EducationAIGateway({ isDemo: true })
    const { sanitizedInput, reverseMap } = gateway.anonymizeStudentInput({
      studentName: 'Carlos Andrés Mendoza',
      studentId: 'uuid-12345',
      observedDifficulty: 'Comprensión lectora'
    })

    expect(sanitizedInput.studentName).toBe('[ESTUDIANTE_ANONIMO]')
    expect(sanitizedInput.studentId).toBe('[ID_ANONIMO]')
    expect(reverseMap.get('[ESTUDIANTE_ANONIMO]')).toBe('Carlos Andrés Mendoza')

    const rehydrated = gateway.rehydrateOutput({
      diagnostic: 'El estudiante [ESTUDIANTE_ANONIMO] presenta avances.'
    }, reverseMap)

    expect(rehydrated.diagnostic).toBe('El estudiante Carlos Andrés Mendoza presenta avances.')
  })

  it('registers /planificacion-ia route in router and nav item in Sidebar', () => {
    expect(routerSource).toContain("path: '/planificacion-ia'")
    expect(routerSource).toContain("name: 'planificacion-ia'")
    expect(sidebarSource).toContain("name: 'Planificación IA'")
    expect(sidebarSource).toContain("path: '/planificacion-ia'")
    expect(sidebarSource).toContain("ai-planning")
  })

  it('verifies SQL migration 49 creates lesson planning tables, RLS and RPCs', () => {
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.curriculum_catalogs')
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.curriculum_items')
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.lesson_plans')
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.lesson_plan_versions')
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.lesson_plan_resources')
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.student_support_plans')
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.institution_ai_settings')
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.ai_usage_ledger')
    expect(migrationSource).toContain('check_ai_planning_access')
    expect(migrationSource).toContain('lesson_plans_select')
    expect(migrationSource).toContain('lesson_plans_insert')
  })

  it('verifies SuperAdmin TenantsTab includes ai_planning module activation', () => {
    expect(tenantsTabSource).toContain("ai_planning: 'Planificación Educativa con IA (Ecuador)'")
    expect(tenantsTabSource).toContain("ai_planning: true")
  })

  it('verifies wizard and viewer components implement promptless experience and 6 tabs', () => {
    expect(wizardSource).toContain('Paso 1: Contexto Académico')
    expect(wizardSource).toContain('Paso 2: Propósito Curricular')
    expect(wizardSource).toContain('Paso 3: Diseño Metodológico')
    expect(wizardSource).toContain('Paso 4: Inclusión y DUA')
    expect(wizardSource).toContain('Paso 5: Revisión')

    expect(viewerSource).toContain("activeTab === 'resumen'")
    expect(viewerSource).toContain("activeTab === 'secuencia'")
    expect(viewerSource).toContain("activeTab === 'evaluacion'")
    expect(viewerSource).toContain("activeTab === 'inclusion'")
    expect(viewerSource).toContain("activeTab === 'recursos'")
    expect(viewerSource).toContain("activeTab === 'seguimiento'")

    expect(mainViewSource).toContain('Planificación Curricular con IA')
    expect(mainViewSource).toContain('PlanningPaywallBanner')
  })

  it('verifies support for Gemini 3.7 Flash, 2.5 Flash, 2.5 Flash-Lite, 2.5 Pro and OpenAI in AI modal and types', () => {
    const modalSource = readFileSync(resolve(__dirname, '../src/components/planning/InstitutionAISettingsModal.vue'), 'utf8')
    const typesSource = readFileSync(resolve(__dirname, '../src/lib/ai/types.js'), 'utf8')
    const wizardModalSource = readFileSync(resolve(__dirname, '../src/components/planning/PlanningWizardModal.vue'), 'utf8')

    // Admin models
    expect(modalSource).toContain('gemini-3.7-flash')
    expect(modalSource).toContain('gemini-2.5-flash')
    expect(modalSource).toContain('gemini-2.5-flash-lite')
    expect(modalSource).toContain('gemini-2.5-pro')
    expect(modalSource).toContain('gpt-5.6-luna')
    expect(modalSource).toContain('Automático — recomendado')
    expect(modalSource).toContain('Alta calidad — Gemini 3.7 Flash')
    expect(modalSource).toContain('Equilibrado — Gemini 2.5 Flash')
    expect(modalSource).toContain('Económico — Gemini 2.5 Flash-Lite')
    expect(modalSource).toContain('Revisión avanzada — Gemini 2.5 Pro')

    // Deprecated models eliminated
    expect(modalSource).not.toContain('gemini-1.5-flash')
    expect(modalSource).not.toContain('gemini-1.5-pro')
    expect(modalSource).not.toContain('gemini-2.0-flash')

    // Teacher simplified quality selector
    expect(wizardModalSource).toContain('Calidad de generación')
    expect(wizardModalSource).toContain('value="automatica"')
    expect(wizardModalSource).toContain('value="economica"')
    expect(wizardModalSource).toContain('value="alta_calidad"')
    expect(wizardModalSource).not.toContain('gemini-3.7-flash') // Technical model hidden from teacher

    // Types
    expect(typesSource).toContain('gemini-3.7-flash')
    expect(typesSource).toContain('gemini-2.5-flash')
    expect(typesSource).toContain('gemini-2.5-flash-lite')
    expect(typesSource).toContain('gemini-2.5-pro')
    expect(typesSource).toContain('gpt-5.6-luna')
  })
})
