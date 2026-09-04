<script setup>
import { onMounted, computed } from 'vue'
import { 
  Sparkles, 
  Plus, 
  Search, 
  BrainCircuit, 
  BookOpen, 
  Layers, 
  CheckCircle2, 
  Clock, 
  Printer, 
  Copy, 
  Trash2, 
  Settings, 
  Eye, 
  FileText, 
  Users, 
  FolderPlus, 
  Loader2,
  AlertCircle,
  Inbox
} from 'lucide-vue-next'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'
import PlanningWizardModal from '../components/planning/PlanningWizardModal.vue'
import PlanningDocumentViewer from '../components/planning/PlanningDocumentViewer.vue'
import PlanningResourceCreatorModal from '../components/planning/PlanningResourceCreatorModal.vue'
import StudentSupportModal from '../components/planning/StudentSupportModal.vue'
import InstitutionAISettingsModal from '../components/planning/InstitutionAISettingsModal.vue'
import PlanningOfficialPrintDocument from '../components/planning/PlanningOfficialPrintDocument.vue'
import PlanningPaywallBanner from '../components/planning/PlanningPaywallBanner.vue'
import { useAIPlanning } from '../composables/useAIPlanning'
import { isInstitutionAdmin } from '../lib/permissions'
import { useAuthStore } from '../stores/auth'

const authStore = useAuthStore()
const isAdmin = computed(() => isInstitutionAdmin(authStore.accessContext))

const {
  loading,
  generating,
  saving,
  moduleAccess,
  lessonPlans,
  filteredLessonPlans,
  courses,
  subjects,
  students,
  institutionConfig,
  stats,
  searchQuery,
  selectedCourseFilter,
  selectedSubjectFilter,
  selectedStatusFilter,
  showWizardModal,
  showViewerModal,
  showResourceModal,
  showSupportModal,
  showPrintModal,
  showSettingsModal,
  activePlan,
  activeResources,
  activeSupportPlans,
  selectedStudentForSupport,
  wizardStep,
  wizardData,
  fetchInitialData,
  onGradeChange,
  openWizard,
  nextStep,
  prevStep,
  generatePlanWithAI,
  saveActivePlan,
  regenerateSingleSection,
  createResource,
  createStudentSupport,
  openPlanViewer,
  deletePlan,
  duplicatePlan,
  submitFeedback
} = useAIPlanning()

onMounted(() => {
  fetchInitialData()
})

const openSupportForStudent = (st) => {
  selectedStudentForSupport.value = st
  showSupportModal.value = true
}

const statusBadgeClasses = {
  borrador: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 border-slate-300 dark:border-slate-700',
  generando: 'bg-indigo-100 dark:bg-indigo-500/20 text-indigo-600 dark:text-indigo-400 border-indigo-300 dark:border-indigo-700',
  lista: 'bg-emerald-100 dark:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 border-emerald-300 dark:border-emerald-700',
  en_revision: 'bg-amber-100 dark:bg-amber-500/20 text-amber-600 dark:text-amber-400 border-amber-300 dark:border-amber-700',
  aprobada: 'bg-teal-100 dark:bg-teal-500/20 text-teal-600 dark:text-teal-400 border-teal-300 dark:border-teal-700',
  archivada: 'bg-slate-200 dark:bg-slate-800 text-slate-500 border-slate-400'
}
</script>

