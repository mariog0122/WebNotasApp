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
  <div class="space-y-4 w-full min-w-0">
    
    <!-- Filtros de Alertas -->
    <div class="p-4 sm:p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3 min-w-0">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 flex-1 min-w-0">
        <!-- Buscador -->
        <div class="relative min-w-0">
          <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            v-model="searchFilter"
            type="text"
            placeholder="Buscar por estudiante, curso u observación..."
            class="w-full pl-9 pr-4 py-2.5 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none min-w-0 placeholder-slate-400"
            aria-label="Buscar alertas"
          />
        </div>

        <!-- Tipo de Incidencia -->
        <div class="min-w-0">
          <select
            v-model="filterStatus"
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2.5 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none min-w-0 truncate"
            aria-label="Filtrar por tipo de incidencia"
          >
            <option value="">Todas las Incidencias</option>
            <option value="falta_injustificada">Faltas Injustificadas</option>
            <option value="atraso">Atrasos</option>
            <option value="fuga">Fugas / Evasión</option>
          </select>
        </div>
      </div>

      <span class="text-xs font-bold text-slate-500 dark:text-slate-400 shrink-0 self-end sm:self-center">
        {{ filteredAlerts.length }} Registros recientes
      </span>
    </div>

    <!-- Lista de Alertas -->
    <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 shadow-sm overflow-hidden relative min-w-0">
      <div v-if="loading" class="absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/60 z-20 backdrop-blur-sm">
        <Loader2 class="w-8 h-8 text-teal-500 animate-spin" />
      </div>

      <!-- VISTA DESKTOP (>= 768px) -->
      <div class="hidden md:block overflow-x-auto custom-scrollbar">
        <table class="w-full text-left border-collapse text-xs min-w-[700px]">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-800 bg-slate-100/70 dark:bg-slate-950/70 text-[11px] font-bold text-slate-600 dark:text-slate-400 uppercase">
              <th class="p-3.5 pl-5 min-w-[200px]">Estudiante & Curso</th>
              <th class="p-3.5 min-w-[140px]">Fecha & Incidencia</th>
              <th class="p-3.5 min-w-[180px]">Detalle / Observación</th>
              <th class="p-3.5 min-w-[150px]">Representante</th>
              <th class="p-3.5 pr-5 text-right w-44">Acciones Rápidas</th>
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
                <strong class="text-slate-900 dark:text-white font-bold block truncate">
                  {{ al.students?.full_name || 'N/A' }}
                </strong>
                <span class="text-[11px] text-slate-500 dark:text-slate-400 font-mono">
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
                <span class="font-medium text-slate-900 dark:text-white block truncate">{{ al.students?.representative_name || 'No registrado' }}</span>
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
                    class="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-[11px] font-bold shadow-sm transition-colors cursor-pointer min-h-[32px]"
                  >
                    <Share2 class="w-3.5 h-3.5" />
                    WhatsApp
                  </button>

                  <!-- Citación Formal -->
                  <button
                    type="button"
                    @click="createCitationInReports(al)"
                    title="Generar citación oficial en Informes Docentes"
                    class="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-slate-100 dark:bg-slate-800 hover:bg-teal-50 dark:hover:bg-teal-900/30 text-teal-700 dark:text-teal-300 text-[11px] font-bold border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer min-h-[32px]"
                  >
                    <FileText class="w-3.5 h-3.5" />
                    Citar
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- VISTA MÓVIL (< 768px) — TARJETAS DE ALERTA -->
      <div class="md:hidden p-3 space-y-3">
        <div
          v-for="al in filteredAlerts"
          :key="al.id"
          class="p-3.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 space-y-2.5 shadow-sm"
        >
          <!-- Header: Estudiante + Badge -->
          <div class="flex items-start justify-between gap-2">
            <div class="min-w-0">
              <strong class="text-xs font-bold text-slate-900 dark:text-white block truncate">
                {{ al.students?.full_name || 'N/A' }}
              </strong>
              <span class="text-[10px] text-slate-500 font-mono">
                {{ al.courses?.name }} • C.I. {{ al.students?.student_cedula }}
              </span>
            </div>
            <span :class="[
              'inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold border shrink-0',
              ATTENDANCE_STATUSES[al.status]?.badgeClass
            ]">
              {{ ATTENDANCE_STATUSES[al.status]?.label }}
            </span>
          </div>

          <!-- Fecha y Detalle -->
          <div class="p-2.5 rounded-lg bg-slate-50 dark:bg-slate-950 text-xs space-y-1">
            <div class="flex items-center justify-between text-[11px] text-slate-500 font-mono">
              <span>📅 {{ al.attendance_date }}</span>
              <span>Rep: {{ al.students?.representative_name || 'N/A' }}</span>
            </div>
            <p v-if="al.observations" class="text-slate-700 dark:text-slate-300 text-[11px] italic">
              "{{ al.observations }}"
            </p>
          </div>

          <!-- Botones de Acción Móviles -->
          <div class="grid grid-cols-2 gap-2 pt-1">
            <button
              type="button"
              @click="onSendWhatsapp(al.students, al.status, al.attendance_date, al.observations)"
              class="w-full inline-flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-sm transition-colors cursor-pointer min-h-[38px]"
            >
              <Share2 class="w-3.5 h-3.5" />
              <span>WhatsApp</span>
            </button>

            <button
              type="button"
              @click="createCitationInReports(al)"
              class="w-full inline-flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-teal-50 dark:hover:bg-teal-900/30 text-teal-700 dark:text-teal-300 text-xs font-bold border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer min-h-[38px]"
            >
              <FileText class="w-3.5 h-3.5" />
              <span>Citar</span>
            </button>
          </div>
        </div>
      </div>

      <div v-if="!loading && filteredAlerts.length === 0" class="p-12 text-center text-xs text-slate-500">
        No se registran alertas de inasistencias en este periodo.
      </div>
    </div>

  </div>
</template>
