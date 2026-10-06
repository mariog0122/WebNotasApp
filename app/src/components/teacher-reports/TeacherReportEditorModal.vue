<script setup>
import { ref, computed } from 'vue'
import { 
  X, 
  FileText, 
  Mail, 
  FileSpreadsheet, 
  ShieldAlert, 
  UserCheck, 
  FileSignature, 
  User, 
  Calendar, 
  Clock, 
  MapPin, 
  Check, 
  Send, 
  Save, 
  Eye, 
  GraduationCap, 
  BookOpen, 
  Phone, 
  IdCard,
  AlertCircle 
} from 'lucide-vue-next'
import { 
  TEMPLATE_CONFIGS, 
  RECIPIENT_ROLES, 
  REPORT_TEMPLATES, 
  REPORT_PRIORITIES, 
  getTemplateConfig 
} from '../../lib/teacherReportTemplates'

const props = defineProps({
  formData: {
    type: Object,
    required: true
  },
  courses: {
    type: Array,
    default: () => []
  },
  quarters: {
    type: Array,
    default: () => []
  },
  availableStudents: {
    type: Array,
    default: () => []
  },
  availableSubjects: {
    type: Array,
    default: () => []
  },
  saving: {
    type: Boolean,
    default: false
  },
  onCourseChange: {
    type: Function,
    required: true
  },
  onStudentChange: {
    type: Function,
    required: true
  },
  onSubjectChange: {
    type: Function,
    required: true
  },
  onTemplateChange: {
    type: Function,
    required: true
  },
  onSave: {
    type: Function,
    required: true
  },
  onClose: {
    type: Function,
    required: true
  }
})

const activeTab = ref('formulario') // 'formulario' | 'destinatario' | 'previsualizacion'

