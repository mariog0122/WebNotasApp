<script setup>
import { computed } from 'vue'
import { 
  Plus, 
  Search, 
  FileText, 
  Mail, 
  FileSpreadsheet, 
  ShieldAlert, 
  UserCheck, 
  FileSignature, 
  Printer, 
  Share2, 
  Edit, 
  Trash2, 
  ShieldCheck, 
  Loader2, 
  CheckCircle, 
  Clock, 
  AlertTriangle,
  Send,
  Sparkles,
  Inbox
} from 'lucide-vue-next'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'
import TeacherReportEditorModal from '../components/teacher-reports/TeacherReportEditorModal.vue'
import TeacherReportPrintDocument from '../components/teacher-reports/TeacherReportPrintDocument.vue'
import DeceDigitalSignModal from '../components/dece/DeceDigitalSignModal.vue'
import { useTeacherReports } from '../composables/useTeacherReports'
import { 
  TEMPLATE_CONFIGS, 
  REPORT_STATUSES, 
  REPORT_TEMPLATES, 
  RECIPIENT_ROLES, 
  getTemplateConfig 
} from '../lib/teacherReportTemplates'

const {
  loading,
  saving,
  reports,
  totalCount,
  courses,
  quarters,
  availableStudents,
  availableSubjects,
  institutionConfig,
  stats,
  searchQuery,
  selectedCourseFilter,
  selectedTemplateFilter,
  selectedStatusFilter,
  selectedQuarterFilter,
  page,
  showEditorModal,
  showPrintModal,
  showDigitalSignModal,
  activeReport,
  formData,
  onCourseSelected,
  onStudentSelected,
  onSubjectSelected,
  onTemplateSelected,
  openCreateModal,
  openEditModal,
  openPrintModal,
  openDigitalSignModal,
  saveReport,
  deleteReport,
  updateStatus,
  sendWhatsAppNotification
} = useTeacherReports()

const getTemplateIcon = (iconName) => {
  switch (iconName) {
    case 'Mail': return Mail
    case 'FileSpreadsheet': return FileSpreadsheet
    case 'ShieldAlert': return ShieldAlert
    case 'UserCheck': return UserCheck
    case 'FileSignature': return FileSignature
    default: return FileText
  }
}
</script>

