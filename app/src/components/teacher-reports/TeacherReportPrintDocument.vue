<script setup>
import { computed } from 'vue'
import { loadHtml2Pdf } from '../../lib/pdf'
import { Printer, Download, Share2, X, ShieldCheck, CheckCircle2 } from 'lucide-vue-next'
import { getTemplateConfig, REPORT_TEMPLATES, RECIPIENT_ROLES } from '../../lib/teacherReportTemplates'
import { toast } from 'vue-sonner'

const props = defineProps({
  report: {
    type: Object,
    required: true
  },
  institutionConfig: {
    type: Object,
    default: () => ({})
  },
  onClose: {
    type: Function,
    required: true
  },
  onSendWhatsapp: {
    type: Function,
    default: null
  }
})

const templateCfg = computed(() => getTemplateConfig(props.report.template_type))
const recipientCfg = computed(() => RECIPIENT_ROLES[props.report.recipient_role?.toUpperCase()] || { label: props.report.recipient_role || 'Destinatario' })

const student = computed(() => props.report.students || {})
const course = computed(() => props.report.courses || {})
const subject = computed(() => props.report.subjects || {})
const teacher = computed(() => props.report.profiles || {})

const formattedDate = computed(() => {
  if (props.report.created_at) {
    const d = new Date(props.report.created_at)
    return d.toLocaleDateString('es-EC', { year: 'numeric', month: 'long', day: 'numeric' })
  }
  return new Date().toLocaleDateString('es-EC', { year: 'numeric', month: 'long', day: 'numeric' })
})

const handlePrint = () => {
  window.print()
}

