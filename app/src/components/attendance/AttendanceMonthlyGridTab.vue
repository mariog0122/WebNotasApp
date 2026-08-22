<script setup>
import { computed } from 'vue'
import { 
  Calendar, 
  Download, 
  Printer, 
  School, 
  AlertTriangle, 
  CheckCircle, 
  Loader2 
} from 'lucide-vue-next'
import { ATTENDANCE_STATUSES } from '../../lib/attendanceConstants'
import { toast } from 'vue-sonner'

const props = defineProps({
  courses: { type: Array, default: () => [] },
  gridCourseId: { type: String, required: true },
  gridMonth: { type: String, required: true },
  gridDays: { type: Array, default: () => [] },
  gridMatrix: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  onCourseChange: { type: Function, required: true },
  onMonthChange: { type: Function, required: true }
})

const currentCourseName = computed(() => {
  const c = props.courses.find(item => item.id === props.gridCourseId)
  return c?.name || 'Curso'
})

const overallCoursePercentage = computed(() => {
  if (props.gridMatrix.length === 0) return 100
  const sum = props.gridMatrix.reduce((acc, row) => acc + (row.stats?.percentage || 100), 0)
  return Math.round((sum / props.gridMatrix.length) * 10) / 10
})

const atRiskCount = computed(() => {
  return props.gridMatrix.filter(row => row.stats?.isAtRisk).length
})

const handlePrint = () => {
  window.print()
}

const handleExportCsv = () => {
  if (props.gridMatrix.length === 0) {
    toast.error('No hay datos para exportar')
    return
  }

  const headers = ['Estudiante', 'Cédula', ...props.gridDays.map(d => `${d.dayNumber}-${d.dayName}`), 'Presentes', 'Atrasos', 'Injustificadas', 'Justificadas', 'Fugas', '% Asistencia']
  
  const rows = props.gridMatrix.map(row => {
    const student = row.student
    const dayCols = props.gridDays.map(d => {
      const st = row.daysMap[d.date]
      return st ? (ATTENDANCE_STATUSES[st]?.code || '-') : '-'
    })
    return [
      `"${student.full_name}"`,
      `"${student.student_cedula || ''}"`,
      ...dayCols,
      row.stats.presentCount,
      row.stats.lateCount,
      row.stats.unexcusedCount,
      row.stats.excusedCount,
      row.stats.truantCount,
      `${row.stats.percentage}%`
    ]
  })

  const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n')
  const encodedUri = encodeURI(csvContent)
  const link = document.createElement('a')
  link.setAttribute('href', encodedUri)
  link.setAttribute('download', `Sabana_Asistencia_${currentCourseName.value}_${props.gridMonth}.csv`.replace(/\s+/g, '_'))
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  toast.success('Archivo CSV descargado')
}
</script>