<template>
  <div class="h-full flex flex-col space-y-6">
    <!-- Academic Year Banner -->
    <AcademicYearBanner module-name="Planificación Educativa con IA" class="no-print" />

    <!-- Header & Action Buttons -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 no-print">
      <div>
        <div class="flex items-center gap-2.5">
          <div class="p-2.5 rounded-2xl bg-gradient-to-tr from-indigo-600 to-indigo-500 text-white shadow-lg shadow-indigo-600/20">
            <BrainCircuit class="w-6 h-6" />
          </div>
          <div>
            <div class="flex items-center gap-2">
              <h1 class="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">Planificación Curricular con IA</h1>
              <span v-if="moduleAccess.mode === 'demo'" class="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/30">
                Modo Demostración
              </span>
            </div>
            <p class="text-sm text-slate-500 dark:text-slate-400">
              Diseño de unidades, secuencias ERCA, adaptaciones DUA y recursos según el currículo nacional de Ecuador
            </p>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <button
          v-if="isAdmin"
          @click="showSettingsModal = true"
          type="button"
          class="inline-flex items-center gap-1.5 px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-slate-800 hover:bg-slate-100 dark:hover:bg-slate-800 text-xs font-semibold text-slate-700 dark:text-slate-300 transition-colors"
          title="Configuración de IA y Cuotas"
        >
          <Settings class="w-4 h-4" />
          <span class="hidden md:inline">Configuración IA</span>
        </button>

        <button
          @click="openWizard"
          type="button"
          class="inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white text-sm font-bold shadow-lg shadow-indigo-900/20 transition-all cursor-pointer"
        >
          <Plus class="w-4 h-4" />
          Nueva Planificación con IA
        </button>
      </div>
    </div>

    <!-- Paywall / Notice Banner if module is disabled by Superadmin -->
    <PlanningPaywallBanner
      v-if="!moduleAccess.module_enabled || moduleAccess.is_limit_reached"
      :reason="moduleAccess.is_limit_reached ? 'limit_reached' : 'inactive'"
      :monthly-quota="moduleAccess.monthly_quota"
      :monthly-usage="moduleAccess.monthly_usage"
      @open-settings="showSettingsModal = true"
      class="no-print"
    />

    <!-- Summary Stats Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 no-print">
      <!-- Total Planificaciones -->
      <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 p-4 shadow-sm">
        <div class="flex items-center gap-3">
          <div class="rounded-xl bg-indigo-100 dark:bg-indigo-500/20 p-2.5 text-indigo-600 dark:text-indigo-400">
            <BookOpen class="w-5 h-5" />
          </div>
          <div>
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Planificaciones</p>
            <p class="text-2xl font-extrabold text-slate-900 dark:text-white">{{ stats.total }}</p>
          </div>
        </div>
      </div>

      <!-- Borradores -->
      <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 p-4 shadow-sm">
        <div class="flex items-center gap-3">
          <div class="rounded-xl bg-amber-100 dark:bg-amber-500/20 p-2.5 text-amber-600 dark:text-amber-400">
            <Clock class="w-5 h-5" />
          </div>
          <div>
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Borradores</p>
            <p class="text-2xl font-extrabold text-slate-900 dark:text-white">{{ stats.drafts }}</p>
          </div>
        </div>
      </div>

      <!-- Listas / Aprobadas -->
      <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 p-4 shadow-sm">
        <div class="flex items-center gap-3">
          <div class="rounded-xl bg-emerald-100 dark:bg-emerald-500/20 p-2.5 text-emerald-600 dark:text-emerald-400">
            <CheckCircle2 class="w-5 h-5" />
          </div>
          <div>
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Listas para Aula</p>
            <p class="text-2xl font-extrabold text-slate-900 dark:text-white">{{ stats.ready }}</p>
          </div>
        </div>
      </div>

      <!-- Recursos Generados -->
      <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 p-4 shadow-sm">
        <div class="flex items-center gap-3">
          <div class="rounded-xl bg-teal-100 dark:bg-teal-500/20 p-2.5 text-teal-600 dark:text-teal-400">
            <FolderPlus class="w-5 h-5" />
          </div>
          <div>
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Recursos Creados</p>
            <p class="text-2xl font-extrabold text-slate-900 dark:text-white">{{ stats.resourcesCount }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Filters & Plans History Table -->
    <div class="flex-1 rounded-3xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 flex flex-col min-h-0 overflow-hidden shadow-sm no-print">
      
      <!-- Filters Row -->
      <div class="p-4 border-b border-slate-200 dark:border-slate-800 flex flex-wrap gap-3 items-center bg-slate-50 dark:bg-slate-900/80">
        <!-- Search Input -->
        <div class="relative flex-1 min-w-[220px]">
          <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar por tema, destreza o asignatura..."
            class="w-full pl-9 pr-4 py-2 bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none placeholder-slate-400"
          />
        </div>

        <!-- Curso Filter -->
        <select
          v-model="selectedCourseFilter"
          class="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-slate-200 focus:ring-2 focus:ring-indigo-500 focus:outline-none"
        >
          <option value="">Todos los Cursos</option>
          <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>

        <!-- Asignatura Filter -->
        <select
          v-model="selectedSubjectFilter"
          class="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-slate-200 focus:ring-2 focus:ring-indigo-500 focus:outline-none"
        >
          <option value="">Todas las Asignaturas</option>
          <option v-for="s in subjects" :key="s.id" :value="s.name">{{ s.name }}</option>
        </select>

        <!-- Estado Filter -->
        <select
          v-model="selectedStatusFilter"
          class="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-slate-200 focus:ring-2 focus:ring-indigo-500 focus:outline-none"
        >
          <option value="all">Todos los Estados</option>
          <option value="borrador">Borradores</option>
          <option value="lista">Listas para Aula</option>
          <option value="en_revision">En Revisión</option>
          <option value="aprobada">Aprobadas</option>
        </select>
      </div>

      <!-- Table Body -->
      <div class="flex-1 overflow-auto custom-scrollbar relative">
        <div v-if="loading" class="absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/50 z-10 backdrop-blur-sm">
          <Loader2 class="w-8 h-8 text-indigo-600 animate-spin" />
        </div>

        <table v-if="filteredLessonPlans.length > 0" class="w-full text-left border-collapse">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-800 bg-slate-100/70 dark:bg-slate-950/70 text-[11px] font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
              <th class="p-3.5 pl-5">Planificación / Tema</th>
              <th class="p-3.5">Grado & Asignatura</th>
              <th class="p-3.5">Metodología</th>
              <th class="p-3.5">Duración</th>
              <th class="p-3.5 text-center">Estado</th>
              <th class="p-3.5 pr-5 text-right">Acciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60 text-xs">
            <tr
              v-for="p in filteredLessonPlans"
              :key="p.id"
              class="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors group"
            >
              <!-- Plan / Tema -->
              <td class="p-3.5 pl-5">
                <div class="flex items-center gap-3">
                  <div class="p-2 rounded-xl bg-indigo-50 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 shrink-0">
                    <BookOpen class="w-4 h-4" />
                  </div>
                  <div>
                    <strong class="text-slate-900 dark:text-white font-bold block line-clamp-1 cursor-pointer hover:text-indigo-600" @click="openPlanViewer(p)">
                      {{ p.topic_title || p.title }}
                    </strong>
                    <span class="text-[11px] text-slate-500 dark:text-slate-400">
                      {{ p.dcd_codes?.[0] || 'DCD Curricular' }} · {{ p.unit_title }}
                    </span>
                  </div>
                </div>
              </td>

              <!-- Grado & Asignatura -->
              <td class="p-3.5">
                <strong class="text-slate-900 dark:text-white font-semibold block">
                  {{ p.grade_year }} {{ p.parallel ? `- Paralelo ${p.parallel}` : '' }}
                </strong>
                <span class="text-[11px] text-slate-500 dark:text-slate-400">
                  {{ p.subject_name }}
                </span>
              </td>

              <!-- Metodología -->
              <td class="p-3.5">
                <span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-teal-50 dark:bg-teal-500/10 text-teal-700 dark:text-teal-300">
                  {{ p.methodology_primary || 'ERCA' }}
                </span>
              </td>

              <!-- Duración -->
              <td class="p-3.5 text-slate-600 dark:text-slate-300">
                <div class="font-medium">
                  {{ p.duration_minutes * p.session_count }} min
                </div>
                <div class="text-slate-400 text-[10px]">
                  {{ p.session_count }} sesiones
                </div>
              </td>

              <!-- Estado -->
              <td class="p-3.5 text-center">
                <span :class="['inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold border uppercase', statusBadgeClasses[p.status] || statusBadgeClasses.borrador]">
                  {{ p.status }}
                </span>
              </td>

              <!-- Acciones -->
              <td class="p-3.5 pr-5 text-right">
                <div class="inline-flex items-center gap-1.5 justify-end">
                  
                  <!-- Ver / Editar Documento -->
                  <button
                    @click="openPlanViewer(p)"
                    title="Abrir área de trabajo de la planificación"
                    class="p-1.5 rounded-lg text-slate-600 dark:text-slate-300 hover:text-indigo-600 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                  >
                    <Eye class="w-4 h-4" />
                  </button>

                  <!-- Imprimir / PDF -->
                  <button
                    @click="() => { activePlan = p; showPrintModal = true; }"
                    title="Imprimir documento oficial MinEduc"
                    class="p-1.5 rounded-lg text-slate-600 dark:text-slate-300 hover:text-teal-600 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                  >
                    <Printer class="w-4 h-4" />
                  </button>

                  <!-- Duplicar -->
                  <button
                    @click="duplicatePlan(p)"
                    title="Duplicar planificación"
                    class="p-1.5 rounded-lg text-slate-600 dark:text-slate-300 hover:text-cyan-600 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                  >
                    <Copy class="w-4 h-4" />
                  </button>

                  <!-- Eliminar -->
                  <button
                    @click="deletePlan(p.id)"
                    title="Eliminar planificación"
                    class="p-1.5 rounded-lg text-slate-400 hover:text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-500/10 transition-colors"
                  >
                    <Trash2 class="w-4 h-4" />
                  </button>

                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- Empty State -->
        <div v-else-if="!loading" class="p-12 text-center space-y-4">
          <div class="w-16 h-16 rounded-3xl bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 flex items-center justify-center mx-auto border border-indigo-500/20">
            <Inbox class="w-8 h-8" />
          </div>
          <div>
            <h3 class="text-base font-bold text-slate-900 dark:text-white">No se encontraron planificaciones</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1 max-w-md mx-auto">
              Diseña tu primera planificación de clase seleccionando el régimen, grado, asignatura y tema desde el catálogo oficial de Ecuador.
            </p>
          </div>

          <div class="pt-2">
            <button
              @click="openWizard"
              type="button"
              class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-lg shadow-indigo-600/20 transition-all cursor-pointer"
            >
              <Plus class="w-4 h-4" />
              Crear Planificación con IA
            </button>
          </div>
        </div>

      </div>

    </div>

    <!-- Modals -->
    <PlanningWizardModal
      v-if="showWizardModal"
      :step="wizardStep"
      :form-data="wizardData"
      :courses="courses"
      :subjects="subjects"
      :generating="generating"
      :is-demo="moduleAccess.mode === 'demo'"
      :on-next="nextStep"
      :on-prev="prevStep"
      :on-generate="generatePlanWithAI"
      :on-close="() => { showWizardModal = false }"
      :on-grade-select="onGradeChange"
    />

    <PlanningDocumentViewer
      v-if="showViewerModal && activePlan"
      :plan="activePlan"
      :resources="activeResources"
      :support-plans="activeSupportPlans"
      :students="students"
      :saving="saving"
      :generating="generating"
      :on-save="saveActivePlan"
      :on-regenerate-section="regenerateSingleSection"
      :on-duplicate="duplicatePlan"
      :on-delete="deletePlan"
      :on-open-print="() => { showPrintModal = true }"
      :on-open-resource-creator="() => { showResourceModal = true }"
      :on-open-support-modal="openSupportForStudent"
      :on-submit-feedback="submitFeedback"
      :on-close="() => { showViewerModal = false }"
    />

    <PlanningResourceCreatorModal
      v-if="showResourceModal && activePlan"
      :plan="activePlan"
      :generating="generating"
      :on-generate-resource="createResource"
      :on-close="() => { showResourceModal = false }"
    />

    <StudentSupportModal
      v-if="showSupportModal && selectedStudentForSupport && activePlan"
      :student="selectedStudentForSupport"
      :plan="activePlan"
      :generating="generating"
      :on-submit="createStudentSupport"
      :on-close="() => { showSupportModal = false }"
    />

    <InstitutionAISettingsModal
      v-if="showSettingsModal"
      :on-close="() => { showSettingsModal = false }"
    />

    <PlanningOfficialPrintDocument
      v-if="showPrintModal && activePlan"
      :plan="activePlan"
      :institution-config="institutionConfig"
      :on-close="() => { showPrintModal = false }"
    />

  </div>
</template>
