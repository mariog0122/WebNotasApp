<template>
  <div class="min-h-screen bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 p-6 md:p-8">
    <div class="max-w-7xl mx-auto space-y-8">
      
      <!-- Top Bar / Breadcrumb & Actions -->
      <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <div class="flex items-center space-x-2 text-xs font-semibold text-indigo-600 dark:text-indigo-400 uppercase tracking-wider mb-1">
            <TrendingUp class="w-4 h-4" />
            <span>Panel de Dirección Pedagógica • Rectoría</span>
          </div>
          <h1 class="text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">
            Indicadores Institucionales y Crecimiento Longitudinal
          </h1>
          <p class="text-slate-500 dark:text-slate-400 text-sm mt-1">
            Evidencia institucional del cierre de brechas pedagógicas y dominio de competencias clave.
          </p>
        </div>

        <div class="flex items-center gap-3">
          <button 
            @click="loadAnalytics"
            :disabled="isLoading"
            class="px-4 py-2 text-sm font-medium rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-200 shadow-sm flex items-center gap-2 transition"
          >
            <RefreshCw :class="['w-4 h-4', isLoading ? 'animate-spin' : '']" />
            <span>Actualizar</span>
          </button>
          <button 
            @click="printReport"
            :disabled="!analytics || !!loadError"
            class="px-4 py-2 text-sm font-medium rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white shadow-md shadow-indigo-600/20 flex items-center gap-2 transition"
          >
            <Printer class="w-4 h-4" />
            <span>Imprimir Informe</span>
          </button>
        </div>
      </div>

      <div v-if="loadError" class="rounded-2xl border border-rose-200 dark:border-rose-900 bg-rose-50 dark:bg-rose-950/20 p-4 text-sm text-rose-800 dark:text-rose-200">
        {{ loadError }} Revisa tu conexión o tus permisos e inténtalo nuevamente.
      </div>

      <!-- KPI Executive Summary Cards -->
      <div v-if="analytics" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <!-- 1. Cierre de Brechas -->
        <div class="bg-white dark:bg-slate-900 rounded-2xl p-5 border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center space-x-4">
          <div class="w-12 h-12 rounded-xl bg-emerald-100 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 flex items-center justify-center shrink-0">
            <CheckCircle2 class="w-6 h-6" />
          </div>
          <div>
            <div class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide">
              Tasa de Cierre de Brechas
            </div>
            <div class="text-2xl font-black text-slate-900 dark:text-white mt-0.5">
              {{ analytics?.gap_closure_rate || 0 }}%
            </div>
            <div class="text-xs text-emerald-600 dark:text-emerald-400 font-medium mt-0.5">
              {{ analytics?.total_gaps_resolved || 0 }} de {{ analytics?.total_gaps_identified || 0 }} resueltas
            </div>
          </div>
        </div>

        <!-- 2. Índice de Salud Institucional -->
        <div class="bg-white dark:bg-slate-900 rounded-2xl p-5 border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center space-x-4">
          <div class="w-12 h-12 rounded-xl bg-indigo-100 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400 flex items-center justify-center shrink-0">
            <Activity class="w-6 h-6" />
          </div>
          <div>
            <div class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide">
              Salud Curricular
            </div>
            <div class="text-2xl font-black text-slate-900 dark:text-white mt-0.5">
              {{ analytics?.institutional_health_index || 0 }} / 100
            </div>
            <div class="text-xs text-indigo-600 dark:text-indigo-400 font-medium mt-0.5">
              {{ healthStatusLabel }}
            </div>
          </div>
        </div>

        <!-- 3. Estudiantes Evaluados -->
        <div class="bg-white dark:bg-slate-900 rounded-2xl p-5 border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center space-x-4">
          <div class="w-12 h-12 rounded-xl bg-blue-100 dark:bg-blue-950/60 text-blue-600 dark:text-blue-400 flex items-center justify-center shrink-0">
            <Users class="w-6 h-6" />
          </div>
          <div>
            <div class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide">
              Estudiantes Diagnosticados
            </div>
            <div class="text-2xl font-black text-slate-900 dark:text-white mt-0.5">
              {{ analytics?.total_students_assessed || 0 }}
            </div>
            <div class="text-xs text-blue-600 dark:text-blue-400 font-medium mt-0.5">
              En grafo competencial
            </div>
          </div>
        </div>

        <!-- 4. Cuadrante Crítico -->
        <div class="bg-white dark:bg-slate-900 rounded-2xl p-5 border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center space-x-4">
          <div class="w-12 h-12 rounded-xl bg-rose-100 dark:bg-rose-950/60 text-rose-600 dark:text-rose-400 flex items-center justify-center shrink-0">
            <AlertTriangle class="w-6 h-6" />
          </div>
          <div>
            <div class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide">
              Rezago Crítico Activo
            </div>
            <div class="text-2xl font-black text-slate-900 dark:text-white mt-0.5">
              {{ analytics?.distribution?.critical_gap || 0 }}
            </div>
            <div class="text-xs text-rose-600 dark:text-rose-400 font-medium mt-0.5">
              En microintervención prioritaria
            </div>
          </div>
        </div>
      </div>

      <!-- Main Visual Grid: Distribution & Bottlenecks -->
      <div v-if="analytics" class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        <!-- Left 2 Cols: Distribution Quadrant -->
        <div class="lg:col-span-2 bg-white dark:bg-slate-900 rounded-2xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-6">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="font-bold text-lg text-slate-900 dark:text-white">
                Distribución del Dominio Institucional
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                Segmentación basada en evidencias continuas y reevaluación
              </p>
            </div>
            <span class="text-xs font-medium px-2.5 py-1 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
              Corte Actual
            </span>
          </div>

          <!-- Progress Bars Stack -->
          <div class="space-y-4">
            <!-- Dominio Consolidado -->
            <div>
              <div class="flex justify-between text-xs font-medium mb-1.5">
                <span class="text-emerald-700 dark:text-emerald-400 flex items-center gap-1.5">
                  <span class="w-2.5 h-2.5 rounded-full bg-emerald-500"></span> Dominio Consolidado (Score ≥ 70%)
                </span>
                <span class="text-slate-600 dark:text-slate-400 font-bold">
                  {{ analytics?.distribution?.mastered || 0 }} estudiantes
                </span>
              </div>
              <div class="h-3 w-full bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden">
                <div 
                  class="h-full bg-emerald-500 rounded-full transition-all duration-700" 
                  :style="{ width: `${getPercentage(analytics?.distribution?.mastered)}%` }"
                ></div>
              </div>
            </div>

            <!-- En Desarrollo -->
            <div>
              <div class="flex justify-between text-xs font-medium mb-1.5">
                <span class="text-amber-700 dark:text-amber-400 flex items-center gap-1.5">
                  <span class="w-2.5 h-2.5 rounded-full bg-amber-500"></span> En Proceso de Dominio (Score 50% - 69%)
                </span>
                <span class="text-slate-600 dark:text-slate-400 font-bold">
                  {{ analytics?.distribution?.in_progress || 0 }} estudiantes
                </span>
              </div>
              <div class="h-3 w-full bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden">
                <div 
                  class="h-full bg-amber-500 rounded-full transition-all duration-700" 
                  :style="{ width: `${getPercentage(analytics?.distribution?.in_progress)}%` }"
                ></div>
              </div>
            </div>

            <!-- Rezago Crítico -->
            <div>
              <div class="flex justify-between text-xs font-medium mb-1.5">
                <span class="text-rose-700 dark:text-rose-400 flex items-center gap-1.5">
                  <span class="w-2.5 h-2.5 rounded-full bg-rose-500"></span> Brecha Crítica / Rezago Causal (Score < 50%)
                </span>
                <span class="text-slate-600 dark:text-slate-400 font-bold">
                  {{ analytics?.distribution?.critical_gap || 0 }} estudiantes
                </span>
              </div>
              <div class="h-3 w-full bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden">
                <div 
                  class="h-full bg-rose-500 rounded-full transition-all duration-700" 
                  :style="{ width: `${getPercentage(analytics?.distribution?.critical_gap)}%` }"
                ></div>
              </div>
            </div>
          </div>

          <!-- Directorial Recommendation Banner -->
          <div class="p-4 rounded-xl bg-indigo-50 dark:bg-indigo-950/40 border border-indigo-200/70 dark:border-indigo-900/60 flex items-start space-x-3">
            <Sparkles class="w-5 h-5 text-indigo-600 dark:text-indigo-400 shrink-0 mt-0.5" />
            <div class="text-xs leading-relaxed text-indigo-950 dark:text-indigo-200">
              <span class="font-bold">Estrategia Directiva Sugerida:</span>
              {{ institutionalRecommendation }}
            </div>
          </div>
        </div>

        <!-- Right 1 Col: Top Bottlenecks -->
        <div class="bg-white dark:bg-slate-900 rounded-2xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-4">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="font-bold text-base text-slate-900 dark:text-white">
                Cuellos de Botella Curriculares
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                Competencias que concentran mayor dificultad
              </p>
            </div>
            <Target class="w-4 h-4 text-slate-400" />
          </div>

          <div class="space-y-3 pt-2">
            <div 
              v-for="(bn, idx) in analytics?.bottlenecks" 
              :key="bn.code || idx"
              class="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200/60 dark:border-slate-700/60 space-y-1.5"
            >
              <div class="flex items-center justify-between">
                <span class="text-[11px] font-bold px-2 py-0.5 rounded bg-indigo-100 dark:bg-indigo-950/80 text-indigo-700 dark:text-indigo-300">
                  {{ bn.code }}
                </span>
                <span class="text-xs font-semibold text-rose-600 dark:text-rose-400">
                  {{ bn.active_gaps_count }} casos activos
                </span>
              </div>
              <div class="text-xs font-medium text-slate-800 dark:text-slate-200 line-clamp-2">
                {{ bn.name }}
              </div>
              <div class="text-[11px] text-slate-400">
                Área: {{ bn.subject_area }}
              </div>
            </div>

            <div v-if="!analytics?.bottlenecks || analytics.bottlenecks.length === 0" class="text-center py-6 text-xs text-slate-400">
              No hay cuellos de botella detectados en este período.
            </div>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup>
