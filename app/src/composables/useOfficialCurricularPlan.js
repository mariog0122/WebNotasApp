/**
 * Estado y acciones de la Planificación Curricular Oficial (PCA + microcurricular) basada en los
 * currículos del MinEduc y en las plantillas Word institucionales.
 */
import { computed, reactive, ref, watch } from 'vue'
import { toast } from 'vue-sonner'
import { OFFICIAL_PROGRAMS, getProgramOptions, loadProgram } from '../lib/curriculum/officialCurricula'
import {
  annualAIInput,
  applyAnnualAI,
  applyUnitAI,
  buildAnnualTemplateData,
  buildUnitTemplateData,
  distributeUnits,
  unitAIInput,
  unitDurations,
} from '../lib/curriculum/curricularPlanBuilder'
import { exportPlanDocx, safeFileName } from '../lib/curriculum/docxExport'

export function useOfficialCurricularPlan({ createGateway, institutionConfig, defaults = {} }) {
  const step = ref(1)
  const loadingCurriculum = ref(false)
  const generatingAnnual = ref(false)
  const generatingUnit = ref(null)
  const exporting = ref(false)
  const curriculum = ref(null)
  const units = ref([])
  const excluded = reactive(new Set())
  const unitPlans = reactive({})

  const datos = reactive({
    programa: 'elemental',
    edad: '',
    asignaturaCurricular: '',
    subnivel: '',
    unidadEducativa: institutionConfig?.institution_name || '',
    direccion: institutionConfig?.institution_address || '',
    anioLectivo: defaults.anioLectivo || '',
    area: '',
    asignatura: '',
    docente: defaults.docente || '',
    grado: '',
    nivel: '',
    paralelos: '',
    cargaHoraria: 20,
    semanasTrabajo: 40,
    semanasEvaluacion: 4,
    fechaInicio: '',
    fechaFin: '',
    numeroUnidades: 6,
    estudiantesNEE: 0,
    directorArea: '',
    coordinador: '',
    vicerrector: '',
    rector: institutionConfig?.institution_rector_name || '',
    valores: '',
    ejes: '',
    observaciones: '',
    fechaElaboracion: new Date().toISOString().slice(0, 10),
  })

  const autoFilled = { nivel: '', asignatura: '', area: '' }
  const programs = OFFICIAL_PROGRAMS
  const program = computed(() => programs.find(p => p.id === datos.programa))
  const options = ref({ asignaturas: [], subniveles: [], edades: [] })
  const loadingOptions = ref(false)

  const selectedOption = computed(() => options.value.asignaturas.find(a => a.id === datos.asignaturaCurricular) || null)
  const needsAsignatura = computed(() => options.value.asignaturas.length > 0)
  const needsSubnivel = computed(() => {
    const subs = selectedOption.value?.subniveles || []
    return subs.length > 1
  })
  const canContinue = computed(() => (
    !loadingOptions.value
    && (!needsAsignatura.value || (selectedOption.value && selectedOption.value.estado !== 'incompleta'))
    && (!needsSubnivel.value || Boolean(datos.subnivel))
    && (!options.value.edades.length || Boolean(datos.edad))
  ))

  async function loadOptions() {
    loadingOptions.value = true
    try {
      options.value = await getProgramOptions(datos.programa)
      const firstUsable = options.value.asignaturas.find(a => a.estado !== 'incompleta')
      datos.asignaturaCurricular = firstUsable?.id || ''
      datos.edad = options.value.edades.at(-1)?.id || ''
    } catch (err) {
      options.value = { asignaturas: [], subniveles: [], edades: [] }
      toast.error(err.message || 'No se pudo cargar el currículo.')
    } finally {
      loadingOptions.value = false
    }
  }

  watch(() => datos.programa, loadOptions, { immediate: true })
  watch(() => datos.asignaturaCurricular, () => {
    const subs = selectedOption.value?.subniveles || []
    datos.subnivel = subs.length === 1 ? subs[0] : ''
  })

  async function loadCurriculum() {
    loadingCurriculum.value = true
    try {
      curriculum.value = await loadProgram(datos.programa, {
        edad: datos.edad,
        asignatura: datos.asignaturaCurricular,
        subnivel: datos.subnivel,
      })
      excluded.clear()
      units.value = []
      Object.keys(unitPlans).forEach(k => delete unitPlans[k])
      // Rellena área/asignatura/nivel con la selección; respeta lo que el docente haya escrito a mano.
      const named = selectedOption.value && datos.asignaturaCurricular !== 'todas' ? selectedOption.value.nombre : program.value.nombre
      const next = { nivel: curriculum.value.subnivel || program.value.nombre, asignatura: named, area: named.split('/')[0].split(' (')[0] }
      for (const field of ['nivel', 'asignatura', 'area']) {
        if (!datos[field] || datos[field] === autoFilled[field]) datos[field] = next[field]
        autoFilled[field] = next[field]
      }
    } catch (err) {
      toast.error(err.message || 'No se pudo cargar el currículo.')
    } finally {
      loadingCurriculum.value = false
    }
  }

  watch(() => [datos.programa, datos.edad, datos.asignaturaCurricular, datos.subnivel], () => { curriculum.value = null })

  const selectedCriterios = computed(() => (curriculum.value?.criterios || [])
    .map(c => ({ ...c, destrezas: c.destrezas.filter(d => !excluded.has(d.codigo || d.ref)) }))
    .filter(c => c.destrezas.length))

  const totalSkills = computed(() => selectedCriterios.value.reduce((n, c) => n + c.destrezas.length, 0))

  function toggleSkill(key) {
    if (excluded.has(key)) excluded.delete(key)
    else excluded.add(key)
    units.value = []
  }

  function buildUnits() {
    units.value = distributeUnits(selectedCriterios.value, Number(datos.numeroUnidades) || 6)
    Object.keys(unitPlans).forEach(k => delete unitPlans[k])
  }

  const classWeeks = computed(() => Math.max(1, (Number(datos.semanasTrabajo) || 40) - (Number(datos.semanasEvaluacion) || 0)))
  const durations = computed(() => unitDurations(units.value, classWeeks.value))

  async function generateAnnual() {
    if (!units.value.length) buildUnits()
    generatingAnnual.value = true
    try {
      const gateway = await createGateway()
      const ai = await gateway.generateAnnualPlan(annualAIInput({ curriculum: curriculum.value, datos, units: units.value }))
      units.value = applyAnnualAI(units.value, ai)
      toast.success('Planificación anual generada. Revisa los títulos y temas antes de descargar.')
      return true
    } catch (err) {
      // Sin IA el documento igual se arma con el currículo oficial y textos de respaldo.
      units.value = applyAnnualAI(units.value, {})
      toast.error(`${err.message || 'La IA no respondió.'} Se usaron textos base; puedes editarlos.`)
      return false
    } finally {
      generatingAnnual.value = false
    }
  }

  async function generateUnit(unit) {
    generatingUnit.value = unit.numero
    try {
      const gateway = await createGateway()
      const ai = await gateway.generateUnitPlan(unitAIInput({ curriculum: curriculum.value, datos, unit }))
      unitPlans[unit.numero] = applyUnitAI(unit, ai)
      toast.success(`Microcurricular de la unidad ${unit.numero} generada.`)
    } catch (err) {
      unitPlans[unit.numero] = applyUnitAI(unit, {})
      toast.error(`${err.message || 'La IA no respondió.'} Se usaron textos base para la unidad ${unit.numero}.`)
    } finally {
      generatingUnit.value = null
    }
  }

  async function downloadAnnual() {
    exporting.value = true
    try {
      const data = buildAnnualTemplateData({ curriculum: curriculum.value, datos, units: units.value })
      await exportPlanDocx('anual', data, `PCA_${safeFileName(datos.asignatura || program.value.nombre)}_${safeFileName(datos.anioLectivo)}.docx`)
    } catch (err) {
      toast.error(err.message || 'No se pudo generar el documento Word.')
    } finally {
      exporting.value = false
    }
  }

  async function downloadUnit(unit) {
    const plan = unitPlans[unit.numero]
    if (!plan) return
    exporting.value = true
    try {
      const index = units.value.findIndex(u => u.numero === unit.numero)
      const weekOffset = durations.value.slice(0, index).reduce((a, b) => a + b, 0)
      const data = buildUnitTemplateData({ datos, unit: plan, weekCount: durations.value[index], weekOffset })
      await exportPlanDocx('micro', data, `Microcurricular_U${unit.numero}_${safeFileName(datos.asignatura || program.value.nombre)}.docx`)
    } catch (err) {
      toast.error(err.message || 'No se pudo generar el documento Word.')
    } finally {
      exporting.value = false
    }
  }

  return {
    step,
    datos,
    programs,
    program,
    options,
    loadingOptions,
    selectedOption,
    needsAsignatura,
    needsSubnivel,
    canContinue,
    curriculum,
    units,
    unitPlans,
    excluded,
    selectedCriterios,
    totalSkills,
    durations,
    classWeeks,
    loadingCurriculum,
    generatingAnnual,
    generatingUnit,
    exporting,
    loadCurriculum,
    toggleSkill,
    buildUnits,
    generateAnnual,
    generateUnit,
    downloadAnnual,
    downloadUnit,
  }
}
