/**
 * Adaptador de Integración para Google Gemini API
 * Utiliza llamadas seguras en formato JSON estructurado con temperatura baja (0.2).
 */

export class GeminiEducationAIProvider {
  constructor(apiKey, model = 'gemini-2.5-flash') {
    this.apiKey = apiKey
    this.model = model || 'gemini-2.5-flash'
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

      const data = await response.json()
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

  async _callGemini(prompt, systemInstruction = '') {
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
        maxOutputTokens: 3000
      }
    }

    if (systemInstruction) {
      payload.systemInstruction = {
        parts: [{ text: systemInstruction }]
      }
    }

    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 25000)

    try {
      const response = await fetch(`${this.baseUrl}/${this.model}:generateContent?key=${this.apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: controller.signal
      })

      if (!response.ok) {
        const errJson = await response.json().catch(() => ({}))
        throw new Error(errJson?.error?.message || `Error del proveedor Gemini: ${response.status}`)
      }

      const resData = await response.json()
      const rawText = resData?.candidates?.[0]?.content?.parts?.[0]?.text
      if (!rawText) {
        throw new Error('Respuesta vacía del modelo Gemini.')
      }

      return JSON.parse(rawText)
    } finally {
      clearTimeout(timeoutId)
    }
  }

  async generatePlan(input) {
    const sysPrompt = `Eres un diseñador curricular pedagógico experto en el sistema educativo del Ecuador (Ministerio de Educación - MinEduc).
Genera planificaciones didácticas de aula con estructura ERCA (Experiencia, Reflexión, Conceptualización, Aplicación) y principios DUA (Diseño Universal para el Aprendizaje).
Devuelve SIEMPRE un objeto JSON estricto con las claves: summary, didactic_sequence, evaluation_plan, inclusion_dua_plan, resources_plan.`

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

    return await this._callGemini(userPrompt, sysPrompt)
  }

  async regenerateSection(input, sectionKey) {
    const sysPrompt = `Eres un experto curricular ecuatoriano. Regenera únicamente la sección "${sectionKey}" para la planificación didáctica indicada. Responde en formato JSON estricto.`
    const userPrompt = `Regenera la sección "${sectionKey}" para el tema "${input.topicTitle}" en ${input.subjectName} (${input.gradeYear}). Metodología: ${input.methodologyPrimary}.`
    return await this._callGemini(userPrompt, sysPrompt)
  }

  async generateResource(input) {
    const sysPrompt = `Eres un especialista en diseño de recursos didácticos para el currículo de Ecuador. Genera el recurso solicitado en formato JSON estricto.`
    const userPrompt = `Genera el recurso "${input.resourceType}" para el tema "${input.topicTitle}" en ${input.subjectName} (${input.gradeYear}). Nivel de dificultad: ${input.difficultyLevel}. Destreza: ${input.dcdDescriptions?.[0] || ''}.`
    return await this._callGemini(userPrompt, sysPrompt)
  }

  async generateStudentSupport(input) {
    const sysPrompt = `Eres un consejero pedagógico y docente especialista en nivelación y adecuaciones para Ecuador. Diseña una propuesta de apoyo y recuperación en formato JSON estricto sin incluir información clínica ni nombres personales.`
    const userPrompt = `Diseña un plan de apoyo pedagógico para: Dificultad observada: ${input.observedDifficulty}, Evidencia: ${input.evidenceType}, Intensidad: ${input.intensity}, Duración: ${input.durationWeeks} semanas, Materia: ${input.subjectName}, Tema: ${input.topicTitle}.`
    return await this._callGemini(userPrompt, sysPrompt)
  }
}
