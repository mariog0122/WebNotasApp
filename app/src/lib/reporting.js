export const groupBy = (items, keyFn) => {
  const map = new Map()
  items.forEach(item => {
    const key = keyFn(item)
    if (!map.has(key)) map.set(key, [])
    map.get(key).push(item)
  })
  return map
}

export const getQuarterOrder = (quarterName) => {
  const name = (quarterName || '').toLowerCase()
  const digits = name.match(/\d+/)
  if (digits) return parseInt(digits[0], 10)
  if (name.includes('primer') || name.includes('1er') || name.includes('1ro')) return 1
  if (name.includes('segundo') || name.includes('2do')) return 2
  if (name.includes('tercer') || name.includes('3er')) return 3
  return 99
}

export const getPeriodLabel = (periodName) => {
  const name = (periodName || '').toLowerCase()
  if (name.includes('quimestre')) {
    if (name.includes('primer') || name.includes('1')) return '1Q'
    if (name.includes('segundo') || name.includes('2')) return '2Q'
  }
  if (name.includes('trimestre')) {
    if (name.includes('primer') || name.includes('1')) return '1T'
    if (name.includes('segundo') || name.includes('2')) return '2T'
    if (name.includes('tercer') || name.includes('3')) return '3T'
  }
  const order = getQuarterOrder(periodName)
  return order !== 99 ? `P${order}` : 'P'
}

export const computeProjectAverage = (projectSubjectGradesByStudent, selectedSubjectIds, studentId) => {
  if (!selectedSubjectIds || selectedSubjectIds.length === 0) return null
  const grades = projectSubjectGradesByStudent?.[studentId] || {}
  let sum = 0
  let count = 0
  selectedSubjectIds.forEach(subjectId => {
    const val = grades[subjectId]
    const num = parseFloat(val)
    if (!isNaN(num)) {
      sum += num
      count++
    }
  })
  if (count === 0) return null
  return sum / count
}

export const computeSubjectTotal = (definitions, studentGrades, projectAverage, subjectIsProject) => {
  const isProjectDefinition = (def) => {
    return def.category === 'SUMATIVA' && String(def.name || '').toLowerCase().includes('proyecto')
  }

  // Helper to get average of a combined list of categories
  const getAvg = (categories) => {
    const defs = definitions.filter(d => categories.includes(d.category))
    if (defs.length === 0) return null
    let sum = 0
    let count = 0
    defs.forEach(d => {
      let val = parseFloat(studentGrades?.[d.id])
      // Handle project override
      if (categories.includes('SUMATIVA') && isProjectDefinition(d) && subjectIsProject) {
        if (projectAverage !== null && projectAverage !== undefined) {
          val = projectAverage
        }
      }
      if (!isNaN(val)) {
        sum += val
        count++
      }
    })
    return count > 0 ? sum / count : null
  }

  const avgIndividual = getAvg(['INDIVIDUAL'])
  const avgGroup = getAvg(['GRUPAL'])
  const avgRefuerzo = getAvg(['REFUERZO'])
  const avgSummative = getAvg(['SUMATIVA'])

  const formativeParts = [avgIndividual, avgGroup, avgRefuerzo]
    .filter(v => v !== null && v !== undefined && !isNaN(v))
  const avgFormative = formativeParts.length > 0
    ? (formativeParts.reduce((s, v) => s + v, 0) / formativeParts.length)
    : null

  const weightedFormative = avgFormative !== null ? (avgFormative * 0.70) : null
  const weightedSummative = avgSummative !== null ? (avgSummative * 0.30) : null

  const total = (weightedFormative !== null && weightedSummative !== null)
    ? (weightedFormative + weightedSummative)
    : null

  return {
    avgIndividual,
    avgGroup,
    avgFormative,
    avgSum: avgSummative,
    weightedFormative,
    weightedSummative,
    total
  }
}


export const truncate2 = (value) => {
  if (value === null || value === undefined || isNaN(value)) return null
  return Math.trunc(value * 100) / 100
}

export const computeFinalAnnual = (p, s) => {
  if (p === null || p === undefined || isNaN(p)) return null
  const sVal = s === null || s === undefined || s === '' || isNaN(s) ? null : parseFloat(s)
  if (p >= 7) return p
  if (sVal === null) return p
  if (p < 4.01) return p
  if (sVal < 7) return p
  return 7
}

export const computeFinalObservation = (p, s, finalAnnual) => {
  if (p === null || p === undefined || isNaN(p)) return ''
  const sVal = s === null || s === undefined || s === '' || isNaN(s) ? null : parseFloat(s)
  if (p >= 7 && sVal !== null) return 'DEJE EN BLANCO EL CASILLERO SUPLETORIO'
  if (p < 5 && sVal !== null) return 'NO PUEDE RENDIR SUPLETORIO;REPRUEBA EL GRADO'
  if (finalAnnual !== null && finalAnnual < 7) return 'NO PROMOVIDO'
  if (finalAnnual !== null && finalAnnual >= 7) return 'PROMOVIDO'
  return ''
}

export const computeTrimesterObservation = (p) => {
  if (p === null || p === undefined || isNaN(p)) return ''
  if (p >= 7) return 'APROBADO'
  if (p >= 5) return 'SUPLETORIO'
  return 'REPROBADO'
}
