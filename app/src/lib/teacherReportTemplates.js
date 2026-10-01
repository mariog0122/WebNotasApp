/**
 * Modelos de Documentos y Plantillas Oficiales para el Módulo Informes Docentes.
 * 
 * Permite la generación de actas, citaciones, derivaciones DECE y reportes
 * con auto-relleno reactivo en vivo de datos del estudiante, docente,
 * representante e institución educativa.
 */

export const REPORT_TEMPLATES = Object.freeze({
  CITACION_REPRESENTANTE: 'citacion_representante',
  INFORME_RENDIMIENTO: 'informe_rendimiento',
  INFORME_COMPORTAMIENTO: 'informe_comportamiento',
  INFORME_DECE_VICERRECTORADO: 'informe_dece_vicerrectorado',
  ACTA_COMPROMISO: 'acta_compromiso',
})

export const RECIPIENT_ROLES = Object.freeze({
  REPRESENTANTE_LEGAL: {
    id: 'representante_legal',
    label: 'Representante Legal / Padre de Familia',
    shortLabel: 'Representante',
    badgeClass: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20',
  },
  DECE: {
    id: 'dece',
    label: 'Departamento de Consejería Estudiantil (DECE)',
    shortLabel: 'DECE',
    badgeClass: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border-indigo-500/20',
  },
  VICERRECTORADO: {
    id: 'vicerrectorado',
    label: 'Vicerrectorado Académico',
    shortLabel: 'Vicerrectorado',
    badgeClass: 'bg-sky-500/10 text-sky-600 dark:text-sky-400 border-sky-500/20',
  },
  INSPECCION: {
    id: 'inspeccion',
    label: 'Inspección General',
    shortLabel: 'Inspección',
    badgeClass: 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/20',
  },
  RECTORADO: {
    id: 'rectorado',
    label: 'Rectorado / Dirección',
    shortLabel: 'Rectorado',
    badgeClass: 'bg-purple-500/10 text-purple-600 dark:text-purple-400 border-purple-500/20',
  },
  TUTOR: {
    id: 'tutor',
    label: 'Docente Tutor de Curso',
    shortLabel: 'Tutor',
    badgeClass: 'bg-teal-500/10 text-teal-600 dark:text-teal-400 border-teal-500/20',
  },
})

export const REPORT_STATUSES = Object.freeze({
  borrador: {
    id: 'borrador',
    label: 'Borrador',
    badgeClass: 'bg-slate-500/10 text-slate-600 dark:text-slate-400 border-slate-500/20',
  },
  enviado: {
    id: 'enviado',
    label: 'Enviado / Notificado',
    badgeClass: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-500/20',
  },
  en_revision: {
    id: 'en_revision',
    label: 'En Revisión',
    badgeClass: 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/20',
  },
  atendido: {
    id: 'atendido',
    label: 'Atendido / Firmado',
    badgeClass: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20',
  },
  archivado: {
    id: 'archivado',
    label: 'Archivado',
    badgeClass: 'bg-zinc-500/10 text-zinc-600 dark:text-zinc-400 border-zinc-500/20',
  },
})

export const REPORT_PRIORITIES = Object.freeze({
  baja: { id: 'baja', label: 'Baja', color: 'text-slate-500' },
  normal: { id: 'normal', label: 'Normal', color: 'text-blue-500' },
  alta: { id: 'alta', label: 'Alta', color: 'text-amber-500' },
  urgente: { id: 'urgente', label: 'Urgente', color: 'text-rose-500' },
})

