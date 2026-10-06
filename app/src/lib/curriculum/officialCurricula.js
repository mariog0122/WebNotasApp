/**
 * Catálogo de currículos oficiales del MinEduc cargados desde los PDF institucionales.
 * Los códigos y textos son copia literal del documento oficial (ver scripts/curriculum/*):
 * ninguna parte de la app ni de la IA puede inventarlos o modificarlos.
 */

export const INSERTION_TYPES = Object.freeze({
  civica_etica_integridad: { label: 'Educación Cívica, Ética e Integridad', enfoque: 'Enfoque Humanista' },
  desarrollo_sostenible: { label: 'Educación para el Desarrollo Sostenible', enfoque: 'Enfoque Integral' },
  socioemocional: { label: 'Educación Socioemocional', enfoque: 'Enfoque Integral y Preventivo' },
  financiera: { label: 'Educación Financiera', enfoque: 'Enfoque Sociocultural' },
  seguridad_vial: { label: 'Educación para la Seguridad Vial y Movilidad Sostenible', enfoque: 'Enfoque Movilidad Sostenible' },
  seguridad_integral: { label: 'Educación para la Seguridad Integral', enfoque: 'Enfoque Integral' },
})

/** Programas disponibles para planificar. `subnivel` apunta al mapa curricular dentro del archivo. */
export const OFFICIAL_PROGRAMS = Object.freeze([
  {
    id: 'alfabetizacion',
    nombre: 'Alfabetización (personas jóvenes, adultas y adultas mayores)',
    archivo: 'alfabetizacion_postalfabetizacion_2025',
    subnivel: 'alfabetizacion',
    tipo: 'codificado',
  },
  {
    id: 'postalfabetizacion',
    nombre: 'Postalfabetización (personas jóvenes, adultas y adultas mayores)',
    archivo: 'alfabetizacion_postalfabetizacion_2025',
    subnivel: 'postalfabetizacion',
    tipo: 'codificado',
  },
  {
    id: 'primera_infancia',
    nombre: 'Educación de la Primera Infancia (0-3 años)',
    archivo: 'primera_infancia_0_3',
    tipo: 'por_ambitos',
  },
])

const loaders = {
  alfabetizacion_postalfabetizacion_2025: () => import('../../data/curriculos/alfabetizacion_postalfabetizacion_2025.json'),
  primera_infancia_0_3: () => import('../../data/curriculos/primera_infancia_0_3.json'),
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
 * Devuelve el currículo normalizado:
 * { program, titulo, fuente, objetivos, criterios: [{codigo, descripcion, destrezas, indicadores}], civica? }
 * Para Primera Infancia (sin códigos oficiales) cada objetivo de aprendizaje de un ámbito actúa
 * como "criterio" y sus destrezas se filtran por rango de edad.
 */
export async function loadProgram(programId, { edad } = {}) {
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
    }
  }

  const ageId = edad || data.edades[data.edades.length - 1].id
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
  if (criterio.codigo) return `${criterio.codigo}. ${criterio.descripcion}`
  return criterio.ambito ? `Ámbito ${criterio.ambito} — ${criterio.descripcion}` : criterio.descripcion
}
