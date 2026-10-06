import fs from 'node:fs'
import path from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'
import PizZip from 'pizzip'
import alfa from '../src/data/curriculos/alfabetizacion_postalfabetizacion_2025.json'
import primeraInfancia from '../src/data/curriculos/primera_infancia_0_3.json'
import { loadProgram } from '../src/lib/curriculum/officialCurricula'
import {
  applyAnnualAI,
  applyUnitAI,
  buildAnnualTemplateData,
  buildUnitTemplateData,
  cleanText,
  distributeUnits,
  scheduleWeeks,
  unitDurations,
  unitSkills,
} from '../src/lib/curriculum/curricularPlanBuilder'
import { renderDocx } from '../src/lib/curriculum/docxExport'
import { isValidEducationAIOutput } from '../../supabase/functions/education-ai/output-contracts.js'
import { GeminiEducationAIProvider } from '../../supabase/functions/education-ai/providers/GeminiEducationAIProvider.js'
import { sanitizeEducationAIInput } from '../../supabase/functions/education-ai/privacy.js'
import { annualAIInput, unitAIInput } from '../src/lib/curriculum/curricularPlanBuilder'

const templatePath = name => path.resolve(__dirname, '../public/plantillas', name)
const docText = bytes => new PizZip(bytes).file('word/document.xml').asText().replace(/<[^>]+>/g, '')
const datos = {
  unidadEducativa: 'Unidad Educativa Prueba', direccion: 'Milagro', anioLectivo: '2025 – 2026', area: 'Integrada',
  asignatura: 'Alfabetización', docente: 'Docente', grado: 'Alfabetización', cargaHoraria: 20,
  semanasTrabajo: 40, semanasEvaluacion: 4, fechaInicio: '2025-05-07', fechaFin: '2026-02-27', estudiantesNEE: 1,
}

afterEach(() => vi.unstubAllGlobals())

describe('catálogo curricular oficial extraído de los PDF del MinEduc', () => {
  it('conserva completos los mapas de Alfabetización y Postalfabetización', () => {
    const [a, p] = alfa.mapas
    const count = (mapa, key) => mapa.criterios.reduce((n, c) => n + c[key].length, 0)
    expect([a.objetivos.length, a.criterios.length, count(a, 'destrezas'), count(a, 'indicadores')]).toEqual([12, 30, 120, 63])
    expect([p.objetivos.length, p.criterios.length, count(p, 'destrezas'), count(p, 'indicadores')]).toEqual([12, 33, 124, 75])
    expect(alfa.insercion_civica.bloques.flatMap(b => b.destrezas)).toHaveLength(16)
  })

  it('usa solo códigos oficiales bien formados y sin duplicados de destreza', () => {
    for (const [mapa, letra] of [[alfa.mapas[0], 'A'], [alfa.mapas[1], 'P']]) {
      const codes = mapa.criterios.flatMap(c => c.destrezas.map(d => d.codigo))
      expect(new Set(codes).size).toBe(codes.length)
      for (const criterio of mapa.criterios) {
        expect(criterio.codigo).toMatch(new RegExp(`^CE\\.${letra}\\.\\d+$`))
        for (const d of criterio.destrezas) {
          expect(d.codigo).toMatch(new RegExp(`^${letra}\\.(RS|CC|ET)\\.\\d+$`))
          expect(d.descripcion.length).toBeGreaterThan(30)
        }
        for (const i of criterio.indicadores) expect(i.codigo).toMatch(new RegExp(`^I\\.${letra}\\.\\d+\\.\\d+$`))
      }
    }
  })

  it('copia literalmente la destreza A.RS.9 y sus inserciones', () => {
    const destreza = alfa.mapas[0].criterios[0].destrezas.find(d => d.codigo === 'A.RS.11')
    expect(destreza.descripcion).toBe('Explicar oralmente similitudes y diferencias de sus rasgos y características físicas a partir de la observación directa de sí mismo y de artesanías, esculturas e imágenes de la cultura visual.')
    expect(destreza.inserciones).toEqual(['socioemocional'])
  })

  it('Primera Infancia no inventa códigos y filtra por rango de edad', async () => {
    expect(primeraInfancia.ambitos).toHaveLength(5)
    const curriculum = await loadProgram('primera_infancia', { edad: '0_6m' })
    expect(curriculum.criterios.every(c => c.codigo === null && c.destrezas.every(d => d.codigo === null))).toBe(true)
    expect(curriculum.criterios[0].destrezas[0].descripcion).toMatch(/^Responder con miradas/)
  })
})