export const TEMPLATE_CONFIGS = [
  {
    type: REPORT_TEMPLATES.CITACION_REPRESENTANTE,
    title: 'Citación a Representante Legal',
    shortName: 'Citación',
    description: 'Convocatoria oficial con fecha, hora, motivo pedagógico o disciplinario y constancia de recepción.',
    defaultRecipientRole: 'representante_legal',
    icon: 'Mail',
    colorTheme: 'from-amber-600 to-amber-500',
    defaultReason: 'Revisión del rendimiento académico y establecimiento de acuerdos pedagógicos para la mejora del estudiante.',
    defaultObservations: 'Se solicita puntual asistencia para tratar asuntos de vital importancia en el proceso de enseñanza-aprendizaje de su representado/a.',
    defaultAgreements: 'El representante legal se compromete a realizar el seguimiento continuo de tareas y actividades en el hogar.',
    defaultRecommendations: 'Asistir con cédula de identidad original o documento habilitante.',
  },
  {
    type: REPORT_TEMPLATES.INFORME_RENDIMIENTO,
    title: 'Informe de Rendimiento Académico',
    shortName: 'Rendimiento',
    description: 'Reporte técnico detallando dificultades de aprendizaje, notas cuantitativas, refuerzos y plan de mejora.',
    defaultRecipientRole: 'vicerrectorado',
    icon: 'FileSpreadsheet',
    colorTheme: 'from-teal-600 to-teal-500',
    defaultReason: 'Informe pedagógico de bajo rendimiento académico y aplicación de estrategias de refuerzo.',
    defaultObservations: 'El estudiante presenta dificultades persistentes en la comprensión y aplicación de destrezas clave en la asignatura.',
    defaultAgreements: 'Implementación de talleres guiados, tutorías de refuerzo pedagógico y entrega semanal de avances.',
    defaultRecommendations: 'Revisión y acompañamiento supervisado de actividades escolares y refuerzo extraclase.',
  },
  {
    type: REPORT_TEMPLATES.INFORME_COMPORTAMIENTO,
    title: 'Informe de Convivencia y Disciplina',
    shortName: 'Comportamiento',
    description: 'Notificación formal de incidencias de convivencia escolar, faltas cometidas y acciones formativas aplicadas.',
    defaultRecipientRole: 'inspeccion',
    icon: 'ShieldAlert',
    colorTheme: 'from-rose-600 to-rose-500',
    defaultReason: 'Incidencia de comportamiento que afecta el clima armónico en el aula de clases.',
    defaultObservations: 'Se registra falta a las normas de convivencia escolar en la jornada de clases, dialogando inicialmente con el estudiante.',
    defaultAgreements: 'Compromiso de conducta positiva, respeto mutuo con docentes y compañeros, y seguimiento semanal con Inspección.',
    defaultRecommendations: 'Diálogo reflexivo en el entorno familiar sobre la importancia de la disciplina y el cumplimiento de normas.',
  },
  {
    type: REPORT_TEMPLATES.INFORME_DECE_VICERRECTORADO,
    title: 'Informe Técnico / Derivación al DECE',
    shortName: 'Derivación DECE',
    description: 'Derivación técnica al Departamento de Consejería Estudiantil para valoración psicopedagógica o apoyo socioemocional.',
    defaultRecipientRole: 'dece',
    icon: 'UserCheck',
    colorTheme: 'from-indigo-600 to-indigo-500',
    defaultReason: 'Derivación técnica para evaluación y acompañamiento psicopedagógico / NEE.',
    defaultObservations: 'Se observan signos de desatención prolongada, posibles Necesidades Educativas Específicas o factores socioafectivos que requieren intervención especializada.',
    defaultAgreements: 'Coordinación docente-DECE para la aplicación de adaptaciones curriculares grado 1, 2 o 3 según corresponda.',
    defaultRecommendations: 'Entrevista integral con el departamento de consejería estudiantil y emisión del informe de valoración.',
  },
  {
    type: REPORT_TEMPLATES.ACTA_COMPROMISO,
    title: 'Acta de Compromiso Académico y Disciplinario',
    shortName: 'Acta de Compromiso',
    description: 'Acuerdo trilateral vinculante entre docente, representante legal y estudiante con metas de seguimiento.',
    defaultRecipientRole: 'representante_legal',
    icon: 'FileSignature',
    colorTheme: 'from-blue-600 to-blue-500',
    defaultReason: 'Suscripción de acta de compromiso académico y comportamental.',
    defaultObservations: 'Reunión presencial de común acuerdo para consolidar el plan de rescate académico y actitudinal del estudiante.',
    defaultAgreements: '1. El estudiante cumplirá puntualmente con todas las tareas y evaluaciones.\n2. El representante revisará diariamente el cuaderno y plataforma.\n3. El docente brindará retroalimentación periódica.',
    defaultRecommendations: 'Monitoreo conjunto cada 15 días hasta el cierre del periodo lectivo.',
  },
]

