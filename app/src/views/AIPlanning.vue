<script setup>
import { onMounted, computed, ref } from 'vue'
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
  Inbox,
  RefreshCw,
  SearchX
} from 'lucide-vue-next'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'
import PlanningWizardModal from '../components/planning/PlanningWizardModal.vue'
import PlanningDocumentViewer from '../components/planning/PlanningDocumentViewer.vue'
import PlanningResourceCreatorModal from '../components/planning/PlanningResourceCreatorModal.vue'
import StudentSupportModal from '../components/planning/StudentSupportModal.vue'
import InstitutionAISettingsModal from '../components/planning/InstitutionAISettingsModal.vue'
import PlanningOfficialPrintDocument from '../components/planning/PlanningOfficialPrintDocument.vue'
import PlanningPaywallBanner from '../components/planning/PlanningPaywallBanner.vue'
import OfficialCurricularPlanModal from '../components/planning/OfficialCurricularPlanModal.vue'
import { useAIPlanning } from '../composables/useAIPlanning'
import { isInstitutionAdmin } from '../lib/permissions'
import { useAuthStore } from '../stores/auth'
import { useAcademicYearStore } from '../stores/academicYear'

const authStore = useAuthStore()
const isAdmin = computed(() => isInstitutionAdmin(authStore.accessContext))

const {
  loading,
  loadError,
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
  submitFeedback,
  createAIGateway
} = useAIPlanning()

const academicYearStore = useAcademicYearStore()
const showOfficialPlanModal = ref(false)
const officialPlanDefaults = computed(() => ({
  anioLectivo: academicYearStore.selectedYearName || '',
  docente: authStore.profile?.full_name || '',
}))

const canGeneratePlan = computed(() => (
  moduleAccess.value.module_enabled &&
  !moduleAccess.value.is_limit_reached &&
  !moduleAccess.value.is_teacher_limit_reached &&
  !loading.value
))

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

const statusLabels = {
  borrador: 'Borrador',
  generando: 'Generando',
  lista: 'Lista para aula',
  en_revision: 'En revisión',
  aprobada: 'Aprobada',
  archivada: 'Archivada'
}

const hasActiveFilters = computed(() => (
  Boolean(searchQuery.value.trim()) ||
  Boolean(selectedCourseFilter.value) ||
  Boolean(selectedSubjectFilter.value) ||
  selectedStatusFilter.value !== 'all'
))

const clearFilters = () => {
  searchQuery.value = ''
  selectedCourseFilter.value = ''
  selectedSubjectFilter.value = ''
  selectedStatusFilter.value = 'all'
}

// El aviso de "módulo desactivado" solo se muestra cuando ya se conoce el estado real.
const showPaywall = computed(() => (
  !loading.value &&
  !loadError.value &&
  (!moduleAccess.value.module_enabled || moduleAccess.value.is_limit_reached || moduleAccess.value.is_teacher_limit_reached)
))

