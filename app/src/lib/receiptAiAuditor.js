import { createWorker } from 'tesseract.js'

/**
 * Normaliza y formatea fecha y hora local actual para inputs datetime-local (YYYY-MM-DDTHH:mm)
 */
export function getLocalCurrentDateTimeString(date = new Date()) {
  const pad = (n) => String(n).padStart(2, '0')
  const yyyy = date.getFullYear()
  const mm = pad(date.getMonth() + 1)
  const dd = pad(date.getDate())
  const hh = pad(date.getHours())
  const min = pad(date.getMinutes())
  return `${yyyy}-${mm}-${dd}T${hh}:${min}`
}

/**
 * Limpia y convierte texto de montos a número float (ej. "$ 1,122.34" -> 1122.34)
 */
function parseAmountText(str) {
  if (!str) return null
  // Reemplazar coma de miles o puntos
  const clean = str.replace(/[^\d.,]/g, '').trim()
  if (!clean) return null
  
  // Si contiene coma y punto: ej 1,122.34
  if (clean.includes(',') && clean.includes('.')) {
    return parseFloat(clean.replace(/,/g, ''))
  }
  // Si solo contiene coma decimal: ej 1122,34
  if (clean.includes(',') && !clean.includes('.')) {
    const parts = clean.split(',')
    if (parts[1] && parts[1].length === 2) {
      return parseFloat(clean.replace(',', '.'))
    }
    return parseFloat(clean.replace(/,/g, ''))
  }
  return parseFloat(clean)
}

/**
 * Detecta bancos ecuatorianos e internacionales en el texto OCR
 */
function detectBankName(rawText) {
  const upper = rawText.toUpperCase()
  if (upper.includes('PICHINCHA')) return 'Banco Pichincha'
  if (upper.includes('GUAYAQUIL')) return 'Banco Guayaquil'
  if (upper.includes('PACIFICO') || upper.includes('PACÍFICO')) return 'Banco del Pacífico'
  if (upper.includes('PRODUBANCO')) return 'Produbanco'
  if (upper.includes('BOLIVARIANO')) return 'Banco Bolivariano'
  if (upper.includes('INTERNACIONAL')) return 'Banco Internacional'
  if (upper.includes('AUSTRO')) return 'Banco del Austro'
  if (upper.includes('DEUNA') || upper.includes('DE UNA')) return 'DeUna (Banco Pichincha)'
  if (upper.includes('JEP')) return 'Cooperativa JEP'
  if (upper.includes('JUVENTUD ECUATORIANA') || upper.includes('JUVENTUD')) return 'Coop. Juventud Ecuatoriana'
  if (upper.includes('ALIANZA DEL VALLE')) return 'Coop. Alianza del Valle'
  if (upper.includes('POLICIA NACIONAL') || upper.includes('POLICÍA')) return 'Coop. Policía Nacional'
  if (upper.includes('KUSHKI')) return 'Pasarela Kushki'
  if (upper.includes('STRIPE')) return 'Stripe Gateway'
  if (upper.includes('PAYPAL')) return 'PayPal'
  return 'Transferencia Bancaria'
}

/**
 * Extrae número de comprobante o referencia
 */
function detectReferenceNumber(rawText) {
  const patterns = [
    /(?:N[°oº\.]*|NUMERO|NRO|NO\.?)\s*(?:DE\s*)?(?:COMPROBANTE|TRANSACCI[OÓ]N|CONTROL|DOCUMENTO|REFERENCIA|OPERACI[OÓ]N)[:\s#]*([A-Z0-9-]{4,20})/i,
    /(?:COMPROBANTE|REFERENCIA|SECUENCIAL|TRANSACCI[OÓ]N|AUTORIZACI[OÓ]N)[:\s#]*([A-Z0-9-]{4,20})/i,
    /(?:DOCUMENTO|DOC|REF)[:\s#]*([0-9]{5,15})/i,
    /\b([0-9]{7,14})\b/
  ]

  for (const regex of patterns) {
    const match = rawText.match(regex)
    if (match && match[1]) {
      const cleanRef = match[1].trim()
      if (cleanRef.length >= 4 && !cleanRef.includes('$')) {
        return cleanRef
      }
    }
  }
  return null
}

/**
 * Extrae monto del comprobante
 */
function detectAmount(rawText) {
  // 1. Buscar montos precedidos por $ o USD
  const dollarPatterns = [
    /\$\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2}))/i,
    /USD\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2}))/i,
    /(?:MONTO|VALOR|TOTAL|IMPORTE|CANTIDAD)[:\s]*\$?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2}))/i,
    /\$\s*([0-9]+[.,][0-9]{2})/i
  ]

  for (const regex of dollarPatterns) {
    const match = rawText.match(regex)
    if (match && match[1]) {
      const val = parseAmountText(match[1])
      if (val && val > 0 && val < 100000) return val
    }
  }

  // 2. Fallback de cualquier patrón numérico decimal
  const anyDecimal = rawText.match(/\b([0-9]{2,4}[.,][0-9]{2})\b/g)
  if (anyDecimal && anyDecimal.length > 0) {
    for (const item of anyDecimal) {
      const val = parseAmountText(item)
      if (val && val >= 5) return val
    }
  }
  return null
}

/**
 * Extrae fecha y hora del texto
 */