const currentTemplateCfg = computed(() => getTemplateConfig(props.formData.template_type))

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
  <div class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/80 backdrop-blur-md overflow-y-auto">
    <div class="relative w-full max-w-4xl bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 overflow-hidden my-4 flex flex-col max-h-[92vh]">
      
      <!-- Modal Header -->
      <div class="px-6 py-4 bg-slate-900 text-white border-b border-slate-800 flex items-center justify-between shrink-0">
        <div class="flex items-center gap-3">
          <div class="p-2 rounded-xl bg-teal-500/20 text-teal-400 border border-teal-500/30">
            <FileText class="w-5 h-5" />
          </div>
          <div>
            <h3 class="font-bold text-base text-white">
              {{ formData.id ? 'Editar Informe / Citación' : 'Nuevo Informe o Citación Docente' }}
            </h3>
            <p class="text-xs text-slate-400">Completa los datos; los campos del estudiante se auto-rellenan al seleccionarlo</p>
          </div>
        </div>

        <button
          @click="onClose"
          type="button"
          class="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <!-- Navigation Tabs -->
      <div class="px-6 py-2.5 bg-slate-50 dark:bg-slate-950/60 border-b border-slate-200 dark:border-slate-800 flex items-center gap-2 shrink-0">
        <button
          type="button"
          @click="activeTab = 'formulario'"
          :class="[
            'px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5',
            activeTab === 'formulario'
              ? 'bg-teal-600 text-white shadow-sm'
              : 'text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-800'
          ]"
        >
          <FileText class="w-3.5 h-3.5" />
          1. Estudiante & Plantilla
        </button>

        <button
          type="button"
          @click="activeTab = 'destinatario'"
          :class="[
            'px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5',
            activeTab === 'destinatario'
              ? 'bg-teal-600 text-white shadow-sm'
              : 'text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-800'
          ]"
        >
          <UserCheck class="w-3.5 h-3.5" />
          2. Contenido & Destinatario
        </button>

        <button
          type="button"
          @click="activeTab = 'previsualizacion'"
          :class="[
            'px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5',
            activeTab === 'previsualizacion'
              ? 'bg-teal-600 text-white shadow-sm'
              : 'text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-800'
          ]"
        >
          <Eye class="w-3.5 h-3.5" />
          3. Vista Previa Rápida
        </button>
      </div>

      <!-- Modal Body (Scrollable) -->
      <div class="flex-1 overflow-y-auto p-6 space-y-6 custom-scrollbar">

        <!-- TAB 1: Plantilla & Estudiante -->
        <div v-if="activeTab === 'formulario'" class="space-y-6">
          
          <!-- Template Picker -->
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-2.5">
              Selecciona el Modelo de Documento:
            </label>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              <button
                v-for="tpl in TEMPLATE_CONFIGS"
                :key="tpl.type"
                type="button"
                @click="onTemplateChange(tpl.type)"
                :class="[
                  'p-3.5 rounded-xl border text-left transition-all duration-200 flex flex-col justify-between relative overflow-hidden group',
                  formData.template_type === tpl.type
                    ? 'border-teal-500 bg-teal-500/10 dark:bg-teal-500/15 ring-2 ring-teal-500/30'
                    : 'border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-800/60 hover:border-slate-300 dark:hover:border-slate-700'
                ]"
              >
                <div>
                  <div class="flex items-center justify-between mb-2">
                    <div :class="['p-2 rounded-lg bg-gradient-to-r text-white shadow-sm', tpl.colorTheme]">
                      <component :is="getTemplateIcon(tpl.icon)" class="w-4 h-4" />
                    </div>
                    <span v-if="formData.template_type === tpl.type" class="w-5 h-5 rounded-full bg-teal-600 text-white flex items-center justify-center">
                      <Check class="w-3.5 h-3.5" />
                    </span>
                  </div>
                  <h4 class="font-bold text-xs text-slate-900 dark:text-white line-clamp-1">{{ tpl.title }}</h4>
                  <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1 line-clamp-2 leading-snug">
                    {{ tpl.description }}
                  </p>
                </div>
              </button>
            </div>
          </div>

          <!-- Selectores de Curso y Estudiante (Auto-relleno Reactivo) -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 rounded-xl bg-slate-50 dark:bg-slate-950/50 border border-slate-200 dark:border-slate-800">
            <!-- Curso -->
            <div>
              <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5 flex items-center gap-1.5">
                <GraduationCap class="w-4 h-4 text-teal-600 dark:text-teal-400" />
                Curso / Grado: *
              </label>
              <select
                :value="formData.course_id"
                @change="onCourseChange($event.target.value)"
                class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
              >
                <option value="">-- Selecciona un curso --</option>
                <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
              </select>
            </div>

            <!-- Asignatura (Opcional) -->
            <div>
              <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5 flex items-center gap-1.5">
                <BookOpen class="w-4 h-4 text-teal-600 dark:text-teal-400" />
                Materia / Asignatura:
              </label>
              <select
                :value="formData.subject_id"
                @change="onSubjectChange($event.target.value)"
                class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
              >
                <option value="">General / Tutoría</option>
                <option v-for="s in availableSubjects" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
            </div>

            <!-- Estudiante -->
            <div class="md:col-span-2">
              <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5 flex items-center gap-1.5">
                <User class="w-4 h-4 text-teal-600 dark:text-teal-400" />
                Estudiante Objetivo: *
              </label>
              <select
                :value="formData.student_id"
                @change="onStudentChange($event.target.value)"
                :disabled="!formData.course_id"
                class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none disabled:opacity-50"
              >
                <option value="">{{ formData.course_id ? '-- Selecciona el estudiante --' : 'Primero selecciona un curso' }}</option>
                <option v-for="st in availableStudents" :key="st.id" :value="st.id">
                  {{ st.full_name }} {{ st.student_cedula ? `(C.I. ${st.student_cedula})` : '' }}
                </option>
              </select>
            </div>
          </div>

          <!-- Tarjeta de Datos Sincronizados Automáticamente -->
          <div v-if="formData.student_id" class="p-4 rounded-xl bg-teal-500/10 border border-teal-500/30 space-y-3 animate-fade-in">
            <div class="flex items-center justify-between">
              <h4 class="text-xs font-bold uppercase text-teal-700 dark:text-teal-300 flex items-center gap-1.5">
                <Check class="w-4 h-4" />
                Datos Auto-Rellenados del Estudiante y Familia
              </h4>
              <span class="text-[11px] text-teal-600 dark:text-teal-400 font-mono">Sincronizado</span>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 text-xs">
              <div>
                <span class="text-slate-500 dark:text-slate-400 block text-[11px]">Estudiante:</span>
                <strong class="text-slate-900 dark:text-white">{{ formData.student_name }}</strong>
              </div>
              <div>
                <span class="text-slate-500 dark:text-slate-400 block text-[11px]">Cédula:</span>
                <span class="text-slate-800 dark:text-slate-200">{{ formData.student_cedula || 'No registrada' }}</span>
              </div>
              <div>
                <span class="text-slate-500 dark:text-slate-400 block text-[11px]">Representante:</span>
                <strong class="text-slate-900 dark:text-white">{{ formData.representative_name || 'No registrado' }}</strong>
              </div>
              <div>
                <span class="text-slate-500 dark:text-slate-400 block text-[11px]">C.I. Representante:</span>
                <span class="text-slate-800 dark:text-slate-200">{{ formData.representative_cedula || 'N/A' }}</span>
              </div>
              <div>
                <span class="text-slate-500 dark:text-slate-400 block text-[11px]">Teléfono Contacto:</span>
                <span class="text-slate-800 dark:text-slate-200 font-mono">{{ formData.representative_phone || 'N/A' }}</span>
              </div>
              <div>
                <span class="text-slate-500 dark:text-slate-400 block text-[11px]">Docente Emisor:</span>
                <span class="text-slate-800 dark:text-slate-200">{{ formData.teacher_name }}</span>
              </div>
            </div>
          </div>

          <!-- Campos Específicos para Citación -->
          <div v-if="formData.template_type === REPORT_TEMPLATES.CITACION_REPRESENTANTE" class="p-4 rounded-xl bg-amber-500/10 border border-amber-500/30 space-y-4">
            <h4 class="text-xs font-bold uppercase text-amber-800 dark:text-amber-300 flex items-center gap-1.5">
              <Mail class="w-4 h-4" />
              Datos de la Convocatoria / Citación
            </h4>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1 flex items-center gap-1">
                  <Calendar class="w-3.5 h-3.5 text-amber-600" />
                  Fecha de la Citación: *
                </label>
                <input
                  v-model="formData.citation_date"
                  type="date"
                  class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3 py-2 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-amber-500 focus:outline-none"
                />
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1 flex items-center gap-1">
                  <Clock class="w-3.5 h-3.5 text-amber-600" />
                  Hora: *
                </label>
                <input
                  v-model="formData.citation_time"
                  type="time"
                  class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3 py-2 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-amber-500 focus:outline-none"
                />
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1 flex items-center gap-1">
                  <MapPin class="w-3.5 h-3.5 text-amber-600" />
                  Lugar / Sala:
                </label>
                <input
                  v-model="formData.citation_location"
                  type="text"
                  placeholder="Ej. Aula 4 / Sala de Profesores"
                  class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3 py-2 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-amber-500 focus:outline-none"
                />
              </div>
            </div>
          </div>

        </div>

        <!-- TAB 2: Contenido & Destinatario -->
        <div v-else-if="activeTab === 'destinatario'" class="space-y-5">
          
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1.5">
                Destinatario del Documento: *
              </label>
              <select
                v-model="formData.recipient_role"
                class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
              >
                <option v-for="r in RECIPIENT_ROLES" :key="r.id" :value="r.id">
                  {{ r.label }}
                </option>
              </select>
            </div>

            <div>
              <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1.5">
                Prioridad del Trámite:
              </label>
              <select
                v-model="formData.priority"
                class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
              >
                <option v-for="p in REPORT_PRIORITIES" :key="p.id" :value="p.id">
                  {{ p.label }}
                </option>
              </select>
            </div>
          </div>

          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1.5">
              Título Oficial del Informe: *
            </label>
            <input
              v-model="formData.title"
              type="text"
              class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
            />
          </div>

          <!-- Motivo o Fundamento -->
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1.5">
              1. Motivo y Antecedentes Pedagógicos / Convivencia: *
            </label>
            <textarea
              v-model="formData.reason"
              rows="3"
              class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl p-3 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
              placeholder="Detalla los antecedentes que motivan este informe o citación..."
            ></textarea>
          </div>

          <!-- Observaciones -->
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1.5">
              2. Observaciones Pedagógicas y Factores Identificados:
            </label>
            <textarea
              v-model="formData.observations"
              rows="3"
              class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl p-3 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
              placeholder="Describa el comportamiento, rendimiento o situación socioemocional..."
            ></textarea>
          </div>

          <!-- Acuerdos y Compromisos -->
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1.5">
              3. Acuerdos y Compromisos Establecidos:
            </label>
            <textarea
              v-model="formData.agreements_commitments"
              rows="3"
              class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl p-3 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
              placeholder="Acciones y compromisos que asume el estudiante, docente o representante..."
            ></textarea>
          </div>

          <!-- Recomendaciones -->
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1.5">
              4. Recomendaciones Finales:
            </label>
            <textarea
              v-model="formData.recommendations"
              rows="2"
              class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl p-3 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-teal-500 focus:outline-none"
              placeholder="Sugerencias o directrices para el seguimiento..."
            ></textarea>
          </div>

        </div>

        <!-- TAB 3: Previsualización Rápida -->
        <div v-else-if="activeTab === 'previsualizacion'" class="p-6 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 space-y-4">
          <div class="text-center pb-3 border-b border-slate-200 dark:border-slate-800">
            <span class="text-xs uppercase tracking-widest text-teal-600 font-bold">VISTA PREVIA RÁPIDA DEL DOCUMENTO</span>
            <h3 class="text-lg font-bold text-slate-900 dark:text-white mt-1">{{ formData.title }}</h3>
          </div>

          <div class="grid grid-cols-2 gap-2 text-xs bg-white dark:bg-slate-900 p-3.5 rounded-lg border border-slate-200 dark:border-slate-800">
            <div><strong class="text-slate-700 dark:text-slate-300">Estudiante:</strong> {{ formData.student_name || 'No seleccionado' }}</div>
            <div><strong class="text-slate-700 dark:text-slate-300">Cédula:</strong> {{ formData.student_cedula || 'N/A' }}</div>
            <div><strong class="text-slate-700 dark:text-slate-300">Curso:</strong> {{ formData.course_name || 'N/A' }}</div>
            <div><strong class="text-slate-700 dark:text-slate-300">Representante:</strong> {{ formData.representative_name || 'N/A' }}</div>
            <div><strong class="text-slate-700 dark:text-slate-300">Docente:</strong> {{ formData.teacher_name }}</div>
            <div><strong class="text-slate-700 dark:text-slate-300">Destinatario:</strong> {{ formData.recipient_role }}</div>
          </div>

          <div class="text-xs space-y-2 bg-white dark:bg-slate-900 p-4 rounded-lg border border-slate-200 dark:border-slate-800">
            <p><strong class="text-slate-900 dark:text-white block mb-1">Motivo:</strong> {{ formData.reason || 'Sin motivo redactado.' }}</p>
            <p v-if="formData.observations"><strong class="text-slate-900 dark:text-white block mb-1">Observaciones:</strong> {{ formData.observations }}</p>
            <p v-if="formData.agreements_commitments"><strong class="text-slate-900 dark:text-white block mb-1">Compromisos:</strong> {{ formData.agreements_commitments }}</p>
          </div>
        </div>

      </div>

      <!-- Modal Footer Action Buttons -->
      <div class="px-6 py-4 bg-slate-50 dark:bg-slate-950 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between shrink-0">
        <button
          type="button"
          @click="onClose"
          class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-800 transition-colors"
        >
          Cancelar
        </button>

        <div class="flex items-center gap-2.5">
          <button
            type="button"
            :disabled="saving"
            @click="onSave(false)"
            class="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl border border-slate-300 dark:border-slate-700 text-xs font-bold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors disabled:opacity-50"
          >
            <Save class="w-4 h-4" />
            Guardar Borrador
          </button>

          <button
            type="button"
            :disabled="saving"
            @click="onSave(true)"
            class="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-gradient-to-r from-teal-600 to-teal-500 hover:from-teal-500 hover:to-teal-400 text-white text-xs font-bold shadow-lg shadow-teal-900/30 transition-all disabled:opacity-50"
          >
            <Send class="w-4 h-4" />
            {{ saving ? 'Guardando...' : 'Emitir y Notificar' }}
          </button>
        </div>
      </div>

    </div>
  </div>
</template>
