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
  <div class="h-full flex flex-col space-y-6">
    
    <!-- Academic Year Banner -->
    <AcademicYearBanner module-name="Asistencia" class="no-print" />

    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 no-print">
      <div class="flex items-center gap-3">
        <div class="p-2.5 rounded-xl bg-teal-500/10 text-teal-600 dark:text-teal-400 border border-teal-500/20">
          <CalendarCheck class="w-6 h-6" />
        </div>
        <div>
          <h1 class="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">Control de Asistencia</h1>
          <p class="text-sm text-slate-500 dark:text-slate-400">
            Toma rápida para docentes, sábana mensual y gestión de justificaciones para Inspección General
          </p>
        </div>
      </div>
    </div>

    <!-- Navigation Tabs -->
    <div class="flex items-center gap-2 p-1.5 rounded-2xl bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shrink-0 overflow-x-auto custom-scrollbar no-print">
      
      <!-- Tab 1: Toma de Asistencia -->
      <button
        type="button"
        @click="activeTab = 'roll_call'"
        :class="[
          'px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 shrink-0 cursor-pointer',
          activeTab === 'roll_call'
            ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm'
            : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
        ]"
      >
        <UserCheck class="w-4 h-4" />
        1. Toma Rápida de Asistencia
      </button>

      <!-- Tab 2: Justificaciones -->
      <button
        type="button"
        @click="activeTab = 'justifications'"
        :class="[
          'px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 shrink-0 cursor-pointer',
          activeTab === 'justifications'
            ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm'
            : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
        ]"
      >
        <ShieldCheck class="w-4 h-4" />
        2. Justificaciones de Inspección
      </button>

      <!-- Tab 3: Sábana Mensual -->
      <button
        type="button"
        @click="activeTab = 'monthly_grid'"
        :class="[
          'px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 shrink-0 cursor-pointer',
          activeTab === 'monthly_grid'
            ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm'
            : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
        ]"
      >
        <Calendar class="w-4 h-4" />
        3. Sábana Mensual & % Asistencia
      </button>

      <!-- Tab 4: Alertas & WhatsApp -->
      <button
        type="button"
        @click="activeTab = 'alerts'"
        :class="[
          'px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 shrink-0 cursor-pointer',
          activeTab === 'alerts'
            ? 'bg-white dark:bg-slate-800 text-teal-700 dark:text-teal-300 shadow-sm'
            : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
        ]"
      >
        <ShieldAlert class="w-4 h-4" />
        4. Alertas de Inasistencia
      </button>

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