<template>
  <div class="space-y-4">
    
    <!-- Header de Control de Sábana Mensual -->
    <div class="p-4 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm flex flex-wrap items-center justify-between gap-4 no-print">
      <div class="flex flex-wrap items-center gap-3 flex-1">
        <!-- Curso -->
        <div class="w-full sm:w-60">
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-1 flex items-center gap-1">
            <School class="w-3.5 h-3.5 text-teal-600" />
            Curso:
          </label>
          <select
            :value="gridCourseId"
            @change="onCourseChange($event.target.value)"
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs font-semibold text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
          >
            <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>

        <!-- Mes -->
        <div class="w-full sm:w-48">
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-1 flex items-center gap-1">
            <Calendar class="w-3.5 h-3.5 text-teal-600" />
            Mes:
          </label>
          <input
            type="month"
            :value="gridMonth"
            @input="onMonthChange($event.target.value)"
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs font-semibold text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
          />
        </div>
      </div>

      <!-- Export & Print Actions -->
      <div class="flex items-center gap-2">
        <button
          type="button"
          @click="handleExportCsv"
          class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-xs font-bold text-slate-700 dark:text-slate-300 transition-colors cursor-pointer"
        >
          <Download class="w-3.5 h-3.5" />
          Exportar CSV
        </button>

        <button
          type="button"
          @click="handlePrint"
          class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-teal-600 hover:bg-teal-700 text-white text-xs font-bold shadow-sm transition-colors cursor-pointer"
        >
          <Printer class="w-3.5 h-3.5" />
          Imprimir Sábana
        </button>
      </div>
    </div>

    <!-- Metrics Cards -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 no-print">
      <div class="p-3 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 flex items-center justify-between">
        <span class="text-xs font-semibold text-slate-500">Días Laborables Registrados</span>
        <span class="text-base font-extrabold text-slate-900 dark:text-white">{{ gridDays.length }} días</span>
      </div>
      <div class="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-between">
        <span class="text-xs font-bold text-emerald-700 dark:text-emerald-300">Promedio de Asistencia Grupal</span>
        <span class="text-base font-extrabold text-emerald-700 dark:text-emerald-300">{{ overallCoursePercentage }}%</span>
      </div>
      <div class="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-between">
        <span class="text-xs font-bold text-rose-700 dark:text-rose-300">Estudiantes en Riesgo (&lt;85%)</span>
        <span class="text-base font-extrabold text-rose-700 dark:text-rose-300">{{ atRiskCount }}</span>
      </div>
    </div>

    <!-- Sábana Matriz Table -->
    <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 shadow-sm overflow-hidden relative">
      <div v-if="loading" class="absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/60 z-10 backdrop-blur-sm">
        <Loader2 class="w-8 h-8 text-teal-500 animate-spin" />
      </div>

      <div class="overflow-x-auto custom-scrollbar">
        <table class="w-full text-left border-collapse text-[11px]">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-800 bg-slate-100/80 dark:bg-slate-950/80 text-slate-600 dark:text-slate-400 font-bold uppercase">
              <th class="p-2.5 pl-4 sticky left-0 bg-slate-100 dark:bg-slate-950 z-10 min-w-[200px]">
                Estudiante
              </th>
              
              <!-- Días del Mes -->
              <th
                v-for="d in gridDays"
                :key="d.date"
                class="p-1.5 text-center min-w-[32px] border-l border-slate-200 dark:border-slate-800 font-mono"
              >
                <span class="block text-[9px] text-slate-400 font-normal">{{ d.dayName }}</span>
                <span>{{ d.dayNumber }}</span>
              </th>

              <!-- Totales -->
              <th class="p-2 text-center min-w-[35px] bg-emerald-500/10 text-emerald-700 dark:text-emerald-300">P</th>
              <th class="p-2 text-center min-w-[35px] bg-amber-500/10 text-amber-700 dark:text-amber-300">A</th>
              <th class="p-2 text-center min-w-[35px] bg-rose-500/10 text-rose-700 dark:text-rose-300">FI</th>
              <th class="p-2 text-center min-w-[35px] bg-sky-500/10 text-sky-700 dark:text-sky-300">FJ</th>
              <th class="p-2 text-center min-w-[35px] bg-purple-500/10 text-purple-700 dark:text-purple-300">F</th>
              <th class="p-2.5 pr-4 text-center min-w-[80px] bg-slate-200/60 dark:bg-slate-800/60 font-bold">
                % Asist.
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60">
            <tr
              v-for="row in gridMatrix"
              :key="row.student.id"
              class="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors"
            >
              <!-- Nombre Estudiante (Sticky) -->
              <td class="p-2.5 pl-4 sticky left-0 bg-white dark:bg-slate-900 font-medium text-slate-900 dark:text-white z-10">
                <span class="block truncate max-w-[220px]" :title="row.student.full_name">
                  {{ row.student.full_name }}
                </span>
              </td>

              <!-- Celdas por Día -->
              <td
                v-for="d in gridDays"
                :key="d.date"
                :class="[
                  'p-1 text-center font-mono font-bold border-l border-slate-100 dark:border-slate-800/60',
                  row.daysMap[d.date] ? ATTENDANCE_STATUSES[row.daysMap[d.date]]?.tableBg : 'text-slate-300 dark:text-slate-700'
                ]"
              >
                {{ row.daysMap[d.date] ? ATTENDANCE_STATUSES[row.daysMap[d.date]]?.code : '·' }}
              </td>

              <!-- Totales -->
              <td class="p-2 text-center font-bold text-emerald-700 dark:text-emerald-300 bg-emerald-500/5">
                {{ row.stats.presentCount }}
              </td>
              <td class="p-2 text-center font-bold text-amber-700 dark:text-amber-300 bg-amber-500/5">
                {{ row.stats.lateCount }}
              </td>
              <td class="p-2 text-center font-bold text-rose-700 dark:text-rose-300 bg-rose-500/5">
                {{ row.stats.unexcusedCount }}
              </td>
              <td class="p-2 text-center font-bold text-sky-700 dark:text-sky-300 bg-sky-500/5">
                {{ row.stats.excusedCount }}
              </td>
              <td class="p-2 text-center font-bold text-purple-700 dark:text-purple-300 bg-purple-500/5">
                {{ row.stats.truantCount }}
              </td>

              <!-- Porcentaje de Asistencia con Semáforo -->
              <td class="p-2.5 pr-4 text-center font-extrabold font-mono">
                <span :class="[
                  'inline-block px-2 py-0.5 rounded text-[10px]',
                  row.stats.isAtRisk
                    ? 'bg-rose-500 text-white font-bold animate-pulse'
                    : (row.stats.percentage >= 90 ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300' : 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300')
                ]">
                  {{ row.stats.percentage }}%
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

    </div>

  </div>
</template>
