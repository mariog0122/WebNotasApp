<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAcademicYearStore } from '../../stores/academicYear'
import { useAuthStore } from '../../stores/auth'
import { isInstitutionAdmin, canManageAcademicYearLock } from '../../lib/permissions'
import { toast } from 'vue-sonner'
import { 
  Calendar, 
  CalendarCheck2, 
  History, 
  Sparkles, 
  AlertTriangle,
  ArrowRightLeft,
  School,
  Lock,
  Unlock,
  ShieldAlert,
  ShieldCheck,
  CheckCircle2
} from 'lucide-vue-next'

const props = defineProps({
  moduleName: {
    type: String,
    default: ''
  },
  compact: {
    type: Boolean,
    default: false
  },
  showSwitcher: {
    type: Boolean,
    default: true
  }
})

const router = useRouter()
const academicYearStore = useAcademicYearStore()
const authStore = useAuthStore()

const isAdmin = computed(() => isInstitutionAdmin(authStore.accessContext))
const canManageLock = computed(() => canManageAcademicYearLock(authStore.accessContext, authStore.profile))

const selectedYear = computed(() => academicYearStore.selectedYear)
const selectedYearName = computed(() => academicYearStore.selectedYearName || 'No definido')
const isCurrentYear = computed(() => academicYearStore.isCurrentYear)
const isLocked = computed(() => academicYearStore.isLocked)
const academicYears = computed(() => academicYearStore.academicYears)

const showLockModal = ref(false)
const isProcessingLock = ref(false)

const onYearChange = (e) => {
  const newYearId = e.target.value
  if (newYearId) {
    academicYearStore.setSelectedYearId(newYearId)
  }
}

const goToCourses = () => {
  router.push('/courses')
}

const handlePadlockClick = () => {
  if (!canManageLock.value) {
    toast.info('Permiso restringido', {
      description: 'Solo el Super Administrador, Administrador Institucional o Rector pueden cambiar el estado de bloqueo del año lectivo.'
    })
    return
  }
  showLockModal.value = true
}

const confirmToggleLock = async () => {
  if (!academicYearStore.selectedYearId) return
  isProcessingLock.value = true

  const willLock = !isLocked.value
  try {
    await academicYearStore.toggleAcademicYearLock(academicYearStore.selectedYearId, willLock)
    showLockModal.value = false
    if (willLock) {
      toast.success(`Año lectivo ${selectedYearName.value} bloqueado`, {
        description: 'Se han protegido los cursos, materias y notas contra modificaciones no autorizadas.'
      })
    } else {
      toast.success(`Año lectivo ${selectedYearName.value} desbloqueado`, {
        description: 'Se han reactivado los permisos de edición académica para este ciclo.'
      })
    }
  } catch (error) {
    console.error('Error toggling academic year lock:', error)
    toast.error('Error al actualizar bloqueo', {
      description: error.message || 'No se pudo cambiar el estado de bloqueo del año lectivo.'
    })
  } finally {
    isProcessingLock.value = false
  }
}
</script>

