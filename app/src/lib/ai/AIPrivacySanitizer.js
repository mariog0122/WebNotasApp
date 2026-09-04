/**
 * Servicio de Sanitización de Privacidad (PII) y Defensa Anti-Inyección de Prompts
 * Diseñado para el contexto educativo ecuatoriano (Cédulas, DECE, Teléfonos, Nombres de Menores).
 */

export class AIPrivacySanitizer {
  /**
   * Valida si una cadena de 10 dígitos es una cédula ecuatoriana válida usando algoritmo Módulo 10
   */
  static isValidEcuadorianCedula(cedula) {
    if (!cedula || typeof cedula !== 'string') return false
    const clean = cedula.trim()
    if (!/^\d{10}$/.test(clean)) return false

    const province = parseInt(clean.substring(0, 2), 10)
    if ((province < 1 || province > 24) && province !== 30) return false

    const thirdDigit = parseInt(clean.charAt(2), 10)
    if (thirdDigit >= 6) return false // 0 a 5 son personas naturales

    const coefficients = [2, 1, 2, 1, 2, 1, 2, 1, 2]
    const verifier = parseInt(clean.charAt(9), 10)
    let sum = 0

    for (let i = 0; i < 9; i++) {
      let val = parseInt(clean.charAt(i), 10) * coefficients[i]
      if (val >= 10) val -= 9
      sum += val
    }

    const mod = sum % 10
    const calculatedVerifier = mod === 0 ? 0 : 10 - mod
    return calculatedVerifier === verifier
  }

  /**
   * Analiza el texto en busca de patrones de inyección de prompt o jailbreak
   */
  static detectPromptInjection(text) {
    if (!text || typeof text !== 'string') {
      return { isInjected: false, riskLevel: 'low', matchedPatterns: [] }
    }

    const suspiciousPatterns = [
      // Intentos directos de sobrescribir instrucciones
      { regex: /ignora\s+(las\s+)?(instrucciones|reglas|órdenes)\s+anteriores/i, name: 'ignore_instructions_es' },
      { regex: /ignore\s+(all\s+)?(previous\s+)?instructions/i, name: 'ignore_instructions_en' },
      { regex: /cambia\s+(el\s+)?system\s+prompt/i, name: 'change_system_prompt' },
      { regex: /override\s+(the\s+)?rules/i, name: 'override_rules' },
      { regex: /a\s+partir\s+de\s+ahora\s+(responde|actúa|di)\s+siempre/i, name: 'persona_hijack_es' },
      { regex: /you\s+are\s+now\s+(a|an)/i, name: 'persona_hijack_en' },
      { regex: /dan\s+mode|jailbreak/i, name: 'jailbreak_explicit' },
      // Intentos de extraer el system prompt o secretos
      { regex: /revela\s+(tu\s+)?(system\s+prompt|instrucciones)/i, name: 'prompt_leak_es' },
      { regex: /show\s+(your\s+)?system\s+(prompt|instructions)/i, name: 'prompt_leak_en' },
      { regex: /(api[_\-\s]?key|bearer\s+[a-z0-9_\-\.]{20,}|sk-[a-z0-9]{20,})/i, name: 'secret_leak' },
      // Intentos de inyección de código o scripts
      { regex: /<script\b[^>]*>([\s\S]*?)<\/script>/i, name: 'xss_script' },
      { regex: /javascript\s*:/i, name: 'xss_javascript' }
    ]

    const matchedPatterns = []
    for (const pattern of suspiciousPatterns) {
      if (pattern.regex.test(text)) {
        matchedPatterns.push(pattern.name)
      }
    }

    const isInjected = matchedPatterns.length > 0
    let riskLevel = 'low'
    if (matchedPatterns.length >= 2 || matchedPatterns.some(p => p.includes('jailbreak') || p.includes('secret') || p.includes('xss'))) {
      riskLevel = 'high'
    } else if (matchedPatterns.length === 1) {
      riskLevel = 'medium'
    }

    return {
      isInjected,
      riskLevel,
      matchedPatterns
    }
  }