const statCards = computed(() => [
  { key: 'total', label: 'Planificaciones', value: stats.value.total, icon: BookOpen, tile: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400' },
  { key: 'drafts', label: 'Borradores', value: stats.value.drafts, icon: Clock, tile: 'bg-amber-500/10 text-amber-600 dark:text-amber-400' },
  { key: 'ready', label: 'Listas para aula', value: stats.value.ready, icon: CheckCircle2, tile: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400' },
  { key: 'resources', label: 'Recursos creados', value: stats.value.resourcesCount, icon: FolderPlus, tile: 'bg-teal-500/10 text-teal-600 dark:text-teal-400' }
])

const selectClasses = 'h-10 rounded-xl border border-slate-300 bg-white px-3 text-xs font-medium text-slate-800 transition-colors hover:border-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-200 dark:hover:border-slate-600'
</script>

<template>
  <div class="h-full flex flex-col space-y-6">
    <!-- Academic Year Banner -->
    <AcademicYearBanner module-name="Planificación Educativa con IA" class="no-print" />

    <!-- Header & Action Buttons -->
    <header class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between no-print">
      <div class="flex items-start gap-4">
        <span class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-indigo-500/10 text-indigo-600 ring-1 ring-inset ring-indigo-500/20 dark:text-indigo-400" aria-hidden="true">
          <BrainCircuit class="h-6 w-6" />
        </span>
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
            <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-white">Planificación Curricular con IA</h1>
            <span v-if="moduleAccess.is_demo && !loading" class="rounded-full border border-amber-500/30 bg-amber-500/10 px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider text-amber-600 dark:text-amber-400">
              Modo demostración
            </span>
          </div>
          <p class="mt-1 max-w-2xl text-sm leading-relaxed text-slate-500 dark:text-slate-400">
            Diseño de unidades, secuencias ERCA, adaptaciones DUA y recursos según el currículo nacional de Ecuador.
          </p>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2.5">
        <button
          v-if="isAdmin"
          @click="showSettingsModal = true"
          type="button"
          class="inline-flex h-11 items-center gap-2 rounded-xl border border-slate-300 px-4 text-xs font-semibold text-slate-700 transition-colors hover:border-slate-400 hover:bg-slate-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500/40 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
          title="Configuración de IA y cuotas"
        >
          <Settings class="h-4 w-4" />
          <span class="hidden md:inline">Configuración IA</span>
        </button>

        <button
          @click="showOfficialPlanModal = true"
          :disabled="!canGeneratePlan"
          type="button"
          class="inline-flex h-11 items-center gap-2 rounded-xl border border-indigo-300 px-4 text-xs font-bold text-indigo-700 transition-colors hover:bg-indigo-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500/40 disabled:cursor-not-allowed disabled:opacity-50 dark:border-indigo-500/40 dark:text-indigo-300 dark:hover:bg-indigo-500/10"
          title="PCA y planificación microcurricular con códigos oficiales del MinEduc"
        >
          <FileText class="h-4 w-4" />
          <span>PCA y Microcurricular</span>
        </button>

        <button
          @click="openWizard"
          :disabled="!canGeneratePlan"
          type="button"
          class="inline-flex h-11 cursor-pointer items-center justify-center gap-2 rounded-xl bg-indigo-600 px-5 text-sm font-bold text-white shadow-lg shadow-indigo-900/20 ring-1 ring-inset ring-white/10 transition-all hover:-translate-y-px hover:bg-indigo-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-300 disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:translate-y-0"
        >
          <Plus class="h-4 w-4" />
          Nueva Planificación con IA
        </button>
      </div>
    </header>

    <!-- Error de carga (distinto de "módulo desactivado") -->
    <div
      v-if="loadError && !loading"
      role="alert"
      class="no-print flex flex-col gap-4 rounded-2xl border border-rose-200 bg-rose-50 p-5 sm:flex-row sm:items-center dark:border-rose-500/30 dark:bg-rose-500/10"
    >
      <span class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-rose-500/10 text-rose-600 dark:text-rose-400" aria-hidden="true">
        <AlertCircle class="h-6 w-6" />
      </span>
      <div class="min-w-0 flex-1">
        <p class="text-sm font-bold text-rose-900 dark:text-rose-200">No se pudo cargar el módulo</p>
        <p class="mt-0.5 break-words text-xs text-rose-700 dark:text-rose-300/90">{{ loadError }}</p>
      </div>
      <button
        type="button"
        @click="fetchInitialData"
        class="inline-flex h-10 shrink-0 items-center justify-center gap-2 rounded-xl bg-rose-600 px-4 text-xs font-bold text-white transition-colors hover:bg-rose-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-rose-300"
      >
        <RefreshCw class="h-4 w-4" />
        Reintentar
      </button>
    </div>

    <!-- Paywall / Notice Banner if module is disabled by Superadmin -->
    <PlanningPaywallBanner
      v-if="showPaywall"
      :reason="moduleAccess.is_teacher_limit_reached ? 'daily_limit' : moduleAccess.is_limit_reached ? 'limit_reached' : 'inactive'"
      :monthly-quota="moduleAccess.monthly_quota"
      :monthly-usage="moduleAccess.monthly_usage"
      :daily-limit="moduleAccess.teacher_daily_limit"
      :daily-usage="moduleAccess.teacher_daily_usage"
      @open-settings="showSettingsModal = true"
      class="no-print"
    />

    <!-- Summary Stats Cards -->
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4 no-print">
      <div
        v-for="card in statCards"
        :key="card.key"
        class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm transition-colors hover:border-slate-300 sm:p-5 dark:border-slate-800 dark:bg-slate-900/60 dark:hover:border-slate-700"
      >
        <div class="flex items-center gap-3.5">
          <span :class="['flex h-11 w-11 shrink-0 items-center justify-center rounded-xl', card.tile]" aria-hidden="true">
            <component :is="card.icon" class="h-5 w-5" />
          </span>
          <div class="min-w-0">
            <p class="truncate text-[11px] font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">{{ card.label }}</p>
            <div v-if="loading" class="mt-1.5 h-7 w-12 animate-pulse rounded-md bg-slate-200 dark:bg-slate-700" aria-label="Cargando"></div>
            <p v-else class="text-2xl font-extrabold tabular-nums text-slate-900 dark:text-white">{{ card.value }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Filters & Plans History Table -->
    <div class="no-print flex min-h-0 flex-1 flex-col overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900/50">

      <!-- Filters Row -->
      <div class="flex flex-wrap items-center gap-3 border-b border-slate-200 bg-slate-50/80 p-4 dark:border-slate-800 dark:bg-slate-900/80">
        <div class="relative min-w-[220px] flex-1">
          <Search class="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" aria-hidden="true" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar por tema, destreza o asignatura..."
            aria-label="Buscar planificaciones"
            class="h-10 w-full rounded-xl border border-slate-300 bg-white pl-10 pr-4 text-xs text-slate-900 placeholder-slate-400 transition-colors hover:border-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:hover:border-slate-600"
          />
        </div>

        <select v-model="selectedCourseFilter" :class="selectClasses" aria-label="Filtrar por curso">
          <option value="">Todos los cursos</option>
          <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>

        <select v-model="selectedSubjectFilter" :class="selectClasses" aria-label="Filtrar por asignatura">
          <option value="">Todas las asignaturas</option>
          <option v-for="s in subjects" :key="s.id" :value="s.name">{{ s.name }}</option>
        </select>

        <select v-model="selectedStatusFilter" :class="selectClasses" aria-label="Filtrar por estado">
          <option value="all">Todos los estados</option>
          <option value="borrador">Borradores</option>
          <option value="lista">Listas para aula</option>
          <option value="en_revision">En revisión</option>
          <option value="aprobada">Aprobadas</option>
        </select>

        <p v-if="!loading && lessonPlans.length > 0" class="ml-auto whitespace-nowrap text-xs font-medium text-slate-500 dark:text-slate-400">
          {{ filteredLessonPlans.length }} de {{ lessonPlans.length }}
        </p>
      </div>

      <!-- Table Body -->
      <div class="custom-scrollbar relative flex-1 overflow-auto">

        <!-- Cargando: esqueleto con la forma de la tabla -->
        <div v-if="loading" class="divide-y divide-slate-100 dark:divide-slate-800/60" role="status" aria-label="Cargando planificaciones">
          <div v-for="n in 5" :key="n" class="flex items-center gap-4 p-4 pl-5">
            <div class="h-9 w-9 shrink-0 animate-pulse rounded-xl bg-slate-200 dark:bg-slate-700"></div>
            <div class="min-w-0 flex-1 space-y-2">
              <div class="h-3.5 w-2/5 animate-pulse rounded bg-slate-200 dark:bg-slate-700"></div>
              <div class="h-3 w-1/4 animate-pulse rounded bg-slate-100 dark:bg-slate-800"></div>
            </div>
            <div class="hidden h-5 w-24 animate-pulse rounded-full bg-slate-200 sm:block dark:bg-slate-700"></div>
            <div class="hidden h-5 w-20 animate-pulse rounded-full bg-slate-200 md:block dark:bg-slate-700"></div>
          </div>
        </div>

        <table v-else-if="filteredLessonPlans.length > 0" class="w-full min-w-[880px] border-collapse text-left">
          <thead class="sticky top-0 z-10">
            <tr class="border-b border-slate-200 bg-slate-100/90 text-[11px] font-bold uppercase tracking-wider text-slate-600 backdrop-blur dark:border-slate-800 dark:bg-slate-950/90 dark:text-slate-400">
              <th class="p-3.5 pl-5">Planificación / tema</th>
              <th class="p-3.5">Grado y asignatura</th>
              <th class="p-3.5">Metodología</th>
              <th class="p-3.5">Duración</th>
              <th class="p-3.5 text-center">Estado</th>
              <th class="p-3.5 pr-5 text-right">Acciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 text-xs dark:divide-slate-800/60">
            <tr
              v-for="p in filteredLessonPlans"
              :key="p.id"
              class="group transition-colors hover:bg-slate-50 dark:hover:bg-slate-800/40"
            >
              <!-- Plan / Tema -->
              <td class="p-3.5 pl-5">
                <div class="flex items-center gap-3">
                  <span class="shrink-0 rounded-xl bg-indigo-500/10 p-2.5 text-indigo-600 dark:text-indigo-400" aria-hidden="true">
                    <BookOpen class="h-4 w-4" />
                  </span>
                  <div class="min-w-0">
                    <button
                      type="button"
                      class="block max-w-[26rem] truncate text-left text-[13px] font-bold text-slate-900 transition-colors hover:text-indigo-600 focus:outline-none focus-visible:text-indigo-600 dark:text-white dark:hover:text-indigo-300"
                      @click="openPlanViewer(p)"
                    >
                      {{ p.topic_title || p.title }}
                    </button>
                    <span class="mt-0.5 block truncate text-[11px] text-slate-500 dark:text-slate-400">
                      {{ p.dcd_codes?.[0] || 'DCD curricular' }} · {{ p.unit_title }}
                    </span>
                  </div>
                </div>
              </td>

              <!-- Grado & Asignatura -->
              <td class="p-3.5">
                <strong class="block font-semibold text-slate-900 dark:text-white">
                  {{ p.grade_year }} {{ p.parallel ? `- Paralelo ${p.parallel}` : '' }}
                </strong>
                <span class="text-[11px] text-slate-500 dark:text-slate-400">
                  {{ p.subject_name }}
                </span>
              </td>

              <!-- Metodología -->
              <td class="p-3.5">
                <span class="inline-flex items-center gap-1 rounded-full bg-teal-500/10 px-2.5 py-0.5 text-[11px] font-bold text-teal-700 dark:text-teal-300">
                  {{ p.methodology_primary || 'ERCA' }}
                </span>
              </td>

              <!-- Duración -->
              <td class="p-3.5 text-slate-600 dark:text-slate-300">
                <div class="font-medium tabular-nums">
                  {{ p.duration_minutes * p.session_count }} min
                </div>
                <div class="text-[10px] text-slate-400">
                  {{ p.session_count }} {{ p.session_count === 1 ? 'sesión' : 'sesiones' }}
                </div>
              </td>

              <!-- Estado -->
              <td class="p-3.5 text-center">
                <span :class="['inline-flex items-center whitespace-nowrap rounded-full border px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wide', statusBadgeClasses[p.status] || statusBadgeClasses.borrador]">
                  {{ statusLabels[p.status] || p.status }}
                </span>
              </td>

              <!-- Acciones -->
              <td class="p-3.5 pr-5 text-right">
                <div class="inline-flex items-center justify-end gap-1">
                  <button
                    @click="openPlanViewer(p)"
                    title="Abrir área de trabajo de la planificación"
                    aria-label="Abrir planificación"
                    class="rounded-lg p-2 text-slate-600 transition-colors hover:bg-indigo-500/10 hover:text-indigo-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500/40 dark:text-slate-300 dark:hover:text-indigo-300"
                  >
                    <Eye class="h-4 w-4" />
                  </button>

                  <button
                    @click="() => { activePlan = p; showPrintModal = true; }"
                    title="Imprimir documento oficial MinEduc"
                    aria-label="Imprimir planificación"
                    class="rounded-lg p-2 text-slate-600 transition-colors hover:bg-teal-500/10 hover:text-teal-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-teal-500/40 dark:text-slate-300 dark:hover:text-teal-300"
                  >
                    <Printer class="h-4 w-4" />
                  </button>

                  <button
                    @click="duplicatePlan(p)"
                    title="Duplicar planificación"
                    aria-label="Duplicar planificación"
                    class="rounded-lg p-2 text-slate-600 transition-colors hover:bg-cyan-500/10 hover:text-cyan-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-cyan-500/40 dark:text-slate-300 dark:hover:text-cyan-300"
                  >
                    <Copy class="h-4 w-4" />
                  </button>

                  <button
                    @click="deletePlan(p.id)"
                    title="Eliminar planificación"
                    aria-label="Eliminar planificación"
                    class="rounded-lg p-2 text-slate-400 transition-colors hover:bg-rose-500/10 hover:text-rose-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-rose-500/40"
                  >
                    <Trash2 class="h-4 w-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- Sin resultados con los filtros actuales -->
        <div v-else-if="!loadError && lessonPlans.length > 0 && hasActiveFilters" class="flex flex-col items-center gap-3 px-6 py-14 text-center">
          <span class="flex h-14 w-14 items-center justify-center rounded-2xl bg-slate-500/10 text-slate-500 dark:text-slate-400" aria-hidden="true">
            <SearchX class="h-7 w-7" />
          </span>
          <div>
            <h3 class="text-base font-bold text-slate-900 dark:text-white">Ninguna planificación coincide</h3>
            <p class="mx-auto mt-1 max-w-md text-xs text-slate-500 dark:text-slate-400">Prueba con otros términos o quita algún filtro para ver todas tus planificaciones.</p>
          </div>
          <button type="button" @click="clearFilters" class="inline-flex h-10 items-center rounded-xl border border-slate-300 px-4 text-xs font-semibold text-slate-700 transition-colors hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800">
            Limpiar filtros
          </button>
        </div>

        <!-- Empty State -->
        <div v-else-if="!loadError" class="flex flex-col items-center gap-4 px-6 py-14 text-center">
          <span class="flex h-16 w-16 items-center justify-center rounded-3xl bg-indigo-500/10 text-indigo-600 ring-1 ring-inset ring-indigo-500/20 dark:text-indigo-400" aria-hidden="true">
            <Inbox class="h-8 w-8" />
          </span>
          <div>
            <h3 class="text-base font-bold text-slate-900 dark:text-white">No se encontraron planificaciones</h3>
            <p class="mx-auto mt-1 max-w-md text-xs leading-relaxed text-slate-500 dark:text-slate-400">
              Diseña tu primera planificación de clase seleccionando el régimen, grado, asignatura y tema desde el catálogo oficial de Ecuador.
            </p>
          </div>
          <button
            @click="openWizard"
            :disabled="!canGeneratePlan"
            type="button"
            class="inline-flex h-11 cursor-pointer items-center gap-2 rounded-xl bg-indigo-600 px-5 text-xs font-bold text-white shadow-lg shadow-indigo-900/20 transition-all hover:bg-indigo-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-300 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <Plus class="h-4 w-4" />
            Crear planificación con IA
          </button>
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
      :is-demo="moduleAccess.is_demo"
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

    <OfficialCurricularPlanModal
      v-if="showOfficialPlanModal"
      :create-gateway="createAIGateway"
      :institution-config="institutionConfig"
      :defaults="officialPlanDefaults"
      :is-demo="moduleAccess.is_demo"
      :on-close="() => { showOfficialPlanModal = false }"
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
