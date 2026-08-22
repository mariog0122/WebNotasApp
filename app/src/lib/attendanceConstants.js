/**
 * Constantes y utilidades para el Módulo de Asistencia.
 */

export const ATTENDANCE_STATUSES = Object.freeze({
  presente: {
    id: 'presente',
    label: 'Presente',
    code: 'P',
    color: 'emerald',
    badgeClass: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20',
    buttonActive: 'bg-emerald-600 text-white shadow-sm ring-2 ring-emerald-500/50',
    buttonInactive: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-emerald-500/10 hover:text-emerald-600',
    tableBg: 'bg-emerald-50 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-300',
  },
  atraso: {
    id: 'atraso',
    label: 'Atraso',
    code: 'A',
    color: 'amber',
    badgeClass: 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/20',
    buttonActive: 'bg-amber-500 text-white shadow-sm ring-2 ring-amber-500/50',
    buttonInactive: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-amber-500/10 hover:text-amber-600',
    tableBg: 'bg-amber-50 text-amber-800 dark:bg-amber-950/40 dark:text-amber-300',
  },
  falta_injustificada: {
    id: 'falta_injustificada',
    label: 'Falta Injustificada',
    code: 'FI',
    color: 'rose',
    badgeClass: 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-500/20',
    buttonActive: 'bg-rose-600 text-white shadow-sm ring-2 ring-rose-500/50',
    buttonInactive: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-rose-500/10 hover:text-rose-600',
    tableBg: 'bg-rose-50 text-rose-800 dark:bg-rose-950/40 dark:text-rose-300',
  },
  falta_justificada: {
    id: 'falta_justificada',
    label: 'Falta Justificada',
    code: 'FJ',
    color: 'sky',
    badgeClass: 'bg-sky-500/10 text-sky-600 dark:text-sky-400 border-sky-500/20',
    buttonActive: 'bg-sky-600 text-white shadow-sm ring-2 ring-sky-500/50',
    buttonInactive: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-sky-500/10 hover:text-sky-600',
    tableBg: 'bg-sky-50 text-sky-800 dark:bg-sky-950/40 dark:text-sky-300',
  },
  fuga: {
    id: 'fuga',
    label: 'Fuga / Evasión',
    code: 'F',
    color: 'purple',
    badgeClass: 'bg-purple-500/10 text-purple-600 dark:text-purple-400 border-purple-500/20',
    buttonActive: 'bg-purple-600 text-white shadow-sm ring-2 ring-purple-500/50',
    buttonInactive: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-purple-500/10 hover:text-purple-600',
    tableBg: 'bg-purple-50 text-purple-800 dark:bg-purple-950/40 dark:text-purple-300',
  },
})

export const HOUR_BLOCKS = [
  { id: 'jornada_completa', label: 'Jornada Completa / General' },
  { id: '1', label: '1ª Hora' },
  { id: '2', label: '2ª Hora' },
  { id: '3', label: '3ª Hora' },
  { id: '4', label: '4ª Hora' },
  { id: '5', label: '5ª Hora' },
  { id: '6', label: '6ª Hora' },
  { id: '7', label: '7ª Hora' },
]

/**
 * Calcula estadísticas y % de asistencia acumulado para un estudiante.
 */
export function calculateStudentAttendanceStats(records = []) {
  let presentCount = 0
  let lateCount = 0
  let unexcusedCount = 0
  let excusedCount = 0
  let truantCount = 0

  records.forEach(r => {
    switch (r.status) {
      case 'presente':
        presentCount++
        break
      case 'atraso':
        lateCount++
        // Un atraso computa como presente con retraso
        presentCount++
        break
      case 'falta_injustificada':
        unexcusedCount++
        break
      case 'falta_justificada':
        excusedCount++
        break
      case 'fuga':
        truantCount++
        unexcusedCount++
        break
      default:
        break
    }
  })

  const totalEvaluated = records.length
  // El porcentaje se calcula sobre los días evaluados
  const percentage = totalEvaluated > 0
    ? ((presentCount) / totalEvaluated) * 100
    : 100

  // Según la normativa LOEI, menos del 85% de asistencia activa riesgo
  const isAtRisk = totalEvaluated >= 5 && percentage < 85

  return {
    totalEvaluated,
    presentCount,
    lateCount,
    unexcusedCount,
    excusedCount,
    truantCount,
    percentage: Math.round(percentage * 10) / 10,
    isAtRisk
  }
}

/**
 * Genera el mensaje para notificar al representante legal vía WhatsApp.
 */
export function buildAttendanceWhatsAppMessage({
  institutionName = 'Institución Educativa',
  studentName = '',
  courseName = '',
  subjectName = '',
  date = '',
  status = 'falta_injustificada',
  observations = '',
  representativeName = ''
}) {
  const greeting = representativeName
    ? `Estimado/a *${representativeName}* (Representante de *${studentName}*),`
    : `Estimado/a Representante de *${studentName}*,`

  const instHeader = `🏛️ *${institutionName.toUpperCase()}*`
  const dateFormatted = date ? `📅 *Fecha:* ${date}` : ''
  const subText = subjectName ? ` (Materia: ${subjectName})` : ''

  if (status === 'atraso') {
    return [
      instHeader,
      `⏰ *NOTIFICACIÓN DE ATRASO ESCOLAR*`,
      '',
      greeting,
      `Le informamos que el estudiante ha registrado un *ATRASO* en la jornada del curso *${courseName}*${subText}.`,
      dateFormatted,
      observations ? `📝 *Observación:* ${observations}` : '',
      '',
      `Agradecemos fomentar la puntualidad en el ingreso a clases para no perjudicar su desarrollo pedagógico.`,
      '',
      `_Atentamente,_\n*Inspección General / Docente*`
    ].filter(Boolean).join('\n')
  }

  if (status === 'fuga') {
    return [
      instHeader,
      `🚨 *ALERTA URGENTE: EVASIÓN / FUGA DE CLASES*`,
      '',
      greeting,
      `Le informamos con carácter de urgencia que el estudiante no estuvo presente en el aula durante la jornada del curso *${courseName}*${subText} habiendo ingresado previamente a la institución.`,
      dateFormatted,
      observations ? `📝 *Detalle:* ${observations}` : '',
      '',
      `Por favor comunicarse de inmediato con *Inspección General* para coordinar las medidas correspondientes.`,
      '',
      `_Atentamente,_\n*Inspección General*`
    ].filter(Boolean).join('\n')
  }

  // Falta Injustificada por defecto
  return [
    instHeader,
    `⚠️ *NOTIFICACIÓN DE INASISTENCIA ESCOLAR*`,
    '',
    greeting,
    `Le informamos que el estudiante registró *INASISTENCIA* el día de hoy en el curso *${courseName}*${subText}.`,
    dateFormatted,
    observations ? `📝 *Observación:* ${observations}` : '',
    '',
    `Recuerde que dispone de 48 horas laborables para presentar la debida justificación médica o institucional en *Inspección General*.`,
    '',
    `_Atentamente,_\n*Inspección General / Docente*`
  ].filter(Boolean).join('\n')
}
