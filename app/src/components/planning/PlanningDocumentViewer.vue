<script setup>
import { ref } from 'vue'
import { 
  X, 
  Save, 
  Printer, 
  Copy, 
  Trash2, 
  Sparkles, 
  RefreshCw, 
  BookOpen, 
  Layers, 
  CheckSquare, 
  HeartHandshake, 
  FolderPlus, 
  Users, 
  FileText, 
  CheckCircle2, 
  Clock, 
  Plus, 
  ArrowRight,
  Loader2,
  TrendingUp,
  AlertTriangle,
  UserCheck
} from 'lucide-vue-next'
import FeedbackActionButtons from './FeedbackActionButtons.vue'
import PlanningFeedbackModal from './PlanningFeedbackModal.vue'

const props = defineProps({
  plan: {
    type: Object,
    required: true
  },
  resources: {
    type: Array,
    default: () => []
  },
  supportPlans: {
    type: Array,
    default: () => []
  },
  students: {
    type: Array,
    default: () => []
  },
  saving: {
    type: Boolean,
    default: false
  },
  generating: {
    type: Boolean,
    default: false
  },
  onSave: {
    type: Function,
    required: true
  },
  onRegenerateSection: {
    type: Function,
    required: true
  },
  onDuplicate: {
    type: Function,
    required: true
  },
  onDelete: {
    type: Function,
    required: true
  },
  onOpenPrint: {
    type: Function,
    required: true
  },
  onOpenResourceCreator: {
    type: Function,
    required: true
  },
  onOpenSupportModal: {
    type: Function,
    required: true
  },
  onClose: {
    type: Function,
    required: true
  },
  onSubmitFeedback: {
    type: Function,
    default: null
  }
})

const activeTab = ref('secuencia') // 'resumen' | 'secuencia' | 'evaluacion' | 'inclusion' | 'recursos' | 'seguimiento'
const showFeedbackModal = ref(false)
const feedbackTarget = ref({
  targetType: 'lesson_plan',
  targetId: '',
  sectionKey: null,
  initialRating: 2,
  mode: 'negative'
})

const onOpenFeedback = (data) => {
  feedbackTarget.value = {
    targetType: data.targetType || 'lesson_plan',
    targetId: data.targetId || props.plan?.id,
    sectionKey: data.sectionKey || null,
    initialRating: data.initialRating || 2,
    mode: data.mode || 'negative'
  }
  showFeedbackModal.value = true
}

const onDirectFeedback = async (payload) => {
  if (props.onSubmitFeedback) {
    await props.onSubmitFeedback(payload)
  }
}

const tabs = [
  { id: 'resumen', label: 'Resumen Curricular', icon: BookOpen },
  { id: 'secuencia', label: 'Secuencia ERCA', icon: Layers },
  { id: 'evaluacion', label: 'Evaluación & Rúbrica', icon: CheckSquare },
  { id: 'inclusion', label: 'Inclusión & DUA', icon: HeartHandshake },
  { id: 'recursos', label: 'Recursos Didácticos', icon: FolderPlus },
  { id: 'seguimiento', label: 'Seguimiento de Estudiantes', icon: Users }
]

const statusColors = {
  borrador: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 border-slate-300',
  generando: 'bg-indigo-100 dark:bg-indigo-500/20 text-indigo-600 dark:text-indigo-400 border-indigo-300',
  lista: 'bg-emerald-100 dark:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 border-emerald-300',
  en_revision: 'bg-amber-100 dark:bg-amber-500/20 text-amber-600 dark:text-amber-400 border-amber-300',
  aprobada: 'bg-teal-100 dark:bg-teal-500/20 text-teal-600 dark:text-teal-400 border-teal-300',
  archivada: 'bg-slate-200 dark:bg-slate-700 text-slate-500 border-slate-400'
}
</script>

