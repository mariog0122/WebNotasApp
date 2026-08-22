<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../../lib/supabase'
import { Activity, Database, Key, HardDrive, Cpu, CreditCard, ShieldCheck, RefreshCw, Bug } from 'lucide-vue-next'

const testing = ref(false)
const services = ref([])
const lastChecked = ref(null)

const icons = {
  database: Database,
  auth: Key,
  storage: HardDrive,
  cron: Cpu,
  billing: CreditCard,
  rls: ShieldCheck,
  telemetry: Bug
}

const checkHealth = async () => {
  testing.value = true
  const start = performance.now()
  try {
    const { data, error } = await supabase.rpc('get_platform_health')
    if (error) throw error

    const latency = Math.round(performance.now() - start)
    services.value = (data?.services || []).map(service => ({
      ...service,
      latency: `${latency}ms`,
      icon: icons[service.key] || Activity
    }))
    lastChecked.value = data?.checked_at || new Date().toISOString()
  } catch (err) {
    services.value = [{
      key: 'monitor',
      name: 'Monitor server-side',
      status: 'down',
      detail: err.message || 'No fue posible completar el diagnóstico',
      latency: `${Math.round(performance.now() - start)}ms`,
      icon: Activity
    }]
    lastChecked.value = new Date().toISOString()
  } finally {
    testing.value = false
  }
}

onMounted(() => {
  checkHealth()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between bg-slate-900/80 p-5 rounded-2xl border border-slate-800 shadow-md">
      <div>
        <h3 class="font-bold text-lg text-white flex items-center gap-2">
          <Activity class="w-5 h-5 text-emerald-400" /> Monitor de Salud del Sistema
        </h3>
        <p class="text-xs text-slate-400 mt-0.5">Diagnóstico server-side seguro de servicios de infraestructura SaaS.</p>
        <p v-if="lastChecked" class="text-[11px] text-slate-500 mt-1">Última medición: {{ new Date(lastChecked).toLocaleString() }}</p>
      </div>

      <button 
        @click="checkHealth" 
        :disabled="testing"
        class="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center gap-2 transition-all shadow-lg"
      >
        <RefreshCw :class="['w-4 h-4', testing ? 'animate-spin' : '']" /> Check Status
      </button>
    </div>

    <!-- Cards Grid Services Status -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div 
        v-for="serv in services" 
        :key="serv.name"
        class="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 shadow-lg flex items-center justify-between hover:border-slate-700 transition-colors"
      >
        <div class="flex items-center gap-3">
          <div class="p-3 bg-slate-800 rounded-xl text-indigo-400">
            <component :is="serv.icon" class="w-5 h-5" />
          </div>
          <div>
            <div class="font-bold text-sm text-white">{{ serv.name }}</div>
            <div class="text-xs text-slate-400 mt-0.5">{{ serv.detail }}</div>
            <div class="text-[11px] text-slate-500 font-mono mt-1">Respuesta: {{ serv.latency }}</div>
          </div>
        </div>

        <span :class="[
          'px-2.5 py-1 rounded-full text-xs font-semibold uppercase tracking-wider',
          serv.status === 'operational' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' :
          serv.status === 'degraded' ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20' :
          'bg-rose-500/10 text-rose-400 border border-rose-500/20'
        ]">
          {{ serv.status === 'operational' ? 'Operativo' : serv.status === 'degraded' ? 'Degradado' : 'Caído' }}
        </span>
      </div>
    </div>
  </div>
</template>
