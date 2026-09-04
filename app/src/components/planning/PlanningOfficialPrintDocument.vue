<script setup>
import { computed } from 'vue'
import { Printer, Download, X, FileText, CheckCircle2 } from 'lucide-vue-next'

const props = defineProps({
  plan: {
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
  }
})

const printPlan = () => {
  window.print()
}

const downloadPdf = async () => {
  // Disparar impresión nativa del navegador que permite Guardar como PDF
  window.print()
}
</script>

<template>
  <div class="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-2 sm:p-4 overflow-y-auto">
    <div class="bg-white text-slate-900 rounded-2xl shadow-2xl w-full max-w-4xl max-h-[94vh] flex flex-col overflow-hidden">
      
      <!-- Top Action Bar (No Print) -->
      <div class="px-6 py-3 border-b border-slate-200 flex items-center justify-between bg-slate-100 no-print">
        <div class="flex items-center gap-2">
          <FileText class="w-5 h-5 text-indigo-600" />
          <h3 class="text-xs font-bold text-slate-800 uppercase tracking-wider">
            Documento Oficial de Planificación Didáctica (MinEduc Ecuador)
          </h3>
        </div>

        <div class="flex items-center gap-2">
          <button
            @click="printPlan"
            type="button"
            class="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow transition-all cursor-pointer"
          >
            <Printer class="w-4 h-4" />
            Imprimir / Guardar PDF
          </button>
          
          <button
            @click="onClose"
            type="button"
            class="p-1.5 rounded-xl text-slate-500 hover:bg-slate-200 transition-colors"
          >
            <X class="w-5 h-5" />
          </button>
        </div>
      </div>

      <!-- Document Content Body (Printable Area) -->
      <div class="p-8 sm:p-12 overflow-y-auto flex-1 custom-scrollbar text-slate-900 bg-white" id="printable-lesson-plan">
        
        <!-- Institutional Header -->
        <div class="text-center border-b-2 border-slate-900 pb-4 space-y-1">
          <h1 class="text-base font-extrabold uppercase tracking-wide">
            {{ institutionConfig.institution_name || 'UNIDAD EDUCATIVA FISCAL' }}
          </h1>
          <h2 class="text-xs font-bold uppercase tracking-wider text-slate-700">
            PLANIFICACIÓN MICROCURRICULAR DE CLASE / UNIDAD
          </h2>
          <p class="text-[11px] font-semibold text-slate-600 font-mono">
            AÑO LECTIVO: {{ plan.academic_year || '2025 - 2026' }} · RÉGIMEN: {{ plan.regime === 'costa_galapagos' ? 'COSTA – GALÁPAGOS' : 'SIERRA – AMAZONÍA' }}
          </p>
        </div>

        <!-- 1. DATOS INFORMATIVOS -->
        <div class="mt-4 border border-slate-900 text-xs">
          <div class="bg-slate-200 px-3 py-1 font-bold border-b border-slate-900 uppercase">
            1. Datos Informativos
          </div>
          <div class="grid grid-cols-2 md:grid-cols-4 p-2.5 gap-2">
            <div>
              <span class="font-bold block text-[10px] text-slate-500 uppercase">Docente:</span>
              <span class="font-semibold">{{ plan.teacher_name || 'Docente Responsable' }}</span>
            </div>
            <div>
              <span class="font-bold block text-[10px] text-slate-500 uppercase">Área / Asignatura:</span>
              <span class="font-semibold">{{ plan.subject_name }}</span>
            </div>
            <div>
              <span class="font-bold block text-[10px] text-slate-500 uppercase">Grado / Curso:</span>
              <span class="font-semibold">{{ plan.grade_year }} - Paralelo {{ plan.parallel }}</span>
            </div>
            <div>
              <span class="font-bold block text-[10px] text-slate-500 uppercase">Duración:</span>
              <span class="font-semibold">{{ plan.duration_minutes * plan.session_count }} min ({{ plan.session_count }} sesiones)</span>
            </div>
          </div>
          <div class="border-t border-slate-300 p-2.5 grid grid-cols-1 md:grid-cols-2 gap-2">
            <div>
              <span class="font-bold block text-[10px] text-slate-500 uppercase">Unidad Didáctica:</span>
              <span>{{ plan.unit_title }}</span>
            </div>
            <div>
              <span class="font-bold block text-[10px] text-slate-500 uppercase">Tema de Clase:</span>
              <span class="font-bold">{{ plan.topic_title }}</span>
            </div>
          </div>
          <div class="border-t border-slate-300 p-2.5">
            <span class="font-bold block text-[10px] text-slate-500 uppercase">Objetivo de Aprendizaje:</span>
            <p class="text-[11px] leading-relaxed">{{ plan.learning_objectives?.[0] || 'Objetivo de la destreza.' }}</p>
          </div>
        </div>

        <!-- 2. PLANIFICACIÓN CURRICULAR -->
        <div class="mt-4 border border-slate-900 text-xs">
          <div class="bg-slate-200 px-3 py-1 font-bold border-b border-slate-900 uppercase">
            2. Planificación Didáctica y Secuencia de Aprendizaje
          </div>

          <table class="w-full text-left border-collapse">
            <thead>
              <tr class="bg-slate-100 border-b border-slate-900 text-[10px] uppercase font-bold">
                <th class="p-2 border-r border-slate-900 w-1/4">Destrezas con Criterio de Desempeño (DCD)</th>
                <th class="p-2 border-r border-slate-900 w-1/4">Indicadores de Evaluación</th>
                <th class="p-2 border-r border-slate-900 w-1/3">Estrategias Metodológicas Activas (Ciclo ERCA)</th>
                <th class="p-2 w-1/6">Actividades Evaluativas</th>
              </tr>
            </thead>
            <tbody class="text-[11px] align-top">
              <tr>
                <!-- DCD -->
                <td class="p-2.5 border-r border-slate-900">
                  <span class="font-bold block font-mono text-[10px] mb-1">{{ plan.dcd_codes?.[0] }}</span>
                  <p class="leading-relaxed">{{ plan.dcd_descriptions?.[0] }}</p>
                </td>

                <!-- Indicador -->
                <td class="p-2.5 border-r border-slate-900">
                  <span class="font-bold block font-mono text-[10px] mb-1">INDICADOR MINEDUC</span>
                  <p class="leading-relaxed">{{ plan.evaluation_indicators?.[0] }}</p>
                </td>

                <!-- Secuencia ERCA -->
                <td class="p-2.5 border-r border-slate-900 space-y-2">
                  <div v-for="ph in (plan.didactic_sequence?.phases || [])" :key="ph.phase_id" class="border-b border-slate-200 pb-1.5 last:border-0">
                    <strong class="text-[11px] block font-bold text-indigo-900">{{ ph.name }} ({{ ph.time_minutes }} min)</strong>
                    <p class="text-[10px] text-slate-700 mt-0.5"><strong class="text-slate-900">Docente:</strong> {{ ph.teacher_activity }}</p>
                    <p class="text-[10px] text-slate-700 mt-0.5"><strong class="text-slate-900">Estudiante:</strong> {{ ph.student_activity }}</p>
                  </div>
                </td>

                <!-- Evaluación -->
                <td class="p-2.5 space-y-1.5">
                  <div>
                    <span class="font-bold block text-[10px] uppercase text-slate-500">Técnica:</span>
                    <span class="text-[10px]">{{ plan.evaluation_plan?.technique || 'Observación' }}</span>
                  </div>
                  <div>
                    <span class="font-bold block text-[10px] uppercase text-slate-500">Instrumento:</span>
                    <span class="text-[10px]">{{ plan.evaluation_plan?.instrument || 'Rúbrica' }}</span>
                  </div>
                  <div>
                    <span class="font-bold block text-[10px] uppercase text-slate-500">Evidencia:</span>
                    <span class="text-[10px]">{{ plan.evaluation_plan?.evidence }}</span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- 3. ADAPTACIONES CURRICULARES / DUA -->
        <div class="mt-4 border border-slate-900 text-xs">
          <div class="bg-slate-200 px-3 py-1 font-bold border-b border-slate-900 uppercase">
            3. Adaptaciones Curriculares (Inclusión Educativa — Normativa MINEDEC)
          </div>
          <div class="p-2.5 space-y-2.5 text-[11px]">
            <div v-for="(acc, aIdx) in (plan.inclusion_dua_plan?.accommodations || [])" :key="aIdx" class="border-b border-slate-200 pb-2 last:border-0">
              <div class="flex items-center justify-between">
                <strong class="font-bold text-slate-900">{{ acc.area }}</strong>
                <span v-if="acc.grade" class="font-bold text-[10px] bg-slate-100 px-1.5 py-0.5 border border-slate-300">
                  Grado {{ acc.grade }}
                </span>
              </div>
              <div v-if="acc.students?.length > 0" class="text-[10px] text-indigo-900 font-semibold my-0.5">
                <strong>Estudiantes con adaptación en este curso:</strong> {{ acc.students.join(', ') }}
              </div>
              <p class="text-slate-700 leading-relaxed mt-0.5">{{ acc.strategy }}</p>
            </div>
          </div>
        </div>

        <!-- 4. FIRMAS DE RESPONSABILIDAD -->
        <div class="mt-8 border-t border-slate-900 pt-8 grid grid-cols-3 gap-6 text-center text-xs">
          <div>
            <div class="border-t border-slate-900 mx-4 pt-1 font-bold">
              DOCENTE
            </div>
            <span class="text-[10px] text-slate-500">Elaborado</span>
          </div>

          <div>
            <div class="border-t border-slate-900 mx-4 pt-1 font-bold">
              COMISIÓN PEDAGÓGICA
            </div>
            <span class="text-[10px] text-slate-500">Revisado</span>
          </div>

          <div>
            <div class="border-t border-slate-900 mx-4 pt-1 font-bold">
              VICERRECTORADO
            </div>
            <span class="text-[10px] text-slate-500">Aprobado</span>
          </div>
        </div>

      </div>

    </div>
  </div>
</template>

<style>
@media print {
  body * {
    visibility: hidden;
  }
  #printable-lesson-plan, #printable-lesson-plan * {
    visibility: visible;
  }
  #printable-lesson-plan {
    position: absolute;
    left: 0;
    top: 0;
    width: 100%;
    margin: 0;
    padding: 20px;
    background: white !important;
    color: black !important;
  }
  .no-print {
    display: none !important;
  }
}
</style>
