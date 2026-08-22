<template>
  <div v-if="show" class="fixed inset-0 z-50 flex items-center justify-center p-0 sm:p-4 print:p-0">
    <!-- Backdrop (hidden on print) -->
    <div class="absolute inset-0 bg-slate-900/80 backdrop-blur-sm no-print" @click="close"></div>

    <!-- Modal Window -->
    <div class="relative bg-slate-100 dark:bg-slate-950 sm:border border-slate-200 dark:border-slate-800 sm:rounded-2xl w-full max-w-4xl h-full sm:h-auto sm:max-h-[95vh] overflow-hidden shadow-2xl flex flex-col print:h-auto print:max-h-none print:w-full print:border-none print:shadow-none print:bg-white print:p-0">
      
      <!-- Top Action Bar (hidden on print) -->
      <div class="p-4 sm:px-6 sm:py-3.5 border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex flex-wrap items-center justify-between gap-3 shrink-0 no-print">
        <div class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-950/60 text-teal-700 dark:text-teal-400 flex items-center justify-center font-bold">
            <FileText class="w-4 h-4" />
          </div>
          <div>
            <h3 class="text-sm font-bold text-slate-900 dark:text-white leading-tight">Acta de Notificación / Citación DECE</h3>
            <p class="text-[11px] text-slate-500">Documento oficial para firma física o electrónica</p>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <!-- Digital Sign Button -->
          <button
            v-if="!alertData?.is_digitally_signed"
            type="button"
            @click="$emit('open-sign')"
            class="px-3 py-1.5 text-xs font-bold text-indigo-700 dark:text-indigo-300 bg-indigo-50 dark:bg-indigo-950/50 hover:bg-indigo-100 border border-indigo-200 dark:border-indigo-800 rounded-xl transition-colors flex items-center gap-1.5 shadow-sm"
          >
            <ShieldCheck class="w-3.5 h-3.5 text-indigo-600 dark:text-indigo-400" />
            <span>Firmar con .p12</span>
          </button>
          <div v-else class="px-2.5 py-1 text-[11px] font-bold text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-300 dark:border-emerald-800 rounded-xl flex items-center gap-1.5">
            <CheckCircle2 class="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
            <span>Firmado Electrónicamente</span>
          </div>

          <!-- Print Button -->
          <button
            type="button"
            @click="triggerPrint"
            class="px-3.5 py-1.5 text-xs font-bold text-white bg-teal-600 hover:bg-teal-700 rounded-xl transition-colors flex items-center gap-1.5 shadow-sm ring-1 ring-teal-500/50"
          >
            <Printer class="w-3.5 h-3.5" />
            <span>Imprimir Físico</span>
          </button>

          <!-- Close Button -->
          <button
            type="button"
            @click="close"
            class="p-1.5 text-slate-400 hover:text-slate-700 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            <X class="w-5 h-5" />
          </button>
        </div>
      </div>

      <!-- Printable Document Canvas -->
      <div class="flex-1 overflow-y-auto custom-scrollbar p-3 sm:p-6 print:p-0 print:overflow-visible flex justify-center">
        <div id="dece-print-acta" class="w-full max-w-[210mm] min-h-[297mm] bg-white text-slate-900 p-8 sm:p-12 print:p-8 shadow-md print:shadow-none border border-slate-200 print:border-none rounded-xl print:rounded-none flex flex-col justify-between text-xs leading-relaxed">
          
          <!-- Document Header -->
          <div>
            <div class="border-b-2 border-slate-800 pb-4 mb-5 flex items-center justify-between gap-4">
              <div class="flex items-center gap-4">
                <img 
                  v-if="institutionLogoUrl" 
                  :src="institutionLogoUrl" 
                  alt="Logo Institución" 
                  class="h-16 w-16 object-contain rounded-lg shrink-0" 
                />
                <div>
                  <h1 class="text-sm font-extrabold uppercase tracking-wider text-slate-950">
                    {{ institutionName || 'UNIDAD EDUCATIVA' }}
                  </h1>
                  <h2 class="text-xs font-bold text-teal-800 tracking-wide mt-0.5">
                    DEPARTAMENTO DE CONSEJERÍA ESTUDIANTIL (DECE)
                  </h2>
                  <p class="text-[10px] text-slate-500 font-medium mt-0.5">
                    Coordinación de Bienestar, Disciplina y Acompañamiento Integral
                  </p>
                </div>
              </div>

              <div class="text-right shrink-0">
                <span class="inline-block bg-slate-100 border border-slate-300 rounded px-2 py-0.5 text-[10px] font-mono font-bold text-slate-800">
                  ACTA N° {{ alertData?.id ? alertData.id.slice(0, 8).toUpperCase() : '00000000' }}
                </span>
                <p class="text-[10px] text-slate-600 mt-1 font-semibold">
                  Año Lectivo: {{ selectedAcademicYear || alertData?.courses?.academic_year || 'Actual' }}
                </p>
              </div>
            </div>

            <!-- Title -->
            <div class="text-center my-4">
              <h3 class="text-sm font-black uppercase text-slate-900 tracking-wide underline underline-offset-4 decoration-slate-400">
                ACTA DE NOTIFICACIÓN Y CITACIÓN A REPRESENTANTE LEGAL
              </h3>
            </div>

            <!-- Section 1: Student and Representative Info -->
            <div class="border border-slate-300 rounded-lg overflow-hidden mb-4">
              <div class="bg-slate-100 px-3 py-1.5 border-b border-slate-300 font-bold text-[11px] uppercase tracking-wider text-slate-800">
                1. Datos del Estudiante y Representante
              </div>
              <div class="p-3 grid grid-cols-2 sm:grid-cols-3 gap-x-4 gap-y-2 text-[11px]">
                <div>
                  <span class="text-slate-500 block text-[10px]">Estudiante:</span>
                  <strong class="text-slate-900 font-bold">{{ alertData?.students?.full_name || 'N/A' }}</strong>
                </div>
                <div>
                  <span class="text-slate-500 block text-[10px]">Cédula / Identificación:</span>
                  <span class="font-medium text-slate-800">{{ alertData?.students?.student_cedula || 'N/A' }}</span>
                </div>
                <div>
                  <span class="text-slate-500 block text-[10px]">Curso / Nivel:</span>
                  <span class="font-bold text-slate-800">{{ alertData?.courses?.name || 'N/A' }}</span>
                </div>
                <div>
                  <span class="text-slate-500 block text-[10px]">Representante Legal:</span>
                  <strong class="text-slate-900 font-bold">{{ alertData?.students?.representative_name || 'No registrado' }}</strong>
                </div>
                <div>
                  <span class="text-slate-500 block text-[10px]">C.I. Representante:</span>
                  <span class="font-medium text-slate-800">{{ alertData?.students?.representative_cedula || 'N/A' }}</span>
                </div>
                <div>
                  <span class="text-slate-500 block text-[10px]">Teléfono de Contacto:</span>
                  <span class="font-medium text-slate-800">{{ alertData?.students?.representative_phone || 'N/A' }}</span>
                </div>
              </div>
            </div>

            <!-- Section 2: Incident Details -->
            <div class="border border-slate-300 rounded-lg overflow-hidden mb-4">
              <div class="bg-slate-100 px-3 py-1.5 border-b border-slate-300 font-bold text-[11px] uppercase tracking-wider text-slate-800 flex justify-between items-center">
                <span>2. Detalle de la Novedad o Incidencia</span>
                <span class="text-[10px] font-bold px-2 py-0.5 rounded border" :class="getSeverityClass(alertData?.severity)">
                  {{ getSeverityLabel(alertData?.severity) }}
                </span>
              </div>
              <div class="p-3 space-y-2.5 text-[11px]">
                <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 pb-2 border-b border-slate-200">
                  <div>
                    <span class="text-slate-500 block text-[10px]">Fecha y Hora del Incidente:</span>
                    <span class="font-bold text-slate-800">{{ formatFullDateTime(alertData?.date_occurred) }}</span>
                  </div>
                  <div>
                    <span class="text-slate-500 block text-[10px]">Tipo de Novedad:</span>
                    <span class="font-bold text-teal-800">{{ getTypeLabel(alertData?.alert_type) }}</span>
                  </div>
                  <div>
                    <span class="text-slate-500 block text-[10px]">Reportado por:</span>
                    <span class="font-medium text-slate-800">{{ alertData?.profiles?.full_name || 'Personal Docente' }}</span>
                  </div>
                </div>

                <div>
                  <span class="text-slate-500 block text-[10px] font-bold uppercase mb-1">Descripción Circunstanciada de los Hechos:</span>
                  <p class="p-2.5 bg-slate-50 border border-slate-200 rounded text-slate-800 leading-relaxed whitespace-pre-wrap min-h-[50px]">
                    {{ alertData?.description || 'Sin descripción detallada.' }}
                  </p>
                </div>
              </div>
            </div>

            <!-- Section 3: DECE Notes & Resolution -->
            <div class="border border-slate-300 rounded-lg overflow-hidden mb-5">
              <div class="bg-slate-100 px-3 py-1.5 border-b border-slate-300 font-bold text-[11px] uppercase tracking-wider text-slate-800">
                3. Acciones de Consejería, Acuerdos y Compromisos
              </div>
              <div class="p-3 space-y-2.5 text-[11px]">
                <div v-if="alertData?.dece_notes">
                  <span class="text-slate-500 block text-[10px] font-bold uppercase mb-0.5">Seguimiento / Observaciones DECE:</span>
                  <p class="p-2 bg-slate-50 border border-slate-200 rounded text-slate-800 leading-relaxed whitespace-pre-wrap">
                    {{ alertData.dece_notes }}
                  </p>
                </div>

                <div>
                  <span class="text-slate-500 block text-[10px] font-bold uppercase mb-0.5">Acuerdos, Compromisos y Medidas Formativas:</span>
                  <p class="p-2.5 bg-slate-50 border border-slate-200 rounded text-slate-800 leading-relaxed whitespace-pre-wrap min-h-[45px]">
                    {{ alertData?.resolution || 'Se convoca al representante para suscribir acuerdos y compromisos orientados al bienestar integral y formativo del estudiante, de conformidad con el Reglamento General a la LOEI.' }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Section 4: Signatures and Certification -->
          <div>
            <div class="bg-slate-100 px-3 py-1.5 border border-slate-300 rounded-t-lg font-bold text-[11px] uppercase tracking-wider text-slate-800 mb-0">
              4. Certificación y Firmas de Responsabilidad
            </div>

            <div class="border border-t-0 border-slate-300 rounded-b-lg p-4 bg-white">
              <!-- Digital Signature Certificate Seal -->
              <div v-if="alertData?.is_digitally_signed && alertData?.signature_data" class="p-3.5 border-2 border-dashed border-teal-600 bg-teal-50/50 rounded-xl space-y-1.5">
                <div class="flex items-center gap-2 text-teal-900 font-black text-[11px] uppercase tracking-wider">
                  <ShieldCheck class="w-4 h-4 text-teal-600 shrink-0" />
                  <span>Documento Firmado Electrónicamente (Ley de Comercio Electrónico y Firmas Digitales)</span>
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-1 text-[10px] text-slate-700 pt-1">
                  <div><span class="font-bold text-slate-900">Firmante:</span> {{ alertData.signature_data.signer_name }}</div>
                  <div><span class="font-bold text-slate-900">Entidad Certificadora:</span> {{ alertData.signature_data.certificate_issuer }}</div>
                  <div><span class="font-bold text-slate-900">Fecha y Hora de Firma:</span> {{ formatFullDateTime(alertData.signature_data.signed_at) }}</div>
                  <div><span class="font-bold text-slate-900">Algoritmo:</span> {{ alertData.signature_data.algorithm || 'SHA256withRSA' }}</div>
                  <div class="sm:col-span-2 font-mono text-[9px] text-slate-500 break-all">
                    <span class="font-bold">Huella Digital SHA-256:</span> {{ alertData.signature_data.certificate_fingerprint }}
                  </div>
                </div>
              </div>

              <!-- Physical Signature Blocks -->
              <div class="grid grid-cols-3 gap-6 pt-8 pb-2 text-center text-[10px]">
                <!-- Representative -->
                <div class="flex flex-col items-center justify-end">
                  <div class="w-full border-t border-slate-800 pt-1.5 font-bold text-slate-900">
                    {{ alertData?.students?.representative_name || 'REPRESENTANTE LEGAL' }}
                  </div>
                  <div class="text-slate-500 text-[9px]">
                    C.I.: {{ alertData?.students?.representative_cedula || '................................' }}
                  </div>
                  <div class="text-slate-400 text-[9px] uppercase font-semibold">Padre / Madre / Tutor</div>
                </div>

                <!-- Teacher / Reporter -->
                <div class="flex flex-col items-center justify-end">
                  <div class="w-full border-t border-slate-800 pt-1.5 font-bold text-slate-900">
                    {{ alertData?.profiles?.full_name || 'DOCENTE TUTOR' }}
                  </div>
                  <div class="text-slate-500 text-[9px]">Docente / Personal Notificador</div>
                  <div class="text-slate-400 text-[9px] uppercase font-semibold">Unidad Educativa</div>
                </div>

                <!-- DECE Coordinator -->
                <div class="flex flex-col items-center justify-end">
                  <div class="w-full border-t border-slate-800 pt-1.5 font-bold text-slate-900">
                    {{ institutionTutorName || 'CONSEJERÍA ESTUDIANTIL' }}
                  </div>
                  <div class="text-slate-500 text-[9px]">Coordinador(a) / Psicólogo(a) DECE</div>
                  <div class="text-slate-400 text-[9px] uppercase font-semibold">Sello y Firma Institucional</div>
                </div>
              </div>
            </div>

            <!-- Footer legal notes -->
            <div class="mt-4 pt-2 border-t border-slate-200 flex justify-between items-center text-[9px] text-slate-400 font-medium">
              <span>Emitido conforme al Reglamento General a la LOEI (Art. 330 y concordantes).</span>
              <span>Fecha de impresión: {{ formatFullDateTime(new Date().toISOString()) }}</span>
            </div>
          </div>

        </div>
      </div>

    </div>
  </div>
</template>

<script setup>
import { 
  FileText, Printer, ShieldCheck, CheckCircle2, X 
} from 'lucide-vue-next'
import { ALERT_TYPES, ALERT_SEVERITIES } from '../../lib/alertTypes'

const props = defineProps({
  show: {
    type: Boolean,
    default: false
  },
  alertData: {
    type: Object,
    default: null
  },
  institutionName: {
    type: String,
    default: 'UNIDAD EDUCATIVA'
  },
  institutionLogoUrl: {
    type: String,
    default: ''
  },
  institutionTutorName: {
    type: String,
    default: ''
  },
  selectedAcademicYear: {
    type: String,
    default: ''
  }
})

const emit = defineEmits(['close', 'open-sign'])

const close = () => {
  emit('close')
}

const triggerPrint = () => {
  window.print()
}

const getSeverityLabel = (severity) => {
  return ALERT_SEVERITIES[severity]?.label || severity || 'Leve'
}

const getSeverityClass = (severity) => {
  switch (severity) {
    case 'LEVE':
      return 'bg-emerald-50 text-emerald-800 border-emerald-300'
    case 'GRAVE':
      return 'bg-amber-50 text-amber-800 border-amber-300'
    case 'MUY_GRAVE':
      return 'bg-rose-50 text-rose-800 border-rose-300'
    default:
      return 'bg-slate-50 text-slate-800 border-slate-300'
  }
}

const getTypeLabel = (type) => {
  return ALERT_TYPES[type]?.label || type || 'Indisciplina'
}

const formatFullDateTime = (isoString) => {
  if (!isoString) return 'N/A'
  try {
    return new Date(isoString).toLocaleDateString('es-EC', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  } catch {
    return isoString
  }
}
</script>

<style>
@media print {
  body {
    background: white !important;
    color: black !important;
  }
  
  .no-print,
  nav,
  header,
  aside,
  .app-shell > header,
  .app-shell > aside {
    display: none !important;
  }

  #dece-print-acta {
    width: 100% !important;
    max-width: 100% !important;
    padding: 0 !important;
    margin: 0 !important;
    border: none !important;
    box-shadow: none !important;
  }

  @page {
    size: A4 portrait;
    margin: 15mm 15mm 15mm 15mm;
  }
}
</style>
