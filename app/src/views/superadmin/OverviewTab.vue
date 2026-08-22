<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../../lib/supabase'
import { Building2, Users, GraduationCap, AlertTriangle, DollarSign, Activity, HardDrive, ShieldCheck } from 'lucide-vue-next'

const loading = ref(true)
const metrics = ref({
  totalTenants: 0,
  activeTenants: 0,
  trialTenants: 0,
  pastDueTenants: 0,
  graceTenants: 0,
  suspendedTenants: 0,
  cancelledTenants: 0,
  totalUsers: 0,
  totalTeachers: 0,
  totalStudents: 0,
  mrr: 0,
  arr: 0,
  storageMb: 0
})

const alerts = ref([])
const recentActivity = ref([])

const loadOverview = async () => {
  loading.value = true
  try {
    // 1. Consultar Escuelas / Tenants
    const { data: schools, error: errSchools } = await supabase.from('schools').select('id, name, status, created_at')
    if (!errSchools && schools) {
      metrics.value.totalTenants = schools.length
      metrics.value.activeTenants = schools.filter(s => s.status === 'active').length
      metrics.value.trialTenants = schools.filter(s => s.status === 'trial').length
      metrics.value.pastDueTenants = schools.filter(s => s.status === 'past_due').length
      metrics.value.graceTenants = schools.filter(s => s.status === 'grace_period').length
      metrics.value.suspendedTenants = schools.filter(s => s.status === 'suspended').length
      metrics.value.cancelledTenants = schools.filter(s => s.status === 'cancelled').length
    }

    // 2. Consultar Perfiles
    const { data: profiles } = await supabase.from('profiles').select('id, role')
    if (profiles) {
      metrics.value.totalUsers = profiles.length
      metrics.value.totalTeachers = profiles.filter(p => p.role === 'docente' || p.role === 'teacher').length
    }

    // 3. Consultar Estudiantes
    const { count: countStudents } = await supabase.from('students').select('*', { count: 'exact', head: true })
    metrics.value.totalStudents = countStudents || 0

    // 4. Consultar Suscripciones & MRR
    const { data: subs } = await supabase.from('subscriptions').select('id, plan_id, status, agreed_price, billing_cycle, plans(monthly_price, annual_price, price)')
    if (subs) {
      let sumMrr = 0
      subs.forEach(s => {
        if (s.status === 'active') {
          if (s.billing_cycle === 'yearly') {
            const annual = Number(s.agreed_price ?? s.plans?.annual_price ?? (s.plans?.monthly_price ? s.plans.monthly_price * 10 : 0))
            sumMrr += annual / 12
          } else {
            const monthly = Number(s.agreed_price ?? s.plans?.monthly_price ?? s.plans?.price ?? 0)
            sumMrr += monthly
          }
        }
      })
      metrics.value.mrr = Math.round(sumMrr * 100) / 100
      metrics.value.arr = Math.round(sumMrr * 12 * 100) / 100
    }

    // 5. Cargar Alertas del Sistema
    const newAlerts = []
    if (metrics.value.pastDueTenants > 0) {
      newAlerts.push({ id: 1, type: 'warning', text: `${metrics.value.pastDueTenants} institución(es) con pago vencido.` })
    }
    if (metrics.value.suspendedTenants > 0) {
      newAlerts.push({ id: 2, type: 'danger', text: `${metrics.value.suspendedTenants} institución(es) suspendida(s).` })
    }
    if (metrics.value.graceTenants > 0) {
      newAlerts.push({ id: 3, type: 'info', text: `${metrics.value.graceTenants} institución(es) en período de gracia.` })
    }
    alerts.value = newAlerts

    // 6. Actividad Reciente (Audit logs)
    const { data: logs } = await supabase
      .from('audit_log')
      .select('id, action, table_name, created_at, user_id')
      .order('created_at', { ascending: false })
      .limit(6)
    
    recentActivity.value = logs || []
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadOverview()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Alertas Destacadas -->
    <div v-if="alerts.length > 0" class="space-y-2">
      <div 
        v-for="alert in alerts" 
        :key="alert.id" 
        :class="[
          'p-3.5 rounded-xl border text-sm font-medium flex items-center gap-3 shadow-sm transition-all',
          alert.type === 'danger' ? 'bg-rose-950/40 border-rose-800/60 text-rose-300' : 
          alert.type === 'warning' ? 'bg-amber-950/40 border-amber-800/60 text-amber-300' : 
          'bg-sky-950/40 border-sky-800/60 text-sky-300'
        ]"
      >
        <AlertTriangle class="w-5 h-5 shrink-0" />
        <span>{{ alert.text }}</span>
      </div>
    </div>

    <!-- Indicadores Principales KPIs Grid -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Total Tenants -->
      <div class="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 shadow-lg relative overflow-hidden group hover:border-slate-700 transition-all">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Instituciones</span>
          <div class="p-2 bg-indigo-500/10 text-indigo-400 rounded-xl">
            <Building2 class="w-5 h-5" />
          </div>
        </div>
        <div class="mt-3 flex items-baseline gap-2">
          <span class="text-3xl font-extrabold text-white tracking-tight">{{ metrics.totalTenants }}</span>
          <span class="text-xs font-medium text-emerald-400">{{ metrics.activeTenants }} activas</span>
        </div>
        <div class="mt-3 text-xs text-slate-400 flex gap-2">
          <span class="text-sky-400">{{ metrics.trialTenants }} en prueba</span> • 
          <span class="text-rose-400">{{ metrics.suspendedTenants }} suspendidas</span>
        </div>
      </div>

      <!-- Total Usuarios -->
      <div class="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 shadow-lg relative overflow-hidden group hover:border-slate-700 transition-all">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Usuarios Totales</span>
          <div class="p-2 bg-emerald-500/10 text-emerald-400 rounded-xl">
            <Users class="w-5 h-5" />
          </div>
        </div>
        <div class="mt-3 flex items-baseline gap-2">
          <span class="text-3xl font-extrabold text-white tracking-tight">{{ metrics.totalUsers }}</span>
          <span class="text-xs text-slate-400">en plataforma</span>
        </div>
        <div class="mt-3 text-xs text-slate-400">
          <span class="text-indigo-300 font-medium">{{ metrics.totalTeachers }}</span> docentes activos
        </div>
      </div>

      <!-- Total Estudiantes -->
      <div class="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 shadow-lg relative overflow-hidden group hover:border-slate-700 transition-all">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Estudiantes</span>
          <div class="p-2 bg-sky-500/10 text-sky-400 rounded-xl">
            <GraduationCap class="w-5 h-5" />
          </div>
        </div>
        <div class="mt-3 flex items-baseline gap-2">
          <span class="text-3xl font-extrabold text-white tracking-tight">{{ metrics.totalStudents }}</span>
          <span class="text-xs text-slate-400">matriculados</span>
        </div>
        <div class="mt-3 text-xs text-slate-400">
          Matrícula centralizada
        </div>
      </div>

      <!-- MRR / Facturación -->
      <div class="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 shadow-lg relative overflow-hidden group hover:border-slate-700 transition-all">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Ingreso Mensual (MRR)</span>
          <div class="p-2 bg-teal-500/10 text-teal-400 rounded-xl">
            <DollarSign class="w-5 h-5" />
          </div>
        </div>
        <div class="mt-3 flex items-baseline gap-2">
          <span class="text-3xl font-extrabold text-emerald-400 tracking-tight">${{ metrics.mrr.toFixed(2) }}</span>
          <span class="text-xs text-slate-400">/ mes</span>
        </div>
        <div class="mt-3 text-xs text-slate-400">
          Ingreso Anual Estimado: <strong class="text-slate-200">${{ metrics.arr.toFixed(2) }} USD</strong>
        </div>
      </div>
    </div>

    <!-- Actividad Reciente & Métricas Secundarias -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Actividad Reciente del Sistema -->
      <div class="lg:col-span-2 bg-slate-900/80 border border-slate-800 rounded-2xl p-6 shadow-lg space-y-4">
        <div class="flex items-center justify-between border-b border-slate-800 pb-3">
          <div class="flex items-center gap-2">
            <Activity class="w-5 h-5 text-indigo-400" />
            <h3 class="font-bold text-white tracking-tight">Actividad Reciente del Sistema</h3>
          </div>
          <span class="text-xs text-slate-400">Auditoría en tiempo real</span>
        </div>

        <div v-if="recentActivity.length === 0" class="py-8 text-center text-slate-500 text-sm">
          Sin actividad registrada aún.
        </div>

        <div v-else class="space-y-3">
          <div 
            v-for="log in recentActivity" 
            :key="log.id" 
            class="flex items-center justify-between p-3 rounded-xl bg-slate-800/40 border border-slate-800/80 hover:bg-slate-800/70 transition-colors text-sm"
          >
            <div class="flex items-center gap-3">
              <div class="w-2 h-2 rounded-full bg-indigo-500"></div>
              <div>
                <span class="font-semibold text-slate-200">{{ log.action }}</span>
                <span class="text-slate-400 text-xs ml-2">en <code class="text-indigo-300 font-mono">{{ log.table_name }}</code></span>
              </div>
            </div>
            <span class="text-xs text-slate-400">{{ new Date(log.created_at).toLocaleString() }}</span>
          </div>
        </div>
      </div>

      <!-- Estado de Infraestructura & Seguridad -->
      <div class="bg-slate-900/80 border border-slate-800 rounded-2xl p-6 shadow-lg space-y-4">
        <div class="flex items-center gap-2 border-b border-slate-800 pb-3">
          <ShieldCheck class="w-5 h-5 text-emerald-400" />
          <h3 class="font-bold text-white tracking-tight">Estado de Seguridad</h3>
        </div>

        <div class="space-y-3 text-sm text-slate-300">
          <div class="flex items-center justify-between p-3 rounded-xl bg-slate-800/40 border border-slate-800/80">
            <span>Aislamiento RLS Multi-tenant</span>
            <span class="px-2 py-0.5 rounded text-xs font-semibold bg-emerald-500/10 text-emerald-400">ACTIVO</span>
          </div>

          <div class="flex items-center justify-between p-3 rounded-xl bg-slate-800/40 border border-slate-800/80">
            <span>Impersonación Server-side</span>
            <span class="px-2 py-0.5 rounded text-xs font-semibold bg-emerald-500/10 text-emerald-400">REGISTRADA</span>
          </div>

          <div class="flex items-center justify-between p-3 rounded-xl bg-slate-800/40 border border-slate-800/80">
            <span>Control de Límites & Storage</span>
            <span class="px-2 py-0.5 rounded text-xs font-semibold bg-emerald-500/10 text-emerald-400">MONITOREADO</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
