/**
 * Arma la Planificación Curricular Anual (PCA) y la Planificación Microcurricular a partir
 * del currículo oficial. Funciones puras: no llaman a la red ni a la IA.
 *
 * Regla central: códigos, destrezas, criterios e indicadores salen SIEMPRE del catálogo oficial.
 * La IA solo aporta textos pedagógicos (temas de clase, orientaciones, recursos, actividades)
 * y se aceptan únicamente para códigos que pertenecen a la unidad.
 */

import { INSERTION_TYPES, formatCriterion, formatIndicator, formatSkill, skillKey } from './officialCurricula'

export const TRIMESTRES = ['PRIMER TRIMESTRE', 'SEGUNDO TRIMESTRE', 'TERCER TRIMESTRE']
const TRIMESTRE_KEYS = ['PRIMER_TRIMESTRE', 'SEGUNDO_TRIMESTRE', 'TERCER_TRIMESTRE']

export const DEFAULT_VALORES = 'Justicia, Innovación y Solidaridad (perfil de salida del Bachillerato ecuatoriano).'
export const DEFAULT_EJES = 'Interculturalidad; formación de una ciudadanía democrática; protección del medio ambiente; cuidado de la salud y hábitos de recreación; educación sexual y afectiva.'

/** Texto de IA seguro para imprimir: sin etiquetas, sin caracteres de control y con largo acotado. */
export function cleanText(value, max = 1500) {
  if (value === null || value === undefined) return ''
  let text = Array.isArray(value) ? value.map(v => cleanText(v, max)).filter(Boolean).join('\n') : String(value)
  text = text
    .replace(/<[^>]*>/g, '')
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
  return text.length > max ? `${text.slice(0, max - 1).trimEnd()}…` : text
}

/** Reparte los criterios (con sus destrezas) en unidades contiguas y balanceadas, y las unidades en trimestres. */
export function distributeUnits(criterios, unitCount) {
  const usable = criterios.filter(c => c.destrezas.length > 0)
  const count = Math.max(1, Math.min(unitCount, usable.length))
  const total = usable.reduce((sum, c) => sum + c.destrezas.length, 0)
  const units = Array.from({ length: count }, (_, i) => ({ numero: i + 1, criterios: [] }))

  let unitIndex = 0
  let accumulated = 0
  usable.forEach((criterio, index) => {
    const remainingCriterios = usable.length - index
    const remainingUnits = count - unitIndex
    const target = (total * (unitIndex + 1)) / count
    // Avanza de unidad cuando ya se cubrió su cuota, o cuando quedan tantos criterios como unidades vacías.
    if (units[unitIndex].criterios.length > 0 && (accumulated >= target || remainingCriterios < remainingUnits)) {
      unitIndex = Math.min(unitIndex + 1, count - 1)
    }
    units[unitIndex].criterios.push(criterio)
    accumulated += criterio.destrezas.length
  })

  const perTrimester = [0, 1, 2].map(t => Math.floor(count / 3) + (t < count % 3 ? 1 : 0))
  let cursor = 0
  perTrimester.forEach((n, t) => {
    for (let k = 0; k < n; k += 1) units[cursor++].trimestre = t + 1
  })
  return units
}

export const unitSkills = unit => unit.criterios.flatMap(c => c.destrezas.map(d => ({ destreza: d, criterio: c })))

/** Semanas de clase de cada unidad, proporcionales a sus destrezas (mínimo 1). */
export function unitDurations(units, totalWeeks) {
  const counts = units.map(u => unitSkills(u).length)
  const total = counts.reduce((a, b) => a + b, 0) || 1
  const weeks = counts.map(n => Math.max(1, Math.floor((n / total) * totalWeeks)))
  let diff = totalWeeks - weeks.reduce((a, b) => a + b, 0)
  for (let i = 0; diff !== 0 && i < 1000; i += 1) {
    const idx = i % weeks.length
    if (diff > 0) { weeks[idx] += 1; diff -= 1 } else if (weeks[idx] > 1) { weeks[idx] -= 1; diff += 1 }
  }
  return weeks
}

