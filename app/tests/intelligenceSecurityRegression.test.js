import { beforeEach, describe, expect, it, vi } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'
import { createPinia, setActivePinia } from 'pinia'

const mock = vi.hoisted(() => ({
  from: vi.fn(),
  rpc: vi.fn(),
}))

vi.mock('../src/lib/supabase', () => ({
  supabase: {
    from: mock.from,
    rpc: mock.rpc,
  },
}))

import { intelligenceService } from '../src/modules/intelligence/services/intelligenceService'
import { useIntelligenceStore } from '../src/modules/intelligence/stores/useIntelligenceStore'

const query = (response) => {
  const chain = {
    then: (resolve, reject) => Promise.resolve(response).then(resolve, reject),
  }
  for (const method of ['select', 'insert', 'upsert', 'eq', 'in', 'ilike', 'order']) {
    chain[method] = vi.fn(() => chain)
  }
  return chain
}

beforeEach(() => {
  vi.clearAllMocks()
  setActivePinia(createPinia())
  mock.from.mockReturnValue(query({ data: null, error: new Error('database unavailable') }))
  mock.rpc.mockResolvedValue({ data: null, error: new Error('permission denied') })
})

describe('intelligence module authorization and persistence', () => {
  it('uses the canonical reports.read permission for the management analytics route', () => {
    const routes = readFileSync(
      new URL('../src/modules/intelligence/router/routes.js', import.meta.url),
      'utf8',
    )

    expect(routes).toContain("permission: 'reports.read'")
    expect(routes).not.toContain("permission: 'reports.view'")
  })

  it('does not present fictional students when a real course cannot be loaded', async () => {
    const cockpit = await intelligenceService.getTeacherCockpitData(null, 'school-1')

    expect(cockpit.hasRealData).toBe(false)
    expect(cockpit.totalStudents).toBe(0)
    expect(cockpit.students).toEqual([])
    expect(cockpit.pedagogicalGroups).toEqual([])
  })

  it('does not replace a failed competency catalog with built-in curriculum data', async () => {
    await expect(intelligenceService.getCompetencies('Matemática'))
      .rejects.toThrow('database unavailable')
  })

  it('does not present a failed grade synchronization as a completed operation', async () => {
    await expect(intelligenceService.syncCourseGapsFromGrades({
      schoolId: 'school-1',
      courseId: 'course-1',
      courseSubjectId: 'subject-1',
    })).rejects.toThrow('permission denied')

    const store = useIntelligenceStore()
    await expect(store.syncFromGrades('school-1', 'course-1', 'subject-1'))
      .rejects.toThrow('permission denied')
  })

  it('calculates course mastery from recorded mastery evidence', async () => {
    const tableData = {
      competencies: [{ id: 'comp-1', code: 'C.1', name: 'Competencia', subject_area: 'Matemática' }],
      students: [
        { id: 'student-1', full_name: 'Ana' },
        { id: 'student-2', full_name: 'Luis' },
      ],
      learning_gaps: [],
      interventions: [],
      mastery_state: [{ student_id: 'student-1', competency_id: 'comp-1', state: 'MASTERED' }],
    }
    mock.from.mockImplementation(table => query({ data: tableData[table], error: null }))

    const cockpit = await intelligenceService.getTeacherCockpitData(
      'course-1',
      'school-1',
      'Matemática',
    )

    expect(cockpit.radarStats[0]).toMatchObject({
      assessedStudents: 1,
      masteredStudents: 1,
      masteryRate: 0.5,
    })
  })

  it('fails closed when assigning an intervention is not persisted', async () => {
    await expect(intelligenceService.assignPedagogicalIntervention({
      schoolId: 'school-1',
      interventionId: 'intervention-1',
      courseId: 'course-1',
      studentIds: ['student-1'],
      notes: 'Refuerzo',
    })).rejects.toThrow('permission denied')
  })

  it('fails closed when a reevaluation is not persisted', async () => {
    await expect(intelligenceService.completeInterventionReevaluation({
      schoolId: 'school-1',
      runId: 'run-1',
      studentId: 'student-1',
      competencyId: 'competency-1',
      score: 0.9,
    })).rejects.toThrow('permission denied')
  })

  it('requires a persisted intervention run before recording a reevaluation', async () => {
    await expect(intelligenceService.completeInterventionReevaluation({
      schoolId: 'school-1',
      runId: null,
      studentId: 'student-1',
      competencyId: 'competency-1',
      score: 0.9,
    })).rejects.toThrow('La intervención debe estar asignada antes de reevaluar.')
  })

  it('does not keep a client-side path that writes diagnostic evidence directly', () => {
    const service = readFileSync(
      new URL('../src/modules/intelligence/services/intelligenceService.js', import.meta.url),
      'utf8',
    )

    expect(service).not.toContain('recordEvidence(')
    expect(service).not.toMatch(/from\(['"]student_evidence['"]\)[\s\S]{0,120}\.insert/)
  })

  it('keeps the feature disabled when its tenant state cannot be verified', async () => {
    await expect(intelligenceService.checkModuleEnabled({ schoolId: null })).resolves.toBe(false)
    await expect(intelligenceService.checkModuleEnabled({ schoolId: 'school-1' })).resolves.toBe(false)
  })

  it('does not advance a diagnostic session when its evidence was not saved', async () => {
    const store = useIntelligenceStore()
    store.currentSession = {
      isActive: true,
      items: [{ id: 'item-1', correct_answer: 'A', competency_id: 'competency-1' }],
      currentIndex: 0,
      userAnswers: {},
      sessionResults: null,
      score: 0,
    }

    await expect(store.submitAnswer('A', 'student-1', 'school-1')).rejects.toThrow('permission denied')
    expect(store.currentSession.userAnswers).toEqual({})
    expect(store.currentSession.currentIndex).toBe(0)
    expect(store.currentSession.sessionResults).toBeNull()
  })

  it('requires a real student selection before starting a diagnostic', () => {
    const diagnostic = readFileSync(
      new URL('../src/modules/intelligence/views/DiagnosticSessionView.vue', import.meta.url),
      'utf8',
    )
    const cockpit = readFileSync(
      new URL('../src/modules/intelligence/views/TeacherCockpitView.vue', import.meta.url),
      'utf8',
    )

    expect(diagnostic).toContain('route.query.studentId')
    expect(diagnostic).not.toContain("'eval-session'")
    expect(cockpit).toContain("name: 'intelligence-diagnostico'")
    expect(cockpit).toContain('studentId: std.id')
    expect(cockpit).toContain('subject: store.selectedSubject')
    expect(cockpit).toContain('gradeLevel: selectedCourseLevel')
    expect(diagnostic).toContain('route.query.subject')
    expect(diagnostic).toContain('route.query.gradeLevel')
    expect(diagnostic).not.toContain('Nivel Medio')
  })

  it('hardens every privileged intelligence RPC against anonymous and cross-tenant access', () => {
    const migrationUrl = new URL(
      '../../supabase/migrations/20260915153000_harden_intelligence_module_authorization.sql',
      import.meta.url,
    )
    expect(existsSync(migrationUrl)).toBe(true)

    const migration = readFileSync(migrationUrl, 'utf8')
    expect(migration).toContain('private.has_intelligence_permission')
    expect(migration).toContain("private.has_intelligence_permission(p_school_id, 'reports.read')")
    expect(migration).toContain("private.has_intelligence_permission(p_school_id, 'grades.update')")
    expect(migration).toContain("private.has_intelligence_permission(p_school_id, 'students.read')")
    expect(migration).toContain('public.get_intelligence_diagnostic_items')
    expect(migration).toContain('public.submit_intelligence_diagnostic_answer')
    expect(migration).toContain('public.get_socratic_rag_context')
    expect(migration).toContain('public.record_intelligence_ai_trace')
    expect(migration).toContain("'assigned_runs', v_assigned_runs")
    expect(migration).toContain("raise exception 'INTERVENTION_RUN_REQUIRED'")
    expect(migration).toContain('join public.interventions assigned_intervention')
    expect(migration).toContain("run.outcome = 'in_progress'")
    expect(migration).toContain('v_health_index numeric(5,2) := 0')
    expect(migration).toContain('with student_summary as')
    expect(migration).toContain('revoke select on public.assessment_items from anon, authenticated')
    expect(migration).toContain("raise exception 'AUTHENTICATION_REQUIRED'")
    expect(migration).toContain('from public, anon')
    expect(migration).not.toMatch(/grant execute[^;]+to authenticated\s*,\s*anon/is)
  })

  it('loads diagnostic questions through a server contract that never exposes answers', async () => {
    mock.rpc.mockResolvedValueOnce({
      data: [{
        id: 'item-1',
        stem: 'Pregunta segura',
        options: [{ key: 'A', text: 'Opción' }],
        competency_id: 'competency-1',
      }],
      error: null,
    })

    const items = await intelligenceService.getDiagnosticItems('Matemática', {
      schoolId: 'school-1',
      gradeLevel: 'Media',
    })

    expect(mock.rpc).toHaveBeenCalledWith('get_intelligence_diagnostic_items', {
      p_school_id: 'school-1',
      p_subject_area: 'Matemática',
      p_grade_level: 'Media',
    })
    expect(items[0]).not.toHaveProperty('correct_answer')
  })

  it('stops with an explicit error when the diagnostic bank has no suitable items', async () => {
    mock.rpc.mockResolvedValueOnce({ data: [], error: null })

    await expect(intelligenceService.getDiagnosticItems('Ciencias Naturales', {
      schoolId: 'school-1',
      gradeLevel: 'Básica Superior',
    })).rejects.toThrow('No hay preguntas diagnósticas disponibles para la asignatura y el nivel seleccionados.')
  })

  it('scores diagnostic answers on the server before changing local progress', async () => {
    mock.rpc.mockResolvedValueOnce({
      data: { success: true, is_correct: true, score: 1 },
      error: null,
    })
    const store = useIntelligenceStore()
    store.currentSession = {
      isActive: true,
      items: [{ id: 'item-1', competency_id: 'competency-1' }],
      currentIndex: 0,
      userAnswers: {},
      sessionResults: null,
      score: 0,
    }

    await store.submitAnswer('A', 'student-1', 'school-1')

    expect(mock.rpc).toHaveBeenCalledWith('submit_intelligence_diagnostic_answer', {
      p_school_id: 'school-1',
      p_student_id: 'student-1',
      p_assessment_item_id: 'item-1',
      p_answer: 'A',
    })
    expect(store.currentSession.userAnswers['item-1']).toEqual({
      selected: 'A',
      isCorrect: true,
      score: 1,
    })
  })

  it('does not replace failed analytics or passports with fabricated success data', async () => {
    await expect(intelligenceService.fetchImpactAnalytics({ schoolId: 'school-1' }))
      .rejects.toThrow('permission denied')
    await expect(intelligenceService.fetchStudentLongitudinalPassport({
      schoolId: 'school-1',
      studentId: 'student-1',
    })).rejects.toThrow('permission denied')
  })

  it('enforces the institutional feature flag in routes and navigation', () => {
    const router = readFileSync(new URL('../src/router/index.js', import.meta.url), 'utf8')
    const routes = readFileSync(
      new URL('../src/modules/intelligence/router/routes.js', import.meta.url),
      'utf8',
    )
    const sidebar = readFileSync(new URL('../src/components/Sidebar.vue', import.meta.url), 'utf8')

    expect(routes.match(/intelligenceFeature:\s*true/g)).toHaveLength(4)
    expect(router).toContain('to.meta.intelligenceFeature')
    expect(router).toContain('checkModuleEnabled')
    expect(sidebar).toContain('intelligenceEnabled')
    expect(sidebar).toMatch(/can\('reports\.read'\)[\s\S]{0,120}intelligenceEnabled/)
  })

  it('keeps the feature flag check out of the main intelligence bundle', () => {
    const router = readFileSync(new URL('../src/router/index.js', import.meta.url), 'utf8')
    const sidebar = readFileSync(new URL('../src/components/Sidebar.vue', import.meta.url), 'utf8')

    expect(router).toContain("intelligenceFeatureService")
    expect(sidebar).toContain("intelligenceFeatureService")
    expect(router).not.toContain("services/intelligenceService")
    expect(sidebar).not.toContain("services/intelligenceService")
  })

  it('shows explicit error states instead of leaving intelligence screens with false zeroes', () => {
    const impact = readFileSync(
      new URL('../src/modules/intelligence/views/ImpactAnalyticsView.vue', import.meta.url),
      'utf8',
    )
    const passport = readFileSync(
      new URL('../src/modules/intelligence/views/LearningPassportView.vue', import.meta.url),
      'utf8',
    )
    const cockpit = readFileSync(
      new URL('../src/modules/intelligence/views/TeacherCockpitView.vue', import.meta.url),
      'utf8',
    )

    expect(impact).toContain('loadError')
    expect(impact).toContain('v-if="loadError"')
    expect(passport).toContain('loadError')
    expect(passport).toContain('v-else-if="loadError"')
    expect(cockpit).toContain('store.loadError')
    expect(impact).toContain('institutionalRecommendation')
    expect(impact).not.toContain('evidencia progreso sostenido')
  })

  it('persists an intervention before enabling its classroom reevaluation', () => {
    const cockpit = readFileSync(
      new URL('../src/modules/intelligence/views/TeacherCockpitView.vue', import.meta.url),
      'utf8',
    )

    expect(cockpit).toContain('await intelligenceService.assignPedagogicalIntervention')
    expect(cockpit).toContain('runIdsByStudent')
    expect(cockpit).toContain('group.suggestedIntervention.isPersisted')
    expect(cockpit).not.toContain('<span>Aplicar Mañana</span>')
  })

  it('does not equate the absence of a registered gap with proven mastery', () => {
    const cockpit = readFileSync(
      new URL('../src/modules/intelligence/views/TeacherCockpitView.vue', import.meta.url),
      'utf8',
    )

    expect(cockpit).toContain('item.assessedStudents')
    expect(cockpit).toContain('Sin brechas activas registradas')
    expect(cockpit).not.toContain("'100% Dominado'")
    expect(cockpit).not.toContain('Competencias demostradas con evidencia estable.')
  })

  it('renders intervention instructions from the selected catalog entry', () => {
    const cockpit = readFileSync(
      new URL('../src/modules/intelligence/views/TeacherCockpitView.vue', import.meta.url),
      'utf8',
    )

    expect(cockpit).toContain('interventionPlanSteps')
    expect(cockpit).toContain('resource_payload')
    expect(cockpit).not.toContain('tiras fraccionarias')
    expect(cockpit).not.toContain('Pizarra interactiva con 2 ejemplos')
  })

  it('builds the learning passport only from the real student context', () => {
    const passport = readFileSync(
      new URL('../src/modules/intelligence/views/LearningPassportView.vue', import.meta.url),
      'utf8',
    )

    expect(passport).toContain('studentData.courseName')
    expect(passport).toContain('homeSupportRecommendations')
    expect(passport).toContain('globalStatus')
    expect(passport).not.toContain('Año Lectivo 2026-2027')
    expect(passport).not.toContain('Educación General Básica Media')
    expect(passport).not.toContain('Juegos con recetas o compras')
  })
})
