export const maskIdentifier = (value) => {
  const normalized = String(value || '').trim()
  if (!normalized || normalized === '-') return 'No registrada'
  if (normalized.length <= 4) return '*'.repeat(normalized.length)
  return `${normalized.slice(0, 2)}${'*'.repeat(normalized.length - 4)}${normalized.slice(-2)}`
}

export const normalizeWhatsAppPhone = (value) => {
  const raw = String(value || '').trim()
  if (!raw) return ''
  let digits = raw.replace(/\D/g, '')
  if (digits.startsWith('00')) digits = digits.slice(2)
  if (/^09\d{8}$/.test(digits)) digits = `593${digits.slice(1)}`
  if (digits.length < 8 || digits.length > 15) return ''
  return digits
}