/** Datos mínimos que se envían a la IA (sin datos personales; solo currículo). */
export function annualAIInput({ curriculum, datos, units }) {
  return {
    curriculo: curriculum.program.nombre,
    asignatura: datos.asignatura || '',
    grado: datos.grado || '',
    unidades: units.map(unit => ({
      numero: unit.numero,
      trimestre: unit.trimestre,
      destrezas: unitSkills(unit).map(({ destreza }) => ({ codigo: skillKey(destreza), descripcion: destreza.descripcion })),
      criterios: unit.criterios.map(c => ({ codigo: c.codigo || c.ref || '', descripcion: c.descripcion })),
    })),
  }
}

export function unitAIInput({ curriculum, datos, unit }) {
  return {
    curriculo: curriculum.program.nombre,
    asignatura: datos.asignatura || '',
    grado: datos.grado || '',
    unidad: { numero: unit.numero, titulo: unit.titulo || '' },
    destrezas: unitSkills(unit).map(({ destreza, criterio }) => ({
      codigo: skillKey(destreza),
      descripcion: destreza.descripcion,
      tema: unit.temas?.[skillKey(destreza)] || '',
      inserciones: (destreza.inserciones || []).map(i => INSERTION_TYPES[i]?.label || i),
      indicadores: criterio.indicadores.map(i => i.descripcion),
    })),
    estudiantes_con_nee: Number(datos.estudiantesNEE) || 0,
  }
}

const byCode = (items, allowed) => {
  const map = new Map()
  for (const item of Array.isArray(items) ? items : []) {
    const code = typeof item?.codigo === 'string' ? item.codigo.trim().replace(/\.$/, '') : ''
    if (allowed.has(code) && !map.has(code)) map.set(code, item)
  }
  return map
}

/**
 * Incorpora el resultado de IA de la planificación anual. Ignora unidades y códigos que no
 * correspondan; si falta algún texto deja uno de respaldo para que el documento nunca quede vacío.
 */
export function applyAnnualAI(units, ai = {}) {
  const aiUnits = new Map((Array.isArray(ai.unidades) ? ai.unidades : []).map(u => [Number(u?.numero), u]))
  return units.map(unit => {
    const source = aiUnits.get(unit.numero) || {}
    const skills = unitSkills(unit)
    const allowed = new Set(skills.map(({ destreza }) => skillKey(destreza)))
    const temas = byCode(source.contenidos, allowed)
    return {
      ...unit,
      titulo: cleanText(source.titulo, 160) || `Unidad ${unit.numero}`,
      objetivo: cleanText(source.objetivo, 600),
      temas: Object.fromEntries(skills.map(({ destreza }) => {
        const key = skillKey(destreza)
        return [key, cleanText(temas.get(key)?.tema, 220) || destreza.descripcion.split(/[,.;]/)[0]]
      })),
      metodologia: cleanText(source.orientaciones_metodologicas, 2500)
        || 'Ciclo de aprendizaje ERCA (experiencia, reflexión, conceptualización, aplicación) con principios DUA, partiendo de situaciones de la vida cotidiana, laboral y comunitaria de las y los estudiantes.',
      tecnicas: cleanText(source.evaluacion, 1200)
        || 'Técnica: observación y prueba. Instrumentos: lista de cotejo, rúbrica y cuestionario.',
    }
  })
}

export function applyUnitAI(unit, ai = {}) {
  const skills = unitSkills(unit)
  const allowed = new Set(skills.map(({ destreza }) => skillKey(destreza)))
  const rows = byCode(ai.destrezas, allowed)
  const inserciones = byCode(ai.inserciones, allowed)
  const proyecto = ai.proyecto && typeof ai.proyecto === 'object' ? ai.proyecto : {}
  const proyectoCode = allowed.has(String(proyecto.destreza_codigo || '').replace(/\.$/, ''))
    ? String(proyecto.destreza_codigo).replace(/\.$/, '')
    : skillKey(skills[0].destreza)
  const nee = ai.nee && typeof ai.nee === 'object' ? ai.nee : {}

  return {
    ...unit,
    objetivoUnidad: cleanText(ai.objetivo, 800) || unit.objetivo || '',
    filas: skills.map(({ destreza, criterio }) => {
      const key = skillKey(destreza)
      const row = rows.get(key) || {}
      return {
        key,
        destreza,
        criterio,
        contenido: cleanText(row.contenido_esencial, 600) || unit.temas?.[key] || '',
        orientaciones: cleanText(row.orientaciones, 2500)
          || 'Experiencia: activación de conocimientos previos con situaciones cotidianas.\nReflexión: preguntas guía en parejas.\nConceptualización: explicación con material concreto y visual (DUA: representación).\nAplicación: resolución de una tarea práctica (DUA: acción y expresión).',
        recursos: cleanText(row.recursos, 800) || 'Material concreto, texto de trabajo, pizarra, recursos audiovisuales.',
        actividades: cleanText(row.actividades_evaluativas, 1200) || 'Técnica: observación. Instrumento: lista de cotejo.',
        insercion: inserciones.get(key) || null,
      }
    }),
    proyecto: {
      competencia: cleanText(proyecto.competencia, 200) || 'Pensamiento crítico y resolución de problemas',
      nombre: cleanText(proyecto.nombre, 200) || `Proyecto integrador de la unidad ${unit.numero}`,
      fase: cleanText(proyecto.fase, 200) || 'Fase 1: Planificación',
      objetivos: cleanText(proyecto.objetivos, 800),
      contenidos: cleanText(proyecto.contenidos, 800),
      destrezaKey: proyectoCode,
      orientaciones: cleanText(proyecto.orientaciones, 1500),
      recursos: cleanText(proyecto.recursos, 600),
      actividades: cleanText(proyecto.actividades, 800),
    },
    nee: {
      contenidos: cleanText(nee.contenidos, 800),
      orientaciones: cleanText(nee.orientaciones, 1500),
      recursos: cleanText(nee.recursos, 600),
      actividades: cleanText(nee.actividades, 800),
    },
  }
}

