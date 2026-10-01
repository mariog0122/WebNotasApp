import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

describe('AUDITOR DOCUMENTAL EDUCATIVO — MINEDUC ECUADOR (Print & PDF Quality QA)', () => {
  const planningPath = resolve(__dirname, '../src/components/planning/PlanningOfficialPrintDocument.vue')
  const teacherReportPath = resolve(__dirname, '../src/components/teacher-reports/TeacherReportPrintDocument.vue')
  const deceModalPath = resolve(__dirname, '../src/components/dece/DecePrintModal.vue')
  const reportsViewPath = resolve(__dirname, '../src/views/Reports.vue')
  const attendanceGridPath = resolve(__dirname, '../src/components/attendance/AttendanceMonthlyGridTab.vue')

  const planningSrc = readFileSync(planningPath, 'utf8')
  const teacherReportSrc = readFileSync(teacherReportPath, 'utf8')
  const deceModalSrc = readFileSync(deceModalPath, 'utf8')
  const reportsViewSrc = readFileSync(reportsViewPath, 'utf8')
  const attendanceGridSrc = readFileSync(attendanceGridPath, 'utf8')

  describe('Documento 1: Planificación Microcurricular Didáctica (ERCA / DUA)', () => {
    it('declares standard A4 portrait print size and margins', () => {
      expect(planningSrc).toMatch(/size:\s*A4\s+portrait/i)
      expect(planningSrc).toMatch(/margin:\s*12mm\s+15mm/i)
    })

    it('declares official authority reference (Normativa MINEDEC)', () => {
      expect(planningSrc).toContain('Normativa MINEDEC')
    })

    it('prevents pagination clipping by avoiding absolute positioning during print', () => {
      // In Chromium, position: absolute on the printable root breaks multi-page pagination
      expect(planningSrc).not.toMatch(/#printable-lesson-plan\s*\{[^}]*position:\s*absolute/i)
      expect(planningSrc).toMatch(/#printable-lesson-plan\s*\{[^}]*position:\s*static/i)
    })

    it('enforces table header repetition and row break avoidance', () => {
      expect(planningSrc).toMatch(/thead\s*\{[^}]*display:\s*table-header-group/i)
      expect(planningSrc).toMatch(/tr\s*\{[^}]*(?:page-break-inside|break-inside):\s*avoid/i)
    })

    it('prevents orphaned signatures across page breaks', () => {
      expect(planningSrc).toContain('planning-signatures')
      expect(planningSrc).toMatch(/\.planning-signatures\s*\{[^}]*(?:break-inside|page-break-inside):\s*avoid/i)
    })

    it('contains all 4 mandatory institutional and curricular sections', () => {
      expect(planningSrc).toContain('1. Datos Informativos')
      expect(planningSrc).toContain('2. Planificación Didáctica y Secuencia de Aprendizaje')
      expect(planningSrc).toContain('3. Adaptaciones Curriculares (Inclusión Educativa — Normativa MINEDEC)')
      expect(planningSrc).toContain('4. FIRMAS DE RESPONSABILIDAD')
      expect(planningSrc).toContain('DOCENTE')
      expect(planningSrc).toContain('COMISIÓN PEDAGÓGICA')
      expect(planningSrc).toContain('VICERRECTORADO')
    })
  })

  describe('Documento 2: Informes Docentes, Citaciones y Actas de Compromiso', () => {
    it('declares standard A4 portrait print size', () => {
      expect(teacherReportSrc).toMatch(/size:\s*A4\s+portrait/i)
    })

    it('prevents page break splitting on signature and receipt blocks', () => {
      expect(teacherReportSrc).toContain('report-signatures')
      expect(teacherReportSrc).toContain('report-talon')
      expect(teacherReportSrc).toMatch(/\.report-signatures\s*\{[^}]*(?:break-inside|page-break-inside):\s*avoid/i)
      expect(teacherReportSrc).toMatch(/\.report-talon\s*\{[^}]*(?:break-inside|page-break-inside):\s*avoid/i)
    })

    it('includes statutory fields for student, teacher, and legal representative', () => {
      expect(teacherReportSrc).toContain('Estudiante:')
      expect(teacherReportSrc).toContain('C.I. Estudiante:')
      expect(teacherReportSrc).toContain('Representante Legal:')
      expect(teacherReportSrc).toContain('Docente Emisor:')
      expect(teacherReportSrc).toContain('CORTE AQUÍ')
    })
  })

  describe('Documento 3: Actas DECE / Notificación y Medidas Formativas', () => {
    it('declares A4 portrait page size and margins', () => {
      expect(deceModalSrc).toMatch(/size:\s*A4\s+portrait/i)
      expect(deceModalSrc).toMatch(/margin:\s*15mm\s+15mm/i)
    })

    it('protects responsibility certification signatures from page breaks', () => {
      expect(deceModalSrc).toContain('dece-signatures')
      expect(deceModalSrc).toMatch(/\.dece-signatures\s*\{[^}]*(?:break-inside|page-break-inside):\s*avoid/i)
    })

    it('cites statutory LOEI legal framework', () => {
      expect(deceModalSrc).toContain('Reglamento General a la LOEI')
      expect(deceModalSrc).toContain('Art. 330')
    })
  })

  describe('Documento 4: Cuadros de Calificaciones y Actas de Promoción Escolar', () => {
    it('supports dynamic A4 landscape/portrait sizing according to report mode', () => {
      expect(reportsViewSrc).toMatch(/size:\s*A4\s+\$\{orientation\}/i)
    })

    it('enforces table header repetition and row break protection in print tables', () => {
      expect(reportsViewSrc).toMatch(/\.report-table thead\s*\{[^}]*display:\s*table-header-group/i)
      expect(reportsViewSrc).toMatch(/\.report-table tr\s*\{[^}]*break-inside:\s*avoid/i)
    })

    it('protects report signatures from page splitting', () => {
      expect(reportsViewSrc).toMatch(/\.report-signatures\s*\{[^}]*break-inside:\s*avoid/i)
    })
  })

  describe('Documento 5: Sábana de Asistencia Escolar Mensual', () => {
    it('declares A4 landscape layout for wide table grids', () => {
      expect(attendanceGridSrc).toMatch(/size:\s*A4\s+landscape/i)
    })

    it('includes institutional print header and legalization signatures', () => {
      expect(attendanceGridSrc).toContain('REGISTRO MENSUAL DE ASISTENCIA ESCOLAR')
      expect(attendanceGridSrc).toContain('CONTROL CONFORME A NORMATIVA MINEDEC')
      expect(attendanceGridSrc).toContain('attendance-signatures')
      expect(attendanceGridSrc).toMatch(/\.attendance-signatures\s*\{[^}]*(?:break-inside|page-break-inside):\s*avoid/i)
    })

    it('enforces table header repetition and row break avoidance on the matrix grid', () => {
      expect(attendanceGridSrc).toMatch(/thead\s*\{[^}]*display:\s*table-header-group/i)
      expect(attendanceGridSrc).toMatch(/tr\s*\{[^}]*(?:break-inside|page-break-inside):\s*avoid/i)
    })
  })
})