function detectDateTime(rawText) {
  const months = {
    'ene': 0, 'feb': 1, 'mar': 2, 'abr': 3, 'may': 4, 'jun': 5,
    'jul': 6, 'ago': 7, 'sep': 8, 'oct': 9, 'nov': 10, 'dic': 11,
    'enero': 0, 'febrero': 1, 'marzo': 2, 'abril': 3, 'mayo': 4, 'junio': 5,
    'julio': 6, 'agosto': 7, 'septiembre': 8, 'octubre': 9, 'noviembre': 10, 'diciembre': 11
  }

  // Patrón "15 de Ago 2026" o "15 Ago 2026"
  const textDateRegex = /([0-3]?[0-9])\s*(?:de\s*)?([A-Za-z]{3,10})\s*(?:de\s*)?([2][0-9]{3})/i
  const textMatch = rawText.match(textDateRegex)

  let year, month, day
  if (textMatch) {
    day = parseInt(textMatch[1], 10)
    const monthStr = textMatch[2].toLowerCase()
    for (const [mName, mIdx] of Object.entries(months)) {
      if (monthStr.startsWith(mName)) {
        month = mIdx
        break
      }
    }
    year = parseInt(textMatch[3], 10)
  }

  // Patrón numérico "15/08/2026" o "15-08-2026"
  if (year === undefined) {
    const numDateMatch = rawText.match(/([0-3]?[0-9])[\/\-]([0-1]?[0-9])[\/\-]([2][0-9]{3})/)
    if (numDateMatch) {
      day = parseInt(numDateMatch[1], 10)
      month = parseInt(numDateMatch[2], 10) - 1
      year = parseInt(numDateMatch[3], 10)
    }
  }

  // Extraer hora si existe: ej "22:05" o "03:10:45"
  let hours = new Date().getHours()
  let minutes = new Date().getMinutes()
  const timeMatch = rawText.match(/([0-2]?[0-9])[:.]([0-5][0-9])(?::([0-5][0-9]))?\s*(AM|PM|am|pm)?/)
  if (timeMatch) {
    hours = parseInt(timeMatch[1], 10)
    minutes = parseInt(timeMatch[2], 10)
    if (timeMatch[4]) {
      const meridiem = timeMatch[4].toUpperCase()
      if (meridiem === 'PM' && hours < 12) hours += 12
      if (meridiem === 'AM' && hours === 12) hours = 0
    }
  }

  if (year && month !== undefined && day) {
    const d = new Date(year, month, day, hours, minutes)
    return getLocalCurrentDateTimeString(d)
  }

  // Retornar hora local actual por defecto
  return getLocalCurrentDateTimeString()
}

/**
 * Función principal: Realiza OCR con IA y cuadra los valores con la suscripción
 */
export async function auditReceiptWithAI(imageSource, expectedAmount = 0, onProgress = null) {
  let worker = null
  try {
    if (onProgress) onProgress('Iniciando motor de reconocimiento óptico...')
    
    worker = await createWorker('spa') // español
    
    if (onProgress) onProgress('Escaneando texto y sellos de transferencia...')
    const ret = await worker.recognize(imageSource)
    const rawText = ret.data.text || ''

    if (onProgress) onProgress('Analizando montos, fechas y cuentas...')

    const detectedBank = detectBankName(rawText)
    const detectedRef = detectReferenceNumber(rawText) || `TRANSF-${Date.now().toString().slice(-6)}`
    const detectedAmount = detectAmount(rawText)
    const detectedDate = detectDateTime(rawText)

    // Cuadre de montos
    const expAmt = Number(expectedAmount || 0)
    let reconciliationStatus = 'unknown'
    let reconciliationMessage = ''
    let isMatch = false

    if (detectedAmount !== null) {
      const diff = Math.abs(detectedAmount - expAmt)
      if (diff <= 0.5) {
        isMatch = true
        reconciliationStatus = 'exact_match'
        reconciliationMessage = `✓ Monto exacto verificado ($${detectedAmount.toFixed(2)} USD). Cuadre perfecto con el plan.`
      } else if (detectedAmount > expAmt) {
        reconciliationStatus = 'overpayment'
        reconciliationMessage = `ℹ️ Monto detectado ($${detectedAmount.toFixed(2)} USD) superior al mínimo esperado ($${expAmt.toFixed(2)} USD). Pago con crédito o meses adicionales.`
      } else {
        reconciliationStatus = 'underpayment'
        reconciliationMessage = `⚠️ Advertencia: Monto detectado ($${detectedAmount.toFixed(2)} USD) es menor al esperado ($${expAmt.toFixed(2)} USD).`
      }
    } else {
      reconciliationStatus = 'amount_unclear'
      reconciliationMessage = `ℹ️ No se pudo leer el monto con certeza en la foto. Se sugiere verificar manualmente.`
    }

    return {
      success: true,
      bank: detectedBank,
      reference: detectedRef,
      amount: detectedAmount,
      expectedAmount: expAmt,
      date: detectedDate,
      rawText: rawText.slice(0, 300),
      isMatch,
      status: reconciliationStatus,
      message: reconciliationMessage
    }
  } catch (err) {
    console.error('Error en auditoría IA del comprobante:', err)
    return {
      success: false,
      error: err.message,
      bank: 'Transferencia Bancaria',
      reference: `TRANSF-${Date.now().toString().slice(-6)}`,
      amount: null,
      date: getLocalCurrentDateTimeString(),
      message: 'No se pudo procesar la imagen con OCR: ' + err.message
    }
  } finally {
    if (worker) {
      await worker.terminate()
    }
  }
}
