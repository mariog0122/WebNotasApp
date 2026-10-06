<script setup>
import { computed, ref } from 'vue'
import { X, FileText, Loader2, Download, Sparkles, ChevronLeft, ChevronRight, BookOpenCheck, Info } from 'lucide-vue-next'
import { useOfficialCurricularPlan } from '../../composables/useOfficialCurricularPlan'
import { INSERTION_TYPES, formatCriterion } from '../../lib/curriculum/officialCurricula'
import { TRIMESTRES, unitSkills } from '../../lib/curriculum/curricularPlanBuilder'

const props = defineProps({
  createGateway: { type: Function, required: true },
  institutionConfig: { type: Object, default: () => ({}) },
  defaults: { type: Object, default: () => ({}) },
  isDemo: { type: Boolean, default: false },
  onClose: { type: Function, required: true },
})

const plan = useOfficialCurricularPlan({
  createGateway: props.createGateway,
  institutionConfig: props.institutionConfig,
  defaults: props.defaults,
})
const {
  step, datos, programs, program, curriculum, units, unitPlans, excluded, totalSkills, durations, classWeeks,
  loadingCurriculum, generatingAnnual, generatingUnit, exporting,
  options, loadingOptions, selectedOption, needsAsignatura, needsSubnivel, canContinue,
} = plan

const programGroups = computed(() => {
  const groups = {}
  for (const p of programs) (groups[p.grupo] ||= []).push(p)
  return groups
})
const estadoLabel = { completa: 'Verificada', con_avisos: 'Con correcciones', incompleta: 'Incompleta' }
const showNotices = ref(false)

const steps = ['Currículo y datos', 'Destrezas y unidades', 'Generar y descargar']
const annualReady = computed(() => units.value.some(u => u.temas))

async function goToSkills() {
  if (!curriculum.value) await plan.loadCurriculum()
  if (curriculum.value) step.value = 2
}

function goBack() {
  if (step.value > 1) step.value -= 1
}

function goToGenerate() {
  plan.buildUnits()
  step.value = 3
}

