/**
 * Registro Centralizado y Versionado de Prompts del Motor de IA Educativo
 * Proporciona inmutabilidad, trazabilidad y capacidad de rollback sin alterar código de negocio.
 */

class PromptRegistryService {
  constructor() {
    this.registry = new Map()
    this.initializeDefaultPrompts()
  }

  initializeDefaultPrompts() {
    // 1. Generador de Planificación Didáctica (Currículo Ecuador)
    this.registerVersion('planning-generator', 1, {
      template: `Actúa como un Planificador Curricular Senior experto en el Currículo Nacional del Ministerio de Educación del Ecuador (MINEDUC).
Diseña una planificación didáctica rigurosa, completa y contextualizada utilizando la metodología seleccionada (ej. ERCA) y principios DUA.
Genera la respuesta estrictamente en formato JSON válido con la estructura solicitada.`,
      active: true,
      createdAt: '2026-08-01T00:00:00Z',
      description: 'Versión base curricular con soporte ERCA y DUA.'
    })

    // 2. Generador de Recursos Didácticos
    this.registerVersion('resource-generator', 1, {
      template: `Eres un especialista en diseño de material didáctico para el aula de clases en Ecuador.
Crea un recurso educativo estructurado, práctico y listo para ser aplicado según el tipo solicitado.
Responde únicamente con el JSON estructurado.`,
      active: true,
      createdAt: '2026-08-01T00:00:00Z',
      description: 'Generador estándar de rúbricas, guías y talleres.'
    })

    // 3. Regenerador de Secciones Granulares
    this.registerVersion('section-regenerator', 1, {
      template: `Eres un consultor pedagógico especializado en optimización curricular.
Regenera exclusivamente la sección solicitada manteniendo coherencia con el resto del plan de clase.
Responde únicamente con el JSON de la sección indicada.`,
      active: true,
      createdAt: '2026-08-01T00:00:00Z',
      description: 'Regeneración granular de fases ERCA, evaluación o DUA.'
    })

    // 4. Plantilla de Inyección de Memoria Institucional (RAG Delimitado)
    this.registerVersion('rag-institutional-template', 1, {
      template: `[PAUTAS DE CALIDAD INSTITUCIONAL APRENDIDAS - USAR COMO REFERENCIA]
A continuación se presentan directrices y ejemplos modelo previamente validados y aprobados por la coordinación pedagógica de esta institución:
{{INSTITUTIONAL_GUIDELINES}}
Asegúrate de alinear la planificación con estas prioridades sin desviarte del currículo oficial del Ecuador.`,
      active: true,
      createdAt: '2026-09-03T00:00:00Z',
      description: 'Bloque estructurado para incorporar directrices de RAG de forma delimitada.'
    })
  }

  registerVersion(name, version, options = {}) {
    if (!this.registry.has(name)) {
      this.registry.set(name, new Map())
    }

    const versions = this.registry.get(name)
    // Si se activa esta versión, desactivar las demás
    if (options.active) {
      for (const [, v] of versions) {
        v.active = false
      }
    }

    versions.set(version, {
      name,
      version,
      template: options.template || '',
      active: options.active !== undefined ? options.active : true,
      createdAt: options.createdAt || new Date().toISOString(),
      description: options.description || ''
    })
  }

  getActivePrompt(name) {
    const versions = this.registry.get(name)
    if (!versions) return null

    for (const [, prompt] of versions) {
      if (prompt.active) return prompt
    }

    // Si no hay activa, devolver la última registrada
    const all = Array.from(versions.values())
    return all.length > 0 ? all[all.length - 1] : null
  }

  getPrompt(name, version) {
    const versions = this.registry.get(name)
    return versions ? versions.get(version) || null : null
  }

  rollbackVersion(name, toVersion) {
    const versions = this.registry.get(name)
    if (!versions || !versions.has(toVersion)) {
      throw new Error(`La versión ${toVersion} del prompt '${name}' no existe para realizar rollback.`)
    }

    for (const [, v] of versions) {
      v.active = false
    }

    const target = versions.get(toVersion)
    target.active = true
    return target
  }

  listPrompts() {
    const result = []
    for (const [name, versions] of this.registry.entries()) {
      for (const [ver, p] of versions.entries()) {
        result.push({
          name,
          version: ver,
          active: p.active,
          createdAt: p.createdAt,
          description: p.description
        })
      }
    }
    return result
  }
}

export const PromptRegistry = new PromptRegistryService()