<template>
  <div class="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-2 sm:p-4 overflow-y-auto">
    <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl shadow-2xl w-full max-w-6xl h-[94vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
      
      <!-- Top Action Bar -->
      <div class="px-6 py-3.5 border-b border-slate-200 dark:border-slate-800 flex flex-wrap items-center justify-between gap-3 bg-slate-50 dark:bg-slate-900/80">
        <div class="flex items-center gap-3 min-w-0">
          <div class="p-2 rounded-xl bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-500/20 shrink-0">
            <BookOpen class="w-5 h-5" />
          </div>
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <h2 class="text-sm sm:text-base font-bold text-slate-900 dark:text-white truncate">
                {{ plan.title }}
              </h2>
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-bold border uppercase tracking-wider', statusColors[plan.status] || statusColors.borrador]">
                {{ plan.status }}
              </span>
              <span v-if="plan.is_demo" class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/30">
                Demo
              </span>
            </div>
            <p class="text-xs text-slate-500 dark:text-slate-400 truncate">
              {{ plan.grade_year }} · {{ plan.subject_name }} · v{{ plan.version || 1 }}
            </p>
          </div>
        </div>

        <!-- Right Quick Actions -->
        <div class="flex items-center gap-2">
          <!-- Feedback Discreto Global del Plan -->
          <FeedbackActionButtons
            target-type="lesson_plan"
            :target-id="plan.id"
            @feedback-submitted="onDirectFeedback"
            @open-modal="onOpenFeedback"
          />

          <!-- Status Selector -->
          <select
            v-model="plan.status"
            @change="onSave"
            class="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-2.5 py-1.5 text-xs text-slate-700 dark:text-slate-200 focus:outline-none"
          >
            <option value="borrador">Borrador</option>
            <option value="lista">Lista para Clase</option>
            <option value="en_revision">En Revisión</option>
            <option value="aprobada">Aprobada</option>
            <option value="archivada">Archivada</option>
          </select>

          <!-- Imprimir -->
          <button
            @click="onOpenPrint"
            type="button"
            class="p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            title="Imprimir / Exportar Formato Oficial"
          >
            <Printer class="w-4 h-4" />
          </button>

          <!-- Duplicar -->
          <button
            @click="onDuplicate(plan)"
            type="button"
            class="p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            title="Duplicar Planificación"
          >
            <Copy class="w-4 h-4" />
          </button>

          <!-- Guardar -->
          <button
            @click="onSave"
            :disabled="saving"
            type="button"
            class="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow transition-all cursor-pointer disabled:opacity-50"
          >
            <Loader2 v-if="saving" class="w-3.5 h-3.5 animate-spin" />
            <Save v-else class="w-3.5 h-3.5" />
            <span>Guardar</span>
          </button>

          <!-- Cerrar -->
          <button
            @click="onClose"
            type="button"
            class="p-2 rounded-xl text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            <X class="w-5 h-5" />
          </button>
        </div>
      </div>

      <!-- Navigation Tabs Bar -->
      <div class="px-6 border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex overflow-x-auto gap-2">
        <button
          v-for="t in tabs"
          :key="t.id"
          @click="activeTab = t.id"
          type="button"
          :class="[
            'py-3 px-3 text-xs font-bold border-b-2 flex items-center gap-2 transition-all whitespace-nowrap',
            activeTab === t.id
              ? 'border-indigo-600 text-indigo-600 dark:text-indigo-400'
              : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
          ]"
        >
          <component :is="t.icon" class="w-4 h-4" />
          {{ t.label }}
          <span v-if="t.id === 'recursos' && resources.length > 0" class="px-1.5 py-0.2 rounded-full text-[10px] bg-teal-500/20 text-teal-600 dark:text-teal-400">
            {{ resources.length }}
          </span>
          <span v-if="t.id === 'seguimiento' && supportPlans.length > 0" class="px-1.5 py-0.2 rounded-full text-[10px] bg-indigo-500/20 text-indigo-600 dark:text-indigo-400">
            {{ supportPlans.length }}
          </span>
        </button>
      </div>

      <!-- Main Workspace Panels -->
      <div class="p-6 overflow-y-auto flex-1 custom-scrollbar space-y-6 bg-slate-50/50 dark:bg-slate-950/40">

        <!-- ========================================================================= -->
        <!-- TAB 1: RESUMEN CURRICULAR -->
        <!-- ========================================================================= -->
        <div v-if="activeTab === 'resumen'" class="space-y-4 animate-in fade-in duration-200">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-1">
              <span class="text-[10px] font-bold text-slate-400 uppercase">Régimen & Nivel</span>
              <p class="text-xs font-bold text-slate-900 dark:text-white capitalize">{{ plan.regime?.replace('_', ' ') }}</p>
              <p class="text-xs text-slate-500 dark:text-slate-400">{{ plan.grade_year }} - Paralelo {{ plan.parallel }}</p>
            </div>

            <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-1">
              <span class="text-[10px] font-bold text-slate-400 uppercase">Asignatura & Unidad</span>
              <p class="text-xs font-bold text-slate-900 dark:text-white">{{ plan.subject_name }}</p>
              <p class="text-xs text-slate-500 dark:text-slate-400">{{ plan.unit_title }}</p>
            </div>

            <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-1">
              <span class="text-[10px] font-bold text-slate-400 uppercase">Tiempo Estimado</span>
              <p class="text-xs font-bold text-slate-900 dark:text-white">{{ plan.duration_minutes * plan.session_count }} Minutos</p>
              <p class="text-xs text-slate-500 dark:text-slate-400">{{ plan.session_count }} Sesiones de {{ plan.duration_minutes }} min</p>
            </div>
          </div>

          <!-- Tema y Objetivo -->
          <div class="p-5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-3">
            <div>
              <span class="text-[10px] font-bold text-slate-400 uppercase">Tema de Clase</span>
              <h3 class="text-base font-bold text-indigo-600 dark:text-indigo-400">{{ plan.topic_title }}</h3>
            </div>
            <div>
              <span class="text-[10px] font-bold text-slate-400 uppercase">Objetivo de Aprendizaje</span>
              <p class="text-xs text-slate-700 dark:text-slate-300 leading-relaxed font-medium">
                {{ plan.learning_objectives?.[0] }}
              </p>
            </div>
            <div>
              <span class="text-[10px] font-bold text-slate-400 uppercase">Destreza con Criterio de Desempeño (DCD)</span>
              <div class="flex items-center gap-2 mt-1">
                <span class="px-2 py-0.5 rounded font-mono font-bold text-[10px] bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                  {{ plan.dcd_codes?.[0] }}
                </span>
                <p class="text-xs text-slate-700 dark:text-slate-300 font-medium">{{ plan.dcd_descriptions?.[0] }}</p>
              </div>
            </div>
          </div>
        </div>

        <!-- ========================================================================= -->
        <!-- TAB 2: SECUENCIA DIDÁCTICA (CICLO ERCA) -->
        <!-- ========================================================================= -->
        <div v-else-if="activeTab === 'secuencia'" class="space-y-4 animate-in fade-in duration-200">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-bold text-slate-900 dark:text-white">Secuencia Didáctica Metodológica ({{ plan.didactic_sequence?.methodology || 'ERCA' }})</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Fases didácticas, distribución de tiempo y actividades docente/estudiante.</p>
            </div>

            <button
              @click="onRegenerateSection('didactic_sequence')"
              :disabled="generating"
              type="button"
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-indigo-500/30 bg-indigo-50 dark:bg-indigo-500/10 hover:bg-indigo-100 dark:hover:bg-indigo-500/20 text-indigo-600 dark:text-indigo-400 text-xs font-bold transition-all disabled:opacity-50 cursor-pointer"
            >
              <RefreshCw :class="['w-3.5 h-3.5', generating ? 'animate-spin' : '']" />
              Regenerar solo Secuencia
            </button>
          </div>

          <div class="space-y-3">
            <div
              v-for="phase in (plan.didactic_sequence?.phases || [])"
              :key="phase.phase_id"
              class="p-5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-3"
            >
              <div class="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-2">
                <div class="flex items-center gap-2">
                  <span class="w-2.5 h-2.5 rounded-full bg-teal-500"></span>
                  <h4 class="text-xs font-bold text-slate-900 dark:text-white">{{ phase.name }}</h4>
                </div>
                <span class="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400">
                  ⏱ {{ phase.time_minutes }} minutos
                </span>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
                <!-- Actividad Docente -->
                <div class="p-3 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-100 dark:border-slate-800/80">
                  <span class="text-[10px] font-bold text-indigo-600 dark:text-indigo-400 uppercase tracking-wider block mb-1">
                    Rol del Docente (Mediación y Andamiaje)
                  </span>
                  <p class="text-slate-700 dark:text-slate-300 leading-relaxed">{{ phase.teacher_activity }}</p>
                </div>

                <!-- Actividad Estudiante -->
                <div class="p-3 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-100 dark:border-slate-800/80">
                  <span class="text-[10px] font-bold text-teal-600 dark:text-teal-400 uppercase tracking-wider block mb-1">
                    Rol del Estudiante (Aprendizaje Activo)
                  </span>
                  <p class="text-slate-700 dark:text-slate-300 leading-relaxed">{{ phase.student_activity }}</p>
                </div>
              </div>

              <!-- Recursos de la Fase -->
              <div v-if="phase.resources?.length > 0" class="flex items-center gap-2 text-[11px] text-slate-500 dark:text-slate-400">
                <span class="font-bold">Recursos sugeridos:</span>
                <span>{{ phase.resources.join(', ') }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- ========================================================================= -->
        <!-- TAB 3: EVALUACIÓN & RÚBRICA -->
        <!-- ========================================================================= -->
        <div v-else-if="activeTab === 'evaluacion'" class="space-y-4 animate-in fade-in duration-200">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-bold text-slate-900 dark:text-white">Plan de Evaluación de los Aprendizajes</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Técnicas, instrumentos, evidencias y rúbrica analítica estructurada.</p>
            </div>

            <button
              @click="onRegenerateSection('evaluation_plan')"
              :disabled="generating"
              type="button"
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-indigo-500/30 bg-indigo-50 dark:bg-indigo-500/10 hover:bg-indigo-100 text-indigo-600 dark:text-indigo-400 text-xs font-bold transition-all disabled:opacity-50 cursor-pointer"
            >
              <RefreshCw :class="['w-3.5 h-3.5', generating ? 'animate-spin' : '']" />
              Regenerar solo Evaluación
            </button>
          </div>

          <!-- Técnica e Instrumento -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
              <span class="text-[10px] font-bold text-slate-400 uppercase">Técnica de Evaluación</span>
              <p class="text-xs font-bold text-slate-800 dark:text-slate-200 mt-1">{{ plan.evaluation_plan?.technique }}</p>
            </div>
            <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
              <span class="text-[10px] font-bold text-slate-400 uppercase">Instrumento</span>
              <p class="text-xs font-bold text-slate-800 dark:text-slate-200 mt-1">{{ plan.evaluation_plan?.instrument }}</p>
            </div>
            <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
              <span class="text-[10px] font-bold text-slate-400 uppercase">Evidencia Requerida</span>
              <p class="text-xs font-bold text-slate-800 dark:text-slate-200 mt-1">{{ plan.evaluation_plan?.evidence }}</p>
            </div>
          </div>

          <!-- Rúbrica Analítica -->
          <div class="p-5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-3">
            <h4 class="text-xs font-bold text-slate-900 dark:text-white uppercase tracking-wider">
              Rúbrica Analítica de Evaluación (Descriptores de Desempeño)
            </h4>

            <div class="overflow-x-auto">
              <table class="w-full text-left border-collapse text-xs">
                <thead>
                  <tr class="border-b border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-950/60 text-[10px] font-bold text-slate-500 uppercase">
                    <th class="p-2.5 w-1/4">Criterio</th>
                    <th class="p-2.5 w-1/4 text-emerald-600">Excelente (10 - 9)</th>
                    <th class="p-2.5 w-1/4 text-teal-600">Bueno (8.9 - 7)</th>
                    <th class="p-2.5 w-1/4 text-amber-600">En Proceso (&lt; 7)</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60">
                  <tr v-for="(rub, rIdx) in (plan.evaluation_plan?.rubric || [])" :key="rIdx">
                    <td class="p-2.5 font-bold text-slate-900 dark:text-white">{{ rub.criterion }}</td>
                    <td class="p-2.5 text-slate-600 dark:text-slate-300">{{ rub.excellent }}</td>
                    <td class="p-2.5 text-slate-600 dark:text-slate-300">{{ rub.good }}</td>
                    <td class="p-2.5 text-slate-600 dark:text-slate-300">{{ rub.needs_improvement || rub.insufficient }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- ========================================================================= -->
        <!-- TAB 4: INCLUSIÓN & DUA -->
        <!-- ========================================================================= -->
        <div v-else-if="activeTab === 'inclusion'" class="space-y-4 animate-in fade-in duration-200">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-bold text-slate-900 dark:text-white">Estrategias de Inclusión y Accesibilidad (DUA)</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Adaptaciones de acceso a la información, respuesta y motivación.</p>
            </div>

            <button
              @click="onRegenerateSection('inclusion_dua_plan')"
              :disabled="generating"
              type="button"
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-indigo-500/30 bg-indigo-50 dark:bg-indigo-500/10 hover:bg-indigo-100 text-indigo-600 dark:text-indigo-400 text-xs font-bold transition-all disabled:opacity-50 cursor-pointer"
            >
              <RefreshCw :class="['w-3.5 h-3.5', generating ? 'animate-spin' : '']" />
              Regenerar solo DUA
            </button>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div
              v-for="(acc, aIdx) in (plan.inclusion_dua_plan?.accommodations || [])"
              :key="aIdx"
              class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-2.5"
            >
              <div class="flex items-center justify-between">
                <span class="text-[10px] font-bold text-teal-600 dark:text-teal-400 uppercase tracking-wider block">
                  {{ acc.area }}
                </span>
                <span v-if="acc.grade" class="px-2 py-0.5 rounded text-[9px] font-bold bg-teal-50 dark:bg-teal-950 text-teal-700 dark:text-teal-300 border border-teal-200 dark:border-teal-800">
                  Grado {{ acc.grade }}
                </span>
              </div>

              <!-- Estudiantes Asignados con este Grado de Adaptación -->
              <div v-if="acc.students?.length > 0" class="p-2.5 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200 dark:border-slate-800">
                <span class="text-[9px] font-bold uppercase text-slate-400 block mb-1">Estudiantes en este curso:</span>
                <div class="flex flex-wrap gap-1">
                  <span v-for="stName in acc.students" :key="stName" class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-indigo-50 dark:bg-indigo-500/10 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800/40">
                    {{ stName }}
                  </span>
                </div>
              </div>

              <p class="text-xs text-slate-700 dark:text-slate-300 leading-relaxed font-medium">
                {{ acc.strategy }}
              </p>
            </div>
          </div>
        </div>

        <!-- ========================================================================= -->
        <!-- TAB 5: RECURSOS DIDÁCTICOS VINCULADOS -->
        <!-- ========================================================================= -->
        <div v-else-if="activeTab === 'recursos'" class="space-y-4 animate-in fade-in duration-200">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-bold text-slate-900 dark:text-white">Recursos Didácticos Creados para esta Planificación</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Guías, talleres, rúbricas y cuestionarios asociados.</p>
            </div>

            <button
              @click="onOpenResourceCreator"
              type="button"
              class="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-gradient-to-r from-teal-600 to-teal-500 hover:from-teal-500 hover:to-teal-400 text-white text-xs font-bold shadow transition-all cursor-pointer"
            >
              <Plus class="w-4 h-4" />
              Crear Nuevo Recurso
            </button>
          </div>

          <div v-if="resources.length > 0" class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div
              v-for="res in resources"
              :key="res.id"
              class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-2"
            >
              <div class="flex items-center justify-between">
                <strong class="text-xs font-bold text-slate-900 dark:text-white">{{ res.title }}</strong>
                <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-teal-50 dark:bg-teal-500/10 text-teal-700 dark:text-teal-300 uppercase">
                  {{ res.resource_type }}
                </span>
              </div>
              <p class="text-[11px] text-slate-500 dark:text-slate-400 line-clamp-2">
                {{ res.content?.instructions || res.content?.content_summary || 'Material didáctico generado para el aula.' }}
              </p>
            </div>
          </div>

          <div v-else class="p-8 text-center border-2 border-dashed border-slate-200 dark:border-slate-800 rounded-3xl space-y-2">
            <FolderPlus class="w-8 h-8 text-slate-400 mx-auto" />
            <p class="text-xs font-bold text-slate-700 dark:text-slate-300">Aún no se han creado recursos para esta planificación</p>
            <p class="text-[11px] text-slate-400">Haz clic en "+ Crear Nuevo Recurso" para generar fichas de trabajo, rúbricas o cuestionarios.</p>
          </div>
        </div>

        <!-- ========================================================================= -->
        <!-- TAB 6: SEGUIMIENTO ESTUDIANTIL -->
        <!-- ========================================================================= -->
        <div v-else-if="activeTab === 'seguimiento'" class="space-y-4 animate-in fade-in duration-200">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-bold text-slate-900 dark:text-white">Seguimiento Individual y Recuperación Pedagógica</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Nómina del curso con estado de logro y planes de refuerzo asignados.</p>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div
              v-for="st in students"
              :key="st.id"
              class="p-3.5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between gap-3"
            >
              <div class="flex items-center gap-3 min-w-0">
                <div class="w-9 h-9 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center font-bold text-xs text-slate-700 dark:text-slate-300 shrink-0">
                  {{ st.full_name?.charAt(0) }}
                </div>
                <div class="min-w-0">
                  <strong class="text-xs font-semibold text-slate-900 dark:text-white block truncate">{{ st.full_name }}</strong>
                  <span class="text-[10px] text-slate-400">Estudiante asignado</span>
                </div>
              </div>

              <button
                @click="onOpenSupportModal(st)"
                type="button"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-indigo-50 dark:bg-indigo-500/10 hover:bg-indigo-100 text-indigo-600 dark:text-indigo-400 text-xs font-bold transition-all cursor-pointer shrink-0"
              >
                <HeartHandshake class="w-3.5 h-3.5" />
                Apoyo / Refuerzo
              </button>
            </div>
          </div>
        </div>

      </div>

    </div>

    <!-- Modal de Retroalimentación y Sugerencias -->
    <PlanningFeedbackModal
      :show="showFeedbackModal"
      :target-type="feedbackTarget.targetType"
      :target-id="feedbackTarget.targetId"
      :section-key="feedbackTarget.sectionKey"
      :initial-rating="feedbackTarget.initialRating"
      :mode="feedbackTarget.mode"
      :known-student-names="students.map(s => s.full_name).filter(Boolean)"
      @close="showFeedbackModal = false"
      @submit="onDirectFeedback"
    />
  </div>
</template>