const input = 'mt-1 h-10 w-full rounded-xl border border-slate-300 bg-white px-3 text-sm text-slate-800 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100'
const label = 'block text-xs font-semibold text-slate-600 dark:text-slate-300'
const primaryBtn = 'inline-flex h-10 items-center gap-2 rounded-xl bg-indigo-600 px-4 text-sm font-bold text-white transition-colors hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50'
const secondaryBtn = 'inline-flex h-10 items-center gap-2 rounded-xl border border-slate-300 px-4 text-sm font-semibold text-slate-700 transition-colors hover:bg-slate-100 disabled:opacity-50 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800'
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/80 p-3 backdrop-blur-sm sm:p-5" role="dialog" aria-modal="true" aria-labelledby="official-plan-title">
    <div class="flex max-h-[94vh] w-full max-w-5xl flex-col overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-2xl dark:border-slate-800 dark:bg-slate-900">
      <!-- Encabezado -->
      <div class="flex items-center justify-between border-b border-slate-200 bg-slate-50 px-6 py-4 dark:border-slate-800 dark:bg-slate-900/80">
        <div class="flex items-center gap-3">
          <div class="rounded-2xl border border-indigo-500/20 bg-indigo-500/10 p-2.5 text-indigo-600 dark:text-indigo-400">
            <BookOpenCheck class="h-6 w-6" />
          </div>
          <div>
            <h2 id="official-plan-title" class="text-base font-bold text-slate-900 dark:text-white">Planificación Curricular Oficial (PCA y Microcurricular)</h2>
            <p class="text-xs text-slate-500 dark:text-slate-400">Códigos y destrezas copiados del currículo del MinEduc · formato de las plantillas institucionales</p>
          </div>
        </div>
        <button type="button" class="rounded-xl p-2 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600 dark:hover:bg-slate-800 dark:hover:text-slate-200" aria-label="Cerrar" @click="onClose">
          <X class="h-5 w-5" />
        </button>
      </div>

      <!-- Pasos -->
      <ol class="flex gap-2 border-b border-slate-200 px-6 py-3 text-xs dark:border-slate-800">
        <li v-for="(name, i) in steps" :key="name"
          :class="['flex items-center gap-2 rounded-full px-3 py-1 font-semibold', step === i + 1 ? 'bg-indigo-600 text-white' : step > i + 1 ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-400' : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400']">
          <span>{{ i + 1 }}</span><span class="hidden sm:inline">{{ name }}</span>
        </li>
      </ol>

      <div class="flex-1 overflow-y-auto px-6 py-5">
        <!-- Paso 1 -->
        <section v-if="step === 1" class="space-y-5">
          <div class="grid gap-4 md:grid-cols-3">
            <label :class="label">Currículo oficial
              <select v-model="datos.programa" :class="input">
                <optgroup v-for="(list, grupo) in programGroups" :key="grupo" :label="grupo">
                  <option v-for="p in list" :key="p.id" :value="p.id">{{ p.nombre }}</option>
                </optgroup>
              </select>
            </label>
            <label v-if="needsAsignatura" :class="label">{{ program?.tipo === 'inicial' ? 'Ámbito' : 'Asignatura del currículo' }}
              <select v-model="datos.asignaturaCurricular" :class="input" :disabled="loadingOptions">
                <option v-for="a in options.asignaturas" :key="a.id" :value="a.id" :disabled="a.estado === 'incompleta'">
                  {{ a.nombre }}{{ a.estado === 'incompleta' ? ' (no disponible)' : '' }}
                </option>
              </select>
            </label>
            <label v-if="needsSubnivel" :class="label">Subnivel
              <select v-model="datos.subnivel" :class="input">
                <option value="" disabled>Selecciona…</option>
                <option v-for="sub in selectedOption?.subniveles || []" :key="sub" :value="sub">{{ options.subniveles.find(s => s.id === sub)?.nombre || sub }}</option>
              </select>
            </label>
            <label v-if="options.edades.length" :class="label">Rango de edad
              <select v-model="datos.edad" :class="input">
                <option v-for="e in options.edades" :key="e.id" :value="e.id">{{ e.nombre }}</option>
              </select>
            </label>
          </div>
          <p v-if="program?.tipo === 'por_ambitos' || program?.tipo === 'inicial'" class="flex items-start gap-2 rounded-xl border border-amber-500/30 bg-amber-500/10 p-3 text-xs text-amber-800 dark:text-amber-300">
            <Info class="mt-0.5 h-4 w-4 shrink-0" />
            Este currículo no asigna códigos a sus destrezas: se planifica por ámbito y rango de edad, sin inventar códigos.
          </p>
          <div v-if="selectedOption && selectedOption.id !== 'todas'" class="rounded-xl border p-3 text-xs"
            :class="selectedOption.estado === 'completa' ? 'border-emerald-500/30 bg-emerald-500/10 text-emerald-800 dark:text-emerald-300' : selectedOption.estado === 'incompleta' ? 'border-rose-500/30 bg-rose-500/10 text-rose-800 dark:text-rose-300' : 'border-amber-500/30 bg-amber-500/10 text-amber-800 dark:text-amber-300'">
            <p class="font-semibold">
              {{ estadoLabel[selectedOption.estado] }} · {{ selectedOption.total }} destrezas
              <span v-if="selectedOption.fusionados"> · {{ selectedOption.fusionados }} bloques con criterios fusionados en el archivo fuente</span>
            </p>
            <button v-if="selectedOption.avisos?.length" type="button" class="mt-1 underline" @click="showNotices = !showNotices">
              {{ showNotices ? 'Ocultar' : 'Ver' }} {{ selectedOption.avisos.length }} corrección(es) aplicadas
            </button>
            <ul v-if="showNotices" class="mt-2 list-disc space-y-0.5 pl-5">
              <li v-for="(av, i) in selectedOption.avisos" :key="i">{{ av }}</li>
            </ul>
          </div>

          <div class="grid gap-4 md:grid-cols-3">
            <label :class="label">Unidad educativa<input v-model="datos.unidadEducativa" :class="input"></label>
            <label :class="label">Dirección / ciudad<input v-model="datos.direccion" :class="input"></label>
            <label :class="label">Año lectivo<input v-model="datos.anioLectivo" placeholder="2025 – 2026" :class="input"></label>
            <label :class="label">Área<input v-model="datos.area" :class="input"></label>
            <label :class="label">Asignatura<input v-model="datos.asignatura" :class="input"></label>
            <label :class="label">Docente<input v-model="datos.docente" :class="input"></label>
            <label :class="label">Grado / curso<input v-model="datos.grado" :class="input"></label>
            <label :class="label">Paralelos<input v-model="datos.paralelos" :class="input"></label>
            <label :class="label">Nivel educativo<input v-model="datos.nivel" :placeholder="program?.nombre" :class="input"></label>
            <label :class="label">Fecha de inicio<input v-model="datos.fechaInicio" type="date" :class="input"></label>
            <label :class="label">Fecha de fin<input v-model="datos.fechaFin" type="date" :class="input"></label>
            <label :class="label">Carga horaria semanal<input v-model.number="datos.cargaHoraria" type="number" min="1" max="60" :class="input"></label>
            <label :class="label">Semanas de trabajo<input v-model.number="datos.semanasTrabajo" type="number" min="1" max="52" :class="input"></label>
            <label :class="label">Semanas de evaluación e imprevistos<input v-model.number="datos.semanasEvaluacion" type="number" min="0" max="20" :class="input"></label>
            <label :class="label">Estudiantes con NEE en el curso<input v-model.number="datos.estudiantesNEE" type="number" min="0" max="60" :class="input"></label>
            <label :class="label">Director/a de área<input v-model="datos.directorArea" :class="input"></label>
            <label :class="label">Coordinador/a técnico pedagógico<input v-model="datos.coordinador" :class="input"></label>
            <label :class="label">Vicerrector/a<input v-model="datos.vicerrector" :class="input"></label>
            <label :class="label">Rector/a<input v-model="datos.rector" :class="input"></label>
          </div>
        </section>

        <!-- Paso 2 -->
        <section v-else-if="step === 2 && curriculum" class="space-y-4">
          <div class="flex flex-wrap items-end justify-between gap-3">
            <p class="text-sm text-slate-600 dark:text-slate-300">
              <strong>{{ totalSkills }}</strong> destrezas seleccionadas de <em>{{ curriculum.titulo }}</em>. Desmarca las que no trabajarás este año.
            </p>
            <label :class="label">Número de unidades
              <input v-model.number="datos.numeroUnidades" type="number" min="1" max="12" class="mt-1 h-10 w-24 rounded-xl border border-slate-300 px-3 text-sm dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100">
            </label>
          </div>
          <div v-for="criterio in curriculum.criterios" :key="(criterio.codigo || criterio.ref) + (criterio.asignatura || '')" class="rounded-2xl border border-slate-200 p-4 dark:border-slate-800">
            <p v-if="criterio.asignatura && curriculum.asignatura === 'Currículo integrado'" class="mb-1 text-[10px] font-bold uppercase tracking-wider text-slate-400">{{ criterio.asignatura }}</p>
            <p class="text-xs font-bold text-slate-800 dark:text-slate-100">{{ formatCriterion(criterio) }}</p>
            <p v-if="criterio.nota" class="mt-1 text-[11px] text-amber-700 dark:text-amber-400">{{ criterio.nota }}</p>
            <ul class="mt-2 space-y-1.5">
              <li v-for="d in criterio.destrezas" :key="d.codigo || d.ref">
                <label class="flex cursor-pointer items-start gap-2 text-xs text-slate-600 dark:text-slate-300">
                  <input type="checkbox" class="mt-0.5 rounded" :checked="!excluded.has(d.codigo || d.ref)" @change="plan.toggleSkill(d.codigo || d.ref)">
                  <span><strong v-if="d.codigo" class="text-indigo-700 dark:text-indigo-400">{{ d.codigo }}</strong> {{ d.descripcion }}
                    <span v-for="ins in d.inserciones || []" :key="ins" class="ml-1 inline-block rounded-full bg-teal-500/10 px-2 py-0.5 text-[10px] font-semibold text-teal-700 dark:text-teal-400">{{ INSERTION_TYPES[ins]?.label || ins }}</span>
                  </span>
                </label>
              </li>
            </ul>
          </div>
        </section>

        <!-- Paso 3 -->
        <section v-else-if="step === 3" class="space-y-4">
          <div class="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-indigo-500/20 bg-indigo-500/5 p-4">
            <div class="text-sm text-slate-700 dark:text-slate-200">
              <p class="font-bold">{{ units.length }} unidades · {{ classWeeks }} semanas de clase</p>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                La IA {{ isDemo ? '(modo demostración)' : '' }} redacta títulos, temas de clase y orientaciones; los códigos, destrezas e indicadores se copian del currículo oficial.
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <button type="button" :class="secondaryBtn" :disabled="generatingAnnual" @click="plan.generateAnnual">
                <Loader2 v-if="generatingAnnual" class="h-4 w-4 animate-spin" /><Sparkles v-else class="h-4 w-4" />
                {{ annualReady ? 'Regenerar con IA' : 'Generar PCA con IA' }}
              </button>
              <button type="button" :class="primaryBtn" :disabled="!annualReady || exporting" @click="plan.downloadAnnual">
                <Download class="h-4 w-4" /> Descargar PCA (Word)
              </button>
            </div>
          </div>

          <article v-for="(unit, index) in units" :key="unit.numero" class="rounded-2xl border border-slate-200 p-4 dark:border-slate-800">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="min-w-0 flex-1">
                <p class="text-[11px] font-bold uppercase tracking-wider text-slate-400">{{ TRIMESTRES[(unit.trimestre || 1) - 1] }} · {{ durations[index] }} semanas</p>
                <div class="mt-1 flex items-center gap-2">
                  <span class="text-sm font-bold text-slate-900 dark:text-white">Unidad {{ unit.numero }}:</span>
                  <input v-if="unit.temas" v-model="unit.titulo" class="h-8 min-w-0 flex-1 rounded-lg border border-slate-300 px-2 text-sm dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100">
                  <span v-else class="text-sm text-slate-400">(se titulará al generar)</span>
                </div>
              </div>
              <div class="flex flex-wrap gap-2">
                <button type="button" :class="secondaryBtn" :disabled="!unit.temas || generatingUnit !== null" @click="plan.generateUnit(unit)">
                  <Loader2 v-if="generatingUnit === unit.numero" class="h-4 w-4 animate-spin" /><Sparkles v-else class="h-4 w-4" />
                  Microcurricular
                </button>
                <button type="button" :class="primaryBtn" :disabled="!unitPlans[unit.numero] || exporting" @click="plan.downloadUnit(unit)">
                  <FileText class="h-4 w-4" /> Word
                </button>
              </div>
            </div>
            <ul class="mt-3 space-y-1.5">
              <li v-for="{ destreza } in unitSkills(unit)" :key="destreza.codigo || destreza.ref" class="grid gap-2 text-xs sm:grid-cols-[110px_1fr]">
                <span class="font-bold text-indigo-700 dark:text-indigo-400">{{ destreza.codigo || 'Destreza' }}</span>
                <input v-if="unit.temas" v-model="unit.temas[destreza.codigo || destreza.ref]" class="h-8 rounded-lg border border-slate-200 px-2 text-xs text-slate-700 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-200" :title="destreza.descripcion">
                <span v-else class="text-slate-500 dark:text-slate-400">{{ destreza.descripcion }}</span>
              </li>
            </ul>
          </article>
        </section>
      </div>

      <!-- Pie -->
      <div class="flex items-center justify-between border-t border-slate-200 bg-slate-50 px-6 py-3 dark:border-slate-800 dark:bg-slate-900/80">
        <button type="button" :class="secondaryBtn" :disabled="step === 1" @click="goBack">
          <ChevronLeft class="h-4 w-4" /> Anterior
        </button>
        <button v-if="step === 1" type="button" :class="primaryBtn" :disabled="loadingCurriculum || !canContinue" @click="goToSkills">
          <Loader2 v-if="loadingCurriculum" class="h-4 w-4 animate-spin" /> Ver destrezas <ChevronRight class="h-4 w-4" />
        </button>
        <button v-else-if="step === 2" type="button" :class="primaryBtn" :disabled="!totalSkills" @click="goToGenerate">
          Armar unidades <ChevronRight class="h-4 w-4" />
        </button>
        <button v-else type="button" :class="secondaryBtn" @click="onClose">Cerrar</button>
      </div>
    </div>
  </div>
</template>