const handleDownloadPdf = async () => {
  const element = document.getElementById('printable-teacher-report')
  if (!element) return

  toast.info('Generando documento PDF oficial...')
  try {
    const html2pdf = await loadHtml2Pdf()
    const opt = {
      margin: [10, 10, 10, 10],
      filename: `${props.report.template_type}_${student.value.full_name || 'estudiante'}.pdf`.replace(/\s+/g, '_'),
      image: { type: 'jpeg', quality: 0.98 },
      html2canvas: { scale: 2, useCORS: true },
      jsPDF: { unit: 'mm', format: 'a4', orientation: 'portrait' }
    }
    await html2pdf().set(opt).from(element).save()
    toast.success('Documento PDF descargado exitosamente')
  } catch (err) {
    console.error('Error exporting PDF:', err)
    toast.error('Error al generar el archivo PDF')
  }
}
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md overflow-y-auto print:p-0 print:bg-white print:static">
    <!-- Modal Container -->
    <div class="relative w-full max-w-4xl bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 overflow-hidden my-8 print:my-0 print:border-none print:shadow-none print:w-full print:max-w-none">
      
      <!-- Top Action Bar (hidden on print) -->
      <div class="no-print flex items-center justify-between px-6 py-4 bg-slate-900 text-white border-b border-slate-800">
        <div class="flex items-center gap-3">
          <div class="p-2 rounded-xl bg-teal-500/20 text-teal-400 border border-teal-500/30">
            <Printer class="w-5 h-5" />
          </div>
          <div>
            <h3 class="font-bold text-base">{{ templateCfg.title }}</h3>
            <p class="text-xs text-slate-400">Vista previa oficial e impresión en formato A4</p>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <button
            v-if="onSendWhatsapp"
            @click="onSendWhatsapp(report)"
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold shadow-sm transition-colors"
          >
            <Share2 class="w-3.5 h-3.5" />
            WhatsApp
          </button>
          
          <button
            @click="handleDownloadPdf"
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-semibold shadow-sm transition-colors"
          >
            <Download class="w-3.5 h-3.5" />
            Descargar PDF
          </button>

          <button
            @click="handlePrint"
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-700 text-white text-xs font-semibold transition-colors"
          >
            <Printer class="w-3.5 h-3.5" />
            Imprimir
          </button>

          <button
            @click="onClose"
            type="button"
            class="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors ml-2"
          >
            <X class="w-5 h-5" />
          </button>
        </div>
      </div>

      <!-- Printable A4 Document Content -->
      <div id="printable-teacher-report" class="p-8 sm:p-12 bg-white text-slate-900 text-sm leading-relaxed print:p-0">
        
        <!-- Header Membretado Institucional -->
        <div class="border-b-2 border-slate-900 pb-5 mb-6">
          <div class="flex items-center justify-between gap-6">
            <div class="flex items-center gap-4">
              <img
                v-if="institutionConfig.institution_logo_url"
                :src="institutionConfig.institution_logo_url"
                alt="Logo Institución"
                class="w-16 h-16 object-contain"
              />
              <div>
                <h1 class="text-xl font-black uppercase tracking-tight text-slate-950 font-serif">
                  {{ institutionConfig.institution_name || 'UNIDAD EDUCATIVA' }}
                </h1>
                <p class="text-xs text-slate-600 font-medium">SISTEMA DE GESTIÓN TÉCNICO-PEDAGÓGICA Y CONVIVENCIA ESCOLAR</p>
                <p class="text-[11px] text-slate-500">Año Lectivo: {{ report.academic_year || '2025 - 2026' }}</p>
              </div>
            </div>

            <div class="text-right shrink-0">
              <div class="inline-block px-3 py-1 bg-slate-100 border border-slate-300 rounded text-xs font-mono font-bold text-slate-800">
                INF-{{ report.id ? report.id.substring(0, 8).toUpperCase() : 'DOC' }}
              </div>
              <p class="text-[11px] text-slate-500 mt-1">{{ formattedDate }}</p>
            </div>
          </div>

          <!-- Document Title -->
          <div class="mt-4 pt-3 border-t border-slate-200 text-center">
            <h2 class="text-base font-extrabold uppercase tracking-wide text-slate-900 bg-slate-100 py-1.5 px-4 rounded border border-slate-200 inline-block">
              {{ report.title || templateCfg.title }}
            </h2>
          </div>
        </div>

        <!-- Metadata Grid -->
        <div class="grid grid-cols-2 gap-x-6 gap-y-2.5 bg-slate-50 p-4 rounded-xl border border-slate-200 mb-6 text-xs">
          <div>
            <span class="font-bold text-slate-700">Estudiante:</span>
            <span class="ml-1.5 font-extrabold text-slate-900">{{ student.full_name || 'N/A' }}</span>
          </div>
          <div>
            <span class="font-bold text-slate-700">C.I. Estudiante:</span>
            <span class="ml-1.5 text-slate-900">{{ student.student_cedula || 'N/A' }}</span>
          </div>
          <div>
            <span class="font-bold text-slate-700">Curso / Grado:</span>
            <span class="ml-1.5 text-slate-900 font-semibold">{{ course.name || 'N/A' }}</span>
          </div>
          <div>
            <span class="font-bold text-slate-700">Asignatura:</span>
            <span class="ml-1.5 text-slate-900 font-semibold">{{ subject.name || 'General / Tutoría' }}</span>
          </div>
          <div>
            <span class="font-bold text-slate-700">Representante Legal:</span>
            <span class="ml-1.5 font-bold text-slate-900">{{ student.representative_name || 'No registrado' }}</span>
          </div>
          <div>
            <span class="font-bold text-slate-700">C.I. / Teléfono:</span>
            <span class="ml-1.5 text-slate-900">{{ student.representative_cedula || 'N/A' }} / {{ student.representative_phone || 'N/A' }}</span>
          </div>
          <div>
            <span class="font-bold text-slate-700">Docente Emisor:</span>
            <span class="ml-1.5 text-slate-900 font-semibold">{{ teacher.full_name || 'Docente' }}</span>
          </div>
          <div>
            <span class="font-bold text-slate-700">Destinatario:</span>
            <span class="ml-1.5 text-slate-900 font-semibold">{{ recipientCfg.label }}</span>
          </div>
        </div>

        <!-- Specialized Section: Citación a Representante Legal -->
        <div v-if="report.template_type === REPORT_TEMPLATES.CITACION_REPRESENTANTE" class="mb-6">
          <div class="bg-amber-50/80 border-2 border-amber-300/80 rounded-xl p-4 mb-4">
            <h4 class="text-xs font-bold text-amber-900 uppercase tracking-wider mb-2">Detalles de la Convocatoria</h4>
            <div class="grid grid-cols-3 gap-3 text-xs">
              <div class="bg-white p-2.5 rounded-lg border border-amber-200">
                <span class="block text-[10px] uppercase text-amber-800 font-bold">Fecha Convocada</span>
                <span class="font-extrabold text-sm text-slate-900">{{ report.citation_date || 'Por definir' }}</span>
              </div>
              <div class="bg-white p-2.5 rounded-lg border border-amber-200">
                <span class="block text-[10px] uppercase text-amber-800 font-bold">Hora</span>
                <span class="font-extrabold text-sm text-slate-900">{{ report.citation_time || '08:00' }}</span>
              </div>
              <div class="bg-white p-2.5 rounded-lg border border-amber-200">
                <span class="block text-[10px] uppercase text-amber-800 font-bold">Lugar / Modalidad</span>
                <span class="font-semibold text-xs text-slate-900">{{ report.citation_location || 'Instalaciones del plantel' }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Academic Score Badge (if applicable) -->
        <div v-if="report.academic_score !== null && report.academic_score !== undefined" class="mb-5 flex items-center gap-3 p-3 bg-teal-50 border border-teal-200 rounded-xl text-xs">
          <span class="font-bold text-teal-900">Promedio / Calificación Registrada:</span>
          <span class="px-2.5 py-1 bg-teal-600 text-white rounded font-mono font-bold text-sm">
            {{ Number(report.academic_score).toFixed(2) }} / 10.00
          </span>
        </div>

        <!-- Report Main Body Sections -->
        <div class="space-y-4 mb-8">
          <!-- Motivo o Fundamento -->
          <div>
            <h4 class="text-xs font-extrabold uppercase text-slate-900 tracking-wider mb-1 flex items-center gap-1.5">
              <span class="w-2 h-2 rounded-full bg-slate-900 inline-block"></span>
              1. Motivo y Antecedentes:
            </h4>
            <div class="p-3.5 bg-slate-50/70 border border-slate-200 rounded-lg text-slate-800 whitespace-pre-line text-xs">
              {{ report.reason || 'Sin motivo especificado.' }}
            </div>
          </div>

          <!-- Observaciones o Hallazgos -->
          <div v-if="report.observations">
            <h4 class="text-xs font-extrabold uppercase text-slate-900 tracking-wider mb-1 flex items-center gap-1.5">
              <span class="w-2 h-2 rounded-full bg-slate-900 inline-block"></span>
              2. Observaciones Pedagógicas / Convivencia:
            </h4>
            <div class="p-3.5 bg-slate-50/70 border border-slate-200 rounded-lg text-slate-800 whitespace-pre-line text-xs">
              {{ report.observations }}
            </div>
          </div>

          <!-- Acuerdos y Compromisos -->
          <div v-if="report.agreements_commitments">
            <h4 class="text-xs font-extrabold uppercase text-slate-900 tracking-wider mb-1 flex items-center gap-1.5">
              <span class="w-2 h-2 rounded-full bg-slate-900 inline-block"></span>
              3. Acuerdos y Compromisos Suscritos:
            </h4>
            <div class="p-3.5 bg-slate-50/70 border border-slate-200 rounded-lg text-slate-800 whitespace-pre-line text-xs">
              {{ report.agreements_commitments }}
            </div>
          </div>

          <!-- Recomendaciones -->
          <div v-if="report.recommendations">
            <h4 class="text-xs font-extrabold uppercase text-slate-900 tracking-wider mb-1 flex items-center gap-1.5">
              <span class="w-2 h-2 rounded-full bg-slate-900 inline-block"></span>
              4. Recomendaciones y Seguimiento:
            </h4>
            <div class="p-3.5 bg-slate-50/70 border border-slate-200 rounded-lg text-slate-800 whitespace-pre-line text-xs">
              {{ report.recommendations }}
            </div>
          </div>
        </div>

        <!-- Electronic Signature Stamp (if signed) -->
        <div v-if="report.signature_data" class="mb-6 p-4 bg-emerald-50 border border-emerald-300 rounded-xl flex items-center justify-between text-xs">
          <div class="flex items-center gap-3">
            <ShieldCheck class="w-8 h-8 text-emerald-600" />
            <div>
              <p class="font-bold text-emerald-900">DOCUMENTO FIRMADO ELECTRÓNICAMENTE</p>
              <p class="text-[11px] text-emerald-700">Firmante: {{ report.signature_data.signer_name || teacher.full_name }}</p>
              <p class="text-[10px] text-emerald-600 font-mono">Hash: {{ report.signature_data.hash || 'N/A' }}</p>
            </div>
          </div>
          <div class="text-right">
            <p class="text-[10px] text-emerald-600">{{ report.signature_data.timestamp || formattedDate }}</p>
          </div>
        </div>

        <!-- Signatures Box -->
        <div class="mt-12 pt-8 border-t border-slate-200">
          <div class="grid grid-cols-2 gap-x-12 gap-y-10 text-center">
            
            <!-- Docente Emisor -->
            <div>
              <div class="h-16 flex items-end justify-center mb-1">
                <span class="text-xs text-slate-300 font-mono">____________________________</span>
              </div>
              <p class="font-bold text-xs text-slate-900">{{ teacher.full_name || 'DOCENTE EMISOR' }}</p>
              <p class="text-[11px] text-slate-500 uppercase">{{ subject.name ? `DOCENTE DE ${subject.name}` : 'DOCENTE / TUTOR' }}</p>
              <p class="text-[10px] text-slate-400">C.I.: {{ teacher.email || '................................' }}</p>
            </div>

            <!-- Representante Legal -->
            <div>
              <div class="h-16 flex items-end justify-center mb-1">
                <span class="text-xs text-slate-300 font-mono">____________________________</span>
              </div>
              <p class="font-bold text-xs text-slate-900">{{ student.representative_name || 'REPRESENTANTE LEGAL' }}</p>
              <p class="text-[11px] text-slate-500 uppercase">PADRE DE FAMILIA / TUTOR LEGAL</p>
              <p class="text-[10px] text-slate-400">C.I.: {{ student.representative_cedula || '................................' }}</p>
            </div>

            <!-- Autoridad / Vicerrectorado / DECE (if trilateral) -->
            <div v-if="['vicerrectorado', 'dece', 'inspeccion', 'rectorado'].includes(report.recipient_role) || report.template_type === REPORT_TEMPLATES.ACTA_COMPROMISO">
              <div class="h-16 flex items-end justify-center mb-1">
                <span class="text-xs text-slate-300 font-mono">____________________________</span>
              </div>
              <p class="font-bold text-xs text-slate-900">{{ recipientCfg.label }}</p>
              <p class="text-[11px] text-slate-500 uppercase">AUTORIDAD / CONSEJERÍA ESTUDIANTIL</p>
            </div>

            <!-- Estudiante -->
            <div v-if="report.template_type === REPORT_TEMPLATES.ACTA_COMPROMISO">
              <div class="h-16 flex items-end justify-center mb-1">
                <span class="text-xs text-slate-300 font-mono">____________________________</span>
              </div>
              <p class="font-bold text-xs text-slate-900">{{ student.full_name || 'ESTUDIANTE' }}</p>
              <p class="text-[11px] text-slate-500 uppercase">COMPROMISO DEL ESTUDIANTE</p>
              <p class="text-[10px] text-slate-400">C.I.: {{ student.student_cedula || '................................' }}</p>
            </div>

          </div>
        </div>

        <!-- Talón desprendible de citación (si es citación) -->
        <div v-if="report.template_type === REPORT_TEMPLATES.CITACION_REPRESENTANTE" class="mt-10 pt-6 border-t-2 border-dashed border-slate-400 text-xs">
          <div class="flex items-center justify-between mb-2">
            <span class="text-[10px] font-mono text-slate-500">✁ CORTE AQUÍ (TALÓN DE DESPRENDIBLE Y RECEPCIÓN PARA EL DOCENTE)</span>
            <span class="text-[10px] font-bold text-slate-700">UNIDAD EDUCATIVA</span>
          </div>
          <p class="text-[11px] text-slate-700 mb-4 leading-relaxed">
            Yo, <strong>{{ student.representative_name || '__________________________' }}</strong>, representante legal del estudiante 
            <strong>{{ student.full_name }}</strong> del curso <strong>{{ course.name }}</strong>, declaro haber recibido la citación 
            para el día <strong>{{ report.citation_date || '____/____/________' }}</strong> a las <strong>{{ report.citation_time || '____:____' }}</strong>.
          </p>
          <div class="flex justify-between items-end pt-4">
            <div>
              <p class="text-[10px] text-slate-500">Fecha de recepción: _____ / _____ / 2026</p>
            </div>
            <div class="text-center">
              <span class="text-slate-300 font-mono">____________________________</span>
              <p class="font-bold text-[10px] text-slate-800">Firma del Representante Legal</p>
              <p class="text-[9px] text-slate-400">C.I.: {{ student.representative_cedula || '..........................' }}</p>
            </div>
          </div>
        </div>

      </div>

    </div>
  </div>
</template>

<style scoped>
@media print {
  body, html {
    background: white !important;
  }
  .no-print {
    display: none !important;
  }
}
</style>