<template>
  <div 
    class="relative overflow-hidden rounded-2xl border transition-all duration-300 shadow-sm mb-6"
    :class="[
      isLocked
        ? 'bg-gradient-to-r from-rose-50/95 via-white/90 to-amber-50/90 dark:from-slate-900/95 dark:via-slate-900/70 dark:to-rose-950/40 border-rose-300 dark:border-rose-900/60 ring-1 ring-rose-400/20'
        : isCurrentYear 
          ? 'bg-gradient-to-r from-indigo-50/90 via-white/80 to-blue-50/90 dark:from-slate-900/90 dark:via-slate-900/60 dark:to-indigo-950/40 border-indigo-100/90 dark:border-indigo-900/40' 
          : 'bg-gradient-to-r from-amber-50/90 via-white/80 to-orange-50/90 dark:from-slate-900/90 dark:via-slate-900/60 dark:to-amber-950/30 border-amber-200/80 dark:border-amber-900/40'
    ]"
    role="region"
    aria-label="Información del Año Lectivo activo"
  >
    <!-- Background Ambient Glow -->
    <div 
      class="absolute -right-12 -top-12 w-48 h-48 rounded-full blur-3xl pointer-events-none opacity-40"
      :class="[
        isLocked
          ? 'bg-rose-500 dark:bg-rose-600'
          : isCurrentYear 
            ? 'bg-indigo-400 dark:bg-indigo-600' 
            : 'bg-amber-400 dark:bg-amber-600'
      ]"
    ></div>

    <div :class="props.compact ? 'p-3 sm:p-4' : 'p-4 sm:p-5'" class="relative z-10">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
        
        <!-- Left Section: Icon + Year Details -->
        <div class="flex items-center gap-3.5 min-w-0">
          <div 
            class="w-11 h-11 sm:w-12 sm:h-12 rounded-xl flex items-center justify-center shrink-0 shadow-sm border transition-transform duration-200 hover:scale-105"
            :class="[
              isLocked
                ? 'bg-rose-600 text-white border-rose-500/40 dark:bg-rose-500/30 dark:text-rose-300 dark:border-rose-500/40 shadow-rose-500/20'
                : isCurrentYear 
                  ? 'bg-indigo-600 text-white border-indigo-500/30 dark:bg-indigo-500/20 dark:text-indigo-300 dark:border-indigo-500/30' 
                  : 'bg-amber-600 text-white border-amber-500/30 dark:bg-amber-500/20 dark:text-amber-300 dark:border-amber-500/30'
            ]"
          >
            <Lock v-if="isLocked" class="w-6 h-6 animate-pulse" />
            <CalendarCheck2 v-else-if="isCurrentYear" class="w-6 h-6" />
            <History v-else class="w-6 h-6" />
          </div>

          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2 mb-0.5">
              <span class="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400 flex items-center gap-1.5">
                <Sparkles v-if="isCurrentYear && !isLocked" class="w-3.5 h-3.5 text-indigo-500" />
                <History v-else-if="!isCurrentYear" class="w-3.5 h-3.5 text-amber-500" />
                {{ isCurrentYear ? 'Año Lectivo en Curso' : 'Año Lectivo Histórico' }}
              </span>

              <!-- Status Badge (Current vs Historical) -->
              <span 
                v-if="isCurrentYear"
                class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/80 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800/60"
              >
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500" :class="isLocked ? '' : 'animate-pulse'"></span>
                Ciclo Actual
              </span>
              <span 
                v-else
                class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-amber-100 text-amber-800 dark:bg-amber-950/80 dark:text-amber-300 border border-amber-200 dark:border-amber-800/60"
              >
                <History class="w-3 h-3" />
                Historial / Archivo
              </span>

              <!-- Locked Badge -->
              <span 
                v-if="isLocked"
                class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-100 text-rose-800 dark:bg-rose-950/90 dark:text-rose-300 border border-rose-300 dark:border-rose-800/80 shadow-sm"
              >
                <Lock class="w-3 h-3 text-rose-600 dark:text-rose-400" />
                Bloqueado (Solo Lectura)
              </span>
              <span 
                v-else
                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300 border border-slate-200 dark:border-slate-700"
              >
                <Unlock class="w-3 h-3 text-emerald-500" />
                Modificaciones Habilitadas
              </span>
            </div>

            <div class="flex items-baseline gap-2 flex-wrap">
              <h2 class="text-lg sm:text-xl font-extrabold tracking-tight text-slate-900 dark:text-white flex items-center gap-2">
                {{ selectedYearName }}
                <span v-if="isLocked" class="text-xs px-2 py-0.5 rounded-md bg-rose-600 text-white font-bold tracking-normal uppercase">
                  Protegido
                </span>
              </h2>
              <span v-if="props.moduleName" class="text-xs font-medium text-slate-500 dark:text-slate-400">
                · Módulo {{ props.moduleName }}
              </span>
            </div>

            <p class="text-xs sm:text-sm text-slate-600 dark:text-slate-300 mt-0.5 line-clamp-1 sm:line-clamp-none">
              <template v-if="isLocked">
                Este año lectivo está <strong>bloqueado</strong>. Los datos académicos están protegidos en modo solo lectura.
              </template>
              <template v-else-if="isCurrentYear">
                Los cursos, asignaturas, calificaciones y reportes visualizados corresponden al ciclo académico activo.
              </template>
              <template v-else>
                Estás visualizando datos históricos del ciclo <strong>{{ selectedYearName }}</strong>.
              </template>
            </p>
          </div>
        </div>

        <!-- Right Section: Interactive Year Switcher & Padlock Lock Button -->
        <div v-if="props.showSwitcher && academicYears.length > 0" class="flex flex-wrap items-center gap-2.5 shrink-0 self-start md:self-center">
          
          <!-- Year Selector -->
          <div class="flex flex-col items-start md:items-end">
            <label for="banner-year-select" class="text-[11px] font-semibold text-slate-500 dark:text-slate-400 mb-1 flex items-center gap-1">
              <ArrowRightLeft class="w-3 h-3" />
              Ciclo Lectivo:
            </label>
            <div class="relative flex items-center">
              <select 
                id="banner-year-select"
                :value="academicYearStore.selectedYearId"
                @change="onYearChange"
                class="app-input py-1.5 px-3 text-xs sm:text-sm font-semibold rounded-xl bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 shadow-sm focus:ring-2 focus:ring-indigo-500/50 cursor-pointer min-w-[140px]"
                aria-label="Seleccionar año lectivo a trabajar"
              >
                <option v-for="y in academicYears" :key="y.id" :value="y.id">
                  {{ y.name }} {{ y.is_locked ? '🔒' : '' }} {{ y.is_current ? '⭐' : '' }}
                </option>
              </select>
            </div>
          </div>

          <!-- BOTÓN CANDADO DE BLOQUEO / DESBLOQUEO -->
          <div class="flex flex-col items-start md:items-end">
            <span class="text-[11px] font-semibold text-slate-500 dark:text-slate-400 mb-1 flex items-center gap-1">
              Candado:
            </span>
            <button
              type="button"
              id="academic-year-lock-btn"
              @click="handlePadlockClick"
              :class="[
                isLocked
                  ? 'bg-rose-600 hover:bg-rose-700 text-white border-rose-700 shadow-rose-600/30'
                  : 'bg-white dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 border-slate-300 dark:border-slate-700',
                canManageLock ? 'cursor-pointer hover:scale-[1.02] active:scale-95' : 'opacity-80 cursor-default'
              ]"
              class="inline-flex items-center gap-1.5 py-1.5 px-3 rounded-xl border text-xs sm:text-sm font-bold shadow-sm transition-all focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-indigo-500"
              :title="canManageLock ? (isLocked ? 'Clic para desbloquear año lectivo' : 'Clic para bloquear año lectivo contra modificaciones') : 'Bloqueo gestionado por Rectoría y Administradores'"
              :aria-label="isLocked ? 'Desbloquear año lectivo' : 'Bloquear año lectivo'"
            >
              <Lock v-if="isLocked" class="w-4 h-4 text-white shrink-0" />
              <Unlock v-else class="w-4 h-4 text-emerald-600 dark:text-emerald-400 shrink-0" />
              <span>{{ isLocked ? 'Bloqueado' : 'Abierto' }}</span>
            </button>
          </div>

          <!-- Courses Management Quick Access Button -->
          <button
            v-if="isAdmin && $route.path !== '/courses'"
            type="button"
            @click="goToCourses"
            class="p-2 text-slate-600 hover:text-indigo-600 dark:text-slate-400 dark:hover:text-indigo-400 rounded-xl hover:bg-white/60 dark:hover:bg-slate-800/60 transition-colors border border-transparent hover:border-slate-200 dark:hover:border-slate-700 mt-auto"
            title="Administrar Años Lectivos en Cursos"
          >
            <School class="w-4 h-4" />
          </button>
        </div>

      </div>

      <!-- Warning Alert Banner when Year is Locked -->
      <div 
        v-if="isLocked" 
        class="mt-3 pt-3 border-t border-rose-200/80 dark:border-rose-900/60 flex items-center justify-between gap-3 text-xs font-medium text-rose-800 dark:text-rose-300 bg-rose-50/60 dark:bg-rose-950/30 p-2.5 rounded-xl"
      >
        <div class="flex items-center gap-2">
          <ShieldAlert class="w-4 h-4 shrink-0 text-rose-600 dark:text-rose-400" />
          <span>
            <strong>Año Lectivo Protegido:</strong> Las modificaciones están bloqueadas. Los docentes no pueden realizar cambios ni registrar calificaciones.
          </span>
        </div>
        <span v-if="!canManageLock" class="text-[11px] font-normal text-rose-600 dark:text-rose-400 italic shrink-0">
          (Solo Lectura)
        </span>
      </div>

      <!-- Warning Note ONLY for Rector and Institution Admin / Superadmin when Unlocked -->
      <div 
        v-else-if="canManageLock" 
        class="mt-3 pt-3 border-t border-amber-200/60 dark:border-amber-900/40 flex items-center gap-2 text-xs font-medium text-amber-800 dark:text-amber-300"
      >
        <AlertTriangle class="w-4 h-4 shrink-0 text-amber-600 dark:text-amber-400" />
        <span><strong>Atención:</strong> Una vez bloqueado los docentes no podrán realizar cambios.</span>
      </div>
    </div>

    <!-- MODAL DE CONFIRMACIÓN DE BLOQUEO / DESBLOQUEO -->
    <div 
      v-if="showLockModal" 
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-fade-in"
      role="dialog"
      aria-modal="true"
      aria-labelledby="lock-modal-title"
    >
      <div class="relative w-full max-w-md bg-white dark:bg-slate-900 rounded-3xl p-6 shadow-2xl border border-slate-200 dark:border-slate-800 overflow-hidden">
        
        <!-- Ambient Header Light -->
        <div 
          class="absolute -top-12 -right-12 w-36 h-36 rounded-full blur-2xl opacity-40 pointer-events-none"
          :class="isLocked ? 'bg-emerald-500' : 'bg-rose-500'"
        ></div>

        <!-- Modal Icon -->
        <div class="flex items-center gap-3.5 mb-4">
          <div 
            class="w-12 h-12 rounded-2xl flex items-center justify-center shrink-0 border"
            :class="[
              isLocked 
                ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/80 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800'
                : 'bg-rose-100 text-rose-700 dark:bg-rose-950/80 dark:text-rose-300 border-rose-300 dark:border-rose-800'
            ]"
          >
            <Unlock v-if="isLocked" class="w-6 h-6" />
            <Lock v-else class="w-6 h-6" />
          </div>
          <div>
            <h3 id="lock-modal-title" class="text-base sm:text-lg font-bold text-slate-900 dark:text-white">
              {{ isLocked ? 'Desbloquear Año Lectivo' : 'Bloquear Modificaciones del Año' }}
            </h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 font-semibold">
              Ciclo: {{ selectedYearName }}
            </p>
          </div>
        </div>

        <!-- Modal Body Content -->
        <div class="space-y-3 text-sm text-slate-600 dark:text-slate-300 mb-6">
          <template v-if="isLocked">
            <p>
              ¿Deseas <strong>desbloquear</strong> el año lectivo <strong>{{ selectedYearName }}</strong>?
            </p>
            <div class="p-3 rounded-2xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-900/60 text-xs text-emerald-800 dark:text-emerald-300 flex items-start gap-2">
              <ShieldCheck class="w-4 h-4 shrink-0 mt-0.5 text-emerald-600 dark:text-emerald-400" />
              <span>Se habilitará nuevamente la edición de calificaciones, modificación de cursos y gestión de materias para los docentes asignados.</span>
            </div>
          </template>
          <template v-else>
            <p>
              ¿Estás seguro de <strong>bloquear</strong> las modificaciones para el año lectivo <strong>{{ selectedYearName }}</strong>?
            </p>
            <div class="p-3 rounded-2xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900/60 text-xs text-rose-800 dark:text-rose-300 flex items-start gap-2">
              <ShieldAlert class="w-4 h-4 shrink-0 mt-0.5 text-rose-600 dark:text-rose-400" />
              <span>Todos los cursos, materias, estudiantes y calificaciones pasarán a modo de <strong>Solo Lectura</strong>. Los docentes no podrán modificar notas ni registros de este ciclo hasta que sea desbloqueado por Rectoría o Administración.</span>
            </div>
          </template>
        </div>

        <!-- Action Buttons -->
        <div class="flex items-center justify-end gap-3">
          <button
            type="button"
            @click="showLockModal = false"
            :disabled="isProcessingLock"
            class="px-4 py-2 text-sm font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-colors disabled:opacity-50"
          >
            Cancelar
          </button>
          <button
            type="button"
            id="confirm-lock-action-btn"
            @click="confirmToggleLock"
            :disabled="isProcessingLock"
            class="px-5 py-2 text-sm font-bold text-white rounded-xl shadow-md transition-all flex items-center gap-2 disabled:opacity-50"
            :class="[
              isLocked
                ? 'bg-emerald-600 hover:bg-emerald-700 shadow-emerald-600/30'
                : 'bg-rose-600 hover:bg-rose-700 shadow-rose-600/30'
            ]"
          >
            <span v-if="isProcessingLock" class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
            <span v-else>{{ isLocked ? 'Confirmar y Desbloquear' : 'Confirmar y Bloquear' }}</span>
          </button>
        </div>

      </div>
    </div>

  </div>
</template>
