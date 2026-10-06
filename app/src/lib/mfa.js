import { supabase } from './supabase'

/**
 * Consulta el estado actual de MFA (Autenticación Multifactor) para el usuario autenticado.
 * Retorna si tiene factores configurados y si la sesión actual ha cumplido AAL2.
 */
export async function getMfaStatus(supabaseClient = supabase) {
  if (!supabaseClient?.auth?.mfa?.listFactors) {
    return {
      isEnrolled: false,
      hasMfa: false,
      factors: [],
      verifiedFactors: [],
      currentLevel: null,
      nextLevel: null,
      error: null
    }
  }

  try {
    const [factorsRes, aalRes] = await Promise.all([
      supabaseClient.auth.mfa.listFactors(),
      supabaseClient.auth.mfa.getAuthenticatorAssuranceLevel()
    ])

    if (factorsRes.error) throw factorsRes.error
    if (aalRes.error) throw aalRes.error

    const allFactors = factorsRes.data?.all || factorsRes.data?.totp || []
    const verifiedFactors = allFactors.filter((f) => f.status === 'verified')
    const currentLevel = aalRes.data?.currentLevel || 'aal1'
    const nextLevel = aalRes.data?.nextLevel || 'aal1'

    return {
      isEnrolled: verifiedFactors.length > 0,
      hasMfa: verifiedFactors.length > 0,
      factors: allFactors,
      verifiedFactors,
      currentLevel,
      nextLevel,
      error: null
    }
  } catch (err) {
    return {
      isEnrolled: false,
      hasMfa: false,
      factors: [],
      verifiedFactors: [],
      currentLevel: null,
      nextLevel: null,
      error: err
    }
  }
}

/**
 * Retorna true si la cuenta del usuario tiene 2FA activo pero su sesión actual solo está en AAL1.
 */
export async function isAal2Required(supabaseClient = supabase) {
  if (!supabaseClient?.auth?.mfa?.getAuthenticatorAssuranceLevel) return false
  try {
    const { data, error } = await supabaseClient.auth.mfa.getAuthenticatorAssuranceLevel()
    if (error || !data) return false
    return data.nextLevel === 'aal2' && data.currentLevel !== 'aal2'
  } catch {
    return false
  }
}

/**
 * Inicia el proceso de enrolamiento de un nuevo factor TOTP.
 * Retorna los datos necesarios para mostrar el código QR o la clave secreta manual.
 */
export async function enrollTotpFactor({
  issuer = 'LOGREVA',
  friendlyName = 'LOGREVA Authenticator',
  supabaseClient = supabase
} = {}) {
  if (!supabaseClient?.auth?.mfa?.enroll) {
    const err = new Error('El servicio de autenticación MFA no está disponible en este cliente.')
    err.code = 'MFA_NOT_SUPPORTED'
    throw err
  }

  const { data, error } = await supabaseClient.auth.mfa.enroll({
    factorType: 'totp',
    issuer,
    friendlyName
  })

  if (error) throw error

  return {
    factorId: data.id,
    type: data.type,
    qrCode: data.totp?.qr_code || '',
    secret: data.totp?.secret || '',
    uri: data.totp?.uri || ''
  }
}

/**
 * Verifica y confirma el código de 6 dígitos para activar formalmente un factor recién enrolado.
 */
export async function verifyAndActivateFactor({ factorId, code, supabaseClient = supabase }) {
  const cleanCode = String(code || '').trim().replace(/\s+/g, '')
  if (!cleanCode || cleanCode.length !== 6) {
    const err = new Error('El código de verificación debe contener exactamente 6 dígitos numéricos.')
    err.code = 'INVALID_MFA_CODE_FORMAT'
    throw err
  }

  if (typeof supabaseClient?.auth?.mfa?.challengeAndVerify === 'function') {
    const { data, error } = await supabaseClient.auth.mfa.challengeAndVerify({
      factorId,
      code: cleanCode
    })
    if (error) throw error
    return data
  }

  // Fallback para clientes donde challenge y verify son llamados por separado
  const { data: challengeData, error: challengeError } = await supabaseClient.auth.mfa.challenge({ factorId })
  if (challengeError) throw challengeError

  const { data, error } = await supabaseClient.auth.mfa.verify({
    factorId,
    challengeId: challengeData.id,
    code: cleanCode
  })

  if (error) throw error
  return data
}

/**
 * Resuelve el desafío 2FA durante el inicio de sesión.
 */
export async function challengeAndVerifyLogin({ factorId, code, supabaseClient = supabase }) {
  let targetFactorId = factorId

  if (!targetFactorId) {
    const status = await getMfaStatus(supabaseClient)
    const factor = status.verifiedFactors?.[0]
    if (!factor) {
      const err = new Error('No se encontró un factor TOTP verificado para autenticar.')
      err.code = 'MFA_FACTOR_NOT_FOUND'
      throw err
    }
    targetFactorId = factor.id
  }

  return await verifyAndActivateFactor({
    factorId: targetFactorId,
    code,
    supabaseClient
  })
}

/**
 * Desvincula / elimina un factor TOTP de la cuenta del usuario.
 */
export async function unenrollFactor({ factorId, supabaseClient = supabase }) {
  if (!supabaseClient?.auth?.mfa?.unenroll) {
    const err = new Error('La desvinculación MFA no está disponible en este cliente.')
    err.code = 'MFA_NOT_SUPPORTED'
    throw err
  }

  const { data, error } = await supabaseClient.auth.mfa.unenroll({ factorId })
  if (error) throw error
  return data
}
