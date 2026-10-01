/**
 * LOGREVA — Motor Pedagógico y Algoritmos de Aprendizaje
 * Implementa el cálculo de Mastery, priorización de brechas pedagógicas,
 * agrupación accionable (3-5 grupos) y directivas de tutoría socrática.
 */

export const MASTERY_STATES = {
  NOT_EVIDENCED: 'NOT_EVIDENCED',
  DEVELOPING: 'DEVELOPING',
  COMPETENT: 'COMPETENT',
  MASTERED: 'MASTERED',
  AT_RISK_OF_FORGETTING: 'AT_RISK_OF_FORGETTING'
}

export const SEVERITY_LEVELS = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
  CRITICAL: 'critical'
}

/**
 * Determina el estado de dominio a partir de evidencias acumuladas.
 * No es un promedio simple de notas; evalúa consistencia, transferibilidad y peso temporal.
 * 
 * @param {Array<{ score: number, confidence: number, weight?: number, occurred_at?: string }>} evidences 
 * @returns {{ score: number, confidence: number, state: string, label: string, color: string }}
 */
export function calculateMasteryState(evidences = []) {
  if (!evidences || evidences.length === 0) {
    return {
      score: 0,
      confidence: 0,
      state: MASTERY_STATES.NOT_EVIDENCED,
      label: 'Sin evidencia',
      color: 'gray'
    }
  }

  // Ponderación exponencial temporal (las evidencias más recientes pesan más)
  let totalWeight = 0
  let weightedScore = 0
  let totalConfidence = 0

  evidences.forEach((ev, idx) => {
    const recencyWeight = Math.pow(1.15, idx) // Índice temporal ascendente
    const conf = ev.confidence ?? 0.8
    const baseWeight = (ev.weight ?? 1.0) * recencyWeight * conf

    weightedScore += ev.score * baseWeight
    totalWeight += baseWeight
    totalConfidence += conf
  })

  const finalScore = totalWeight > 0 ? Number((weightedScore / totalWeight).toFixed(3)) : 0
  const avgConfidence = Number((totalConfidence / evidences.length).toFixed(2))

  let state = MASTERY_STATES.DEVELOPING
  let label = 'En desarrollo'
  let color = 'amber'

  if (evidences.length >= 2 && finalScore >= 0.85 && avgConfidence >= 0.7) {
    state = MASTERY_STATES.MASTERED
    label = 'Dominado'
    color = 'emerald'
  } else if (finalScore >= 0.70 && avgConfidence >= 0.6) {
    state = MASTERY_STATES.COMPETENT
    label = 'Competente'
    color = 'blue'
  } else if (finalScore < 0.50) {
    state = MASTERY_STATES.DEVELOPING
    label = 'Requiere refuerzo'
    color = 'rose'
  }

  return {
    score: finalScore,
    confidence: avgConfidence,
    state,
    label,
    color
  }
}

/**
 * Fórmula conceptual de priorización:
 * priority = curricular_impact × severity × frequency × prerequisite_dependency
 * 
 * @param {Object} params
 * @param {number} params.curricularImpact - Peso del 1 al 2 según importancia curricular
 * @param {string} params.severity - 'low' | 'medium' | 'high' | 'critical'
 * @param {number} params.studentCount - Cantidad de estudiantes con esta brecha
 * @param {number} params.totalStudents - Total de estudiantes de la cohorte
 * @param {boolean} params.isPrerequisiteOfOther - Si es prerrequisito de otras competencias
 * @returns {number} Score numérico de prioridad (mayor = más urgente)
 */
export function calculateGapPriority({
  curricularImpact = 1.0,
  severity = 'medium',
  studentCount = 1,
  totalStudents = 30,
  isPrerequisiteOfOther = false
}) {
  const severityMultipliers = {
    low: 1.0,
    medium: 1.3,
    high: 1.7,
    critical: 2.2
  }

  const sevMult = severityMultipliers[severity] || 1.3
  const frequencyRatio = totalStudents > 0 ? Math.min(1.0, studentCount / totalStudents) : 0.1
  const freqMult = 1.0 + (frequencyRatio * 1.5) // De 1.0 a 2.5
  const prereqMult = isPrerequisiteOfOther ? 1.8 : 1.0

  const rawPriority = curricularImpact * sevMult * freqMult * prereqMult
  return Number(rawPriority.toFixed(2))
}

/**
 * Genera entre 3 y 5 grupos pedagógicos viables y accionables para el docente,
 * agrupando estudiantes con dificultades causales comunes en lugar de planes individuales inviables.
 * 
 * @param {Array<{ id: string, name: string, gaps: Array<{ competencyId: string, competencyName: string, causeCompetencyId?: string, causeName?: string, severity: string }> }>} studentsWithGaps 
 * @param {Array<Object>} availableInterventions 
 * @returns {Array<{ id: string, title: string, reason: string, competencyName: string, students: Array<Object>, suggestedIntervention: Object, estimatedTimeMinutes: number }>}
 */
