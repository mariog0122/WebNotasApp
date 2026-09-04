<script setup>
import { computed } from 'vue'
import { 
  X, 
  ChevronRight, 
  ChevronLeft, 
  Sparkles, 
  Check, 
  BookOpen, 
  Compass, 
  Layers, 
  HeartHandshake, 
  HelpCircle, 
  Clock, 
  Users, 
  Sliders, 
  FileCheck2, 
  CheckCircle2, 
  AlertCircle,
  BrainCircuit,
  Loader2
} from 'lucide-vue-next'
import { 
  EDUCATIONAL_REGIMES, 
  EDUCATIONAL_LEVELS, 
  MINEDUC_SUBJECTS, 
  BLOOM_LEVELS, 
  MINEDUC_COMPETENCIES, 
  PEDAGOGICAL_METHODOLOGIES, 
  DUA_OPTIONS, 
  getCurriculumItems 
} from '../../lib/ecuadorCurriculumCatalog'

const props = defineProps({
  step: {
    type: Number,
    default: 1
  },
  formData: {
    type: Object,
    required: true
  },
  courses: {
    type: Array,
    default: () => []
  },
  subjects: {
    type: Array,
    default: () => []
  },
  generating: {
    type: Boolean,
    default: false
  },
  isDemo: {
    type: Boolean,
    default: true
  },
  onNext: {
    type: Function,
    required: true
  },
  onPrev: {
    type: Function,
    required: true
  },
  onGenerate: {
    type: Function,
    required: true
  },
  onClose: {
    type: Function,
    required: true
  },
  onGradeSelect: {
    type: Function,
    required: true
  }
})

// Grados disponibles para el nivel seleccionado
const availableGrades = computed(() => {
  const levelObj = EDUCATIONAL_LEVELS.find(l => l.id === props.formData.level)
  return levelObj ? levelObj.grades : []
})

// Asignaturas para el nivel seleccionado
const availableSubjects = computed(() => {
  return MINEDUC_SUBJECTS[props.formData.level] || MINEDUC_SUBJECTS.basica_media
})

// Items curriculares sugeridos desde el catálogo oficial
const catalogSuggestions = computed(() => {
  return getCurriculumItems({
    level: props.formData.level,
    gradeYear: props.formData.grade_year,
    subjectName: props.formData.subject_name
  })
})

const selectCatalogItem = (item) => {
  props.formData.unit_title = item.unit_title
  props.formData.topic_title = item.topic_title
  props.formData.dcd_codes = [item.dcd_code]
  props.formData.dcd_descriptions = [item.dcd_description]
  props.formData.evaluation_criteria_codes = [item.evaluation_criteria_code]
  props.formData.evaluation_criteria_descriptions = [item.evaluation_criteria_description]
  props.formData.evaluation_indicators = [item.evaluation_indicator_description]
  props.formData.learning_objectives = [item.learning_objective_description]
  props.formData.bloom_level = item.bloom_level
}

const toggleCompetency = (compId) => {
  const idx = props.formData.competencies.indexOf(compId)
  if (idx > -1) {
    props.formData.competencies.splice(idx, 1)
  } else {
    props.formData.competencies.push(compId)
  }
}

const toggleMethodologySecondary = (methId) => {
  const idx = props.formData.methodology_secondary.indexOf(methId)
  if (idx > -1) {
    props.formData.methodology_secondary.splice(idx, 1)
  } else if (props.formData.methodology_secondary.length < 2) {
    props.formData.methodology_secondary.push(methId)
  }
}

const toggleResource = (res) => {
  const idx = props.formData.available_resources.indexOf(res)
  if (idx > -1) {
    props.formData.available_resources.splice(idx, 1)
  } else {
    props.formData.available_resources.push(res)
  }
}

const stepTitles = [
  { num: 1, title: 'Contexto Académico', desc: 'Régimen, grado, asignatura y tema' },
  { num: 2, title: 'Propósito Curricular', desc: 'DCD, criterios, indicadores y Bloom' },
  { num: 3, title: 'Diseño Metodológico', desc: 'ERCA, ABP, modalidad y recursos' },
  { num: 4, title: 'Inclusión y DUA', desc: 'Accesibilidad, barreras y apoyos' },
  { num: 5, title: 'Revisión y Generación', desc: 'Resumen e interruptores de salida' }
]
</script>

