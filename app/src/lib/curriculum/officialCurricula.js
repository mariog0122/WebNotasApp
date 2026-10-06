/**
 * Catálogo de currículos oficiales del MinEduc.
 * - Alfabetización/Postalfabetización y Primera Infancia: extraídos de los PDF oficiales (scripts/curriculum/extract_*.py).
 * - Inicial, Preparatoria, Elemental, Media y Adaptaciones para jóvenes/adultos: JSON entregados por la institución,
 *   normalizados y validados con scripts/curriculum/normalize_priorizados.py (cada corrección queda en `avisos`).
 * Ninguna parte de la app ni de la IA puede inventar o modificar códigos y textos curriculares.
 */

export const INSERTION_TYPES = Object.freeze({
  civica_etica_integridad: { label: 'Educación Cívica, Ética e Integridad', enfoque: 'Enfoque Humanista' },
  desarrollo_sostenible: { label: 'Educación para el Desarrollo Sostenible', enfoque: 'Enfoque Integral' },
  socioemocional: { label: 'Educación Socioemocional', enfoque: 'Enfoque Integral y Preventivo' },
  financiera: { label: 'Educación Financiera', enfoque: 'Enfoque Sociocultural' },
  seguridad_vial: { label: 'Educación para la Seguridad Vial y Movilidad Sostenible', enfoque: 'Enfoque Movilidad Sostenible' },
  seguridad_integral: { label: 'Educación para la Seguridad Integral', enfoque: 'Enfoque Integral' },
})

export const SUBNIVEL_NAMES = Object.freeze({
  1: 'Preparatoria', 2: 'Básica Elemental', 3: 'Básica Media', 4: 'Básica Superior', 5: 'Bachillerato',
})

/**
 * tipo:
 *  - 'codificado'      mapa único con criterios/destrezas/indicadores oficiales (Alfabetización)
 *  - 'por_ambitos'     Primera Infancia 0-3: ámbitos y edades, sin códigos
 *  - 'inicial'         Inicial 2 (3-5 años): ámbitos y edades, sin códigos
 *  - 'por_asignatura'  currículos priorizados con asignaturas y códigos oficiales
 */
export const OFFICIAL_PROGRAMS = Object.freeze([
  { id: 'primera_infancia', grupo: 'Educación ordinaria', nombre: 'Primera Infancia (0-3 años)', archivo: 'primera_infancia_0_3', tipo: 'por_ambitos' },
  { id: 'inicial', grupo: 'Educación ordinaria', nombre: 'Educación Inicial 2 (3-5 años)', archivo: 'inicial', tipo: 'inicial' },
  { id: 'preparatoria', grupo: 'Educación ordinaria', nombre: 'Preparatoria (1.º EGB)', archivo: 'preparatoria', tipo: 'por_asignatura', integrado: true },
  { id: 'elemental', grupo: 'Educación ordinaria', nombre: 'EGB Elemental (2.º a 4.º)', archivo: 'elemental', tipo: 'por_asignatura' },
  { id: 'media', grupo: 'Educación ordinaria', nombre: 'EGB Media (5.º a 7.º)', archivo: 'media', tipo: 'por_asignatura' },
  { id: 'alfabetizacion', grupo: 'Jóvenes, adultos y adultos mayores', nombre: 'Alfabetización', archivo: 'alfabetizacion_postalfabetizacion_2025', subnivel: 'alfabetizacion', tipo: 'codificado' },
  { id: 'postalfabetizacion', grupo: 'Jóvenes, adultos y adultos mayores', nombre: 'Postalfabetización', archivo: 'alfabetizacion_postalfabetizacion_2025', subnivel: 'postalfabetizacion', tipo: 'codificado' },
  { id: 'adaptaciones_jovenes_adultos', grupo: 'Jóvenes, adultos y adultos mayores', nombre: 'EGB Superior y Bachillerato (adaptaciones curriculares)', archivo: 'adaptaciones_jovenes_adultos', tipo: 'por_asignatura' },
])

const loaders = {
  alfabetizacion_postalfabetizacion_2025: () => import('../../data/curriculos/alfabetizacion_postalfabetizacion_2025.json'),
  primera_infancia_0_3: () => import('../../data/curriculos/primera_infancia_0_3.json'),
  inicial: () => import('../../data/curriculos/inicial.json'),
  preparatoria: () => import('../../data/curriculos/preparatoria.json'),
  elemental: () => import('../../data/curriculos/elemental.json'),
  media: () => import('../../data/curriculos/media.json'),
  adaptaciones_jovenes_adultos: () => import('../../data/curriculos/adaptaciones_jovenes_adultos.json'),
}

