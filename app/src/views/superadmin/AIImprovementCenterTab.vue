<script setup>
import { ref, onMounted, computed } from 'vue'
import { 
  Sparkles, 
  ShieldCheck, 
  AlertTriangle, 
  CheckCircle2, 
  XCircle, 
  Play, 
  Layers, 
  Check, 
  Trash2, 
  Loader2,
  TrendingUp,
  Inbox,
  Filter
} from 'lucide-vue-next'
import { supabase } from '../../lib/supabase'
import { KnowledgePromotionService } from '../../lib/ai/KnowledgePromotionService'
import { AIEvaluationService } from '../../lib/ai/AIEvaluationService'
import { DemoEducationAIProvider } from '../../lib/ai/DemoEducationAIProvider'
import { PromptRegistry } from '../../lib/ai/PromptRegistry'
import { toast } from 'vue-sonner'

const loading = ref(false)
const reviewingId = ref(null)
const evaluating = ref(false)

const feedbackStats = ref({
  total: 0,
  positive: 0,
  negative: 0,
  quarantined: 0,
  approved: 0,
  goldenActive: 0
})

const quarantineList = ref([])
const activePrompts = ref([])
const benchmarkResult = ref(null)

const loadDashboardData = async () => {
  loading.value = true
  try {
    // 1. Cargar cola de cuarentena
    quarantineList.value = await KnowledgePromotionService.fetchQuarantineQueue()

    // 2. Cargar estadísticas de feedback
    const { data: logs } = await supabase
      .from('ai_feedback_logs')
      .select('rating, status, category')
      .limit(500)

    if (logs) {
      feedbackStats.value.total = logs.length
      feedbackStats.value.positive = logs.filter(l => l.rating >= 4).length
      feedbackStats.value.negative = logs.filter(l => l.rating <= 2).length
      feedbackStats.value.quarantined = logs.filter(l => l.status === 'quarantined').length
      feedbackStats.value.approved = logs.filter(l => l.status === 'approved').length
    }

    // 3. Cargar memorias institucionales activas
    const { count: memCount } = await supabase
      .from('ai_institutional_memory')
      .select('*', { count: 'exact', head: true })
      .eq('is_active', true)

    feedbackStats.value.goldenActive = memCount || 0

    // 4. Prompts registrados
    activePrompts.value = PromptRegistry.listPrompts()
  } catch (err) {
    console.warn('Error cargando métricas de AI Improvement Center:', err)
  } finally {
    loading.value = false
  }
}

const handleApprove = async (item, targetScope = 'institution') => {
  reviewingId.value = item.id
  try {
    await KnowledgePromotionService.reviewQuarantine(item.id, 'approve', 'Aprobado desde AI Improvement Center', targetScope)
    toast.success(`Elemento promovido a Memoria (${targetScope}) exitosamente.`)
    await loadDashboardData()
  } catch (err) {
    toast.error('Error al aprobar elemento: ' + err.message)
  } finally {
    reviewingId.value = null
  }
}

const handleReject = async (item) => {
  reviewingId.value = item.id
  try {
    await KnowledgePromotionService.reviewQuarantine(item.id, 'reject', 'Rechazado en revisión de calidad')
    toast.info('Elemento rechazado y archivado de la cuarentena.')
    await loadDashboardData()
  } catch (err) {
    toast.error('Error al rechazar elemento: ' + err.message)
  } finally {
    reviewingId.value = null
  }
}

const runEvaluation = async () => {
  evaluating.value = true
  try {
    const demo = new DemoEducationAIProvider()
    benchmarkResult.value = await AIEvaluationService.runBenchmarkSuite(demo)
    toast.success(`Evaluación completada con Score Promedio: ${(benchmarkResult.value.averageScore * 100).toFixed(0)}%`)
  } catch (err) {
    toast.error('Fallo al ejecutar evaluación: ' + err.message)
  } finally {
    evaluating.value = false
  }
}

onMounted(() => {
  loadDashboardData()
})
</script>

