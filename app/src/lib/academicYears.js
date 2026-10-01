const ACADEMIC_YEAR_NAME_PATTERN = /^(\d{4})-(\d{4})$/

export const parseAcademicYearName = (value) => {
  const name = String(value || '').trim()
  const match = ACADEMIC_YEAR_NAME_PATTERN.exec(name)

  if (!match) {
    throw new Error('Usa el formato YYYY-YYYY, por ejemplo 2027-2028.')
  }

  const startYear = Number.parseInt(match[1], 10)
  const endYear = Number.parseInt(match[2], 10)

  if (endYear <= startYear) {
    throw new Error('El año de fin debe ser posterior al año de inicio.')
  }

  return { name, startYear, endYear }
}

export const buildAcademicYearCreateArgs = (name, makeCurrent = false, platformSchoolId = null) => {
  const parsed = parseAcademicYearName(name)
  const args = {
    p_name: parsed.name,
    p_start_year: parsed.startYear,
    p_end_year: parsed.endYear,
    p_make_current: Boolean(makeCurrent),
  }

  if (platformSchoolId) args.p_school_id = platformSchoolId
  return args
}
