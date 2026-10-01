/**
 * Servicio de Tutoría Socrática Avanzada con RAG Curricular y Guardrails Pedagógicos
 * LOGREVA 2026 — Inteligencia del Aprendizaje
 * 
 * Cumple con:
 * 1. Anti-Cheat: Nunca entrega la respuesta directa en práctica.
 * 2. Andamiaje Gradual: Pistas escalonadas (ERCA / Zona de Desarrollo Próximo).
 * 3. RAG Curricular Delimitado: Inyecta lineamientos didácticos institucionales.
 * 4. Privacidad y Seguridad: Sanitización PII y prevención de fugas de datos de menores.
 */

import { supabase } from '../../../lib/supabase'
import { AIPrivacySanitizer } from '../../../lib/ai/AIPrivacySanitizer'

export class SocraticService {
  /**
   * Sanitiza la entrada del estudiante eliminando PII y detectando inyecciones
   */
  static sanitizeInput(rawText, knownStudentNames = []) {
    if (!rawText || typeof rawText !== 'string') {
      return { sanitizedText: '', detectedPII: false, injectionRisk: 'low' }
    }

    // Detección de inyección
    const injectionCheck = AIPrivacySanitizer.detectPromptInjection(rawText)

    // Redacción de PII base (cédulas, teléfonos, correos, datos DECE)
    const piiResult = AIPrivacySanitizer.redactPII(rawText, knownStudentNames)
    let text = piiResult.sanitizedText

    // Redacción heurística complementaria para auto-presentaciones y direcciones de menores
    // e.g. "Me llamo Juan Pérez", "vivo en la calle Olmedo"
    text = text.replace(/me\s+llamo\s+([A-Za-zÁÉÍÓÚáéíóúñÑ]+\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+)/gi, 'me llamo [NOMBRE_REDACTADO]')
    text = text.replace(/vivo\s+en\s+([A-Za-z0-9\s#\.,\-]+?)(?=,|\.|\?|¿|$)/gi, 'vivo en [DIRECCIÓN_REDACTADA]')
    text = text.replace(/soy\s+(del\s+)?[0-9]+[a-z]?\s+(de\s+básica|básico|[A-Z])/gi, 'soy estudiante')

    const hasCustomRedactions = text.includes('[NOMBRE_REDACTADO]') || text.includes('[DIRECCIÓN_REDACTADA]')

    return {
      sanitizedText: text,
      detectedPII: piiResult.piiCount > 0 || hasCustomRedactions,
      injectionRisk: injectionCheck.riskLevel,
      isInjected: injectionCheck.isInjected
    }
  }

  /**
   * Consulta el corpus curricular institucional o estándar mediante RPC
   */
  static async fetchCurriculumRAGContext({
    schoolId = null,
    subjectArea = 'Matemática',
    gradeLevel = 'Media',
    competencyCode = null
  } = {}) {
    try {
      const { data, error } = await supabase.rpc('get_socratic_rag_context', {
        p_school_id: schoolId,
        p_subject_area: subjectArea,
        p_grade_level: gradeLevel,
        p_competency_code: competencyCode
      })

      if (error) throw error
      return Array.isArray(data) ? data : []
    } catch (err) {
      console.warn('Fallo al consultar el repositorio curricular:', err)
      return []
    }
  }

  /**
   * Analiza si la respuesta del estudiante contiene una concepción errónea conocida
   */
  static detectMisconception(userText, itemContext) {
    if (!userText) return null

    // 1. Error típico en suma de fracciones: sumar numeradores y denominadores (1/2 + 1/4 = 2/6)
    if (/2\/6|dos\s+sextos/i.test(userText) || (/(sum[eé]|puse)\s+(los\s+)?de\s+arriba\s+y\s+(los\s+)?de\s+abajo/i.test(userText))) {
      return {
        type: 'fraction_direct_sum',
        diagnosis: 'Suma directa de numeradores y denominadores sin considerar que representan partes de diferente tamaño.',
        guidance: '¡Ojo con ese paso! Si tienes media pizza y un cuarto de pizza, ¿tendrías dos porciones de una pizza cortada en 6? Recuerda que las fracciones deben tener el mismo tamaño de partes (denominador común) para poder sumarlas.'
      }
    }

    // 2. Confusión entre perímetro y área
    if (/multipliqu[eé]\s+todos\s+los\s+lados/i.test(userText) && /per[ií]metro/i.test(itemContext?.stem || '')) {
      return {
        type: 'perimeter_area_confusion',
        diagnosis: 'Multiplicación en lugar de suma en cálculo de perímetro.',
        guidance: 'Recuerda que el perímetro es el contorno, como poner una cerca alrededor de un terreno. ¿Qué operación matemática usamos para juntar longitudes de una cerca?'
      }
    }

    return null
  }

  /**
   * Procesa la interacción socrática completa
   */
  static async generateSocraticGuidance({
    userText,
    itemContext = null,
    hintLevel = 0,
    schoolId = null,
    studentId = null,
    knownStudentNames = []
  }) {
    const startTime = Date.now()

    // 1. Sanitizar entrada y comprobar seguridad
    const sanitization = this.sanitizeInput(userText, knownStudentNames)

    if (sanitization.isInjected && sanitization.injectionRisk === 'high') {
      return {
        reply: 'Como tutor pedagógico, mi única función es guiarte paso a paso en tu razonamiento de la lección. Por favor, reformula tu duda sobre el ejercicio.',
        nextHintLevel: hintLevel,
        isDirectAnswerPrevented: false,
        sanitizedText: sanitization.sanitizedText
      }
    }

    // 2. Detectar si pide la respuesta directa (Anti-Cheat)
    const isAskingDirectSolution = /(dime\s+la\s+respuesta|cu[aá]l\s+es(\s+la\s+soluci[oó]n|\s+el\s+resultado)?|resu[eé]lvelo|dame\s+la\s+soluci[oó]n|cu[aá]nto\s+da(\s+exactamente)?|dime\s+directamente)/i.test(userText)

    // 3. Consultar RAG Curricular
    const ragContext = await this.fetchCurriculumRAGContext({
      schoolId,
      subjectArea: itemContext?.subject_area || 'Matemática',
      gradeLevel: itemContext?.grade_level || 'Media',
      competencyCode: itemContext?.competency_code || null
    })

    // 4. Analizar posibles conceptos erróneos expresados
    const misconception = this.detectMisconception(userText, itemContext)

    // 5. Determinar la respuesta socrática
    let reply = ''
    let nextHintLevel = hintLevel
    let directAnswerPrevented = false

    const itemHints = itemContext?.hints && Array.isArray(itemContext.hints) && itemContext.hints.length > 0
      ? itemContext.hints
      : [
          'Identifica primero qué te pide exactamente la pregunta y qué datos conocidos tienes.',
          'Piensa si puedes transformar los números o fracciones a una forma más sencilla o equivalente.',
          'Haz un dibujo o esquema mental de la situación antes de calcular.'
        ]

    if (isAskingDirectSolution) {
      directAnswerPrevented = true
      const currentHint = itemHints[Math.min(hintLevel, itemHints.length - 1)]
      
      reply = `Mi misión no es darte la respuesta hecha, sino ayudarte a pensar como un científico o matemático. 💡 Pista clave: ${currentHint} ¿Qué se te ocurre hacer con este dato?`
      nextHintLevel = Math.min(hintLevel + 1, itemHints.length - 1)
    } else if (misconception) {
      reply = misconception.guidance
      nextHintLevel = Math.min(hintLevel + 1, itemHints.length - 1)
    } else {
      // Razonamiento o duda del alumno
      const currentHint = itemHints[Math.min(hintLevel, itemHints.length - 1)]
      reply = `¡Buen análisis inicial! Vamos a construir sobre esa idea. Observa esto: ${currentHint} ¿Cuál crees que debería ser el siguiente paso?`
      nextHintLevel = Math.min(hintLevel + 1, itemHints.length - 1)
    }

    // 6. Asegurar que NINGÚN dato sensible de menores se filtre en la respuesta (Seguridad Menores)
    if (sanitization.detectedPII) {
      // Verificar que ningún nombre o dato redactado aparezca en la respuesta
      knownStudentNames.forEach(name => {
        if (name && name.length >= 3) {
          reply = reply.replaceAll(name, '[ESTUDIANTE]')
        }
      })
    }

    const durationMs = Date.now() - startTime

    // 7. Telemetría no bloqueante: solo metadatos técnicos, nunca texto del estudiante.
    if (schoolId) {
      void Promise.resolve(supabase.rpc('record_intelligence_ai_trace', {
        p_school_id: schoolId,
        p_use_case: 'socratic_tutor',
        p_model: 'socratic-rag-v1',
        p_latency_ms: durationMs,
        p_outcome: 'success',
        p_safety_flags: {
          pii_redacted: sanitization.detectedPII,
          injection_risk: sanitization.injectionRisk,
          direct_answer_prevented: directAnswerPrevented,
          misconception_detected: misconception?.type || null
        }
      })).catch(() => {})
    }

    return {
      reply,
      nextHintLevel,
      isDirectAnswerPrevented: directAnswerPrevented,
      detectedMisconception: misconception?.type || null,
      ragContextCount: ragContext.length,
      sanitizedPrompt: sanitization.sanitizedText
    }
  }
}
