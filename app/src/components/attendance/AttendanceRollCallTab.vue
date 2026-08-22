<script setup>
import { 
  CheckCircle2, 
  Clock, 
  AlertCircle, 
  ShieldAlert, 
  HelpCircle, 
  Share2, 
  Save, 
  Check, 
  Loader2, 
  UserCheck, 
  Calendar, 
  BookOpen, 
  School, 
  MessageCircle 
} from 'lucide-vue-next'
import { ATTENDANCE_STATUSES, HOUR_BLOCKS } from '../../lib/attendanceConstants'

const props = defineProps({
  courses: { type: Array, default: () => [] },
  availableSubjects: { type: Array, default: () => [] },
  selectedCourse: { type: String, required: true },
  selectedSubject: { type: String, required: true },
  selectedDate: { type: String, required: true },
  selectedHourBlock: { type: String, required: true },
  students: { type: Array, default: () => [] },
  rollCallState: { type: Object, required: true },
  rollCallStats: { type: Object, required: true },
  loading: { type: Boolean, default: false },
  saving: { type: Boolean, default: false },
  onCourseChange: { type: Function, required: true },
  onSubjectChange: { type: Function, required: true },
  onDateChange: { type: Function, required: true },
  onHourBlockChange: { type: Function, required: true },
  onMarkAllPresent: { type: Function, required: true },
  onSetStatus: { type: Function, required: true },
  onSetObservation: { type: Function, required: true },
  onSave: { type: Function, required: true },
  onSendWhatsapp: { type: Function, required: true }
})
</script>

