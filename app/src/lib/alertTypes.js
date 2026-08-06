// Catálogo de tipos de alerta según normativa LOEI/RLOEI Ecuador

export const ALERT_TYPES = {
  INDISCIPLINA: { label: 'Indisciplina', color: 'bg-indigo-500/20 text-indigo-400', icon: 'UserX' },
  APROVECHAMIENTO: { label: 'Aprovechamiento', color: 'bg-blue-500/20 text-blue-400', icon: 'BookX' },
  FALTA: { label: 'Falta Injustificada', color: 'bg-amber-500/20 text-amber-400', icon: 'CalendarX' },
  FUGA: { label: 'Fuga', color: 'bg-rose-500/20 text-rose-400', icon: 'PersonStanding' },
  ATRASO: { label: 'Atraso', color: 'bg-orange-500/20 text-orange-400', icon: 'Clock' },
  USO_CELULAR: { label: 'Uso de Celular', color: 'bg-pink-500/20 text-pink-400', icon: 'Smartphone' },
  ACOSO: { label: 'Acoso/Bullying', color: 'bg-red-600/20 text-red-500', icon: 'ShieldAlert' },
  OTRA: { label: 'Otra', color: 'bg-slate-500/20 text-slate-400', icon: 'AlertCircle' }
}

// Gravedad según RLOEI Art. 330
export const ALERT_SEVERITIES = {
  LEVE: { label: 'Leve', color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' },
  GRAVE: { label: 'Grave', color: 'bg-amber-500/20 text-amber-400 border-amber-500/30' },
  MUY_GRAVE: { label: 'Muy Grave', color: 'bg-rose-500/20 text-rose-400 border-rose-500/30 animate-pulse' }
}

export const ALERT_STATUSES = {
  PENDIENTE: { label: 'Pendiente', color: 'bg-slate-500/20 text-slate-400' },
  EN_REVISION: { label: 'En Revisión', color: 'bg-blue-500/20 text-blue-400' },
  CONVOCADO: { label: 'Convocado', color: 'bg-purple-500/20 text-purple-400' },
  RESUELTO: { label: 'Resuelto', color: 'bg-emerald-500/20 text-emerald-400' },
  ARCHIVADO: { label: 'Archivado', color: 'bg-stone-500/20 text-stone-400' }
}

/**
 * Genera el mensaje para enviar por WhatsApp al representante
 * 
 * @param {Object} alertData - Datos de la alerta y del estudiante
 * @param {string} institutionName - Nombre de la institución
 * @returns {string} - Texto codificado para URL de WhatsApp
 */
export const generateWhatsAppMessage = (alertData, institutionName = 'Nuestra Institución') => {
  const { student_name, alert_type, date_occurred, severity, description } = alertData
  
  const formattedDate = new Date(date_occurred).toLocaleDateString('es-EC', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
  
  const typeLabel = ALERT_TYPES[alert_type]?.label || alert_type
  
  const text = `*DEPARTAMENTO DE CONSEJERÍA ESTUDIANTIL (DECE)*\n*${institutionName.toUpperCase()}*\n\nEstimado(a) representante de *${student_name}*.\n\nLe comunicamos que el estudiante ha registrado una novedad disciplinaria/académica:\n\n*Tipo:* ${typeLabel}\n*Fecha y Hora:* ${formattedDate}\n*Detalle:* ${description}\n\nPor favor, le solicitamos acercarse a la institución educativa para conversar sobre este particular con el DECE a la brevedad posible.\n\nGracias por su atención y compromiso.`
  
  return encodeURIComponent(text)
}
