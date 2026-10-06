import { CURRICULAR_SYSTEM_PROMPT, annualPlanPrompt, unitPlanPrompt } from '../curricular-prompts.js'

/**
 * Adaptador de Integración para Google Gemini API
 * Utiliza llamadas seguras en formato JSON estructurado con temperatura baja (0.2).
 */

const FALLBACK_MODEL = 'gemini-2.5-flash'

// Estructura exacta que la app espera (misma forma que el proveedor demo).
const PLAN_SHAPE = `{
  "summary": { "title": string, "topic": string, "unit": string, "subject": string, "grade": string, "regime": string, "durationTotal": string, "mainObjective": string, "dcdSummary": string, "bloomLevel": string, "methodology": string },
  "didactic_sequence": { "methodology": string, "total_time_minutes": number, "phases": [ { "phase_id": "experiencia" | "reflexion" | "conceptualizacion" | "aplicacion", "name": string, "time_minutes": number, "teacher_activity": string, "student_activity": string, "resources": [string], "evaluation_type": string } ] },
  "evaluation_plan": { "technique": string, "instrument": string, "criteria": string, "indicator": string, "evidence": string, "rubric": [ { "criterion": string, "excellent": string, "good": string, "needs_improvement": string, "insufficient": string } ], "feedback_strategy": string },
  "inclusion_dua_plan": { "principles_applied": [string], "accommodations": [ { "area": string, "strategy": string } ], "support_for_barriers": { "slow_pacing": string, "fast_pacing": string, "low_connectivity": string } },
  "resources_plan": { "suggested_materials": [string] }
}`

const RESOURCE_SHAPE = `{ "type": string, "title": string, "content_summary": string, "sections": [ { "title": string, "content": string } ] }
(Si el recurso es una evaluación agrega "questions": [ { "num": number, "type": string, "question": string, "options": [string], "correct_answer": string } ])`

const SUPPORT_SHAPE = `{ "diagnostic_summary": string, "pedagogical_goals": [string], "weekly_plan": [ { "week": number, "objective": string, "activities": [string], "evidence": string } ], "family_recommendations": [string] }`

const PLAN_SECTIONS = ['summary', 'didactic_sequence', 'evaluation_plan', 'inclusion_dua_plan', 'resources_plan']

const isRecord = value => Boolean(value) && typeof value === 'object' && !Array.isArray(value)

// Algunos modelos devuelven una sección como texto o lista; se envuelve para no perder la generación.
function normalizePlan(plan) {
  if (!isRecord(plan)) return plan
  const wrapped = { ...plan }
  for (const key of PLAN_SECTIONS) {
    const value = wrapped[key]
    if (isRecord(value)) continue
    if (key === 'summary') wrapped[key] = { title: typeof value === 'string' ? value : 'Planificación de clase' }
    else if (key === 'didactic_sequence') wrapped[key] = { phases: Array.isArray(value) ? value : [] }
    else if (key === 'resources_plan') wrapped[key] = { suggested_materials: Array.isArray(value) ? value : (value ? [String(value)] : []) }
    else wrapped[key] = typeof value === 'string' ? { description: value } : {}
  }
  return wrapped
}

function parseJsonText(rawText) {
  const cleaned = rawText.trim().replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '')
  return JSON.parse(cleaned)
}

const isModelUnavailable = (status, message = '') =>
  status === 404 || /not found|is not supported|unknown model|no such model/i.test(message)

export class GeminiEducationAIProvider {
  constructor(apiKey, model = FALLBACK_MODEL) {
    this.apiKey = apiKey
    this.model = model || FALLBACK_MODEL
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models'
  }

  async testConnection() {
    if (!this.apiKey || !this.apiKey.trim()) {
      return {
        success: false,
        status: 'no_key',
        message: 'No se ha configurado una clave API de Gemini válida.'
      }
    }

    try {
      const response = await fetch(`${this.baseUrl}/${this.model}:generateContent?key=${this.apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [
            {
              role: 'user',
              parts: [{ text: 'Responde únicamente con el JSON: {"status": "ok", "provider": "gemini"}' }]
            }
          ],
          generationConfig: {
            responseMimeType: 'application/json',
            temperature: 0.1
          }
        })
      })

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}))
        throw new Error(errorData?.error?.message || `Error HTTP ${response.status}`)
      }

      await response.json()
      return {
        success: true,
        status: 'active',
        provider: 'gemini',
        model: this.model,
        message: 'Conexión exitosa con el servicio de Google Gemini.',
        timestamp: new Date().toISOString()
      }
    } catch (err) {
      return {
        success: false,
        status: 'error',
        provider: 'gemini',
        message: `Fallo al verificar clave Gemini: ${err.message}`
      }
    }
  }

  async _request(model, payload, timeoutMs = 90_000) {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs)
    try {
      return await fetch(`${this.baseUrl}/${model}:generateContent?key=${this.apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: controller.signal
      })
    } finally {
      clearTimeout(timeoutId)
    }
  }

  async _callGemini(prompt, systemInstruction = '', { maxOutputTokens = 16384, timeoutMs = 90_000 } = {}) {
    if (!this.apiKey) {
      throw new Error('Clave API de Gemini no disponible en el cliente.')
    }

    const payload = {
      contents: [
        {
          role: 'user',
          parts: [{ text: prompt }]
        }
      ],
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.2,
        // Los modelos 2.5+ gastan parte del límite "pensando": con 3000 el JSON quedaba cortado.
        maxOutputTokens
      }
    }

