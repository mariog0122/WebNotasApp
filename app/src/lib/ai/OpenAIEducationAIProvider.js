/**
 * Adaptador de Integración para OpenAI API
 * Soporta modelos gpt-5.6-luna, gpt-4o-mini, gpt-4o con formato estructurado JSON.
 */

export class OpenAIEducationAIProvider {
  constructor(apiKey, model = 'gpt-5.6-luna') {
    this.apiKey = apiKey
    this.model = model || 'gpt-5.6-luna'
    this.baseUrl = 'https://api.openai.com/v1/chat/completions'
  }

  async testConnection() {
    if (!this.apiKey || !this.apiKey.trim()) {
      return {
        success: false,
        status: 'no_key',
        message: 'No se ha configurado una clave API de OpenAI válida.'
      }
    }

    try {
      const response = await fetch(this.baseUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey.trim()}`
        },
        body: JSON.stringify({
          model: this.model,
          messages: [
            {
              role: 'system',
              content: 'Responde exclusivamente con el JSON: {"status": "ok", "provider": "openai"}'
            },
            {
              role: 'user',
              content: 'test'
            }
          ],
          response_format: { type: 'json_object' },
          temperature: 0.1
        })
      })

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}))
        throw new Error(errorData?.error?.message || `Error HTTP ${response.status}`)
      }

      return {
        success: true,
        status: 'active',
        provider: 'openai',
        model: this.model,
        message: 'Conexión exitosa con el servicio de OpenAI.',
        timestamp: new Date().toISOString()
      }
    } catch (err) {
      return {
        success: false,
        status: 'error',
        provider: 'openai',
        message: `Fallo al verificar clave OpenAI: ${err.message}`
      }
    }
  }

  async _executePrompt(systemInstruction, userPrompt) {
    if (!this.apiKey) {
      throw new Error('No hay una clave API configurada para OpenAI.')
    }

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey.trim()}`
      },
      body: JSON.stringify({
        model: this.model,
        messages: [
          { role: 'system', content: systemInstruction + '\nResponde ÚNICAMENTE con el objeto JSON estructurado, sin bloques de código markdown ni texto adicional.' },
          { role: 'user', content: userPrompt }
        ],
        response_format: { type: 'json_object' },
        temperature: 0.2
      })
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      throw new Error(errorData?.error?.message || `Error en llamada OpenAI: ${response.status}`)
    }

    const data = await response.json()
    const content = data?.choices?.[0]?.message?.content
    if (!content) throw new Error('Respuesta vacía recibida desde OpenAI.')

    return JSON.parse(content)
  }

  async generatePlan(input) {
    const system = `Eres un experto pedagógico del Ministerio de Educación de Ecuador (MINEDEC). Generas planificaciones didácticas oficiales con ciclo ERCA y DUA en formato JSON estructurado.`
    const prompt = `Genera un plan de clase para:
Tema: ${input.topicTitle}
Unidad: ${input.unitTitle || 'Unidad de Aprendizaje'}
Asignatura: ${input.subjectName}
Grado: ${input.gradeYear}
Régimen: ${input.regime || 'Costa-Galápagos'}
Duración: ${input.durationMinutes || 45} min x ${input.sessionCount || 2} sesiones
DCD: ${(input.dcdDescriptions || []).join('; ')}
Criterios: ${(input.evaluationCriteriaDescriptions || []).join('; ')}
Indicadores: ${(input.evaluationIndicators || []).join('; ')}
Objetivos: ${(input.learningObjectives || []).join('; ')}
Estudiantes con Adaptación Curricular: ${JSON.stringify(input.adaptedStudents || [])}`

    return await this._executePrompt(system, prompt)
  }

  async regenerateSection(input, sectionKey) {
    const system = `Eres un diseñador curricular del MINEDEC Ecuador. Generas la sección ${sectionKey} en formato JSON.`
    const prompt = `Regenera únicamente la sección ${sectionKey} para el tema "${input.topicTitle}" en ${input.subjectName} (${input.gradeYear}).`
    return await this._executePrompt(system, prompt)
  }

  async generateResource(input) {
    const system = `Genera un recurso educativo oficial para el aula en Ecuador en formato JSON estructurado.`
    const prompt = `Recurso: ${input.resourceType} para el tema "${input.topicTitle}" en ${input.subjectName} (${input.gradeYear}). DCD: ${(input.dcdDescriptions || []).join('; ')}`
    return await this._executePrompt(system, prompt)
  }

  async generateStudentSupport(input) {
    const system = `Genera un plan de recuperación pedagógica y apoyo psicopedagógico individualizado según la normativa MINEDEC Ecuador.`
    const prompt = `Diseña un plan de apoyo para el tema "${input.topicTitle}" en ${input.subjectName}. Dificultad: ${input.observedDifficulty}. Nivel: ${input.intensity || 'moderada'}.`
    return await this._executePrompt(system, prompt)
  }
}
