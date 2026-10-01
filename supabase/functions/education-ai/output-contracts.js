const isRecord = value => Boolean(value) && typeof value === 'object' && !Array.isArray(value)

function validateTree(value, depth = 0) {
  if (depth > 10) return false
  if (value === null || typeof value === 'boolean') return true
  if (typeof value === 'number') return Number.isFinite(value)
  if (typeof value === 'string') return value.length <= 20_000 && !/<script\b|javascript\s*:/i.test(value)
  if (Array.isArray(value)) return value.length <= 200 && value.every(item => validateTree(item, depth + 1))
  if (!isRecord(value)) return false
  const entries = Object.entries(value)
  return entries.length <= 200 && entries.every(([key, item]) => (
    !['__proto__', 'prototype', 'constructor'].includes(key)
    && key.length <= 100
    && validateTree(item, depth + 1)
  ))
}

export function isValidEducationAIOutput(action, output) {
  if (!isRecord(output) || !validateTree(output)) return false
  let encodedSize
  try { encodedSize = new TextEncoder().encode(JSON.stringify(output)).byteLength } catch { return false }
  if (encodedSize > 200_000) return false

  if (action === 'generatePlan') {
    return ['summary', 'didactic_sequence', 'evaluation_plan', 'inclusion_dua_plan', 'resources_plan']
      .every(key => isRecord(output[key]))
  }
  if (action === 'regenerateSection') return Object.keys(output).length > 0
  if (action === 'generateResource') return typeof output.title === 'string' && output.title.trim().length > 0
  if (action === 'generateStudentSupport') {
    return typeof output.diagnostic_summary === 'string'
      && Array.isArray(output.pedagogical_goals)
      && Array.isArray(output.weekly_plan)
      && Array.isArray(output.family_recommendations)
  }
  return false
}