  /**
   * Redacta datos personales sensibles (PII) de forma integral
   */
  static redactPII(text, knownStudentNames = []) {
    if (!text || typeof text !== 'string') {
      return { sanitizedText: text, piiCount: 0, redactionLog: [] }
    }

    let sanitized = text
    let piiCount = 0
    const redactionLog = []

    // 1. Cédulas ecuatorianas de 10 dígitos
    sanitized = sanitized.replace(/\b\d{10}\b/g, (match) => {
      if (AIPrivacySanitizer.isValidEcuadorianCedula(match)) {
        piiCount++
        redactionLog.push('cedula_ecuatoriana')
        return '[CEDULA_REDACTADA]'
      }
      return match
    })

    // 2. Correos electrónicos
    sanitized = sanitized.replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, () => {
      piiCount++
      redactionLog.push('correo_electronico')
      return '[CORREO_REDACTADO]'
    })

    // 3. Teléfonos (formatos Ecuador: 09XXXXXXXX o +5939XXXXXXXX)
    sanitized = sanitized.replace(/(?:\+?593\s?9\d{8}|\b09\d{8}\b)/g, () => {
      piiCount++
      redactionLog.push('telefono_contacto')
      return '[TELEFONO_REDACTADO]'
    })

    // 4. Diagnósticos clínicos o términos DECE altamente sensibles
    const deceSensitiveKeywords = [
      /diagn[oó]stico\s+cl[ií]nico\s*:\s*[^\.,;\n]+/gi,
      /informe\s+psicol[oó]gico\s*:\s*[^\.,;\n]+/gi,
      /medicaci[oó]n\s*:\s*[^\.,;\n]+/gi,
      /historia\s+cl[ií]nica\s*:\s*[^\.,;\n]+/gi
    ]

    for (const kw of deceSensitiveKeywords) {
      sanitized = sanitized.replace(kw, () => {
        piiCount++
        redactionLog.push('informacion_clinica_dece')
        return '[DATOS_CLINICOS_DECE_REDACTADOS]'
      })
    }

    // 5. Nombres de estudiantes conocidos en el curso
    if (Array.isArray(knownStudentNames) && knownStudentNames.length > 0) {
      for (const name of knownStudentNames) {
        if (!name || name.trim().length < 3) continue
        const escaped = name.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        const regex = new RegExp(`\\b${escaped}\\b`, 'gi')
        if (regex.test(sanitized)) {
          sanitized = sanitized.replace(regex, () => {
            piiCount++
            redactionLog.push('nombre_estudiante')
            return '[ESTUDIANTE_REDACTADO]'
          })
        }
      }
    }

    return {
      sanitizedText: sanitized,
      piiCount,
      redactionLog
    }
  }

  /**
   * Sanitización completa de un payload de retroalimentación
   */
  static sanitizeFeedbackPayload(payload, knownStudentNames = []) {
    const rawComment = payload?.comment || ''
    const injectionCheck = AIPrivacySanitizer.detectPromptInjection(rawComment)
    const piiCheck = AIPrivacySanitizer.redactPII(rawComment, knownStudentNames)

    // Si hay inyección de alto riesgo, bloquear contenido
    let finalComment = piiCheck.sanitizedText
    let status = 'received'
    let isReusable = true

    if (injectionCheck.riskLevel === 'high') {
      finalComment = '[CONTENIDO_BLOQUEADO_POR_SEGURIDAD]'
      status = 'rejected'
      isReusable = false
    } else if (injectionCheck.riskLevel === 'medium') {
      status = 'quarantined'
      isReusable = false
    }

    return {
      sanitizedComment: finalComment,
      piiRedactedCount: piiCheck.piiCount,
      injectionDetected: injectionCheck.isInjected,
      riskLevel: injectionCheck.riskLevel,
      matchedThreats: injectionCheck.matchedPatterns,
      status,
      isReusable
    }
  }
}
