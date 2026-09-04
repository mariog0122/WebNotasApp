/**
 * Servicio de Clasificación de Retroalimentación Pedagógica
 * Asigna taxonomía, calcula nivel de confianza y determina reusabilidad.
 */

import { AI_FEEDBACK_CATEGORIES } from './types'

export class FeedbackClassificationService {
  /**
   * Clasifica automáticamente la categoría de feedback según texto y etiquetas
   */
  static classifyFeedback(text = '', explicitTags = [], diff = null) {
    const lower = (text || '').toLowerCase()
    const tags = Array.isArray(explicitTags) ? explicitTags.map(t => t.toLowerCase()) : []

    // 1. Clasificación por reglas léxicas y etiquetas
    if (tags.includes('metodologia') || /metodolog[ií]a|erca|dua|abp|cooperativo|secuencia/i.test(lower)) {
      return AI_FEEDBACK_CATEGORIES.METHODOLOGY
    }
    if (tags.includes('curriculo') || /dcd|criterio|indicador|destreza|mineduc|objetivo/i.test(lower)) {
      return AI_FEEDBACK_CATEGORIES.CURRICULUM
    }
    if (tags.includes('dificultad') || /complejo|b[aá]sico|edad|nivel|dif[ií]cil|f[aá]cil/i.test(lower)) {
      return AI_FEEDBACK_CATEGORIES.DIFFICULTY
    }
    if (tags.includes('formato') || /formato|instituci[oó]n|membrete|estructura|dise[nñ]o/i.test(lower)) {
      return AI_FEEDBACK_CATEGORIES.FORMAT
    }
    if (tags.includes('recurso') || /r[uú]brica|ficha|taller|cuestionario|material/i.test(lower)) {
      return AI_FEEDBACK_CATEGORIES.RESOURCE_QUALITY
    }
    if (tags.includes('error_conceptual') || /error|equivocaci[oó]n|dato|falso|incorrecto/i.test(lower)) {
      return AI_FEEDBACK_CATEGORIES.FACTUAL_ERROR
    }

    if (diff && Object.keys(diff).length > 0) {
      return AI_FEEDBACK_CATEGORIES.PEDAGOGICAL
    }

    return AI_FEEDBACK_CATEGORIES.PEDAGOGICAL
  }

  /**
   * Calcula el Confidence Score (0.00 a 1.00) y riesgo
   */
  static evaluateQuality(text = '', rating = 3, category = 'pedagogical', hasDiff = false) {
    let score = 0.50

    // Factor de longitud útil (entre 20 y 300 caracteres es ideal)
    const len = (text || '').trim().length
    if (len >= 20 && len <= 400) {
      score += 0.20
    } else if (len > 400) {
      score += 0.10 // Muy extenso, posible divagación
    }

    // Si tiene un diff estructurado de corrección docente, la confianza sube drásticamente (Ground Truth)
    if (hasDiff) {
      score += 0.25
    }

    // Consistencia de calificación (4 o 5 estrellas para ejemplos dorados, 1 o 2 para advertencias)
    if (rating === 5 || rating === 1) {
      score += 0.10
    }

    // Normalizar a rango [0.10, 0.99]
    score = Math.min(0.99, Math.max(0.10, parseFloat(score.toFixed(2))))

    // Determinar si es candidato reutilizable
    const reusable = (score >= 0.70 && (rating >= 4 || hasDiff))

    return {
      category,
      confidence: score,
      riskLevel: score < 0.40 ? 'medium' : 'low',
      reusable
    }
  }
}
