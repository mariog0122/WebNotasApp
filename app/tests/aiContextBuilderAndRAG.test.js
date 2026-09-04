import { describe, it, expect } from 'vitest'
import { PromptRegistry } from '../src/lib/ai/PromptRegistry'
import { AIContextBuilder } from '../src/lib/ai/AIContextBuilder'
import { EducationAIGateway } from '../src/lib/ai/EducationAIGateway'

describe('RAG y Orquestación: Context Builder, Prompt Registry y Gateway', () => {
  it('manages versioned prompts and supports rollback without hardcoding', () => {
    const active = PromptRegistry.getActivePrompt('planning-generator')
    expect(active).toBeDefined()
    expect(active.version).toBe(1)
    expect(active.template).toContain('Currículo Nacional')

    // Registrar versión 2
    PromptRegistry.registerVersion('planning-generator', 2, {
      template: 'Prompt v2 experimental para evaluación docente.',
      active: true,
      description: 'Versión v2'
    })

    const newActive = PromptRegistry.getActivePrompt('planning-generator')
    expect(newActive.version).toBe(2)

    // Rollback a versión 1
    const rolledBack = PromptRegistry.rollbackVersion('planning-generator', 1)
    expect(rolledBack.version).toBe(1)
    expect(PromptRegistry.getActivePrompt('planning-generator').version).toBe(1)
  })

  it('builds bounded planning context incorporating RAG memory strictly within limits', () => {
    const mockInstitutionalMemory = {
      has_context: true,
      guidelines: [
        { title: 'ABP_Prioritario', guideline: 'Enfocar aplicación en problemas del entorno local.' }
      ],
      few_shot_examples: [
        { title: 'Matemáticas_6to_Decimales', example: { phase: 'aplicacion', dynamic: 'Tienda escolar' } }
      ]
    }

    const { systemInstruction, userPrompt, contextBudget } = AIContextBuilder.buildPlanningContext({
      topicTitle: 'Operaciones con Decimales',
      unitTitle: 'Unidad 1',
      subjectName: 'Matemáticas',
      gradeYear: '6to_egb',
      level: 'basica_media',
      institutionalMemory: mockInstitutionalMemory
    })

    expect(systemInstruction).toContain('Currículo Nacional')
    expect(userPrompt).toContain('ASIGNATURA: Matemáticas')
    expect(userPrompt).toContain('ABP_Prioritario')
    expect(userPrompt).toContain('Tienda escolar')
    expect(contextBudget.institutionalLength).toBeLessThanOrEqual(AIContextBuilder.MAX_INSTITUTIONAL_CHARS + 200)
  })

  it('verifies EducationAIGateway generates plan preserving meta and supporting feedback submission', async () => {
    const gateway = new EducationAIGateway({ isDemo: true, schoolId: 'test-school-1' })

    const plan = await gateway.generatePlan({
      topicTitle: 'Ecosistemas del Ecuador',
      subjectName: 'Ciencias Naturales',
      gradeYear: '7mo Año EGB',
      level: 'basica_media',
      dcdCodes: ['CN.3.1.1'],
      dcdDescriptions: ['Indagar los ecosistemas del Ecuador'],
      methodologyPrimary: 'ERCA'
    })

    expect(plan.summary).toBeDefined()
    expect(plan._meta).toBeDefined()
    expect(plan._meta.provider).toBe('demo')
    expect(plan._meta.hasInstitutionalMemory).toBeDefined()

    // Enviar feedback simulado
    const feedbackResult = await gateway.submitFeedback({
      targetType: 'lesson_plan',
      targetId: 'plan-test-123',
      rating: 5,
      category: 'pedagogical',
      tags: ['excelente'],
      comment: 'Muy buena contextualización de flora y fauna ecuatoriana.'
    })

    expect(feedbackResult.success).toBe(true)
    expect(feedbackResult.quality.reusable).toBe(true)
  })
})
