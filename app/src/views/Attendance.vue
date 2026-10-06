<script setup>
import { 
  CheckCircle2, 
  CalendarCheck, 
  ShieldCheck, 
  Calendar, 
  ShieldAlert, 
  UserCheck 
} from 'lucide-vue-next'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'
import AttendanceRollCallTab from '../components/attendance/AttendanceRollCallTab.vue'
import AttendanceJustificationsTab from '../components/attendance/AttendanceJustificationsTab.vue'
import AttendanceMonthlyGridTab from '../components/attendance/AttendanceMonthlyGridTab.vue'
import AttendanceAlertsTab from '../components/attendance/AttendanceAlertsTab.vue'
import { useAttendance } from '../composables/useAttendance'

const {
  activeTab,
  loading,
  saving,
  courses,
  availableSubjects,
  selectedCourse,
  selectedSubject,
  selectedDate,
  selectedHourBlock,
  students,
  rollCallState,
  rollCallStats,
  selectedJustificationStudent,
  studentUnexcusedAbsences,
  selectedDatesToJustify,
  justificationReason,
  justifyingLoading,
  gridMonth,
  gridCourseId,
  gridDays,
  gridMatrix,
  gridLoading,
  atRiskStudents,
  alertsLoading,
  markAllPresent,
  setStudentStatus,
  setStudentObservation,
  saveAttendanceRollCall,
  searchStudentAbsences,
  submitJustification,
  sendWhatsAppNotification
} = useAttendance()
</script>