const pad = n => String(n).padStart(2, '0')
const fmtDate = date => `${pad(date.getDate())}/${pad(date.getMonth() + 1)}/${date.getFullYear()}`

function parseDate(value) {
  if (!value) return null
  const [y, m, d] = String(value).split('-').map(Number)
  if (!y || !m || !d) return null
  return new Date(y, m - 1, d)
}

/** Reparte las filas (destrezas) de la unidad entre sus semanas, con fechas lunes-viernes desde `startDate`. */
export function scheduleWeeks(rowCount, weekCount, startDate) {
  const weeks = Math.max(1, weekCount)
  const start = parseDate(startDate)
  const monday = start ? new Date(start.getFullYear(), start.getMonth(), start.getDate() - ((start.getDay() + 6) % 7)) : null
  return Array.from({ length: rowCount }, (_, i) => {
    const week = Math.min(weeks - 1, Math.floor((i * weeks) / Math.max(1, rowCount)))
    let fechas = ''
    if (monday) {
      const from = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + week * 7)
      const to = new Date(from.getFullYear(), from.getMonth(), from.getDate() + 4)
      fechas = `${fmtDate(from)} – ${fmtDate(to)}`
    }
    return { semana: `Semana ${week + 1}`, fechas }
  })
}

export function weekRange(startDate, weekOffset, weekCount) {
  const start = parseDate(startDate)
  if (!start) return { inicio: '', fin: '' }
  const monday = new Date(start.getFullYear(), start.getMonth(), start.getDate() - ((start.getDay() + 6) % 7) + weekOffset * 7)
  const friday = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + (Math.max(1, weekCount) - 1) * 7 + 4)
  return { inicio: fmtDate(monday), fin: fmtDate(friday) }
}

const commonData = datos => ({
  UNIDAD_EDUCATIVA: datos.unidadEducativa || '',
  DIRECCION: datos.direccion || '',
  ANIO_LECTIVO: datos.anioLectivo ? `Año lectivo ${datos.anioLectivo}` : '',
  ANIO_LECTIVO_TITULO: datos.anioLectivo || '',
  AREA: datos.area || '',
  ASIGNATURA: datos.asignatura || '',
  DOCENTE: datos.docente || '',
  DOCENTE_NOMBRE: datos.docente || '',
  GRADO: datos.grado || '',
  VICERRECTOR: datos.vicerrector || '',
})