<template>
  <div class="h-full flex flex-col space-y-6">
    <!-- Academic Year Banner -->
    <AcademicYearBanner module-name="Informes Docentes" class="no-print" />

    <!-- Header & Action Button -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 no-print">
      <div>
        <div class="flex items-center gap-2.5">
          <div class="p-2 rounded-xl bg-teal-500/10 text-teal-600 dark:text-teal-400 border border-teal-500/20">
            <FileText class="w-6 h-6" />
          </div>
          <div>
            <h1 class="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">Informes Docentes</h1>
            <p class="text-sm text-slate-500 dark:text-slate-400">
              Generación de actas, citaciones a representantes y reportes técnicos con sincronización automática
            </p>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <button
          @click="openCreateModal(REPORT_TEMPLATES.CITACION_REPRESENTANTE)"
          type="button"
          class="inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-gradient-to-r from-teal-600 to-teal-500 hover:from-teal-500 hover:to-teal-400 text-white text-sm font-bold shadow-lg shadow-teal-900/20 transition-all cursor-pointer"
        >
          <Plus class="w-4 h-4" />
          Nuevo Documento / Citación
        </button>
      </div>
    </div>

    <!-- Stats Summary Row -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 no-print">
      <!-- Total -->
      <div class="rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 p-4 shadow-sm">
        <div class="flex items-center gap-3">
          <div class="rounded-lg bg-teal-100 dark:bg-teal-500/20 p-2.5 text-teal-600 dark:text-teal-400">
            <FileText class="w-5 h-5" />
          </div>
          <div>
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Total Informes</p>
            <p class="text-2xl font-extrabold text-slate-900 dark:text-white">{{ stats.total }}</p>
          </div>
        </div>
      </div>

      <!-- Citaciones -->
      <div class="rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 p-4 shadow-sm">
        <div class="flex items-center gap-3">
          <div class="rounded-lg bg-amber-100 dark:bg-amber-500/20 p-2.5 text-amber-600 dark:text-amber-400">
            <Mail class="w-5 h-5" />
          </div>
          <div>
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Citaciones</p>
            <p class="text-2xl font-extrabold text-slate-900 dark:text-white">{{ stats.citaciones }}</p>
          </div>
        </div>
      </div>

      <!-- Rendimiento -->
      <div class="rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 p-4 shadow-sm">
        <div class="flex items-center gap-3">
          <div class="rounded-lg bg-sky-100 dark:bg-sky-500/20 p-2.5 text-sky-600 dark:text-sky-400">
            <FileSpreadsheet class="w-5 h-5" />
          </div>
          <div>
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Rendimiento</p>
            <p class="text-2xl font-extrabold text-slate-900 dark:text-white">{{ stats.rendimiento }}</p>
          </div>
        </div>
      </div>

      <!-- Enviados / Atendidos -->
      <div class="rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/60 p-4 shadow-sm">
        <div class="flex items-center gap-3">
          <div class="rounded-lg bg-emerald-100 dark:bg-emerald-500/20 p-2.5 text-emerald-600 dark:text-emerald-400">
            <CheckCircle class="w-5 h-5" />
          </div>
          <div>
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Notificados / Listos</p>
            <p class="text-2xl font-extrabold text-slate-900 dark:text-white">{{ stats.enviados }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Quick Templates Bar -->
    <div class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-gradient-to-r from-slate-900 to-slate-800 p-4 text-white shadow-sm no-print">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-teal-500/20 text-teal-400 border border-teal-500/30">
            <Sparkles class="w-3 h-3" />
            Modelos de Documentos Oficiales
          </span>
          <h3 class="text-sm font-bold text-white mt-1">¿Qué documento deseas emitir hoy?</h3>
        </div>

        <div class="flex flex-wrap gap-2">
          <button
            v-for="tpl in TEMPLATE_CONFIGS"
            :key="tpl.type"
            @click="openCreateModal(tpl.type)"
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800/80 hover:bg-slate-700 border border-slate-700 text-xs font-semibold text-slate-200 transition-all hover:scale-[1.02] cursor-pointer"
          >
            <component :is="getTemplateIcon(tpl.icon)" class="w-3.5 h-3.5 text-teal-400" />
            {{ tpl.shortName }}
          </button>
        </div>
      </div>
    </div>

    <!-- Filters & Table Panel -->
    <div class="flex-1 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 flex flex-col min-h-0 overflow-hidden shadow-sm no-print">
      
      <!-- Filters Row -->
      <div class="p-4 border-b border-slate-200 dark:border-slate-800 flex flex-wrap gap-3 items-center bg-slate-50 dark:bg-slate-900/80">
        <!-- Search Input -->
        <div class="relative flex-1 min-w-[220px]">
          <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar por estudiante, motivo o título..."
            class="w-full pl-9 pr-4 py-2 bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none placeholder-slate-400"
          />
        </div>

        <!-- Filter Curso -->
        <select
          v-model="selectedCourseFilter"
          class="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-slate-200 focus:ring-2 focus:ring-teal-500 focus:outline-none"
        >
          <option value="">Todos los Cursos</option>
          <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>

        <!-- Filter Plantilla -->
        <select
          v-model="selectedTemplateFilter"
          class="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-slate-200 focus:ring-2 focus:ring-teal-500 focus:outline-none"
        >
          <option value="">Todas las Plantillas</option>
          <option v-for="t in TEMPLATE_CONFIGS" :key="t.type" :value="t.type">{{ t.shortName }}</option>
        </select>

        <!-- Filter Estado -->
        <select
          v-model="selectedStatusFilter"
          class="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-slate-200 focus:ring-2 focus:ring-teal-500 focus:outline-none"
        >
          <option value="">Todos los Estados</option>
          <option v-for="st in REPORT_STATUSES" :key="st.id" :value="st.id">{{ st.label }}</option>
        </select>
      </div>

      <!-- Table Body -->
      <div class="flex-1 overflow-auto custom-scrollbar relative">
        <div v-if="loading" class="absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/50 z-10 backdrop-blur-sm">
          <Loader2 class="w-8 h-8 text-teal-500 animate-spin" />
        </div>

        <table v-if="reports.length > 0" class="w-full text-left border-collapse">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-800 bg-slate-100/70 dark:bg-slate-950/70 text-[11px] font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
              <th class="p-3.5 pl-5">Documento</th>
              <th class="p-3.5">Estudiante & Curso</th>
              <th class="p-3.5">Destinatario</th>
              <th class="p-3.5">Fecha / Convocatoria</th>
              <th class="p-3.5 text-center">Estado</th>
              <th class="p-3.5 pr-5 text-right">Acciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60 text-xs">
            <tr
              v-for="rep in reports"
              :key="rep.id"
              class="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors group"
            >
              <!-- Documento / Plantilla -->
              <td class="p-3.5 pl-5">
                <div class="flex items-center gap-3">
                  <div :class="['p-2 rounded-lg bg-gradient-to-r text-white shrink-0 shadow-sm', getTemplateConfig(rep.template_type).colorTheme]">
                    <component :is="getTemplateIcon(getTemplateConfig(rep.template_type).icon)" class="w-4 h-4" />
                  </div>
                  <div>
                    <strong class="text-slate-900 dark:text-white font-bold block line-clamp-1">{{ rep.title }}</strong>
                    <span class="text-[11px] text-slate-500 dark:text-slate-400">
                      {{ getTemplateConfig(rep.template_type).shortName }}
                    </span>
                  </div>
                </div>
              </td>

              <!-- Estudiante & Curso -->
              <td class="p-3.5">
                <strong class="text-slate-900 dark:text-white font-semibold block">
                  {{ rep.students?.full_name || 'N/A' }}
                </strong>
                <span class="text-[11px] text-slate-500 dark:text-slate-400">
                  {{ rep.courses?.name }} {{ rep.subjects?.name ? `• ${rep.subjects?.name}` : '' }}
                </span>
              </td>

              <!-- Destinatario -->
              <td class="p-3.5">
                <span :class="['inline-flex items-center px-2 py-0.5 rounded-md text-[11px] font-semibold border', (RECIPIENT_ROLES[rep.recipient_role?.toUpperCase()] || RECIPIENT_ROLES.REPRESENTANTE_LEGAL).badgeClass]">
                  {{ (RECIPIENT_ROLES[rep.recipient_role?.toUpperCase()] || RECIPIENT_ROLES.REPRESENTANTE_LEGAL).shortLabel }}
                </span>
              </td>

              <!-- Fecha / Convocatoria -->
              <td class="p-3.5 text-slate-600 dark:text-slate-300">
                <div v-if="rep.citation_date" class="font-medium text-amber-600 dark:text-amber-400">
                  📅 {{ rep.citation_date }} {{ rep.citation_time ? `(${rep.citation_time})` : '' }}
                </div>
                <div v-else class="text-slate-400 text-[11px]">
                  {{ new Date(rep.created_at).toLocaleDateString('es-EC') }}
                </div>
              </td>

              <!-- Estado -->
              <td class="p-3.5 text-center">
                <span :class="['inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold border', (REPORT_STATUSES[rep.status] || REPORT_STATUSES.borrador).badgeClass]">
                  {{ (REPORT_STATUSES[rep.status] || REPORT_STATUSES.borrador).label }}
                </span>
              </td>

              <!-- Acciones -->
              <td class="p-3.5 pr-5 text-right">
                <div class="inline-flex items-center gap-1.5 justify-end">
                  
                  <!-- Ver / Imprimir / PDF -->
                  <button
                    @click="openPrintModal(rep)"
                    title="Ver documento oficial / Imprimir PDF"
                    class="p-1.5 rounded-lg text-slate-600 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                  >
                    <Printer class="w-4 h-4" />
                  </button>

                  <!-- WhatsApp Directo -->
                  <button
                    @click="sendWhatsAppNotification(rep)"
                    title="Enviar notificación por WhatsApp"
                    class="p-1.5 rounded-lg text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-500/10 transition-colors"
                  >
                    <Share2 class="w-4 h-4" />
                  </button>

                  <!-- Editar -->
                  <button
                    @click="openEditModal(rep)"
                    title="Editar informe"
                    class="p-1.5 rounded-lg text-slate-600 dark:text-slate-300 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                  >
                    <Edit class="w-4 h-4" />
                  </button>

                  <!-- Eliminar -->
                  <button
                    @click="deleteReport(rep.id)"
                    title="Eliminar informe"
                    class="p-1.5 rounded-lg text-slate-400 hover:text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-500/10 transition-colors"
                  >
                    <Trash2 class="w-4 h-4" />
                  </button>

                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- Empty State -->
        <div v-else-if="!loading" class="p-12 text-center space-y-4">
          <div class="w-16 h-16 rounded-2xl bg-teal-500/10 text-teal-600 dark:text-teal-400 flex items-center justify-center mx-auto border border-teal-500/20">
            <Inbox class="w-8 h-8" />
          </div>
          <div>
            <h3 class="text-base font-bold text-slate-900 dark:text-white">No se encontraron informes</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1 max-w-md mx-auto">
              Comienza emitiendo una citación para padres de familia o un informe de rendimiento académico seleccionando un modelo abajo.
            </p>
          </div>

          <div class="flex flex-wrap items-center justify-center gap-2 pt-2">
            <button
              v-for="tpl in TEMPLATE_CONFIGS"
              :key="tpl.type"
              @click="openCreateModal(tpl.type)"
              type="button"
              class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-teal-50 dark:hover:bg-teal-900/30 border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-700 dark:text-slate-200 transition-colors"
            >
              <component :is="getTemplateIcon(tpl.icon)" class="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
              Crear {{ tpl.shortName }}
            </button>
          </div>
        </div>
      </div>

    </div>

    <!-- Modals -->
    <TeacherReportEditorModal
      v-if="showEditorModal"
      :form-data="formData"
      :courses="courses"
      :quarters="quarters"
      :available-students="availableStudents"
      :available-subjects="availableSubjects"
      :saving="saving"
      :on-course-change="onCourseSelected"
      :on-student-change="onStudentSelected"
      :on-subject-change="onSubjectSelected"
      :on-template-change="onTemplateSelected"
      :on-save="saveReport"
      :on-close="() => { showEditorModal = false }"
    />

    <TeacherReportPrintDocument
      v-if="showPrintModal && activeReport"
      :report="activeReport"
      :institution-config="institutionConfig"
      :on-close="() => { showPrintModal = false }"
      :on-send-whatsapp="sendWhatsAppNotification"
    />

    <DeceDigitalSignModal
      v-if="showDigitalSignModal && activeReport"
      :alert-id="activeReport.id"
      :student-name="activeReport.students?.full_name || 'Estudiante'"
      :case-code="`INF-${activeReport.id.substring(0, 8).toUpperCase()}`"
      :description="activeReport.reason"
      @close="showDigitalSignModal = false"
      @signed="() => { showDigitalSignModal = false; fetchReports(); }"
    />

  </div>
</template>
