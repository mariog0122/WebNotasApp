/**
 * Gateway de Inteligencia Artificial para el Módulo de Planificación
 * Orquesta la selección de proveedor (Demo vs Gemini), anonimización de datos estudiantiles,
 * registro de telemetría y cuotas de consumo por institución.
 */

import { DemoEducationAIProvider } from './DemoEducationAIProvider'
import { GeminiEducationAIProvider } from './GeminiEducationAIProvider'
import { OpenAIEducationAIProvider } from './OpenAIEducationAIProvider'
import { AI_PROVIDERS, AI_TASK_TYPES } from './types'
import { supabase } from '../supabase'
import { KnowledgePromotionService } from './KnowledgePromotionService'
import { AIContextBuilder } from './AIContextBuilder'
import { AIPrivacySanitizer } from './AIPrivacySanitizer'

export class EducationAIGateway {
  constructor(options = {}) {
    this.schoolId = options.schoolId || null
    this.userId = options.userId || null
    this.providerType = options.providerType || AI_PROVIDERS.DEMO
    this.apiKey = options.apiKey || null
    this.model = options.model || (this.providerType === 'openai' ? 'gpt-5.6-luna' : 'gemini-2.5-flash')
    this.isDemo = options.isDemo !== undefined ? options.isDemo : (this.providerType === AI_PROVIDERS.DEMO || !this.apiKey)

    this.demoProvider = new DemoEducationAIProvider()
    this.geminiProvider = (this.apiKey && this.providerType === 'gemini') ? new GeminiEducationAIProvider(this.apiKey, this.model) : null
    this.openaiProvider = (this.apiKey && this.providerType === 'openai') ? new OpenAIEducationAIProvider(this.apiKey, this.model) : null
  }

  get activeProvider() {
    if (!this.isDemo && this.apiKey) {
      if (this.providerType === 'openai' && this.openaiProvider) {
        return this.openaiProvider
      }
      if (this.providerType === 'gemini' && this.geminiProvider) {
        return this.geminiProvider
      }
    }
    return this.demoProvider
  }

  /**
   * Anonimiza datos estudiantiles sensibles antes de invocar cualquier modelo de IA
   */
  anonymizeStudentInput(input) {
    if (!input) return { sanitizedInput: input, reverseMap: new Map() }
    const reverseMap = new Map()

    const sanitized = { ...input }
    if (sanitized.studentName) {
      const token = '[ESTUDIANTE_ANONIMO]'
      reverseMap.set(token, sanitized.studentName)
      sanitized.studentName = token
    }

    if (sanitized.studentId) {
      const token = '[ID_ANONIMO]'
      reverseMap.set(token, sanitized.studentId)
      sanitized.studentId = token
    }

    return { sanitizedInput: sanitized, reverseMap }
  }

  /**
   * Rehidrata el resultado con los nombres reales en el cliente
   */
  rehydrateOutput(output, reverseMap) {
    if (!output || reverseMap.size === 0) return output
    let str = JSON.stringify(output)
    for (const [token, realVal] of reverseMap.entries()) {
      str = str.replaceAll(token, realVal)
    }
    try {
      return JSON.parse(str)
    } catch {
      return output
    }
  }

  /**
   * Registra el uso de IA en la tabla ai_usage_ledger de forma asíncrona no bloqueante
   */
  async logUsage(taskType, durationMs, status = 'success', errorMsg = null) {
    if (!this.schoolId) return
    try {
      await supabase.from('ai_usage_ledger').insert({
        school_id: this.schoolId,
        user_id: this.userId,
        task_type: taskType,
        provider: this.isDemo ? 'demo' : 'gemini',
        model_id: this.isDemo ? 'demo-pedagogico-ec' : this.model,
        prompt_tokens_estimated: 850,
        completion_tokens_estimated: 1200,
        duration_ms: durationMs,
        status: status,
        is_demo: this.isDemo
      })
    } catch (err) {
      console.warn('No se pudo registrar ledger de IA:', err)
    }
  }

  /**
   * Consulta lineamientos institucionales y ejemplos dorados mediante RAG delimitado
   */
  async getInstitutionalContext(subjectName, gradeYear, level) {
    if (!this.schoolId) return { has_context: false, guidelines: [], few_shot_examples: [] }
    try {
      const { data, error } = await supabase.rpc('get_institutional_ai_context', {
        p_school_id: this.schoolId,
        p_subject_name: subjectName,
        p_grade_year: gradeYear,
        p_level: level
      })
      if (!error && data) return data
    } catch (err) {
      console.warn('Fallback al consultar memoria institucional de IA:', err)
    }
    return { has_context: false, guidelines: [], few_shot_examples: [] }
  }