<template>
  <div class="space-y-6">
    
    <!-- Top Summary Banner -->
    <div class="p-6 rounded-3xl border border-indigo-500/20 bg-linear-to-r from-indigo-500/10 via-purple-500/5 to-transparent flex flex-wrap items-center justify-between gap-4">
      <div class="space-y-1">
        <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-bold bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-500/20">
          <Sparkles class="w-3.5 h-3.5" />
          AI Improvement Center & Knowledge Quarantine
        </div>
        <h2 class="text-xl font-bold text-slate-900 dark:text-white">
          Mejora Continua y Memoria Pedagógica Verificada
        </h2>
        <p class="text-xs text-slate-500 dark:text-slate-400 max-w-2xl">
          Supervisa el feedback de docentes ecuatorianos, audita candidatos en cuarentena y promueve directrices a la base de conocimiento institucional sin riesgo de contaminación del modelo.
        </p>
      </div>

      <button
        @click="runEvaluation"
        :disabled="evaluating"
        type="button"
        class="inline-flex items-center gap-2 px-4 py-2.5 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-md transition-all cursor-pointer disabled:opacity-50"
      >
        <Loader2 v-if="evaluating" class="w-4 h-4 animate-spin" />
        <Play v-else class="w-4 h-4" />
        <span>Ejecutar Evaluación Golden Dataset</span>
      </button>
    </div>

    <!-- Metrics Cards -->
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
      <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
        <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">Total Feedbacks</span>
        <strong class="text-xl font-black text-slate-900 dark:text-white mt-1 block">{{ feedbackStats.total }}</strong>
      </div>
      <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
        <span class="text-[10px] font-bold text-emerald-500 uppercase tracking-wider block">Positivos (👍)</span>
        <strong class="text-xl font-black text-emerald-600 dark:text-emerald-400 mt-1 block">{{ feedbackStats.positive }}</strong>
      </div>
      <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
        <span class="text-[10px] font-bold text-amber-500 uppercase tracking-wider block">A Mejorar (👎)</span>
        <strong class="text-xl font-black text-amber-600 dark:text-amber-400 mt-1 block">{{ feedbackStats.negative }}</strong>
      </div>
      <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
        <span class="text-[10px] font-bold text-indigo-500 uppercase tracking-wider block">En Cuarentena</span>
        <strong class="text-xl font-black text-indigo-600 dark:text-indigo-400 mt-1 block">{{ quarantineList.length }}</strong>
      </div>
      <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
        <span class="text-[10px] font-bold text-teal-500 uppercase tracking-wider block">Aprobados L2/L3</span>
        <strong class="text-xl font-black text-teal-600 dark:text-teal-400 mt-1 block">{{ feedbackStats.approved }}</strong>
      </div>
      <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
        <span class="text-[10px] font-bold text-purple-500 uppercase tracking-wider block">Golden Samples</span>
        <strong class="text-xl font-black text-purple-600 dark:text-purple-400 mt-1 block">{{ feedbackStats.goldenActive }}</strong>
      </div>
    </div>

    <!-- Evaluation Results Banner if run -->
    <div v-if="benchmarkResult" class="p-5 rounded-3xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/60 space-y-3">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <CheckCircle2 v-if="benchmarkResult.suitePassed" class="w-5 h-5 text-emerald-500" />
          <AlertTriangle v-else class="w-5 h-5 text-amber-500" />
          <h3 class="text-sm font-bold text-slate-900 dark:text-white">
            Resultado de Evaluación Automática contra Golden Dataset
          </h3>
        </div>
        <span class="text-xs font-bold text-indigo-600 dark:text-indigo-400">
          Score Global: {{ (benchmarkResult.averageScore * 100).toFixed(0) }}%
        </span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div v-for="res in benchmarkResult.results" :key="res.caseId" class="p-3.5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
          <div class="flex items-center justify-between mb-1">
            <strong class="text-xs font-bold text-slate-900 dark:text-white">{{ res.subject }}</strong>
            <span :class="['px-2 py-0.5 rounded text-[10px] font-bold border', res.passed ? 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800' : 'bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-800']">
              {{ res.passed ? 'APROBADO' : 'FALLO' }}
            </span>
          </div>
          <div class="text-[11px] text-slate-500 dark:text-slate-400 space-y-0.5 font-mono">
            <div>Alineación Curricular: {{ (res.metrics?.curriculum_alignment * 100).toFixed(0) }}%</div>
            <div>Calidad Pedagógica: {{ (res.metrics?.pedagogical_quality * 100).toFixed(0) }}%</div>
            <div>Tasa Alucinación: {{ (res.metrics?.hallucination_rate * 100).toFixed(0) }}%</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Knowledge Quarantine Table -->
    <div class="border border-slate-200 dark:border-slate-800 rounded-3xl bg-white dark:bg-slate-900 overflow-hidden shadow-xs">
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
        <div>
          <h3 class="text-sm font-bold text-slate-900 dark:text-white">
            Cola de Cuarentena (Knowledge Quarantine)
          </h3>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Sugerencias y correcciones candidatas que requieren validación humana antes de ser RAG en producción.
          </p>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full text-left border-collapse text-xs">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-950/60 text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase">
              <th class="p-3">Categoría</th>
              <th class="p-3">Contenido Sanitizado</th>
              <th class="p-3">Confianza</th>
              <th class="p-3">Riesgo</th>
              <th class="p-3">Estado</th>
              <th class="p-3 text-right">Compuerta de Aprobación</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60">
            <tr v-for="item in quarantineList" :key="item.id" class="hover:bg-slate-50/60 dark:hover:bg-slate-800/30">
              <td class="p-3 font-semibold text-slate-900 dark:text-white uppercase text-[11px]">
                {{ item.category }}
              </td>
              <td class="p-3 max-w-md">
                <p class="text-xs text-slate-700 dark:text-slate-300 line-clamp-2">
                  {{ item.sanitized_content }}
                </p>
              </td>
              <td class="p-3 font-mono text-[11px] font-bold text-indigo-600 dark:text-indigo-400">
                {{ ((item.confidence || 0.8) * 100).toFixed(0) }}%
              </td>
              <td class="p-3">
                <span :class="[
                  'px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border',
                  item.risk_score > 0.3 ? 'bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 border-amber-200 dark:border-amber-800/40' : 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800/40'
                ]">
                  {{ item.risk_score > 0.3 ? 'Medio' : 'Bajo' }}
                </span>
              </td>
              <td class="p-3">
                <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-700">
                  {{ item.status }}
                </span>
              </td>
              <td class="p-3 text-right space-x-1.5">
                <button
                  @click="handleApprove(item, 'institution')"
                  :disabled="reviewingId === item.id || item.status === 'approved'"
                  type="button"
                  class="px-2.5 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-[11px] transition-colors cursor-pointer disabled:opacity-50"
                  title="Aprobar para uso en este colegio"
                >
                  Aprobar Colegio
                </button>
                <button
                  @click="handleApprove(item, 'global')"
                  :disabled="reviewingId === item.id || item.status === 'approved'"
                  type="button"
                  class="px-2.5 py-1 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-[11px] transition-colors cursor-pointer disabled:opacity-50"
                  title="Promover como patrón global verificado"
                >
                  Promover Global
                </button>
                <button
                  @click="handleReject(item)"
                  :disabled="reviewingId === item.id || item.status === 'rejected'"
                  type="button"
                  class="px-2.5 py-1 rounded-lg bg-slate-100 dark:bg-slate-800 text-rose-600 dark:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-950/40 border border-slate-200 dark:border-slate-700 font-bold text-[11px] transition-colors cursor-pointer disabled:opacity-50"
                  title="Rechazar y archivar"
                >
                  Rechazar
                </button>
              </td>
            </tr>

            <tr v-if="quarantineList.length === 0">
              <td colspan="6" class="p-8 text-center text-slate-400 dark:text-slate-500">
                <Inbox class="w-8 h-8 mx-auto mb-2 opacity-50" />
                No hay elementos pendientes en cuarentena en este momento.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

  </div>
</template>
