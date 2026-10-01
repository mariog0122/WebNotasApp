<script setup>
defineProps({
  institutionLogoUrl: {
    type: String,
    default: ''
  },
  institutionName: {
    type: String,
    default: ''
  },
  institutionTutorName: {
    type: String,
    default: ''
  },
  institutionRectorName: {
    type: String,
    default: ''
  },
  quarterName: {
    type: String,
    default: ''
  },
  courseName: {
    type: String,
    default: ''
  },
  studentName: {
    type: String,
    default: ''
  },
  hasStudents: {
    type: Boolean,
    default: false
  },
  hasSelectedStudent: {
    type: Boolean,
    default: false
  },
  individualLoading: {
    type: Boolean,
    default: false
  },
  individualError: {
    type: String,
    default: ''
  },
  isQualitativeCourse: {
    type: Boolean,
    default: false
  },
  individualSubjects: {
    type: Array,
    default: () => []
  },
  individualProjectAverage: {
    type: [Number, null],
    default: null
  },
  individualAverage: {
    type: [Number, null],
    default: null
  }
})
</script>

<template>
  <div class="report-stack">
    <!-- CABECERA PARA PDF (VISIBLE AL EXPORTAR O IMPRIMIR) -->
    <div class="report-header screen-hidden">
      <img v-if="institutionLogoUrl" :src="institutionLogoUrl" alt="Logo" class="report-logo" />
      <div v-else style="width: 70px; height: 70px; background: #e2e8f0; display:flex; align-items:center; justify-content:center; flex-shrink:0;">Logo</div>
      <div class="report-header-content">
        <h1 style="margin: 0; color: #0f172a; font-size: 20px; font-weight: 800; text-transform: uppercase;">{{ institutionName || 'Unidad Educativa' }}</h1>
        <h2 style="margin: 0; color: #0f766e; font-size: 14px; font-weight: 700; margin-top: 2px;">Reporte Individual de Calificaciones</h2>
        <p style="margin: 0; color: #475569; font-size: 11px; margin-top: 4px;">
          Periodo: {{ quarterName }} | Curso: {{ courseName }} | Estudiante: {{ studentName }}
        </p>
        <p style="margin: 0; color: #475569; font-size: 10px; margin-top: 2px;">Generado el: {{ new Date().toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' }) }}</p>
      </div>
    </div>

    <section class="report-section print-page">
      <div v-if="!hasStudents" class="report-empty">No hay estudiantes en el curso.</div>
      <div v-else>
        <div class="report-section-head">
          <div>
            <p class="report-pill">Reporte Individual</p>
            <h3>{{ studentName || 'Seleccione un estudiante' }}</h3>
            <p class="report-section-note">
              Curso: {{ courseName }} · {{ quarterName }}
            </p>
          </div>
        </div>

        <div v-if="!hasSelectedStudent" class="report-empty">
          Selecciona un estudiante para ver su reporte.
        </div>
        <div v-else-if="individualLoading" class="report-loading">Cargando reporte individual...</div>
        <div v-else-if="individualError" class="report-alert report-alert-error">{{ individualError }}</div>
        <div v-else class="report-table-wrap">
          <div v-if="isQualitativeCourse" class="report-legend">
            Escala cualitativa: A+/A- (alcanzado), B+/B-/C+/C- (en proceso), D+/D-/E+/E- (iniciado).
          </div>
          <table class="report-table report-table-compact">
            <thead>
              <tr>
                <th>Asignatura</th>
                <th class="text-right" v-if="!isQualitativeCourse">Promedio</th>
                <th class="text-center" v-else>Calificacion</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in individualSubjects" :key="row.subject">
                <td>{{ row.subject }}</td>
                <td v-if="!isQualitativeCourse" class="text-right">{{ row.total?.toFixed(2) || '-' }}</td>
                <td v-else class="text-center">{{ row.qualitative || '-' }}</td>
              </tr>
              <tr v-if="!isQualitativeCourse && individualProjectAverage !== null && individualProjectAverage !== undefined">
                <td>Proyecto Interdisciplinario</td>
                <td class="text-right">{{ individualProjectAverage?.toFixed(2) || '-' }}</td>
              </tr>
            </tbody>
            <tfoot v-if="!isQualitativeCourse">
              <tr class="bg-gray-50">
                <td class="strong">Promedio General del Trimestre</td>
                <td class="text-right strong">{{ individualAverage !== null ? individualAverage.toFixed(2) : '-' }}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
    </section>

    <!-- Firmas -->
    <section class="report-section print-page">
      <div class="report-signatures">
        <div class="signature-date">
          <span class="report-meta-label">Fecha de Emisión:</span>
          <span class="report-meta-value">{{ new Date().toLocaleDateString('es-EC') }}</span>
        </div>
        <div class="signature-grid">
          <div class="report-signature-line">
            <span class="signature-name">{{ institutionTutorName || 'Tutor' }}</span>
            <span class="signature-role">DOCENTE TUTOR</span>
          </div>
          <div class="report-signature-line">
            <span class="signature-name">{{ institutionRectorName || 'Rector/a' }}</span>
            <span class="signature-role">RECTOR/A</span>
          </div>
          <div class="report-signature-line">
            <span class="signature-name">Secretario/a</span>
            <span class="signature-role">SECRETARIO/A</span>
          </div>
        </div>
        <div class="report-legal-note">
          <strong>Nota Legal:</strong> El presente documento tiene un fin estrictamente informativo para comunicar los resultados académicos obtenidos por el estudiante. Las calificaciones aquí reflejadas podrían presentar variaciones mínimas respecto al sistema oficial. La validez legal y definitiva de las notas está sujeta a la información registrada y emitida por la plataforma educativa del Ministerio de Educación (MINEDUC).
        </div>
      </div>
    </section>
  </div>
</template>

<style>
/* Firmas de la libreta individual: tres columnas con línea superior, nombre en negrita y cargo debajo.
   Estilos propios (no dependen de utilidades de otras vistas) para que pantalla, PDF e impresión coincidan. */
.report-stack .signature-date {
  margin-bottom: 1.5rem;
}

.report-stack .signature-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 2rem;
  margin-top: 4rem;
}

.report-stack .report-signature-line {
  padding-top: 0.6rem;
  border-top: 1.5px solid #1e293b;
  text-align: center;
}

.report-stack .signature-name {
  display: block;
  color: #0f172a;
  font-size: 0.78rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  line-height: 1.3;
  text-transform: uppercase;
  overflow-wrap: anywhere;
}

.report-stack .signature-role {
  display: block;
  margin-top: 0.2rem;
  color: #64748b;
  font-size: 0.66rem;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.dark .report-stack .report-signature-line {
  border-top-color: #64748b;
}

.dark .report-stack .signature-name {
  color: #e2e8f0;
}

.dark .report-stack .signature-role {
  color: #94a3b8;
}

@media screen and (max-width: 560px) {
  .report-stack .signature-grid {
    grid-template-columns: 1fr;
    gap: 2.75rem;
  }
}

/* Al imprimir siempre sobre papel blanco, con tinta oscura. */
@media print {
  .report-stack .signature-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
    margin-top: 44px !important;
  }

  .report-stack .report-signature-line {
    border-top-color: #1e293b !important;
  }

  .report-stack .signature-name {
    color: #0f172a !important;
  }

  .report-stack .signature-role {
    color: #64748b !important;
  }
}
</style>
