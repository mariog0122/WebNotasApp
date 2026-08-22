const configuredAppUrl = import.meta.env.VITE_APP_URL?.trim()
const runtimeOrigin = typeof window !== 'undefined' ? window.location.origin : ''

export const APP_URL = (configuredAppUrl || runtimeOrigin).replace(/\/$/, '')

if (!APP_URL) {
  throw new Error('VITE_APP_URL debe estar configurada para los flujos de autenticación.')
}

