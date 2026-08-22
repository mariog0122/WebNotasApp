import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { 
  ATTENDANCE_STATUSES, 
  HOUR_BLOCKS, 
  calculateStudentAttendanceStats, 
  buildAttendanceWhatsAppMessage 
} from '../src/lib/attendanceConstants'

describe('Attendance Module (Módulo de Asistencia para Docentes e Inspección)', () => {
  const routerSource = readFileSync(resolve(__dirname, '../src/router/index.js'), 'utf8')
  const sidebarSource = readFileSync(resolve(__dirname, '../src/components/Sidebar.vue'), 'utf8')
  const migrationSource = readFileSync(resolve(__dirname, '../../migrations/48_attendance_module.sql'), 'utf8')
  const rollCallTabSource = readFileSync(resolve(__dirname, '../src/components/attendance/AttendanceRollCallTab.vue'), 'utf8')
  const justificationsTabSource = readFileSync(resolve(__dirname, '../src/components/attendance/AttendanceJustificationsTab.vue'), 'utf8')
  const monthlyGridTabSource = readFileSync(resolve(__dirname, '../src/components/attendance/AttendanceMonthlyGridTab.vue'), 'utf8')
  const mainViewSource = readFileSync(resolve(__dirname, '../src/views/Attendance.vue'), 'utf8')

  it('defines the 5 standard attendance statuses and hour blocks', () => {
    expect(ATTENDANCE_STATUSES.presente).toBeDefined()
    expect(ATTENDANCE_STATUSES.atraso).toBeDefined()
    expect(ATTENDANCE_STATUSES.falta_injustificada).toBeDefined()
    expect(ATTENDANCE_STATUSES.falta_justificada).toBeDefined()
    expect(ATTENDANCE_STATUSES.fuga).toBeDefined()

    expect(ATTENDANCE_STATUSES.presente.code).toBe('P')
    expect(ATTENDANCE_STATUSES.atraso.code).toBe('A')
    expect(ATTENDANCE_STATUSES.falta_injustificada.code).toBe('FI')
    expect(ATTENDANCE_STATUSES.falta_justificada.code).toBe('FJ')
    expect(ATTENDANCE_STATUSES.fuga.code).toBe('F')

    expect(HOUR_BLOCKS.length).toBeGreaterThanOrEqual(5)
  })

  it('calculates student attendance stats and flags risk below 85%', () => {
    const mockRecordsNormal = [
      { status: 'presente' },
      { status: 'presente' },
      { status: 'presente' },
      { status: 'atraso' },
      { status: 'presente' },
      { status: 'presente' },
      { status: 'presente' },
      { status: 'presente' },
      { status: 'falta_justificada' },
      { status: 'presente' },
    ]

    const statsNormal = calculateStudentAttendanceStats(mockRecordsNormal)
    expect(statsNormal.totalEvaluated).toBe(10)
    expect(statsNormal.percentage).toBeGreaterThanOrEqual(85)
    expect(statsNormal.isAtRisk).toBe(false)

    const mockRecordsRisk = [
      { status: 'presente' },
      { status: 'falta_injustificada' },
      { status: 'falta_injustificada' },
      { status: 'falta_injustificada' },
      { status: 'presente' },
      { status: 'fuga' },
    ]

    const statsRisk = calculateStudentAttendanceStats(mockRecordsRisk)
    expect(statsRisk.totalEvaluated).toBe(6)
    expect(statsRisk.percentage).toBeLessThan(85)
    expect(statsRisk.isAtRisk).toBe(true)
  })

  it('generates institutional WhatsApp notifications for tardiness and absences', () => {
    const msgAbsence = buildAttendanceWhatsAppMessage({
      institutionName: 'Unidad Educativa San Francisco',
      studentName: 'Mateo Alejandro Torres',
      courseName: '8vo Año EGB - Paralelo B',
      subjectName: 'Ciencias Naturales',
      date: '2026-08-22',
      status: 'falta_injustificada',
      observations: 'No ingresó al primer bloque pedagógico.',
      representativeName: 'Sr. Carlos Torres'
    })

    expect(msgAbsence).toContain('UNIDAD EDUCATIVA SAN FRANCISCO')
    expect(msgAbsence).toContain('NOTIFICACIÓN DE INASISTENCIA ESCOLAR')
    expect(msgAbsence).toContain('Mateo Alejandro Torres')
    expect(msgAbsence).toContain('8vo Año EGB - Paralelo B')
    expect(msgAbsence).toContain('2026-08-22')
    expect(msgAbsence).toContain('Carlos Torres')

    const msgTardiness = buildAttendanceWhatsAppMessage({
      institutionName: 'Unidad Educativa San Francisco',
      studentName: 'Ana Belén Morales',
      courseName: '10mo EGB',
      date: '2026-08-22',
      status: 'atraso',
      observations: 'Llegó 20 min tarde'
    })

    expect(msgTardiness).toContain('NOTIFICACIÓN DE ATRASO ESCOLAR')
    expect(msgTardiness).toContain('Ana Belén Morales')
  })

  it('registers /attendance route in router and Asistencia navLink in Sidebar', () => {
    expect(routerSource).toContain("path: '/attendance'")
    expect(routerSource).toContain("name: 'attendance'")
    expect(sidebarSource).toContain("name: 'Asistencia'")
    expect(sidebarSource).toContain("path: '/attendance'")
    expect(sidebarSource).toContain("CalendarCheck")
  })

  it('verifies SQL Migration 48 creates attendance_records table, RPCs and RLS', () => {
    expect(migrationSource).toContain('CREATE TABLE IF NOT EXISTS public.attendance_records')
    expect(migrationSource).toContain('unique_student_attendance_entry')
    expect(migrationSource).toContain('save_attendance_batch')
    expect(migrationSource).toContain('justify_attendance_records')
    expect(migrationSource).toContain('attendance_records_select')
    expect(migrationSource).toContain('attendance_records_insert')
    expect(migrationSource).toContain('attendance_records_update')
  })

  it('verifies tab components provide 1-click roll call, justifications, monthly grid and alerts', () => {
    expect(rollCallTabSource).toContain('Marcar Todos Presentes (1 Clic)')
    expect(rollCallTabSource).toContain('Guardar Asistencia')
    expect(rollCallTabSource).toContain('onSetStatus')

    expect(justificationsTabSource).toContain('Buscar Estudiante')
    expect(justificationsTabSource).toContain('Faltas / Atrasos Pendientes')
    expect(justificationsTabSource).toContain('onSubmitJustification')

    expect(monthlyGridTabSource).toContain('Exportar CSV')
    expect(monthlyGridTabSource).toContain('Imprimir Sábana')
    expect(monthlyGridTabSource).toContain('% Asist.')

    expect(mainViewSource).toContain('Control de Asistencia')
    expect(mainViewSource).toContain('AttendanceRollCallTab')
    expect(mainViewSource).toContain('AttendanceJustificationsTab')
    expect(mainViewSource).toContain('AttendanceMonthlyGridTab')
  })
})
