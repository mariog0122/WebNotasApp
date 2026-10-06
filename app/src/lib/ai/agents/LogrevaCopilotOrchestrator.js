import { supabase } from '../../supabase'
import { hasAccessPermission, isInstitutionAdmin } from '../../permissions'
import { institutionalDateKey } from '../../civilDate'

// Read-only assistant. RLS authorizes data access; presentation roles grant nothing.
export class LogrevaCopilotOrchestrator {
  constructor(options = {}) {
    this.schoolId = options.schoolId || null
    this.userId = options.userId || null
    this.academicYear = options.academicYear || null
    this.accessContext = options.accessContext || null
    this.timeZone = options.timeZone
    this.currentRole = options.role || 'Docente'
  }

  setRole(role) { this.currentRole = role }

  requireAccess(permission) {
    if (!this.schoolId || !this.userId || this.accessContext?.userId !== this.userId
      || this.accessContext?.activeSchoolId !== this.schoolId
      || !hasAccessPermission(this.accessContext, permission)) {
      throw new Error('No tienes acceso a esta consulta en la institución seleccionada.')
    }
  }

  async getAttendanceSummary(dateStr = institutionalDateKey(new Date(), this.timeZone)) {
    this.requireAccess('attendance.read')
    if (!this.academicYear) throw new Error('Selecciona un año lectivo antes de consultar asistencia.')
    let query = supabase.from('attendance_records')
      .select('id,status,student:students(full_name),course:courses(name)', { count: 'exact' })
      .eq('school_id', this.schoolId).eq('attendance_date', dateStr).eq('academic_year', this.academicYear)
      .in('status', ['falta_injustificada', 'falta_justificada', 'atraso', 'fuga'])
    if (this.accessContext.activeMembership?.role === 'teacher' && !this.accessContext.isPlatformAdmin) {
      query = query.eq('teacher_id', this.userId)
    }
    const { data, count, error } = await query.order('id').limit(10)
    if (error || !Array.isArray(data)) throw new Error('No se pudo consultar la asistencia. Inténtalo nuevamente.')
    const labels = { atraso: 'Atraso', falta_justificada: 'Falta justificada', falta_injustificada: 'Falta injustificada', fuga: 'Fuga' }
    const details = data.map(item => ({
      student: item.student?.full_name || 'Estudiante no disponible',
      course: item.course?.name || 'Curso no disponible',
      status: labels[item.status] || item.status,
    }))
    // Different subjects/blocks can refer to one student: count records, not people.
    const total = Number.isInteger(count) ? count : details.length
    return {
      totalAbsences: total, date: dateStr, details,
      summary: total === 0
        ? `No hay novedades de asistencia registradas para ${dateStr} en tu ámbito de consulta.`
        : `Hay ${total} registros de novedades de asistencia para ${dateStr} en tu ámbito de consulta. Se muestran hasta 10 registros; un estudiante puede aparecer en varios bloques.`,
    }
  }

  async getActiveCourses() {
    this.requireAccess('grades.read')
    if (!this.academicYear) throw new Error('Selecciona un año lectivo antes de consultar cursos.')
    let ids = null
    if (this.accessContext.activeMembership?.role === 'teacher' && !this.accessContext.isPlatformAdmin) {
      const { data, error } = await supabase.from('course_subjects').select('course_id')
        .eq('school_id', this.schoolId).eq('teacher_id', this.userId)
      if (error || !Array.isArray(data)) throw new Error('No se pudieron consultar tus asignaciones.')
      ids = [...new Set(data.map(item => item.course_id).filter(Boolean))]
      if (!ids.length) return []
    }
    let query = supabase.from('courses').select('id,name,level')
      .eq('school_id', this.schoolId).eq('academic_year', this.academicYear)
    if (ids) query = query.in('id', ids)
    const { data, error } = await query.order('name').limit(8)
    if (error || !Array.isArray(data)) throw new Error('No se pudieron consultar los cursos.')
    return data
  }

  async processQuery(userInput) {
    const input = typeof userInput === 'string' ? userInput.trim().toLowerCase() : ''
    // Specific intents precede generic words such as "curso" or "estudiante".
    if (/aviso|comunicado|circular|mensaje/.test(input)) {
      this.requireAccess('students.read')
      return { type: 'notice', agentName: 'Asistente de Avisos',
        message: 'Para preparar un comunicado, define el curso, el motivo y la fecha en el Portal de Familias. No se ha generado ni enviado ningún mensaje.',
        actionRoute: '/families', actionText: 'Abrir Portal de Familias' }
    }
    if (/planific|dcd|erca|dua|unidad/.test(input)) {
      this.requireAccess('grades.read')
      return { type: 'planning', agentName: 'Asistente Curricular DUA/ERCA',
        message: 'Abre el módulo de Planificación IA para definir el curso y generar un borrador que puedas revisar.',
        actionRoute: '/planificacion-ia', actionText: 'Iniciar Asistente de Planificación' }
    }
    if (/alerta|riesgo|dece|bajo/.test(input)) {
      this.requireAccess('attendance.read')
      return { type: 'alerts', agentName: 'Asistente de Alertas',
        message: 'Consulta los casos registrados en Alertas Institucionales. El copiloto todavía no calcula un resumen de riesgos.',
        actionRoute: '/alerts', actionText: 'Ver Alertas Institucionales' }
    }
    if (/falt|asistenc/.test(input)) {
      const result = await this.getAttendanceSummary()
      return { type: 'attendance', agentName: 'Asistente de Asistencia', message: result.summary,
        data: result.details, actionRoute: '/attendance', actionText: 'Abrir Módulo de Asistencia' }
    }
    if (/tarea|pendiente|recordatorio|deber/.test(input)) {
      this.requireAccess('grades.read')
      return { type: 'tasks', agentName: 'Asistente de Tareas',
        message: 'El copiloto todavía no dispone de una agenda de tareas conectada. Puedes revisar las actividades y calificaciones en la libreta.',
        actionRoute: '/grades', actionText: 'Abrir Libreta' }
    }
    if (/curso|paralelo|mis clases|activos/.test(input)) {
      const courses = await this.getActiveCourses()
      const admin = isInstitutionAdmin(this.accessContext)
      return { type: 'courses', agentName: 'Asistente de Cursos',
        message: courses.length ? `Estos son hasta 8 cursos disponibles para ti en ${this.academicYear}.` : `No hay cursos disponibles para ti en ${this.academicYear}.`,
        data: courses, actionRoute: admin ? '/courses' : '/grades', actionText: admin ? 'Gestionar Cursos' : 'Abrir Libreta' }
    }
    if (/estudiante|alumno/.test(input)) {
      this.requireAccess('students.read')
      return { type: 'students', agentName: 'Asistente de Estudiantes',
        message: 'Busca y revisa los estudiantes autorizados en el módulo de Estudiantes.',
        actionRoute: '/students', actionText: 'Abrir Estudiantes' }
    }
    return { type: 'chat', agentName: 'Asistente Logreva',
      message: 'Puedo consultar asistencia y cursos, y ayudarte a abrir los módulos de estudiantes, avisos, planificación y alertas.',
      suggestions: ['¿Qué estudiantes faltaron hoy?', 'Muéstrame los cursos activos'] }
  }
}
