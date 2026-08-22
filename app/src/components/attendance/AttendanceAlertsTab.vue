<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { 
  ShieldAlert, 
  Share2, 
  Search, 
  AlertTriangle, 
  Clock, 
  FileText, 
  User, 
  Calendar, 
  Loader2 
} from 'lucide-vue-next'
import { ATTENDANCE_STATUSES } from '../../lib/attendanceConstants'

const props = defineProps({
  alerts: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  onSendWhatsapp: { type: Function, required: true }
})

const router = useRouter()
const filterStatus = ref('')
const searchFilter = ref('')

const filteredAlerts = computed(() => {
  let list = props.alerts
  if (filterStatus.value) {
    list = list.filter(a => a.status === filterStatus.value)
  }
  const term = searchFilter.value.trim().toLowerCase()
  if (term) {
    list = list.filter(a => 
      a.students?.full_name?.toLowerCase().includes(term) ||
      a.courses?.name?.toLowerCase().includes(term) ||
      a.observations?.toLowerCase().includes(term)
    )
  }
  return list
})

const createCitationInReports = (alertItem) => {
  router.push({
    path: '/teacher-reports',
    query: {
      action: 'new_citation',
      course_id: alertItem.course_id,
      student_id: alertItem.student_id
    }
  })
}
</script>

<template>
  <div class="space-y-4">
    
    <!-- Filtros de Alertas -->
    <div class="p-4 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm flex flex-wrap items-center justify-between gap-3">
      <div class="flex flex-wrap items-center gap-3 flex-1">
        <!-- Buscador -->
        <div class="relative flex-1 min-w-[220px]">
          <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            v-model="searchFilter"
            type="text"
            placeholder="Buscar por estudiante, curso u observación..."
            class="w-full pl-9 pr-4 py-2 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
          />
        </div>

        <!-- Tipo de Incidencia -->
        <select
          v-model="filterStatus"
          class="bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
        >
          <option value="">Todas las Incidencias</option>
          <option value="falta_injustificada">Faltas Injustificadas</option>
          <option value="atraso">Atrasos</option>
          <option value="fuga">Fugas / Evasión</option>
        </select>
      </div>

      <span class="text-xs font-bold text-slate-500 dark:text-slate-400">
        {{ filteredAlerts.length }} Registros recientes
      </span>
    </div>

    <!-- Lista de Alertas -->
    <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 shadow-sm overflow-hidden relative">
      <div v-if="loading" class="absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/60 z-10 backdrop-blur-sm">
        <Loader2 class="w-8 h-8 text-teal-500 animate-spin" />
      </div>

      <div class="overflow-x-auto custom-scrollbar">
        <table class="w-full text-left border-collapse text-xs">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-800 bg-slate-100/70 dark:bg-slate-950/70 text-[11px] font-bold text-slate-600 dark:text-slate-400 uppercase">
              <th class="p-3.5 pl-5">Estudiante & Curso</th>
              <th class="p-3.5">Fecha & Incidencia</th>
              <th class="p-3.5">Detalle / Observación</th>
              <th class="p-3.5">Representante</th>
              <th class="p-3.5 pr-5 text-right">Acciones Rápidas</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60">
            <tr
              v-for="al in filteredAlerts"
              :key="al.id"
              class="hover:bg-slate-50 dark:hover:bg-slate-800/30 transition-colors"
            >
              <!-- Estudiante -->
              <td class="p-3.5 pl-5">
                <strong class="text-slate-900 dark:text-white font-bold block">
                  {{ al.students?.full_name || 'N/A' }}
                </strong>
                <span class="text-[11px] text-slate-500 dark:text-slate-400">
                  {{ al.courses?.name }} • C.I. {{ al.students?.student_cedula }}
                </span>
              </td>

              <!-- Fecha e Incidencia -->
              <td class="p-3.5">
                <span :class="[
                  'inline-flex items-center px-2 py-0.5 rounded-md text-[11px] font-bold border mb-1',
                  ATTENDANCE_STATUSES[al.status]?.badgeClass
                ]">
                  {{ ATTENDANCE_STATUSES[al.status]?.label }}
                </span>
                <p class="text-[11px] text-slate-500 font-mono">📅 {{ al.attendance_date }}</p>
              </td>

              <!-- Detalle -->
              <td class="p-3.5 text-slate-600 dark:text-slate-300 max-w-xs truncate">
                {{ al.observations || 'Sin observación adicional registrada.' }}
              </td>

              <!-- Representante -->
              <td class="p-3.5">
                <span class="font-medium text-slate-900 dark:text-white block">{{ al.students?.representative_name || 'No registrado' }}</span>
                <span class="text-[11px] text-slate-500 font-mono">{{ al.students?.representative_phone || 'Sin teléfono' }}</span>
              </td>

              <!-- Acciones Rápidas -->
              <td class="p-3.5 pr-5 text-right">
                <div class="inline-flex items-center gap-2 justify-end">
                  <!-- WhatsApp Directo -->
                  <button
                    type="button"
                    @click="onSendWhatsapp(al.students, al.status, al.attendance_date, al.observations)"
                    title="Notificar por WhatsApp"
                    class="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-[11px] font-bold shadow-sm transition-colors cursor-pointer"
                  >
                    <Share2 class="w-3.5 h-3.5" />
                    WhatsApp
                  </button>

                  <!-- Citación Formal -->
                  <button
                    type="button"
                    @click="createCitationInReports(al)"
                    title="Generar citación oficial en Informes Docentes"
                    class="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-slate-100 dark:bg-slate-800 hover:bg-teal-50 dark:hover:bg-teal-900/30 text-teal-700 dark:text-teal-300 text-[11px] font-bold border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer"
                  >
                    <FileText class="w-3.5 h-3.5" />
                    Citar
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <div v-if="!loading && filteredAlerts.length === 0" class="p-12 text-center text-xs text-slate-500">
          No se registran alertas de inasistencias en este periodo.
        </div>
      </div>
    </div>

  </div>
</template>