import { computed, ref, onMounted } from 'vue'
import { useAuthStore } from '../../../stores/auth'
import { intelligenceService } from '../services/intelligenceService'
import { 
  TrendingUp, 
  RefreshCw, 
  Printer, 
  CheckCircle2, 
  Activity, 
  Users, 
  AlertTriangle, 
  Sparkles,
  Target
} from 'lucide-vue-next'

const authStore = useAuthStore()
const isLoading = ref(false)
const analytics = ref(null)
const loadError = ref('')

const healthStatusLabel = computed(() => {
  if (!analytics.value?.total_students_assessed) return 'Sin evidencia suficiente'
  const score = Number(analytics.value.institutional_health_index) || 0
  if (score >= 70) return 'Dominio institucional favorable'
  if (score >= 50) return 'Dominio institucional en desarrollo'
  return 'Requiere acompañamiento prioritario'
})

const institutionalRecommendation = computed(() => {
  const data = analytics.value
  if (!data?.total_students_assessed) {
    return 'Aún no hay evidencia suficiente. Sincroniza las calificaciones o ejecuta diagnósticos para iniciar el seguimiento institucional.'
  }
  if (!data.total_gaps_identified) {
    return `Hay ${data.total_students_assessed} estudiantes con evidencia registrada y no se observan brechas activas en el corte actual. Mantén la evaluación formativa para confirmar la tendencia.`
  }
  return `Se han resuelto ${data.total_gaps_resolved || 0} de ${data.total_gaps_identified} brechas (${data.gap_closure_rate || 0}%). Prioriza las competencias listadas como cuellos de botella y verifica cada avance con una reevaluación.`
})

async function loadAnalytics() {
  isLoading.value = true
  loadError.value = ''
  analytics.value = null
  try {
    const sId = authStore.activeSchoolId
    analytics.value = await intelligenceService.fetchImpactAnalytics({
      schoolId: sId
    })
  } catch (err) {
    console.error('Error cargando analítica de impacto:', err)
    loadError.value = 'No se pudieron cargar los indicadores institucionales.'
  } finally {
    isLoading.value = false
  }
}

function getPercentage(count) {
  if (!count || !analytics.value?.total_students_assessed) return 0
  const total = analytics.value.total_students_assessed
  return Math.min(100, Math.round((count / total) * 100))
}

function printReport() {
  window.print()
}

onMounted(() => {
  loadAnalytics()
})
</script>

<style scoped>
@media print {
  /* Ocultar botones y navegación en impresión */
  button, nav, aside {
    display: none !important;
  }
  body, .min-h-screen {
    background: white !important;
    color: black !important;
    padding: 0 !important;
  }
}
</style>