export function generateActionablePedagogicalGroups(studentsWithGaps = [], availableInterventions = []) {
  if (!studentsWithGaps || studentsWithGaps.length === 0) {
    return []
  }

  // Agrupar brechas por competencia o prerrequisito causal
  const clusters = new Map()

  studentsWithGaps.forEach(student => {
    (student.gaps || []).forEach(gap => {
      const key = gap.causeCompetencyId || gap.competencyId
      const targetName = gap.causeName || gap.competencyName

      if (!clusters.has(key)) {
        clusters.set(key, {
          competencyId: key,
          competencyName: targetName,
          severity: gap.severity,
          isRootCause: !!gap.causeCompetencyId,
          students: new Map()
        })
      }

      const cluster = clusters.get(key)
      cluster.students.set(student.id, {
        id: student.id,
        name: student.name,
        severity: gap.severity
      })
    })
  })

  // Convertir a lista y ordenar por cantidad de estudiantes afectados y severidad
  const sortedClusters = Array.from(clusters.values())
    .map(c => ({
      ...c,
      studentList: Array.from(c.students.values())
    }))
    .filter(c => c.studentList.length > 0)
    .sort((a, b) => b.studentList.length - a.studentList.length)

  // Limitar a máximo 4 grupos principales + 1 grupo de aceleración/autónomo si aplica (3 a 5 grupos)
  const topClusters = sortedClusters.slice(0, 4)

  return topClusters.map((cluster, idx) => {
    const persistedIntervention = availableInterventions.find(i => i.competency_id === cluster.competencyId)
    const intervention = persistedIntervention ? {
      ...persistedIntervention,
      isPersisted: true
    } : {
      id: null,
      title: `Práctica guiada en ${cluster.competencyName}`,
      description: `Microintervención focalizada de 15 minutos para reforzar conceptos clave con material concreto y ejemplos resueltos.`,
      duration_minutes: 15,
      strategy: 'guided_practice',
      isPersisted: false
    }

    return {
      id: `group-${cluster.competencyId}`,
      groupNumber: idx + 1,
      title: `Grupo de Recuperación ${idx + 1}: ${cluster.competencyName}`,
      reason: cluster.isRootCause 
        ? `Dificultad compartida originada en el prerrequisito básico: ${cluster.competencyName}`
        : `Brecha focalizada en ${cluster.competencyName}`,
      competencyName: cluster.competencyName,
      competencyId: cluster.competencyId,
      students: cluster.studentList,
      studentCount: cluster.studentList.length,
      suggestedIntervention: intervention,
      estimatedTimeMinutes: intervention.duration_minutes || 15
    }
  })
}

/**
 * Políticas y Guardrails Socráticos:
 * Evalúa una respuesta o consulta del estudiante garantizando que el tutor
 * NUNCA entregue la solución directa durante fases de práctica.
 * 
 * @param {string} promptText - Consulta o intento del estudiante
 * @param {Object} itemContext - Pregunta, respuesta correcta y pistas progresivas
 * @param {number} hintLevel - Nivel de pista solicitado (0 = primera pista, 1 = segunda, etc.)
 * @returns {{ allowDirectAnswer: boolean, reply: string, nextHintLevel: number }}
 */
export function evaluateSocraticInteraction(promptText, itemContext, hintLevel = 0) {
  const isAskingDirectSolution = /(dime la respuesta|cu[aá]l es|resu[eé]lvelo|dame la soluci[oó]n|cu[aá]nto da)/i.test(promptText)

  const hints = itemContext?.hints || [
    'Revisa con atención los datos del problema antes de calcular.',
    'Intenta descomponer el problema en un paso intermedio.',
    'Recuerda la regla básica que relaciona los términos.'
  ]

  if (isAskingDirectSolution) {
    const safeHint = hints[Math.min(hintLevel, hints.length - 1)]
    return {
      allowDirectAnswer: false,
      reply: `Mi objetivo es ayudarte a descubrir la solución por ti mismo. 💡 Pista: ${safeHint} ¿Qué se te ocurre intentar con esta pista?`,
      nextHintLevel: Math.min(hintLevel + 1, hints.length - 1)
    }
  }

  // Si el estudiante propone un intento o razonamiento
  return {
    allowDirectAnswer: false,
    reply: `¡Buen intento de razonamiento! Observa detenidamente los pasos que diste: ${hints[Math.min(hintLevel, hints.length - 1)]}`,
    nextHintLevel: Math.min(hintLevel + 1, hints.length - 1)
  }
}
