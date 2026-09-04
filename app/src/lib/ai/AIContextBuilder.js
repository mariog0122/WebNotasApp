/**
 * Ensamblador Centralizado de Contexto de IA (AI Context Builder)
 * Combina exclusivamente datos curriculares autorizados, memoria institucional y preferencias docentes
 * aplicando límites estrictos de contexto para evitar desbordamiento de tokens y contaminación de prompts.
 */

import { PromptRegistry } from './PromptRegistry'
import { AIPrivacySanitizer } from './AIPrivacySanitizer'

export class AIContextBuilder {
  /**
   * Límite estricto de caracteres para memoria institucional (~400 tokens aprox.)
   */
  static MAX_INSTITUTIONAL_CHARS = 1600

  /**
   * Construye el contexto pedagógico autorizado para la generación de un plan didáctico
   */
  static buildPlanningContext(params = {}) {
    const {
      topicTitle = '',
      unitTitle = '',
      subjectName = '',
      gradeYear = '',
      level = '',
      regime = 'costa_galapagos',
      durationMinutes = 45,
      sessionCount = 2,
      dcdDescriptions = [],
      evaluationCriteriaDescriptions = [],
      evaluationIndicators = [],
      learningObjectives = [],
      methodologyPrimary = 'ERCA',
      bloomLevel = 'comprender',
      duaPrinciples = [],
      institutionalMemory = null,
      teacherPreferences = null
    } = params

    // 1. Contexto Curricular Oficial
    const curriculumBlock = [
      `ASIGNATURA: ${subjectName}`,
      `NIVEL EDUCATIVO: ${level} (${gradeYear})`,
      `RÉGIMEN ESCOLAR: ${regime}`,
      `TÍTULO DE LA UNIDAD: ${unitTitle}`,
      `TEMA DE LA CLASE: ${topicTitle}`,
      `DURACIÓN: ${durationMinutes} minutos (${sessionCount} sesiones)`,
      `NIVEL COGNITIVO BLOOM: ${bloomLevel}`,
      `METODOLOGÍA PRINCIPAL: ${methodologyPrimary}`,
      dcdDescriptions.length > 0 ? `DESTREZAS DCD:\n- ${dcdDescriptions.join('\n- ')}` : '',
      evaluationCriteriaDescriptions.length > 0 ? `CRITERIOS DE EVALUACIÓN:\n- ${evaluationCriteriaDescriptions.join('\n- ')}` : '',
      evaluationIndicators.length > 0 ? `INDICADORES DE EVALUACIÓN:\n- ${evaluationIndicators.join('\n- ')}` : '',
      learningObjectives.length > 0 ? `OBJETIVOS DE APRENDIZAJE:\n- ${learningObjectives.join('\n- ')}` : '',
      duaPrinciples.length > 0 ? `PRINCIPIOS DUA PRIORIZADOS: ${duaPrinciples.join(', ')}` : ''
    ].filter(Boolean).join('\n\n')

    // 2. Contexto Institucional Delimitado (RAG Level 2)
    let institutionalBlock = ''
    if (institutionalMemory && institutionalMemory.has_context) {
      const guidelines = []

      if (Array.isArray(institutionalMemory.guidelines)) {
        for (const g of institutionalMemory.guidelines.slice(0, 2)) {
          if (g.title) {
            guidelines.push(`- [Lineamiento ${g.title}]: ${JSON.stringify(g.guideline || '')}`)
          }
        }
      }

      if (Array.isArray(institutionalMemory.few_shot_examples)) {
        for (const f of institutionalMemory.few_shot_examples.slice(0, 1)) {
          if (f.title) {
            guidelines.push(`- [Ejemplo Modelo Aprobado ${f.title}]: ${JSON.stringify(f.example || '')}`)
          }
        }
      }

      if (guidelines.length > 0) {
        let rawText = guidelines.join('\n')
        // Truncar si excede el presupuesto estricto
        if (rawText.length > AIContextBuilder.MAX_INSTITUTIONAL_CHARS) {
          rawText = rawText.substring(0, AIContextBuilder.MAX_INSTITUTIONAL_CHARS) + '... [Límite de contexto RAG aplicado]'
        }

        const template = PromptRegistry.getActivePrompt('rag-institutional-template')?.template ||
          'Lineamientos institucionales aprendidos:\n{{INSTITUTIONAL_GUIDELINES}}'

        institutionalBlock = '\n\n' + template.replace('{{INSTITUTIONAL_GUIDELINES}}', rawText)
      }
    }

    // 3. Preferencias del Docente (Level 1)
    let teacherBlock = ''
    if (teacherPreferences && typeof teacherPreferences === 'object') {
      const prefItems = []
      if (teacherPreferences.pacing) prefItems.push(`Ritmo preferido: ${teacherPreferences.pacing}`)
      if (teacherPreferences.grouping) prefItems.push(`Organización de aula: ${teacherPreferences.grouping}`)
      if (prefItems.length > 0) {
        teacherBlock = `\n\n[PREFERENCIAS DOCENTES VERIFICADAS]:\n${prefItems.join('\n')}`
      }
    }

    // 4. Prompt de Sistema Versionado
    const systemInstruction = PromptRegistry.getActivePrompt('planning-generator')?.template || ''

    const finalUserPrompt = `${curriculumBlock}${institutionalBlock}${teacherBlock}`

    // Sanitización final antes del envío
    const { sanitizedText } = AIPrivacySanitizer.redactPII(finalUserPrompt)

    return {
      systemInstruction,
      userPrompt: sanitizedText,
      contextBudget: {
        curriculumLength: curriculumBlock.length,
        institutionalLength: institutionalBlock.length,
        teacherLength: teacherBlock.length,
        totalLength: sanitizedText.length
      }
    }
  }
}