<template>
  <div class="w-full max-w-[1600px] mx-auto min-w-0 flex flex-col space-y-6">
    
    <!-- Academic Year Banner -->
    <AcademicYearBanner module-name="Asistencia" class="no-print" />

    <!-- Header Principal -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 no-print">
      <div class="flex items-start sm:items-center gap-3.5 min-w-0">
        <div class="p-2.5 sm:p-3 rounded-2xl bg-teal-500/10 text-teal-600 dark:text-teal-400 border border-teal-500/20 shadow-sm shrink-0">
          <CalendarCheck class="w-6 h-6 sm:w-7 sm:h-7" />
        </div>
        <div class="min-w-0">
          <h1 class="text-xl sm:text-2xl lg:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight leading-tight">
            Control de Asistencia
          </h1>
          <p class="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
            Toma rápida para docentes, sábana mensual y gestión de justificaciones para Inspección General
          </p>
        </div>
      </div>
    </div>

    <!-- Navigation Tabs (Ultra-Responsive) -->
    <div class="no-print w-full min-w-0">
      <!-- Desktop & Tablet Grid (>= 640px) -->
      <div class="hidden sm:grid sm:grid-cols-2 lg:grid-cols-4 gap-2 p-1.5 rounded-2xl bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-800">
        <!-- Tab 1: Toma de Asistencia -->
        <button
          type="button"
          @click="activeTab = 'roll_call'"
          :class="[
            'px-3.5 py-2.5 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2 cursor-pointer text-center min-h-[42px]',
            activeTab === 'roll_call'
              ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm ring-1 ring-slate-200 dark:ring-slate-700'
              : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-white/50 dark:hover:bg-slate-800/50'
          ]"
        >
          <UserCheck class="w-4 h-4 shrink-0" />
          <span class="truncate">1. Toma de Asistencia</span>
        </button>

        <!-- Tab 2: Justificaciones -->
        <button
          type="button"
          @click="activeTab = 'justifications'"
          :class="[
            'px-3.5 py-2.5 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2 cursor-pointer text-center min-h-[42px]',
            activeTab === 'justifications'
              ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm ring-1 ring-slate-200 dark:ring-slate-700'
              : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-white/50 dark:hover:bg-slate-800/50'
          ]"
        >
          <ShieldCheck class="w-4 h-4 shrink-0" />
          <span class="truncate">2. Justificaciones</span>
        </button>

        <!-- Tab 3: Sábana Mensual -->
        <button
          type="button"
          @click="activeTab = 'monthly_grid'"
          :class="[
            'px-3.5 py-2.5 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2 cursor-pointer text-center min-h-[42px]',
            activeTab === 'monthly_grid'
              ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm ring-1 ring-slate-200 dark:ring-slate-700'
              : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-white/50 dark:hover:bg-slate-800/50'
          ]"
        >
          <Calendar class="w-4 h-4 shrink-0" />
          <span class="truncate">3. Sábana Mensual</span>
        </button>

        <!-- Tab 4: Alertas -->
        <button
          type="button"
          @click="activeTab = 'alerts'"
          :class="[
            'px-3.5 py-2.5 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2 cursor-pointer text-center min-h-[42px]',
            activeTab === 'alerts'
              ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm ring-1 ring-slate-200 dark:ring-slate-700'
              : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-white/50 dark:hover:bg-slate-800/50'
          ]"
        >
          <ShieldAlert class="w-4 h-4 shrink-0" />
          <span class="truncate">4. Alertas de Inasistencia</span>
        </button>
      </div>

      <!-- Mobile Horizontal Scroll Tabs (< 640px) -->
      <div class="sm:hidden overflow-x-auto custom-scrollbar-tabs pb-1">
        <div class="inline-flex items-center gap-1.5 p-1 rounded-2xl bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-800 min-w-full">
          <button
            type="button"
            @click="activeTab = 'roll_call'"
            :class="[
              'px-3 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer min-h-[40px]',
              activeTab === 'roll_call'
                ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm'
                : 'text-slate-600 dark:text-slate-400'
            ]"
          >
            <UserCheck class="w-3.5 h-3.5 shrink-0" />
            1. Toma Rápida
          </button>
          <button
            type="button"
            @click="activeTab = 'justifications'"
            :class="[
              'px-3 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer min-h-[40px]',
              activeTab === 'justifications'
                ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm'
                : 'text-slate-600 dark:text-slate-400'
            ]"
          >
            <ShieldCheck class="w-3.5 h-3.5 shrink-0" />
            2. Justificaciones
          </button>
          <button
            type="button"
            @click="activeTab = 'monthly_grid'"
            :class="[
              'px-3 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer min-h-[40px]',
              activeTab === 'monthly_grid'
                ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm'
                : 'text-slate-600 dark:text-slate-400'
            ]"
          >
            <Calendar class="w-3.5 h-3.5 shrink-0" />
            3. Sábana
          </button>
          <button
            type="button"
            @click="activeTab = 'alerts'"
            :class="[
              'px-3 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer min-h-[40px]',
              activeTab === 'alerts'
                ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm'
                : 'text-slate-600 dark:text-slate-400'
            ]"
          >
            <ShieldAlert class="w-3.5 h-3.5 shrink-0" />
            4. Alertas
          </button>
        </div>
      </div>
    </div>

    <!-- Active Tab Content -->
    <div class="flex-1 min-h-0">
      
      <!-- Tab 1 -->
      <AttendanceRollCallTab
        v-if="activeTab === 'roll_call'"
        :courses="courses"
        :available-subjects="availableSubjects"
        :selected-course="selectedCourse"
        :selected-subject="selectedSubject"
        :selected-date="selectedDate"
        :selected-hour-block="selectedHourBlock"
        :students="students"
        :roll-call-state="rollCallState"
        :roll-call-stats="rollCallStats"
        :loading="loading"
        :saving="saving"
        :on-course-change="(c) => { selectedCourse = c }"
        :on-subject-change="(s) => { selectedSubject = s }"
        :on-date-change="(d) => { selectedDate = d }"
        :on-hour-block-change="(h) => { selectedHourBlock = h }"
        :on-mark-all-present="markAllPresent"
        :on-set-status="setStudentStatus"
        :on-set-observation="setStudentObservation"
        :on-save="saveAttendanceRollCall"
        :on-send-whatsapp="sendWhatsAppNotification"
      />

      <!-- Tab 2 -->
      <AttendanceJustificationsTab
        v-else-if="activeTab === 'justifications'"
        :students="students"
        :selected-student="selectedJustificationStudent"
        :unexcused-absences="studentUnexcusedAbsences"
        :selected-dates="selectedDatesToJustify"
        :reason="justificationReason"
        :loading="justifyingLoading"
        :on-select-student="searchStudentAbsences"
        :on-submit-justification="submitJustification"
        @update:reason="(val) => { justificationReason = val }"
        @update:selected-dates="(val) => { selectedDatesToJustify = val }"
      />

      <!-- Tab 3 -->
      <AttendanceMonthlyGridTab
        v-else-if="activeTab === 'monthly_grid'"
        :courses="courses"
        :grid-course-id="gridCourseId"
        :grid-month="gridMonth"
        :grid-days="gridDays"
        :grid-matrix="gridMatrix"
        :loading="gridLoading"
        :on-course-change="(c) => { gridCourseId = c }"
        :on-month-change="(m) => { gridMonth = m }"
      />

      <!-- Tab 4 -->
      <AttendanceAlertsTab
        v-else-if="activeTab === 'alerts'"
        :alerts="atRiskStudents"
        :loading="alertsLoading"
        :on-send-whatsapp="sendWhatsAppNotification"
      />

    </div>

  </div>
</template>