    if (systemInstruction) {
      payload.systemInstruction = {
        parts: [{ text: systemInstruction }]
      }
    }

    let response = await this._request(this.model, payload, timeoutMs)
    if (!response.ok) {
      const errJson = await response.json().catch(() => ({}))
      const message = errJson?.error?.message || ''
      // Si el modelo elegido no existe o no está habilitado para la clave, se usa el modelo estable.
      if (this.model !== FALLBACK_MODEL && isModelUnavailable(response.status, message)) {
        response = await this._request(FALLBACK_MODEL, payload, timeoutMs)
        if (!response.ok) {
          const retryJson = await response.json().catch(() => ({}))
          throw new Error(retryJson?.error?.message || `Error del proveedor Gemini: ${response.status}`)
        }
      } else {
        throw new Error(message || `Error del proveedor Gemini: ${response.status}`)
      }
    }

    const resData = await response.json()
    const parts = resData?.candidates?.[0]?.content?.parts || []
    // Se omiten las partes de razonamiento ("thought") y se toma el texto de respuesta.
    const rawText = parts.filter(part => !part?.thought && typeof part?.text === 'string').map(part => part.text).join('')
    if (!rawText) {
      throw new Error(`Respuesta vacía del modelo Gemini (${resData?.candidates?.[0]?.finishReason || 'sin motivo'}).`)
    }

    return parseJsonText(rawText)
  }

  async generatePlan(input) {
    const sysPrompt = `Eres un diseñador curricular pedagógico experto en el sistema educativo del Ecuador (Ministerio de Educación - MinEduc).
Genera planificaciones didácticas de aula con estructura ERCA (Experiencia, Reflexión, Conceptualización, Aplicación) y principios DUA (Diseño Universal para el Aprendizaje).
Responde SOLO con un objeto JSON válido en español con EXACTAMENTE esta estructura (sin texto adicional):
${PLAN_SHAPE}
Incluye las 4 fases ERCA, al menos 3 criterios de rúbrica y al menos 2 adaptaciones DUA. Los tiempos de las fases deben sumar la duración total.`

    const userPrompt = `Genera una planificación de clase completa con los siguientes parámetros académicos:
- Tema: ${input.topicTitle}
- Unidad: ${input.unitTitle}
- Asignatura: ${input.subjectName}
- Nivel/Grado: ${input.gradeYear} (${input.level})
- Régimen: ${input.regime}
- Destreza con Criterio de Desempeño (DCD): ${input.dcdDescriptions?.join('; ') || input.topicTitle}
- Criterios de Evaluación: ${input.evaluationCriteriaDescriptions?.join('; ') || ''}
- Indicadores de Evaluación: ${input.evaluationIndicators?.join('; ') || ''}
- Metodología: ${input.methodologyPrimary || 'ERCA'}
- Duración: ${input.durationMinutes} minutos x ${input.sessionCount} sesiones
- Nivel de Bloom: ${input.bloomLevel}
- Principios DUA: ${input.duaPrinciples?.join(', ')}`

    return normalizePlan(await this._callGemini(userPrompt, sysPrompt))
  }

  async regenerateSection(input, sectionKey) {
    const sysPrompt = `Eres un experto curricular ecuatoriano. Regenera únicamente la sección "${sectionKey}" para la planificación didáctica indicada.
Responde SOLO con el objeto JSON de esa sección, siguiendo la forma que tiene "${sectionKey}" en esta estructura:
${PLAN_SHAPE}`
    const userPrompt = `Regenera la sección "${sectionKey}" para el tema "${input.topicTitle}" en ${input.subjectName} (${input.gradeYear}). Metodología: ${input.methodologyPrimary}.`
    return await this._callGemini(userPrompt, sysPrompt)
  }

  async generateResource(input) {
    const sysPrompt = `Eres un especialista en diseño de recursos didácticos para el currículo de Ecuador.
Responde SOLO con un objeto JSON válido en español con esta estructura:
${RESOURCE_SHAPE}`
    const userPrompt = `Genera el recurso "${input.resourceType}" para el tema "${input.topicTitle}" en ${input.subjectName} (${input.gradeYear}). Nivel de dificultad: ${input.difficultyLevel}. Destreza: ${input.dcdDescriptions?.[0] || ''}.`
    return await this._callGemini(userPrompt, sysPrompt)
  }

  async generateStudentSupport(input) {
    const sysPrompt = `Eres un consejero pedagógico y docente especialista en nivelación y adecuaciones para Ecuador. Diseña una propuesta de apoyo y recuperación sin incluir información clínica ni nombres personales.
Responde SOLO con un objeto JSON válido en español con esta estructura:
${SUPPORT_SHAPE}`
    const userPrompt = `Diseña un plan de apoyo pedagógico para: Dificultad observada: ${input.observedDifficulty}, Evidencia: ${input.evidenceType}, Intensidad: ${input.intensity}, Duración: ${input.durationWeeks} semanas, Materia: ${input.subjectName}, Tema: ${input.topicTitle}.`
    return await this._callGemini(userPrompt, sysPrompt)
  }

  // Planificación curricular oficial: salidas largas, se amplían tokens y tiempo de espera.
  async generateAnnualPlan(input) {
    return await this._callGemini(annualPlanPrompt(input), CURRICULAR_SYSTEM_PROMPT, { maxOutputTokens: 24576, timeoutMs: 110_000 })
  }

  async generateUnitPlan(input) {
    return await this._callGemini(unitPlanPrompt(input), CURRICULAR_SYSTEM_PROMPT, { maxOutputTokens: 24576, timeoutMs: 110_000 })
  }
}