<template>
  <div class="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-3 sm:p-5 overflow-y-auto">
    <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl shadow-2xl w-full max-w-4xl max-h-[92vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
      
      <!-- Header -->
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-900/80">
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-2xl bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-500/20">
            <BrainCircuit class="w-6 h-6" />
          </div>
          <div>
            <div class="flex items-center gap-2">
              <h2 class="text-lg font-bold text-slate-900 dark:text-white">Asistente de Planificación Curricular</h2>
              <span v-if="isDemo" class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/30">
                Modo Demostración
              </span>
            </div>
            <p class="text-xs text-slate-500 dark:text-slate-400">Currículo Nacional del Ecuador · Selección guiada sin escribir prompts</p>
          </div>
        </div>

        <button
          @click="onClose"
          type="button"
          class="p-2 rounded-xl text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <!-- Step Progress Bar -->
      <div class="px-6 py-3 bg-slate-100/70 dark:bg-slate-950/70 border-b border-slate-200 dark:border-slate-800">
        <div class="flex items-center justify-between relative">
          <!-- Connective line -->
          <div class="absolute left-4 right-4 top-1/2 -translate-y-1/2 h-0.5 bg-slate-200 dark:bg-slate-800 -z-0"></div>
          
          <div 
            v-for="st in stepTitles" 
            :key="st.num"
            class="relative z-10 flex flex-col items-center cursor-pointer"
          >
            <div 
              :class="[
                'w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all shadow-sm',
                step === st.num 
                  ? 'bg-indigo-600 text-white ring-4 ring-indigo-500/20 scale-110' 
                  : step > st.num 
                    ? 'bg-emerald-500 text-white' 
                    : 'bg-white dark:bg-slate-800 text-slate-400 border border-slate-300 dark:border-slate-700'
              ]"
            >
              <Check v-if="step > st.num" class="w-4 h-4" />
              <span v-else>{{ st.num }}</span>
            </div>
            <span :class="['text-[10px] font-semibold mt-1 hidden sm:block', step === st.num ? 'text-indigo-600 dark:text-indigo-400' : 'text-slate-400']">
              {{ st.title }}
            </span>
          </div>
        </div>
      </div>

      <!-- Step Content Area -->
      <div class="p-6 overflow-y-auto flex-1 custom-scrollbar space-y-6">

        <!-- ========================================================================= -->
        <!-- PASO 1: CONTEXTO ACADÉMICO -->
        <!-- ========================================================================= -->
        <div v-if="step === 1" class="space-y-5 animate-in fade-in duration-200">
          <div>
            <h3 class="text-sm font-bold text-slate-900 dark:text-white">Paso 1: Contexto Académico e Institucional</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">Define el régimen, grado, asignatura y parámetros de la clase.</p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <!-- Régimen -->
            <div>
              <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Régimen Escolar</label>
              <div class="grid grid-cols-2 gap-2">
                <button
                  v-for="reg in EDUCATIONAL_REGIMES"
                  :key="reg.id"
                  @click="formData.regime = reg.id"
                  type="button"
                  :class="[
                    'p-3 rounded-2xl border text-left transition-all text-xs font-semibold',
                    formData.regime === reg.id
                      ? 'border-indigo-500 bg-indigo-50/50 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 shadow-sm'
                      : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'
                  ]"
                >
                  <p class="font-bold">{{ reg.name }}</p>
                  <p class="text-[10px] text-slate-400 mt-0.5">{{ reg.description }}</p>
                </button>
              </div>
            </div>

            <!-- Nivel / Subnivel -->
            <div>
              <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Subnivel Educativo</label>
              <select
                v-model="formData.level"
                @change="onGradeSelect(availableGrades[0]?.id)"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
              >
                <option v-for="lvl in EDUCATIONAL_LEVELS" :key="lvl.id" :value="lvl.id">{{ lvl.name }}</option>
              </select>
            </div>

            <!-- Grado / Año y Paralelo -->
            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Grado / Año</label>
                <select
                  v-model="formData.grade_year"
                  @change="onGradeSelect(formData.grade_year)"
                  class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2.5 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
                >
                  <option v-for="g in availableGrades" :key="g.id" :value="g.id">{{ g.name }}</option>
                </select>
              </div>

              <div>
                <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Paralelo</label>
                <select
                  v-model="formData.parallel"
                  class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2.5 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
                >
                  <option value="A">Paralelo A</option>
                  <option value="B">Paralelo B</option>
                  <option value="C">Paralelo C</option>
                  <option value="D">Paralelo D</option>
                  <option value="Unico">Paralelo Único</option>
                </select>
              </div>
            </div>

            <!-- Asignatura -->
            <div>
              <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Asignatura</label>
              <select
                v-model="formData.subject_name"
                @change="onGradeSelect(formData.grade_year)"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
              >
                <option v-for="s in availableSubjects" :key="s" :value="s">{{ s }}</option>
              </select>
            </div>
          </div>

          <!-- Sugerencias del Catálogo Curricular -->
          <div class="pt-2">
            <div class="flex items-center justify-between mb-2">
              <label class="text-xs font-bold text-slate-700 dark:text-slate-300 flex items-center gap-1.5">
                <Sparkles class="w-3.5 h-3.5 text-indigo-500" />
                Catálogo Curricular Nacional (Selecciona un tema para auto-llenar DCD y Criterios)
              </label>
            </div>

            <div v-if="catalogSuggestions.length > 0" class="grid grid-cols-1 gap-2 max-h-48 overflow-y-auto custom-scrollbar p-1">
              <button
                v-for="item in catalogSuggestions"
                :key="item.id"
                @click="selectCatalogItem(item)"
                type="button"
                :class="[
                  'p-3 rounded-2xl border text-left transition-all text-xs flex items-start justify-between gap-3',
                  formData.topic_title === item.topic_title
                    ? 'border-indigo-500 bg-indigo-50/60 dark:bg-indigo-500/10 text-slate-900 dark:text-white ring-1 ring-indigo-500'
                    : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'
                ]"
              >
                <div>
                  <div class="flex items-center gap-2">
                    <span class="px-2 py-0.5 rounded text-[10px] font-mono font-bold bg-slate-200 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                      {{ item.dcd_code }}
                    </span>
                    <strong class="font-bold text-slate-900 dark:text-white">{{ item.topic_title }}</strong>
                  </div>
                  <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1 line-clamp-2">{{ item.dcd_description }}</p>
                </div>
                <div v-if="formData.topic_title === item.topic_title" class="shrink-0 text-indigo-600 dark:text-indigo-400">
                  <CheckCircle2 class="w-5 h-5" />
                </div>
              </button>
            </div>
          </div>

          <!-- Duración, Sesiones y Estudiantes -->
          <div class="grid grid-cols-3 gap-3 pt-2">
            <div>
              <label class="block text-[11px] font-bold text-slate-600 dark:text-slate-400 mb-1">Duración (min)</label>
              <input
                v-model.number="formData.duration_minutes"
                type="number"
                min="30"
                max="120"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white"
              />
            </div>
            <div>
              <label class="block text-[11px] font-bold text-slate-600 dark:text-slate-400 mb-1">Sesiones de Clase</label>
              <input
                v-model.number="formData.session_count"
                type="number"
                min="1"
                max="10"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white"
              />
            </div>
            <div>
              <label class="block text-[11px] font-bold text-slate-600 dark:text-slate-400 mb-1">Nº Estudiantes</label>
              <input
                v-model.number="formData.students_count"
                type="number"
                min="5"
                max="60"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white"
              />
            </div>
          </div>
        </div>

        <!-- ========================================================================= -->
        <!-- PASO 2: PROPÓSITO CURRICULAR -->
        <!-- ========================================================================= -->
        <div v-else-if="step === 2" class="space-y-5 animate-in fade-in duration-200">
          <div>
            <h3 class="text-sm font-bold text-slate-900 dark:text-white">Paso 2: Propósito Curricular y Nivel Cognitivo</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">Competencias MinEduc, Destrezas (DCD), Criterios e Indicadores.</p>
          </div>

          <!-- Competencias Transversales -->
          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-2">Competencias a Desarrollar</label>
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
              <button
                v-for="comp in MINEDUC_COMPETENCIES"
                :key="comp.id"
                @click="toggleCompetency(comp.id)"
                type="button"
                :class="[
                  'p-3 rounded-2xl border text-left transition-all text-xs font-semibold flex flex-col justify-between h-20',
                  formData.competencies.includes(comp.id)
                    ? 'border-teal-500 bg-teal-50/60 dark:bg-teal-500/10 text-teal-700 dark:text-teal-300 ring-1 ring-teal-500'
                    : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'
                ]"
              >
                <span>{{ comp.name }}</span>
                <span v-if="formData.competencies.includes(comp.id)" class="text-[10px] font-bold text-teal-600 dark:text-teal-400 flex items-center gap-1">
                  <Check class="w-3 h-3" /> Seleccionada
                </span>
              </button>
            </div>
          </div>

          <!-- Destreza con Criterio de Desempeño (DCD) -->
          <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-950/50 space-y-3">
            <div class="flex items-center justify-between">
              <label class="text-xs font-bold text-slate-900 dark:text-white flex items-center gap-2">
                <span class="px-2 py-0.5 rounded bg-indigo-600 text-white font-mono text-[10px]">
                  {{ formData.dcd_codes[0] || 'DCD' }}
                </span>
                Destreza con Criterio de Desempeño (MinEduc)
              </label>
            </div>
            <p class="text-xs text-slate-700 dark:text-slate-300 leading-relaxed font-medium">
              {{ formData.dcd_descriptions[0] || 'Sin destreza seleccionada' }}
            </p>
          </div>

          <!-- Criterio e Indicador de Evaluación -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div class="p-3.5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-1.5">
              <span class="text-[10px] font-bold font-mono text-cyan-600 dark:text-cyan-400">
                CRITERIO DE EVALUACIÓN: {{ formData.evaluation_criteria_codes[0] || 'CE' }}
              </span>
              <p class="text-xs text-slate-600 dark:text-slate-300 line-clamp-3">
                {{ formData.evaluation_criteria_descriptions[0] || 'Criterio oficial de la unidad.' }}
              </p>
            </div>

            <div class="p-3.5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-1.5">
              <span class="text-[10px] font-bold font-mono text-emerald-600 dark:text-emerald-400">
                INDICADOR DE EVALUACIÓN
              </span>
              <p class="text-xs text-slate-600 dark:text-slate-300 line-clamp-3">
                {{ formData.evaluation_indicators[0] || 'Indicador de logro de la destreza.' }}
              </p>
            </div>
          </div>

          <!-- Nivel Cognitivo de Bloom -->
          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-2">Nivel Cognitivo (Taxonomía de Bloom)</label>
            <div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
              <button
                v-for="b in BLOOM_LEVELS"
                :key="b.id"
                @click="formData.bloom_level = b.id"
                type="button"
                :class="[
                  'p-3 rounded-2xl border text-left transition-all text-xs',
                  formData.bloom_level === b.id
                    ? 'border-indigo-500 bg-indigo-50/60 dark:bg-indigo-500/10 text-indigo-700 dark:text-indigo-300 font-bold ring-1 ring-indigo-500'
                    : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300 font-medium'
                ]"
              >
                <div class="font-bold">{{ b.name }}</div>
                <div class="text-[10px] text-slate-400 mt-0.5 line-clamp-1">{{ b.description }}</div>
              </button>
            </div>
          </div>
        </div>

        <!-- ========================================================================= -->
        <!-- PASO 3: DISEÑO METODOLÓGICO -->
        <!-- ========================================================================= -->
        <div v-else-if="step === 3" class="space-y-5 animate-in fade-in duration-200">
          <div>
            <h3 class="text-sm font-bold text-slate-900 dark:text-white">Paso 3: Diseño Metodológico y Organización de Clase</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">Selecciona la metodología rectora (ERCA), complementarias y recursos de aula.</p>
          </div>

          <!-- Metodología Principal -->
          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-2">Metodología Principal</label>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <button
                v-for="meth in PEDAGOGICAL_METHODOLOGIES"
                :key="meth.id"
                @click="formData.methodology_primary = meth.id"
                type="button"
                :class="[
                  'p-3.5 rounded-2xl border text-left transition-all text-xs flex flex-col justify-between',
                  formData.methodology_primary === meth.id
                    ? 'border-indigo-500 bg-indigo-50/60 dark:bg-indigo-500/10 text-slate-900 dark:text-white ring-2 ring-indigo-500'
                    : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'
                ]"
              >
                <div>
                  <div class="flex items-center justify-between">
                    <strong class="font-bold text-slate-900 dark:text-white">{{ meth.name }}</strong>
                    <span v-if="meth.id === 'ERCA'" class="px-2 py-0.5 rounded text-[9px] font-bold bg-teal-500/20 text-teal-600 dark:text-teal-400">Recomendada</span>
                  </div>
                  <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">{{ meth.subtitle }}</p>
                </div>
              </button>
            </div>
          </div>

          <!-- Modalidad y Organización Grupal -->
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Modalidad de Clase</label>
              <div class="grid grid-cols-3 gap-2">
                <button
                  v-for="m in [{ id: 'presencial', label: 'Presencial' }, { id: 'virtual', label: 'Virtual' }, { id: 'hibrida', label: 'Híbrida' }]"
                  :key="m.id"
                  @click="formData.modality = m.id"
                  type="button"
                  :class="[
                    'py-2 px-3 rounded-xl border text-center text-xs font-bold transition-all',
                    formData.modality === m.id
                      ? 'border-indigo-500 bg-indigo-600 text-white'
                      : 'border-slate-200 dark:border-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-50'
                  ]"
                >
                  {{ m.label }}
                </button>
              </div>
            </div>

            <div>
              <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Organización de Estudiantes</label>
              <div class="grid grid-cols-2 gap-2">
                <button
                  v-for="org in [{ id: 'individual', label: 'Individual' }, { id: 'parejas', label: 'En Parejas' }, { id: 'equipos', label: 'Equipos (3-5)' }, { id: 'grupo_completo', label: 'Grupo Completo' }]"
                  :key="org.id"
                  @click="formData.group_organization = org.id"
                  type="button"
                  :class="[
                    'py-2 px-3 rounded-xl border text-center text-xs font-semibold transition-all',
                    formData.group_organization === org.id
                      ? 'border-indigo-500 bg-indigo-50/60 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 font-bold'
                      : 'border-slate-200 dark:border-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-50'
                  ]"
                >
                  {{ org.label }}
                </button>
              </div>
            </div>
          </div>

          <!-- Recursos Disponibles en Aula -->
          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-2">Recursos Disponibles en el Aula</label>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="res in ['pizarra', 'proyector', 'internet', 'laboratorio', 'dispositivos', 'material_reciclado', 'texto_escolar']"
                :key="res"
                @click="toggleResource(res)"
                type="button"
                :class="[
                  'px-3 py-1.5 rounded-xl border text-xs font-semibold transition-all flex items-center gap-1.5',
                  formData.available_resources.includes(res)
                    ? 'border-teal-500 bg-teal-50 dark:bg-teal-500/10 text-teal-700 dark:text-teal-300'
                    : 'border-slate-200 dark:border-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-50'
                ]"
              >
                <Check v-if="formData.available_resources.includes(res)" class="w-3.5 h-3.5 text-teal-600" />
                <span class="capitalize">{{ res.replace('_', ' ') }}</span>
              </button>
            </div>
          </div>
        </div>

        <!-- ========================================================================= -->
        <!-- PASO 4: INCLUSIÓN Y DUA -->
        <!-- ========================================================================= -->
        <div v-else-if="step === 4" class="space-y-5 animate-in fade-in duration-200">
          <div>
            <h3 class="text-sm font-bold text-slate-900 dark:text-white">Paso 4: Inclusión y DUA (Accesibilidad y Adaptaciones)</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">Configura principios DUA, ritmo de aprendizaje y adaptaciones curriculares.</p>
          </div>

          <!-- Principios DUA -->
          <div class="space-y-3">
            <div
              v-for="dua in DUA_OPTIONS"
              :key="dua.principle"
              class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-950/50 space-y-2.5"
            >
              <div class="flex items-center gap-2">
                <div class="w-2 h-2 rounded-full bg-indigo-500"></div>
                <h4 class="text-xs font-bold text-slate-900 dark:text-white">{{ dua.title }}</h4>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <div
                  v-for="(opt, oIdx) in dua.options"
                  :key="oIdx"
                  class="p-2.5 rounded-xl border border-slate-200/80 dark:border-slate-800/80 bg-white dark:bg-slate-900 text-[11px] text-slate-700 dark:text-slate-300 flex items-start gap-2"
                >
                  <CheckCircle2 class="w-3.5 h-3.5 text-teal-500 mt-0.5 shrink-0" />
                  <span>{{ opt }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Ritmo de Aprendizaje y Adecuaciones -->
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
            <div>
              <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Ritmo Predominante del Grupo</label>
              <select
                v-model="formData.pacing_type"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
              >
                <option value="refuerzo">Refuerzo guiado (ritmo pausado)</option>
                <option value="estandar">Estándar curricular</option>
                <option value="profundizacion">Profundización / Ritmo acelerado</option>
              </select>
            </div>

            <div>
              <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Adaptaciones Pedagógicas de Acceso</label>
              <div class="flex items-center gap-3 pt-1">
                <label class="flex items-center gap-2 text-xs text-slate-700 dark:text-slate-300 cursor-pointer">
                  <input
                    v-model="formData.adaptations_needed"
                    type="checkbox"
                    class="rounded text-indigo-600 focus:ring-indigo-500"
                  />
                  <span>Incluir adaptaciones Grado 1 y 2</span>
                </label>
              </div>
            </div>
          </div>
        </div>

        <!-- ========================================================================= -->
        <!-- PASO 5: REVISIÓN Y GENERACIÓN -->
        <!-- ========================================================================= -->
        <div v-else-if="step === 5" class="space-y-5 animate-in fade-in duration-200">
          <div>
            <h3 class="text-sm font-bold text-slate-900 dark:text-white">Paso 5: Revisión de Parámetros y Generación</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">Verifica las variables académicas antes de generar la planificación completa.</p>
          </div>

          <!-- Resumen de Configuración -->
          <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-950 p-4 space-y-4">
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
              <div>
                <span class="text-[10px] text-slate-400 uppercase font-bold">Régimen</span>
                <p class="font-semibold text-slate-800 dark:text-slate-200 capitalize">{{ formData.regime.replace('_', ' ') }}</p>
              </div>
              <div>
                <span class="text-[10px] text-slate-400 uppercase font-bold">Grado</span>
                <p class="font-semibold text-slate-800 dark:text-slate-200">{{ formData.grade_year }} - Paralelo {{ formData.parallel }}</p>
              </div>
              <div>
                <span class="text-[10px] text-slate-400 uppercase font-bold">Asignatura</span>
                <p class="font-semibold text-slate-800 dark:text-slate-200">{{ formData.subject_name }}</p>
              </div>
              <div>
                <span class="text-[10px] text-slate-400 uppercase font-bold">Metodología</span>
                <p class="font-semibold text-slate-800 dark:text-slate-200">{{ formData.methodology_primary }}</p>
              </div>
            </div>

            <div class="border-t border-slate-200 dark:border-slate-800 pt-3">
              <span class="text-[10px] text-slate-400 uppercase font-bold">Tema y Destreza Seleccionada</span>
              <p class="text-xs font-bold text-indigo-600 dark:text-indigo-400 mt-0.5">{{ formData.topic_title }}</p>
              <p class="text-[11px] text-slate-600 dark:text-slate-300 mt-1">{{ formData.dcd_descriptions[0] }}</p>
            </div>
          </div>

          <!-- Calidad de Generación (Vista del Docente) -->
          <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 p-4 space-y-3">
            <div>
              <label class="block text-xs font-bold text-slate-900 dark:text-white">
                Calidad de generación
              </label>
              <p class="text-[11px] text-slate-500 dark:text-slate-400">Selecciona el nivel de elaboración pedagógica deseado para la clase.</p>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
              <label
                class="flex items-center gap-3 p-3 rounded-2xl border cursor-pointer transition-all text-xs font-semibold"
                :class="formData.generation_quality === 'automatica' ? 'border-indigo-500 bg-indigo-50/60 dark:bg-indigo-500/10 text-indigo-700 dark:text-indigo-300 ring-1 ring-indigo-500' : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'"
              >
                <input
                  type="radio"
                  v-model="formData.generation_quality"
                  value="automatica"
                  class="w-4 h-4 text-indigo-600 focus:ring-indigo-500"
                />
                <div>
                  <div class="font-bold">Automática</div>
                  <div class="text-[10px] text-slate-400">Recomendada</div>
                </div>
              </label>

              <label
                class="flex items-center gap-3 p-3 rounded-2xl border cursor-pointer transition-all text-xs font-semibold"
                :class="formData.generation_quality === 'economica' ? 'border-indigo-500 bg-indigo-50/60 dark:bg-indigo-500/10 text-indigo-700 dark:text-indigo-300 ring-1 ring-indigo-500' : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'"
              >
                <input
                  type="radio"
                  v-model="formData.generation_quality"
                  value="economica"
                  class="w-4 h-4 text-indigo-600 focus:ring-indigo-500"
                />
                <div>
                  <div class="font-bold">Económica</div>
                  <div class="text-[10px] text-slate-400">Rápida y optimizada</div>
                </div>
              </label>

              <label
                class="flex items-center gap-3 p-3 rounded-2xl border cursor-pointer transition-all text-xs font-semibold"
                :class="formData.generation_quality === 'alta_calidad' ? 'border-indigo-500 bg-indigo-50/60 dark:bg-indigo-500/10 text-indigo-700 dark:text-indigo-300 ring-1 ring-indigo-500' : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'"
              >
                <input
                  type="radio"
                  v-model="formData.generation_quality"
                  value="alta_calidad"
                  class="w-4 h-4 text-indigo-600 focus:ring-indigo-500"
                />
                <div>
                  <div class="font-bold">Alta calidad</div>
                  <div class="text-[10px] text-slate-400">Máximo detalle y rigor</div>
                </div>
              </label>
            </div>
          </div>

          <!-- Interruptores de Contenido a Generar -->
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <label class="p-3 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between text-xs font-semibold cursor-pointer">
              <span>Secuencia ERCA</span>
              <input v-model="formData.include_dua" type="checkbox" class="rounded text-indigo-600" />
            </label>
            <label class="p-3 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between text-xs font-semibold cursor-pointer">
              <span>Evaluación & Rúbrica</span>
              <input v-model="formData.include_evaluation" type="checkbox" class="rounded text-indigo-600" />
            </label>
            <label class="p-3 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between text-xs font-semibold cursor-pointer">
              <span>Adaptaciones DUA</span>
              <input v-model="formData.include_adaptations" type="checkbox" class="rounded text-indigo-600" />
            </label>
            <label class="p-3 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between text-xs font-semibold cursor-pointer">
              <span>Recursos Sugeridos</span>
              <input v-model="formData.include_resources" type="checkbox" class="rounded text-indigo-600" />
            </label>
          </div>
        </div>

      </div>

      <!-- Footer Actions -->
      <div class="px-6 py-4 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-900/80">
        <button
          v-if="step > 1"
          @click="onPrev"
          type="button"
          class="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-xs font-semibold text-slate-700 dark:text-slate-200 transition-colors"
        >
          <ChevronLeft class="w-4 h-4" />
          Anterior
        </button>
        <div v-else></div>

        <div class="flex items-center gap-2">
          <button
            v-if="step < 5"
            @click="onNext"
            type="button"
            class="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-lg shadow-indigo-600/20 transition-all cursor-pointer"
          >
            Siguiente
            <ChevronRight class="w-4 h-4" />
          </button>

          <button
            v-else
            @click="onGenerate"
            :disabled="generating"
            type="button"
            class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-gradient-to-r from-teal-600 to-indigo-600 hover:from-teal-500 hover:to-indigo-500 text-white text-xs font-bold shadow-lg shadow-indigo-900/30 transition-all cursor-pointer disabled:opacity-50"
          >
            <Loader2 v-if="generating" class="w-4 h-4 animate-spin" />
            <Sparkles v-else class="w-4 h-4" />
            <span>{{ generating ? 'Generando Planificación...' : 'Generar Planificación con IA' }}</span>
          </button>
        </div>
      </div>

    </div>
  </div>
</template>
