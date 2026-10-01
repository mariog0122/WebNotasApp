export const DEFAULT_INSTITUTION_TIME_ZONE = 'America/Guayaquil'

/** Civil date for date/month inputs; audit timestamps must remain ISO UTC. */
export function institutionalDateKey(date = new Date(), timeZone = DEFAULT_INSTITUTION_TIME_ZONE) {
  const options = { year: 'numeric', month: '2-digit', day: '2-digit' }
  let formatter
  try {
    formatter = new Intl.DateTimeFormat('en-US', { ...options, timeZone: timeZone || DEFAULT_INSTITUTION_TIME_ZONE })
  } catch {
    formatter = new Intl.DateTimeFormat('en-US', { ...options, timeZone: DEFAULT_INSTITUTION_TIME_ZONE })
  }
  const parts = Object.fromEntries(formatter.formatToParts(date).map(({ type, value }) => [type, value]))
  return `${parts.year}-${parts.month}-${parts.day}`
}