  /**
   * Generación de Planificación Didáctica (con soporte de RAG Institucional Seguro)
   */
  async generatePlan(input) {
    const startTime = Date.now()
    const { sanitizedInput, reverseMap } = this.anonymizeStudentInput(input)

    // Consultar contexto institucional si no vino explícito
    if (!sanitizedInput.institutionalMemory && this.schoolId) {
      sanitizedInput.institutionalMemory = await this.getInstitutionalContext(
        sanitizedInput.subjectName,
        sanitizedInput.gradeYear,
        sanitizedInput.level
      )
    }

    try {
      const result = await this.activeProvider.generatePlan(sanitizedInput)
      const durationMs = Date.now() - startTime
      await this.logUsage(AI_TASK_TYPES.PLAN_GENERATION, durationMs, 'success')
      return {
        ...this.rehydrateOutput(result, reverseMap),
        _meta: {
          provider: this.isDemo ? 'demo' : (this.providerType === 'openai' ? 'openai' : 'gemini'),
          model: this.isDemo ? 'demo-pedagogico-ec' : this.model,
          isDemo: this.isDemo,
          hasInstitutionalMemory: Boolean(sanitizedInput.institutionalMemory?.has_context),
          durationMs,
          generatedAt: new Date().toISOString()
        }
      }
    } catch (err) {
      const durationMs = Date.now() - startTime
      await this.logUsage(AI_TASK_TYPES.PLAN_GENERATION, durationMs, 'error', err.message)
      throw err
    }
  }

  /**
   * Registra retroalimentación docente sobre una planificación o recurso
   */
  async submitFeedback(payload = {}, options = {}) {
    return await KnowledgePromotionService.submitFeedback({
      schoolId: this.schoolId,
      userId: this.userId,
      ...payload
    }, options)
  }

  /**
   * Regeneración de una sección individual
   */
  async regenerateSection(input, sectionKey) {
    const startTime = Date.now()
    const { sanitizedInput, reverseMap } = this.anonymizeStudentInput(input)

    try {
      const result = await this.activeProvider.regenerateSection(sanitizedInput, sectionKey)
      const durationMs = Date.now() - startTime
      await this.logUsage(AI_TASK_TYPES.SECTION_REGENERATION, durationMs, 'success')
      return this.rehydrateOutput(result, reverseMap)
    } catch (err) {
      const durationMs = Date.now() - startTime
      await this.logUsage(AI_TASK_TYPES.SECTION_REGENERATION, durationMs, 'error', err.message)
      throw err
    }
  }

  /**
   * Generación de Recursos Didácticos
   */
  async generateResource(input) {
    const startTime = Date.now()
    const { sanitizedInput, reverseMap } = this.anonymizeStudentInput(input)

    try {
      const result = await this.activeProvider.generateResource(sanitizedInput)
      const durationMs = Date.now() - startTime
      await this.logUsage(AI_TASK_TYPES.RESOURCE_GENERATION, durationMs, 'success')
      return this.rehydrateOutput(result, reverseMap)
    } catch (err) {
      const durationMs = Date.now() - startTime
      await this.logUsage(AI_TASK_TYPES.RESOURCE_GENERATION, durationMs, 'error', err.message)
      throw err
    }
  }

  /**
   * Generación de Plan de Recuperación y Apoyo Pedagógico Individual
   */
  async generateStudentSupport(input) {
    const startTime = Date.now()
    const { sanitizedInput, reverseMap } = this.anonymizeStudentInput(input)

    try {
      const result = await this.activeProvider.generateStudentSupport(sanitizedInput)
      const durationMs = Date.now() - startTime
      await this.logUsage(AI_TASK_TYPES.STUDENT_SUPPORT_GENERATION, durationMs, 'success')
      return this.rehydrateOutput(result, reverseMap)
    } catch (err) {
      const durationMs = Date.now() - startTime
      await this.logUsage(AI_TASK_TYPES.STUDENT_SUPPORT_GENERATION, durationMs, 'error', err.message)
      throw err
    }
  }

  /**
   * Prueba de conexión con proveedor
   */
  async testConnection() {
    return await this.activeProvider.testConnection()
  }
}
