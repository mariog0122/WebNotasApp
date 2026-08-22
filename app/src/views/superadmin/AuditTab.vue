<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../../lib/supabase'
import { ShieldCheck, Search, Filter, History, Eye, UserCheck } from 'lucide-vue-next'

const loading = ref(true)
const logs = ref([])
const impersonationLogs = ref([])

const activeSubTab = ref('audit')
const searchQuery = ref('')

const loadAuditLogs = async () => {
  loading.value = true
  try {
    const { data: auditData, error: auditErr } = await supabase
      .from('audit_log')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(100)
    
    if (!auditErr && auditData) logs.value = auditData

    const { data: impData, error: impErr } = await supabase
      .from('impersonation_logs')
      .select('*')
      .order('started_at', { ascending: false })
      .limit(100)
    
    if (!impErr && impData) impersonationLogs.value = impData
  } catch (e) {
    console.warn('Handling audit logs fallback:', e)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadAuditLogs()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Sub-tabs -->
    <div class="flex space-x-2 border-b border-slate-800 pb-2">
      <button 
        @click="activeSubTab = 'audit'"
        :class="['px-4 py-2 text-sm font-medium rounded-xl transition-colors flex items-center gap-2', activeSubTab === 'audit' ? 'bg-indigo-600 text-white font-bold' : 'text-slate-400 hover:text-white']"
      >
        <History class="w-4 h-4" />
        Auditoría de Eventos Críticos
      </button>

      <button 
        @click="activeSubTab = 'impersonation'"
        :class="['px-4 py-2 text-sm font-medium rounded-xl transition-colors flex items-center gap-2', activeSubTab === 'impersonation' ? 'bg-amber-600 text-white font-bold' : 'text-slate-400 hover:text-white']"
      >
        <UserCheck class="w-4 h-4" />
        Logs de Impersonación y Soporte
      </button>
    </div>

    <!-- AUDITORÍA DE EVENTOS -->
    <div v-if="activeSubTab === 'audit'" class="bg-slate-900/80 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
      <div class="overflow-x-auto">
        <table class="w-full text-left text-sm">
          <thead class="bg-slate-950 text-slate-400 border-b border-slate-800 text-xs font-semibold uppercase tracking-wider">
            <tr>
              <th class="px-5 py-3.5">Fecha & Hora</th>
              <th class="px-5 py-3.5">Acción</th>
              <th class="px-5 py-3.5">Tabla / Objeto</th>
              <th class="px-5 py-3.5">ID Usuario</th>
              <th class="px-5 py-3.5">Detalles / Metadata</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-800/60 text-slate-300">
            <tr v-if="loading">
              <td colspan="5" class="py-10 text-center text-slate-500">Cargando registros de auditoría...</td>
            </tr>
            <tr v-else-if="logs.length === 0">
              <td colspan="5" class="py-10 text-center text-slate-500">Sin registros de auditoría almacenados.</td>
            </tr>
            <tr v-else v-for="log in logs" :key="log.id" class="hover:bg-slate-800/40 transition-colors">
              <td class="px-5 py-3.5 text-xs text-slate-400 font-mono">
                {{ new Date(log.created_at).toLocaleString() }}
              </td>
              <td class="px-5 py-3.5">
                <span :class="[
                  'px-2 py-0.5 rounded text-xs font-bold font-mono',
                  log.action === 'INSERT' ? 'bg-emerald-500/10 text-emerald-400' :
                  log.action === 'UPDATE' ? 'bg-sky-500/10 text-sky-400' :
                  log.action === 'DELETE' ? 'bg-rose-500/10 text-rose-400' : 'bg-amber-500/10 text-amber-400'
                ]">
                  {{ log.action }}
                </span>
              </td>
              <td class="px-5 py-3.5 font-mono text-xs text-indigo-300">
                {{ log.table_name }}
              </td>
              <td class="px-5 py-3.5 text-xs text-slate-400 font-mono truncate max-w-[150px]">
                {{ log.user_id }}
              </td>
              <td class="px-5 py-3.5 text-xs font-mono text-slate-400 truncate max-w-[300px]">
                {{ JSON.stringify(log.new_values || log.old_values || {}) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- LOGS DE IMPERSONACIÓN -->
    <div v-if="activeSubTab === 'impersonation'" class="bg-slate-900/80 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
      <div class="overflow-x-auto">
        <table class="w-full text-left text-sm">
          <thead class="bg-slate-950 text-slate-400 border-b border-slate-800 text-xs font-semibold uppercase tracking-wider">
            <tr>
              <th class="px-5 py-3.5">Inicio</th>
              <th class="px-5 py-3.5">Fin</th>
              <th class="px-5 py-3.5">Actor (SuperAdmin)</th>
              <th class="px-5 py-3.5">Usuario Destino</th>
              <th class="px-5 py-3.5">Motivo del Soporte</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-800/60 text-slate-300">
            <tr v-if="loading">
              <td colspan="5" class="py-10 text-center text-slate-500">Cargando logs de soporte e impersonación...</td>
            </tr>
            <tr v-else-if="impersonationLogs.length === 0">
              <td colspan="5" class="py-10 text-center text-slate-500">No hay registros de impersonación activos.</td>
            </tr>
            <tr v-else v-for="imp in impersonationLogs" :key="imp.id" class="hover:bg-slate-800/40 transition-colors">
              <td class="px-5 py-3.5 text-xs font-mono text-slate-400">
                {{ new Date(imp.started_at).toLocaleString() }}
              </td>
              <td class="px-5 py-3.5 text-xs font-mono text-slate-400">
                {{ imp.ended_at ? new Date(imp.ended_at).toLocaleString() : 'EN CURSO' }}
              </td>
              <td class="px-5 py-3.5 text-xs font-mono text-indigo-300">
                {{ imp.actor_id }}
              </td>
              <td class="px-5 py-3.5 text-xs font-mono text-slate-300">
                {{ imp.impersonated_user_id }}
              </td>
              <td class="px-5 py-3.5 text-sm text-slate-200 italic">
                "{{ imp.reason }}"
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