describe('armado de la planificación', () => {
  it('reparte todas las destrezas una sola vez en unidades contiguas y trimestres', async () => {
    const curriculum = await loadProgram('postalfabetizacion')
    const units = distributeUnits(curriculum.criterios, 6)
    expect(units.map(u => u.trimestre)).toEqual([1, 1, 2, 2, 3, 3])
    const codes = units.flatMap(u => unitSkills(u).map(s => s.destreza.codigo))
    expect(codes).toEqual(curriculum.criterios.flatMap(c => c.destrezas.map(d => d.codigo)))
    expect(units.every(u => u.criterios.length > 0)).toBe(true)
    expect(unitDurations(units, 36).reduce((a, b) => a + b, 0)).toBe(36)
  })

  it('descarta códigos que la IA invente o que no pertenezcan a la unidad', async () => {
    const curriculum = await loadProgram('alfabetizacion')
    const base = distributeUnits(curriculum.criterios, 6)
    const otherUnitCode = unitSkills(base[5])[0].destreza.codigo
    const units = applyAnnualAI(base, {
      unidades: [{ numero: 1, titulo: '<b>Mi identidad</b>', contenidos: [
        { codigo: 'A.RS.9.', tema: 'Oralidad y escritura' },
        { codigo: 'A.RS.99', tema: 'código inventado' },
        { codigo: otherUnitCode, tema: 'destreza de otra unidad' },
      ] }],
    })
    expect(units[0].titulo).toBe('Mi identidad')
    expect(units[0].temas['A.RS.9']).toBe('Oralidad y escritura')
    expect(Object.keys(units[0].temas)).not.toContain('A.RS.99')
    expect(Object.values(units[0].temas)).not.toContain('destreza de otra unidad')
    expect(units[1].titulo).toBe('Unidad 2')

    const unit = applyUnitAI(units[0], { destrezas: [{ codigo: 'X.FAKE.1', contenido_esencial: 'no' }], proyecto: { destreza_codigo: 'X.FAKE.1' } })
    expect(unit.filas.map(f => f.key)).toEqual(unitSkills(units[0]).map(s => s.destreza.codigo))
    expect(unit.proyecto.destrezaKey).toBe('A.RS.9')
  })

  it('limpia texto de IA y fija semanas lunes-viernes', () => {
    expect(cleanText('  <script>x</script>Hola\u0007 mundo ')).toBe('xHola mundo')
    expect(scheduleWeeks(3, 2, '2025-05-07')).toEqual([
      { semana: 'Semana 1', fechas: '05/05/2025 – 09/05/2025' },
      { semana: 'Semana 1', fechas: '05/05/2025 – 09/05/2025' },
      { semana: 'Semana 2', fechas: '12/05/2025 – 16/05/2025' },
    ])
  })

  it('cabe en los límites de privacidad y tamaño del servicio de IA', async () => {
    const curriculum = await loadProgram('postalfabetizacion')
    const units = applyAnnualAI(distributeUnits(curriculum.criterios, 6), {})
    const annual = annualAIInput({ curriculum, datos, units })
    const unit = unitAIInput({ curriculum, datos, unit: units[0] })
    for (const input of [annual, unit]) {
      expect(new TextEncoder().encode(JSON.stringify({ input })).byteLength).toBeLessThan(100_000)
      expect(sanitizeEducationAIInput(input).ok).toBe(true)
    }
  })
})

describe('plantillas Word institucionales', () => {
  it('llena la PCA sin marcadores sueltos y con los códigos oficiales', async () => {
    const curriculum = await loadProgram('alfabetizacion')
    const units = applyAnnualAI(distributeUnits(curriculum.criterios, 6), {})
    const text = docText(renderDocx(fs.readFileSync(templatePath('pca.docx')), buildAnnualTemplateData({ curriculum, datos, units })))
    expect(text).not.toMatch(/\{\{|\}\}|\{%/)
    expect(text).toContain('PLANIFICACIÓN CURRICULAR ANUAL 2025 – 2026')
    expect(text).toContain('O.A.12.')
    expect(text).toContain('A.RS.9:')
    expect(text).toContain('CE.A.30')
  })

  it('llena la microcurricular con destrezas e indicadores literales del currículo', async () => {
    const curriculum = await loadProgram('alfabetizacion')
    const units = applyAnnualAI(distributeUnits(curriculum.criterios, 6), {})
    const unit = applyUnitAI(units[0], {})
    const text = docText(renderDocx(fs.readFileSync(templatePath('micro.docx')), buildUnitTemplateData({ datos, unit, weekCount: 6 })))
    expect(text).not.toMatch(/\{\{|\}\}|\{%/)
    expect(text).toContain('PRIMER TRIMESTRE')
    expect(text).toContain('A.RS.9. Reconocer que la oralidad y la escritura son dos sistemas de comunicación diferentes')
    expect(text).toContain('I.A.1.1. Explica las diferencias entre la oralidad y escritura')
    expect(text).toContain('Educación Socioemocional')
  })
})

describe('servicio education-ai: tareas de planificación curricular', () => {
  it('valida la forma de las respuestas nuevas', () => {
    expect(isValidEducationAIOutput('generateAnnualPlan', { unidades: [{ numero: 1 }] })).toBe(true)
    expect(isValidEducationAIOutput('generateAnnualPlan', { unidades: [] })).toBe(false)
    expect(isValidEducationAIOutput('generateUnitPlan', { destrezas: [{ codigo: 'A.RS.9' }] })).toBe(true)
    expect(isValidEducationAIOutput('generateUnitPlan', { objetivo: 'x' })).toBe(false)
  })

  it('Gemini recibe los códigos permitidos y un límite de salida amplio', async () => {
    const fetchMock = vi.fn(async () => ({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: '{"unidades":[{"numero":1}]}' }] } }] }) }))
    vi.stubGlobal('fetch', fetchMock)
    const provider = new GeminiEducationAIProvider('synthetic-key', 'gemini-2.5-flash')
    await provider.generateAnnualPlan({ curriculo: 'Alfabetización', unidades: [{ numero: 1, trimestre: 1, criterios: [], destrezas: [{ codigo: 'A.RS.9', descripcion: 'Reconocer…' }] }] })
    const body = JSON.parse(fetchMock.mock.calls[0][1].body)
    expect(body.generationConfig.maxOutputTokens).toBe(24576)
    expect(body.contents[0].parts[0].text).toContain('A.RS.9: Reconocer…')
    expect(body.systemInstruction.parts[0].text).toMatch(/nunca inventes/)
  })
})