export function getTemplateConfig(templateType) {
  return (
    TEMPLATE_CONFIGS.find(t => t.type === templateType) ||
    TEMPLATE_CONFIGS[0]
  )
}

/**
 * Genera el texto formateado para notificación directa vía WhatsApp al representante legal.
 */
export function buildTeacherReportWhatsAppMessage({
  institutionName = 'Institución Educativa',
  studentName = '',
  courseName = '',
  subjectName = '',
  teacherName = '',
  templateType = REPORT_TEMPLATES.CITACION_REPRESENTANTE,
  citationDate = '',
  citationTime = '',
  citationLocation = '',
  reason = '',
  representativeName = ''
}) {
  const greeting = representativeName
    ? `Estimado/a *${representativeName}* (Representante de *${studentName}*),`
    : `Estimado/a Representante de *${studentName}*,`

  const instHeader = `🏛️ *${institutionName.toUpperCase()}*`

  if (templateType === REPORT_TEMPLATES.CITACION_REPRESENTANTE) {
    const dateFormatted = citationDate ? `📅 *Fecha:* ${citationDate}` : ''
    const timeFormatted = citationTime ? `⏰ *Hora:* ${citationTime}` : ''
    const locFormatted = citationLocation ? `📍 *Lugar:* ${citationLocation}` : '📍 *Lugar:* Instalaciones del plantel'

    return [
      instHeader,
      `📌 *CITACIÓN OFICIAL DE REPRESENTANTE*`,
      '',
      greeting,
      `Por medio de la presente, se le convoca cordialmente a una reunión con el docente *${teacherName}* del curso *${courseName}*${subjectName ? ` (Materia: ${subjectName})` : ''}.`,
      '',
      dateFormatted,
      timeFormatted,
      locFormatted,
      `📝 *Motivo:* ${reason || 'Tratar asuntos pedagógicos y rendimiento escolar.'}`,
      '',
      `⚠️ *Importante:* Se solicita su puntual asistencia con su cédula de identidad para firmar el acta correspondiente.`,
      '',
      `_Atentamente,_\n*${teacherName || 'Docente / Tutor'}*`
    ].filter(Boolean).join('\n')
  }

  if (templateType === REPORT_TEMPLATES.ACTA_COMPROMISO) {
    return [
      instHeader,
      `🤝 *ACTA DE COMPROMISO ACADÉMICO / DISCIPLINARIO*`,
      '',
      greeting,
      `Le informamos que se ha registrado un acta de compromiso para el estudiante *${studentName}* en el curso *${courseName}*.`,
      `📝 *Motivo:* ${reason}`,
      '',
      `Agradecemos su valioso apoyo y supervisión constante en el hogar.`,
      '',
      `_Atentamente,_\n*${teacherName || 'Docente / Tutor'}*`
    ].join('\n')
  }

  // Informe general / Rendimiento / Convivencia
  return [
    instHeader,
    `📄 *INFORME EDUCATIVO INSTITUCIONAL*`,
    '',
    greeting,
    `Le comunicamos que el docente *${teacherName}* ha emitido un informe respecto a su representado/a *${studentName}* (${courseName}${subjectName ? ` - ${subjectName}` : ''}).`,
    `📝 *Detalle:* ${reason}`,
    '',
    `Puede solicitar detalles adicionales o coordinar una entrevista con el docente.`,
    '',
    `_Atentamente,_\n*${teacherName || 'Docente / Tutor'}*`
  ].join('\n')
}
