import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { 
  REPORT_TEMPLATES, 
  TEMPLATE_CONFIGS, 
  RECIPIENT_ROLES, 
  REPORT_STATUSES, 
  getTemplateConfig, 
  buildTeacherReportWhatsAppMessage 
} from '../src/lib/teacherReportTemplates'

describe('Teacher Reports Module (Informes Docentes)', () => {
  const migrationSource = readFileSync(resolve(__dirname, '../../migrations/47_teacher_reports_module.sql'), 'utf8')
  const hardeningMigrationSource = readFileSync(resolve(__dirname, '../../supabase/migrations/20260916023802_harden_teacher_reports_authorization.sql'), 'utf8')
  const composableSource = readFileSync(resolve(__dirname, '../src/composables/useTeacherReports.js'), 'utf8')
  const editorModalSource = readFileSync(resolve(__dirname, '../src/components/teacher-reports/TeacherReportEditorModal.vue'), 'utf8')
  const printDocSource = readFileSync(resolve(__dirname, '../src/components/teacher-reports/TeacherReportPrintDocument.vue'), 'utf8')
  const mainViewSource = readFileSync(resolve(__dirname, '../src/views/TeacherReports.vue'), 'utf8')
  const routerSource = readFileSync(resolve(__dirname, '../src/router/index.js'), 'utf8')
  const sidebarSource = readFileSync(resolve(__dirname, '../src/components/Sidebar.vue'), 'utf8')

  it('defines 5 official document templates with valid configurations', () => {
    expect(Object.keys(REPORT_TEMPLATES)).toHaveLength(5)
    expect(TEMPLATE_CONFIGS).toHaveLength(5)

    const citacion = getTemplateConfig(REPORT_TEMPLATES.CITACION_REPRESENTANTE)
    expect(citacion.title).toBe('Citación a Representante Legal')
    expect(citacion.defaultRecipientRole).toBe('representante_legal')

    const rendimiento = getTemplateConfig(REPORT_TEMPLATES.INFORME_RENDIMIENTO)
    expect(rendimiento.title).toBe('Informe de Rendimiento Académico')

    const comportamiento = getTemplateConfig(REPORT_TEMPLATES.INFORME_COMPORTAMIENTO)
    expect(comportamiento.title).toBe('Informe de Convivencia y Disciplina')

    const dece = getTemplateConfig(REPORT_TEMPLATES.INFORME_DECE_VICERRECTORADO)
    expect(dece.title).toBe('Informe Técnico / Derivación al DECE')

    const acta = getTemplateConfig(REPORT_TEMPLATES.ACTA_COMPROMISO)
    expect(acta.title).toBe('Acta de Compromiso Académico y Disciplinario')
  })

  it('generates rich formatted WhatsApp message for parent citations', () => {
    const message = buildTeacherReportWhatsAppMessage({
      institutionName: 'Colegio Experimental Guayaquil',
      studentName: 'Carlos Andrés Mendoza',
      courseName: '10mo Año EGB - Paralelo A',
      subjectName: 'Matemáticas',
      teacherName: 'Prof. Mario Gómez',
      templateType: REPORT_TEMPLATES.CITACION_REPRESENTANTE,
      citationDate: '2026-08-25',
      citationTime: '09:30',
      citationLocation: 'Sala de Profesores',
      reason: 'Revisión de actividades de refuerzo pedagógico del primer trimestre.',
      representativeName: 'Sra. Elena Mendoza'
    })

    expect(message).toContain('COLEGIO EXPERIMENTAL GUAYAQUIL')
    expect(message).toContain('CITACIÓN OFICIAL DE REPRESENTANTE')
    expect(message).toContain('Carlos Andrés Mendoza')
    expect(message).toContain('10mo Año EGB - Paralelo A')
    expect(message).toContain('2026-08-25')
    expect(message).toContain('09:30')
    expect(message).toContain('Prof. Mario Gómez')
    expect(message).toContain('Elena Mendoza')
  })

  // Real navigation and accessible SVG links are covered in
  // e2e/institution-authenticated.spec.js, independent of the icon library.

  it('verifies SQL migration 47 creates teacher_reports table, indexes and RLS', () => {
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.teacher_reports')
    expect(migrationSource).toContain('idx_teacher_reports_school_id')
    expect(migrationSource).toContain('idx_teacher_reports_teacher_id')
    expect(migrationSource).toContain('save_teacher_report')
    expect(migrationSource).toContain('teacher_reports_select')
    expect(migrationSource).toContain('teacher_reports_insert')
    expect(migrationSource).toContain('teacher_reports_update')
    expect(migrationSource).toContain('teacher_reports_delete')
  })

  it('verifies editor modal and print components integrate auto-fill and institutional letterhead', () => {
    expect(editorModalSource).toContain('formData.student_name')
    expect(editorModalSource).toContain('formData.representative_name')
    expect(editorModalSource).toContain('formData.representative_phone')
    expect(editorModalSource).toContain('onTemplateChange')
    expect(editorModalSource).toContain('onStudentChange')

    expect(printDocSource).toContain('printable-teacher-report')
    expect(printDocSource).toContain('loadHtml2Pdf')
    expect(printDocSource).toContain('TALÓN DE DESPRENDIBLE Y RECEPCIÓN')
    expect(printDocSource).toContain('institution_logo_url')

    expect(mainViewSource).toContain('Informes Docentes')
    expect(mainViewSource).toContain('TeacherReportEditorModal')
    expect(mainViewSource).toContain('TeacherReportPrintDocument')
  })

  it('fails closed in the browser and uses RPCs for every teacher-report mutation', () => {
    expect(composableSource).toContain("supabase.rpc('save_teacher_report'")
    expect(composableSource).toContain("supabase.rpc('set_teacher_report_status'")
    expect(composableSource).toContain("supabase.rpc('delete_teacher_report'")
    expect(composableSource).not.toMatch(/from\('teacher_reports'\)\.insert/)
    expect(composableSource).not.toMatch(/from\('teacher_reports'\)\.update/)
    expect(composableSource).not.toMatch(/from\('teacher_reports'\)\.delete/)
    expect(composableSource).not.toContain('school_id.is.null')
  })

  it('uses the reports permission consistently in the route and menu', () => {
    expect(routerSource).toMatch(/path: '\/teacher-reports'[\s\S]*?permission: 'reports\.read'/)
    expect(sidebarSource).toMatch(/can\('reports\.read'\)[\s\S]*?name: 'Informes Docentes'/)
  })

  it('validates tenant relationships and revokes direct teacher-report writes', () => {
    expect(hardeningMigrationSource).toContain('STUDENT_COURSE_MISMATCH')
    expect(hardeningMigrationSource).toContain('SUBJECT_COURSE_MISMATCH')
    expect(hardeningMigrationSource).toContain('QUARTER_TENANT_MISMATCH')
    expect(hardeningMigrationSource).toContain("private.has_intelligence_permission(v_school_id, 'reports.read')")
    expect(hardeningMigrationSource).toContain('set_teacher_report_status')
    expect(hardeningMigrationSource).toContain('delete_teacher_report')
    expect(hardeningMigrationSource).toContain('revoke insert, update, delete on table public.teacher_reports from authenticated')
    expect(hardeningMigrationSource).not.toMatch(/or\s+school_id\s+is\s+null/i)
  })
})
