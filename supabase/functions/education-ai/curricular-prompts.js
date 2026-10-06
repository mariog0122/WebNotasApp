/**
 * Prompts de planificación curricular oficial (PCA y microcurricular).
 * Compartidos por los proveedores Gemini y OpenAI. La app reinserta códigos, destrezas,
 * criterios e indicadores desde el currículo oficial: el modelo solo redacta textos pedagógicos.
 */

export const CURRICULAR_SYSTEM_PROMPT = `Eres especialista curricular del Ministerio de Educación del Ecuador y redactas planificaciones oficiales (PCA y microcurriculares) con ciclo ERCA, principios DUA e inserciones curriculares.
Reglas obligatorias:
- Usa EXCLUSIVAMENTE los códigos de destreza recibidos, copiados exactamente; nunca inventes, cambies ni omitas códigos.
- No reescribas destrezas, criterios ni indicadores: la aplicación los inserta desde el currículo oficial.
- Cada tema o contenido debe derivarse directamente de la destreza de su mismo código y del contexto de las y los estudiantes.
- Redacta en español formal de Ecuador, con lenguaje inclusivo y sin datos personales.
- Responde ÚNICAMENTE con un objeto JSON válido con la estructura pedida.`

const destrezasLines = destrezas => (destrezas || [])
  .map(d => `- ${d.codigo}: ${d.descripcion}${d.inserciones?.length ? ` [Inserción: ${d.inserciones.join(', ')}]` : ''}${d.tema ? ` (tema previsto: ${d.tema})` : ''}`)
  .join('\n')

export function annualPlanPrompt(input) {
  const unidades = (input.unidades || []).map(u => `UNIDAD ${u.numero} (trimestre ${u.trimestre})
Criterios: ${(u.criterios || []).map(c => `${c.codigo}: ${c.descripcion}`).join(' | ')}
Destrezas:
${destrezasLines(u.destrezas)}`).join('\n\n')

  return `Currículo: ${input.curriculo}
Asignatura: ${input.asignatura || 'Integrada'}
Grado/curso: ${input.grado || ''}

Redacta la Planificación Curricular Anual con estas unidades ya definidas:

${unidades}

Devuelve JSON con esta forma exacta:
{"unidades":[{"numero":1,"titulo":"título motivador de la unidad (máx. 10 palabras)","objetivo":"objetivo de aprendizaje de la unidad (1 oración)","contenidos":[{"codigo":"código exacto de la destreza","tema":"tema de clase concreto derivado de esa destreza (máx. 12 palabras)"}],"orientaciones_metodologicas":"estrategias ERCA y DUA para la unidad (máx. 80 palabras)","evaluacion":"técnicas e instrumentos de evaluación de la unidad (máx. 40 palabras)"}]}
Incluye una entrada en "contenidos" por cada destreza de cada unidad.`
}

export function unitPlanPrompt(input) {
  return `Currículo: ${input.curriculo}
Asignatura: ${input.asignatura || 'Integrada'}
Grado/curso: ${input.grado || ''}
Unidad ${input.unidad?.numero}: ${input.unidad?.titulo || ''}
Estudiantes con necesidades educativas específicas en el curso: ${input.estudiantes_con_nee || 0}

Destrezas de la unidad (con sus indicadores oficiales de referencia):
${(input.destrezas || []).map(d => `${destrezasLines([d])}\n  Indicadores: ${(d.indicadores || []).join(' / ')}`).join('\n')}

Redacta la planificación microcurricular. Devuelve JSON con esta forma exacta:
{"objetivo":"objetivo de aprendizaje de la unidad",
"destrezas":[{"codigo":"código exacto","contenido_esencial":"tema de clase de esa destreza","orientaciones":"Experiencia: …\\nReflexión: …\\nConceptualización: …\\nAplicación: … (incluye la estrategia DUA y, si la destreza tiene inserción, cómo se trabaja)","recursos":"recursos concretos","actividades_evaluativas":"Técnica: … Instrumento: … y la actividad evaluativa"}],
"inserciones":[{"codigo":"código exacto de una destreza con inserción","dimension":"dimensión de la inserción","tema":"tema","subtema":"subtema"}],
"proyecto":{"competencia":"competencia básica de Educación para el Desarrollo Sostenible","nombre":"nombre del proyecto integrador","fase":"fase del proyecto","objetivos":"objetivo del proyecto","contenidos":"contenidos esenciales","destreza_codigo":"código exacto de la destreza principal del proyecto","orientaciones":"orientaciones metodológicas","recursos":"recursos","actividades":"actividades evaluativas"},
"nee":{"contenidos":"contenidos adaptados","orientaciones":"adaptaciones curriculares y estrategias","recursos":"recursos adaptados","actividades":"actividades evaluativas adaptadas"}}
Incluye una entrada en "destrezas" por cada destreza listada, en el mismo orden.`
}