<template>
  <div class="space-y-4">
    
    <!-- Filtros y Selectores de Toma de Asistencia -->
    <div class="p-4 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm flex flex-wrap items-center justify-between gap-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 w-full lg:w-auto flex-1">
        <!-- Selector de Curso -->
        <div>
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-1 flex items-center gap-1">
            <School class="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
            Curso / Grado:
          </label>
          <select
            :value="selectedCourse"
            @change="onCourseChange($event.target.value)"
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs font-semibold text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
          >
            <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>

        <!-- Selector de Asignatura -->
        <div>
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-1 flex items-center gap-1">
            <BookOpen class="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
            Asignatura / Bloque:
          </label>
          <select
            :value="selectedSubject"
            @change="onSubjectChange($event.target.value)"
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs font-semibold text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
          >
            <option value="">Jornada General / Tutoría</option>
            <option v-for="s in availableSubjects" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>

        <!-- Selector de Fecha -->
        <div>
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-1 flex items-center gap-1">
            <Calendar class="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
            Fecha:
          </label>
          <input
            type="date"
            :value="selectedDate"
            @input="onDateChange($event.target.value)"
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs font-semibold text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
          />
        </div>

        <!-- Selector de Hora / Bloque -->
        <div>
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-1 flex items-center gap-1">
            <Clock class="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
            Hora Pedagógica:
          </label>
          <select
            :value="selectedHourBlock"
            @change="onHourBlockChange($event.target.value)"
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs font-semibold text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
          >
            <option v-for="b in HOUR_BLOCKS" :key="b.id" :value="b.id">{{ b.label }}</option>
          </select>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex items-center gap-2.5 w-full lg:w-auto justify-end pt-2 lg:pt-0 border-t lg:border-t-0 border-slate-100 dark:border-slate-800">
        <button
          type="button"
          @click="onMarkAllPresent"
          class="inline-flex items-center gap-1.5 px-3.5 py-2.5 rounded-xl border border-emerald-500/30 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 text-xs font-bold transition-all shadow-sm cursor-pointer"
        >
          <Check class="w-4 h-4" />
          Marcar Todos Presentes (1 Clic)
        </button>

        <button
          type="button"
          :disabled="saving || loading || students.length === 0"
          @click="onSave"
          class="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-gradient-to-r from-teal-600 to-teal-500 hover:from-teal-500 hover:to-teal-400 text-white text-xs font-bold shadow-lg shadow-teal-900/20 transition-all disabled:opacity-50 cursor-pointer"
        >
          <Save class="w-4 h-4" />
          {{ saving ? 'Guardando...' : 'Guardar Asistencia' }}
        </button>
      </div>
    </div>

    <!-- Live Counters Banner -->
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2.5">
      <!-- Total -->
      <div class="p-3 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 flex items-center justify-between">
        <span class="text-xs font-semibold text-slate-500">Total Alumnos</span>
        <span class="text-base font-extrabold text-slate-900 dark:text-white">{{ rollCallStats.total }}</span>
      </div>
      <!-- Presentes -->
      <div class="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-between">
        <span class="text-xs font-bold text-emerald-700 dark:text-emerald-300">Presentes (P)</span>
        <span class="text-base font-extrabold text-emerald-700 dark:text-emerald-300">{{ rollCallStats.present }}</span>
      </div>
      <!-- Atrasos -->
      <div class="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-between">
        <span class="text-xs font-bold text-amber-700 dark:text-amber-300">Atrasos (A)</span>
        <span class="text-base font-extrabold text-amber-700 dark:text-amber-300">{{ rollCallStats.late }}</span>
      </div>
      <!-- Faltas Injustificadas -->
      <div class="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-between">
        <span class="text-xs font-bold text-rose-700 dark:text-rose-300">Injustificadas (FI)</span>
        <span class="text-base font-extrabold text-rose-700 dark:text-rose-300">{{ rollCallStats.unexcused }}</span>
      </div>
      <!-- Faltas Justificadas -->
      <div class="p-3 rounded-xl bg-sky-500/10 border border-sky-500/20 flex items-center justify-between">
        <span class="text-xs font-bold text-sky-700 dark:text-sky-300">Justificadas (FJ)</span>
        <span class="text-base font-extrabold text-sky-700 dark:text-sky-300">{{ rollCallStats.excused }}</span>
      </div>
      <!-- Fugas -->
      <div class="p-3 rounded-xl bg-purple-500/10 border border-purple-500/20 flex items-center justify-between">
        <span class="text-xs font-bold text-purple-700 dark:text-purple-300">Fugas (F)</span>
        <span class="text-base font-extrabold text-purple-700 dark:text-purple-300">{{ rollCallStats.truant }}</span>
      </div>
    </div>

    <!-- Student List Roll-Call Table -->
    <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 shadow-sm overflow-hidden relative">
      <div v-if="loading" class="absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/60 z-10 backdrop-blur-sm">
        <Loader2 class="w-8 h-8 text-teal-500 animate-spin" />
      </div>

      <div class="overflow-x-auto custom-scrollbar">
        <table class="w-full text-left border-collapse">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-800 bg-slate-100/70 dark:bg-slate-950/70 text-[11px] font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
              <th class="p-3.5 pl-5 w-12 text-center">#</th>
              <th class="p-3.5">Estudiante</th>
              <th class="p-3.5 text-center">Estado de Asistencia</th>
              <th class="p-3.5">Observación Rápida</th>
              <th class="p-3.5 pr-5 text-right">Notificar</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60 text-xs">
            <tr
              v-for="(st, idx) in students"
              :key="st.id"
              class="hover:bg-slate-50 dark:hover:bg-slate-800/30 transition-colors"
            >
              <!-- Index -->
              <td class="p-3.5 pl-5 text-center font-mono text-slate-400 font-semibold">
                {{ idx + 1 }}
              </td>

              <!-- Estudiante -->
              <td class="p-3.5">
                <strong class="text-slate-900 dark:text-white font-bold block">
                  {{ st.full_name }}
                </strong>
                <span class="text-[11px] text-slate-500 dark:text-slate-400">
                  C.I. {{ st.student_cedula || 'No registrada' }}
                </span>
              </td>

              <!-- Estado Chips (P, A, FI, FJ, F) -->
              <td class="p-3.5 text-center">
                <div class="inline-flex items-center p-1 rounded-xl bg-slate-100 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 gap-1">
                  <button
                    v-for="statusObj in ATTENDANCE_STATUSES"
                    :key="statusObj.id"
                    type="button"
                    @click="onSetStatus(st.id, statusObj.id)"
                    :title="statusObj.label"
                    :class="[
                      'w-8 h-8 rounded-lg text-xs font-black transition-all flex items-center justify-center cursor-pointer',
                      rollCallState[st.id]?.status === statusObj.id
                        ? statusObj.buttonActive
                        : statusObj.buttonInactive
                    ]"
                  >
                    {{ statusObj.code }}
                  </button>
                </div>
              </td>

              <!-- Observación Rápida -->
              <td class="p-3.5">
                <input
                  :value="rollCallState[st.id]?.observations || ''"
                  @input="onSetObservation(st.id, $event.target.value)"
                  type="text"
                  placeholder="Ej. Llegó 15 min tarde..."
                  class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg px-2.5 py-1.5 text-xs text-slate-900 dark:text-white focus:ring-1 focus:ring-teal-500 focus:outline-none placeholder-slate-400"
                />
              </td>

              <!-- Notificación por WhatsApp -->
              <td class="p-3.5 pr-5 text-right">
                <button
                  v-if="['atraso', 'falta_injustificada', 'fuga'].includes(rollCallState[st.id]?.status)"
                  type="button"
                  @click="onSendWhatsapp(st, rollCallState[st.id]?.status, selectedDate, rollCallState[st.id]?.observations)"
                  title="Enviar notificación por WhatsApp al Representante"
                  class="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-[11px] font-bold shadow-sm transition-colors cursor-pointer"
                >
                  <Share2 class="w-3.5 h-3.5" />
                  Avisar
                </button>
                <span v-else class="text-slate-300 dark:text-slate-700 text-[11px] font-mono">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Empty State -->
      <div v-if="!loading && students.length === 0" class="p-12 text-center space-y-3">
        <UserCheck class="w-12 h-12 text-slate-300 dark:text-slate-700 mx-auto" />
        <p class="text-sm font-bold text-slate-700 dark:text-slate-300">No hay estudiantes matriculados en este curso</p>
      </div>

    </div>

  </div>
</template>