/** Datos para public/plantillas/pca.docx */
export function buildAnnualTemplateData({ curriculum, datos, units }) {
  const carga = Number(datos.cargaHoraria) || 0
  const semanasTrabajo = Number(datos.semanasTrabajo) || 40
  const semanasEvaluacion = Number(datos.semanasEvaluacion) || 4
  const semanasClase = Math.max(1, semanasTrabajo - semanasEvaluacion)
  const durations = unitDurations(units, semanasClase)

  const rowsByTrimester = [[], [], []]
  units.forEach((unit, index) => {
    const skills = unitSkills(unit)
    const contenidos = skills.map(({ destreza }) => {
      const key = skillKey(destreza)
      return destreza.codigo ? `${destreza.codigo}: ${unit.temas?.[key] || ''}` : `• ${unit.temas?.[key] || destreza.descripcion}`
    }).join('\n')
    const evaluacion = unit.criterios.map(criterio => {
      const indicadores = criterio.indicadores.map(i => i.codigo).filter(Boolean)
      // En la PCA basta con los códigos; el texto completo va en la microcurricular.
      if (!criterio.codigo) return criterio.ambito ? `Ámbito ${criterio.ambito}` : formatCriterion(criterio)
      return `${criterio.codigo}${indicadores.length ? ` — ${indicadores.join(', ')}` : ''}`
    }).filter((v, i, all) => all.indexOf(v) === i).join('\n')
    rowsByTrimester[(unit.trimestre || 1) - 1].push({
      titulo: `Unidad ${unit.numero}: ${unit.titulo || ''}\n(${TRIMESTRES[(unit.trimestre || 1) - 1].toLowerCase()})`,
      contenidos,
      metodologia: unit.metodologia || '',
      evaluacion: `${evaluacion}\n\n${unit.tecnicas || ''}`.trim(),
      duracion: `${durations[index]} semana${durations[index] === 1 ? '' : 's'}`,
    })
  })

  const objetivos = curriculum.objetivos.map(o => (o.codigo ? `${o.codigo}. ${o.descripcion}` : o.descripcion)).join('\n')
  const aprendizaje = units.map(u => (u.objetivo ? `Unidad ${u.numero}: ${u.objetivo}` : '')).filter(Boolean).join('\n')

  return {
    ...commonData(datos),
    NIVEL: datos.nivel || curriculum.program.nombre,
    FECHA_INICIO_FIN: [datos.fechaInicio, datos.fechaFin].filter(Boolean).map(v => fmtDate(parseDate(v))).join(' – '),
    CARGA_HORARIA_SEMANAL: carga ? String(carga) : '',
    SEMANAS_TRABAJO: String(semanasTrabajo),
    SEMANAS_EVALUACION: String(semanasEvaluacion),
    TOTAL_SEMANAS_CLASE: String(semanasClase),
    TOTAL_PERIODOS: carga ? String(carga * semanasClase) : '',
    NUMERO_UNIDADES: String(units.length),
    OBJETIVOS_SUBNIVEL: objetivos,
    OBJETIVOS_APRENDIZAJE: aprendizaje,
    VALORES: datos.valores || DEFAULT_VALORES,
    EJES_TRANSVERSALES: datos.ejes || DEFAULT_EJES,
    OBSERVACIONES: datos.observaciones || '',
    DIRECTOR: datos.directorArea || '',
    COORDINADOR: datos.coordinador || '',
    FECHA: datos.fechaElaboracion ? `Fecha: ${fmtDate(parseDate(datos.fechaElaboracion))}` : 'Fecha:',
    [TRIMESTRE_KEYS[0]]: rowsByTrimester[0],
    [TRIMESTRE_KEYS[1]]: rowsByTrimester[1],
    [TRIMESTRE_KEYS[2]]: rowsByTrimester[2],
  }
}

/**
 * Los indicadores pertenecen al criterio, no a cada destreza: se escriben completos en la primera
 * fila de cada criterio y en las siguientes solo sus códigos, para no repetir el mismo texto.
 */
function indicatorsCell(fila, index, filas) {
  const { indicadores } = fila.criterio
  const firstOfCriterion = filas.findIndex(f => f.criterio === fila.criterio) === index
  if (!indicadores.length) {
    // Currículos sin indicadores (Inicial, Primera Infancia): el objetivo se escribe una vez por grupo.
    if (firstOfCriterion) return formatCriterion(fila.criterio)
    return fila.criterio.ambito ? `Ámbito ${fila.criterio.ambito} (mismo objetivo de aprendizaje).` : 'Mismo criterio que la fila anterior.'
  }
  if (firstOfCriterion) return indicadores.map(formatIndicator).join('\n')
  return `${indicadores.map(i => i.codigo).join(', ')} (ver ${fila.criterio.codigo})`
}