const cache = new Map()

async function loadFile(name) {
  if (!cache.has(name)) {
    cache.set(name, loaders[name]().then(mod => mod.default || mod))
  }
  return cache.get(name)
}

export function getProgram(programId) {
  const program = OFFICIAL_PROGRAMS.find(p => p.id === programId)
  if (!program) throw new Error(`Currículo no disponible: ${programId}`)
  return program
}

/**
 * Opciones de selección de un programa (asignaturas/ámbitos, subniveles y edades) con su estado de calidad.
 * `asignaturas`: [{ id, nombre, estado: 'completa'|'con_avisos'|'incompleta', subniveles, avisos, total }]
 */
export async function getProgramOptions(programId) {
  const program = getProgram(programId)
  const data = await loadFile(program.archivo)
  if (program.tipo === 'por_asignatura') {
    const asignaturas = data.asignaturas.map(a => ({
      id: a.id, nombre: a.nombre, estado: a.estado, subniveles: a.subniveles, avisos: a.avisos, total: a.total_destrezas,
      fusionados: a.criterios.filter(c => c.nota).length,
    }))
    const subniveles = [...new Set(asignaturas.flatMap(a => a.subniveles))].sort()
    return {
      asignaturas: program.integrado ? [{ id: 'todas', nombre: 'Todas (currículo integrado)', estado: 'con_avisos', subniveles, avisos: [], total: asignaturas.reduce((n, a) => n + a.total, 0) }, ...asignaturas] : asignaturas,
      subniveles: subniveles.map(id => ({ id, nombre: SUBNIVEL_NAMES[id] || id })),
      edades: [],
    }
  }
  if (program.tipo === 'inicial') {
    return {
      asignaturas: [{ id: 'todas', nombre: 'Todos los ámbitos (currículo integrado)', estado: 'completa', avisos: [] },
        ...data.ambitos.map(a => ({ id: a.id, nombre: a.nombre, estado: 'completa', avisos: a.avisos, total: a.destrezas.length }))],
      subniveles: [],
      edades: data.edades,
      avisos: data.ambitos[0]?.avisos || [],
    }
  }
  if (program.tipo === 'por_ambitos') {
    return { asignaturas: [], subniveles: [], edades: data.edades }
  }
  return { asignaturas: [], subniveles: [], edades: [] }
}

const ind = i => ({ codigo: i.codigo, descripcion: i.descripcion, referencia: Boolean(i.referencia) })

/**
 * Devuelve el currículo listo para planificar:
 * { program, titulo, fuente, objetivos, criterios: [{codigo, descripcion, destrezas, indicadores}], avisos }
 * Para currículos sin códigos oficiales cada ámbito/objetivo actúa como "criterio" (codigo: null).
 */