/** Datos para public/plantillas/micro.docx de una unidad ya enriquecida con applyUnitAI. */
export function buildUnitTemplateData({ datos, unit, weekCount, weekOffset = 0 }) {
  const startWeeks = scheduleWeeks(unit.filas.length, weekCount, datos.fechaInicio
    ? (() => { const d = parseDate(datos.fechaInicio); d.setDate(d.getDate() + weekOffset * 7); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` })()
    : '')
  const range = weekRange(datos.fechaInicio, weekOffset, weekCount)
  const proyectoFila = unit.filas.find(f => f.key === unit.proyecto.destrezaKey) || unit.filas[0]

  const insercionesRows = unit.filas.flatMap(fila => (fila.destreza.inserciones || []).map(tipo => ({
    INSERCION_TIPO: INSERTION_TYPES[tipo]?.label || tipo,
    INSERCION_DIMENSION: cleanText(fila.insercion?.dimension, 200) || INSERTION_TYPES[tipo]?.enfoque || '',
    INSERCION_TEMA: cleanText(fila.insercion?.tema, 200) || fila.contenido,
    INSERCION_SUBTEMA: cleanText(fila.insercion?.subtema, 200),
    INSERCION_CRITERIO: formatCriterion(fila.criterio),
    INSERCION_DESTREZA: formatSkill(fila.destreza),
    INSERCION_INDICADORES: fila.criterio.indicadores.map(formatIndicator).join('\n'),
  })))

  const neeRows = Number(datos.estudiantesNEE) > 0 || unit.nee.orientaciones
    ? [{
      NEE_CONTENIDOS: unit.nee.contenidos || proyectoFila.contenido,
      NEE_DESTREZA: formatSkill(proyectoFila.destreza),
      NEE_INDICADORES: proyectoFila.criterio.indicadores.map(formatIndicator).join('\n'),
      NEE_ORIENTACIONES: unit.nee.orientaciones || 'Adaptaciones de grado 3 (no significativas): instrucciones segmentadas, apoyos visuales, tiempo adicional y tutoría entre pares.',
      NEE_RECURSOS: unit.nee.recursos || 'Material concreto y visual adaptado.',
      NEE_ACTIVIDADES: unit.nee.actividades || 'Técnica: observación. Instrumento: lista de cotejo adaptada.',
    }]
    : []

  return {
    ...commonData(datos),
    TRIMESTRE: TRIMESTRES[(unit.trimestre || 1) - 1],
    UNIDAD_DIDACTICA: String(unit.numero),
    TITULO_UNIDAD: unit.titulo || '',
    NUM_SEMANAS: String(weekCount),
    PARALELOS: datos.paralelos || '',
    FECHA_INICIO: range.inicio,
    FECHA_FIN: range.fin,
    VALORES: datos.valores || DEFAULT_VALORES,
    OBJETIVOS_APRENDIZAJE: unit.objetivoUnidad || unit.objetivo
      || `Desarrollar las destrezas con criterios de desempeño ${unit.filas.map(f => f.destreza.codigo).filter(Boolean).join(', ')} en situaciones de la vida cotidiana, laboral y comunitaria.`,
    SEMANAS: unit.filas.map((fila, i) => ({
      SEMANA: startWeeks[i].semana,
      FECHAS: startWeeks[i].fechas,
      CONTENIDO_ESENCIAL: fila.contenido,
      DESTREZA: formatSkill(fila.destreza),
      INDICADORES: indicatorsCell(fila, i, unit.filas),
      ORIENTACIONES: fila.orientaciones,
      RECURSOS: fila.recursos,
      ACTIVIDADES: fila.actividades,
    })),
    INSERCIONES: insercionesRows,
    COMPETENCIA_EDS: unit.proyecto.competencia,
    FASE_PROYECTO: unit.proyecto.fase,
    NOMBRE_PROYECTO: unit.proyecto.nombre,
    OBJETIVOS_PROYECTO: unit.proyecto.objetivos,
    CONTENIDOS_PROYECTO: unit.proyecto.contenidos || proyectoFila.contenido,
    DESTREZA_PROYECTO: formatSkill(proyectoFila.destreza),
    INDICADORES_PROYECTO: proyectoFila.criterio.indicadores.map(formatIndicator).join('\n'),
    ORIENTACIONES_PROYECTO: unit.proyecto.orientaciones,
    RECURSOS_PROYECTO: unit.proyecto.recursos,
    ACTIVIDADES_PROYECTO: unit.proyecto.actividades,
    NEE: neeRows,
    DIRECTOR_AREA: datos.directorArea || '',
    RECTOR: datos.rector || '',
  }
}