export async function loadProgram(programId, { edad, asignatura, subnivel } = {}) {
  const program = getProgram(programId)
  const data = await loadFile(program.archivo)

  if (program.tipo === 'codificado') {
    const mapa = data.mapas.find(m => m.subnivel === program.subnivel)
    return {
      program,
      titulo: data.titulo,
      fuente: data.fuente,
      objetivos: mapa.objetivos,
      criterios: mapa.criterios,
      civica: data.insercion_civica,
      avisos: [],
    }
  }

  if (program.tipo === 'por_asignatura') {
    const all = data.asignaturas
    const selected = asignatura && asignatura !== 'todas' ? all.filter(a => a.id === asignatura) : all.filter(a => a.estado !== 'incompleta')
    if (!selected.length) throw new Error('Selecciona una asignatura del currículo.')
    const blocked = selected.find(a => a.estado === 'incompleta')
    if (blocked) throw new Error(`${blocked.nombre}: ${blocked.avisos[0]}`)
    const sub = subnivel ? String(subnivel) : null
    const criterios = []
    for (const a of selected) {
      for (const c of a.criterios) {
        const destrezas = c.destrezas.filter(d => !sub || d.subnivel === sub)
        if (!destrezas.length) continue
        const codigos = (c.codigos || []).filter(code => !sub || code.split('.').at(-2) === sub)
        const indicadores = c.indicadores.filter(i => !sub || !/\.(\d)\.\d+\.\d+$/.test(i.codigo) || i.codigo.match(/\.(\d)\.\d+\.\d+$/)[1] === sub).map(ind)
        criterios.push({
          codigo: codigos.length ? codigos.join(' / ') : c.codigo,
          // Los bloques de Cívica (CAI) no traen código de criterio: referencia interna estable.
          ref: c.codigo ? undefined : `${a.id}.${c.codigo_descripcion || criterios.length + 1}`,
          codigos,
          codigo_descripcion: c.codigo_descripcion,
          descripcion: c.descripcion,
          nota: c.nota,
          asignatura: a.nombre,
          destrezas,
          indicadores,
        })
      }
    }
    const objetivos = selected.flatMap(a => a.objetivos).filter(o => !sub || o.codigo.split('.').at(-2) === sub)
    return {
      program,
      titulo: data.titulo,
      fuente: data.fuente,
      asignatura: selected.length === 1 ? selected[0].nombre : 'Currículo integrado',
      subnivel: sub ? SUBNIVEL_NAMES[sub] : null,
      objetivos,
      criterios,
      avisos: selected.flatMap(a => a.avisos.map(av => (selected.length > 1 ? `${a.nombre}: ${av}` : av))),
    }
  }

  if (program.tipo === 'inicial') {
    const ageId = edad && data.edades.some(e => e.id === edad) ? edad : data.edades[data.edades.length - 1].id
    const ambitos = asignatura && asignatura !== 'todas' ? data.ambitos.filter(a => a.id === asignatura) : data.ambitos
    const criterios = ambitos.map((ambito, index) => ({
      codigo: null,
      ref: `ini.${ambito.id}`,
      ambito: ambito.nombre,
      descripcion: ambito.objetivos[0] || ambito.nombre,
      destrezas: ambito.destrezas.filter(d => d.edad === ageId).map((d, k) => ({ ...d, ref: `ini.${ambito.id}.${index + 1}.${ageId}.${k + 1}` })),
      indicadores: [],
    })).filter(c => c.destrezas.length)
    return {
      program,
      titulo: data.titulo,
      fuente: data.fuente,
      nota_codigos: 'El currículo de Educación Inicial no asigna códigos a sus destrezas; se identifican por ámbito y edad.',
      edad: data.edades.find(e => e.id === ageId),
      edades: data.edades,
      objetivos: ambitos.flatMap(a => a.objetivos.map(o => ({ codigo: null, descripcion: `${a.nombre}: ${o}` }))),
      criterios,
      avisos: ambitos[0]?.avisos || [],
    }
  }

  // Primera Infancia (0-3): cada objetivo de aprendizaje de un ámbito actúa como "criterio".
  const ageId = edad && data.edades.some(e => e.id === edad) ? edad : data.edades[data.edades.length - 1].id
  const criterios = []
  for (const ambito of data.ambitos) {
    ambito.objetivos_aprendizaje.forEach((objetivo, index) => {
      const destrezas = objetivo.filas.flatMap(fila => fila[ageId] || [])
      if (!destrezas.length) return
      criterios.push({
        codigo: null,
        ref: `${ambito.id}.${index + 1}`,
        ambito: ambito.nombre,
        eje: ambito.eje,
        descripcion: objetivo.descripcion,
        destrezas,
        indicadores: [],
      })
    })
  }
  return {
    program,
    titulo: data.titulo,
    fuente: data.fuente,
    nota_codigos: data.nota_codigos,
    edad: data.edades.find(e => e.id === ageId),
    edades: data.edades,
    objetivos: data.ambitos.map(a => ({ codigo: null, descripcion: `${a.nombre}: ${a.objetivo}` })),
    criterios,
    avisos: [],
  }
}

/** Clave estable de una destreza: el código oficial o, si el currículo no tiene códigos, su referencia interna. */
export const skillKey = destreza => destreza.codigo || destreza.ref

/** Texto oficial de la destreza tal como debe imprimirse ("A.RS.9. Reconocer…"). */
export function formatSkill(destreza) {
  return destreza.codigo ? `${destreza.codigo}. ${destreza.descripcion}` : destreza.descripcion
}

export function formatIndicator(indicador) {
  return indicador.codigo ? `${indicador.codigo}. ${indicador.descripcion}` : indicador.descripcion
}

export function formatCriterion(criterio) {
  if (criterio.codigo) {
    // Bloque fusionado en el archivo fuente: se indica a qué código corresponde la descripción disponible.
    if (criterio.codigos?.length > 1 && criterio.codigo_descripcion) {
      return `${criterio.codigos.join(' y ')} — ${criterio.codigo_descripcion}. ${criterio.descripcion}`
    }
    return `${criterio.codigo}. ${criterio.descripcion}`
  }
  if (criterio.ambito) return `Ámbito ${criterio.ambito} — ${criterio.descripcion}`
  return criterio.asignatura ? `${criterio.asignatura} — ${criterio.descripcion}` : criterio.descripcion
}
