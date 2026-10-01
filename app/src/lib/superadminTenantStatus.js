const VALID_TENANT_STATUSES = new Set(['active', 'trial', 'past_due', 'suspended', 'cancelled'])
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

const FRIENDLY_ERRORS = {
  '22023': ['INVALID_STATUS', 'El estado solicitado no es válido.'],
  '22004': ['INVALID_INSTITUTION_ID', 'La institución indicada no es válida.'],
  '22P02': ['INVALID_INSTITUTION_ID', 'La institución indicada no es válida.'],
  '42501': ['FORBIDDEN', 'No tienes autorización para cambiar el estado de esta institución.'],
  P0002: ['INSTITUTION_NOT_FOUND', 'La institución ya no existe o no está disponible.'],
  '40001': ['STATUS_CONFLICT', 'Otra operación modificó la institución. Actualiza la lista e inténtalo nuevamente.']
}

export class TenantStatusError extends Error {
  constructor(code, message, cause = null) {
    super(message, cause ? { cause } : undefined)
    this.name = 'TenantStatusError'
    this.code = code
  }
}

const mapBackendError = (error) => {
  const [code, message] = FRIENDLY_ERRORS[error?.code] || [
    'STATUS_UPDATE_FAILED',
    'No se pudo cambiar el estado de la institución. Intenta nuevamente.'
  ]
  return new TenantStatusError(code, message, error)
}

export const tenantStatusSuccessMessage = (status, institutionName, changed = true) => {
  if (!changed) return `${institutionName} ya tenía el estado solicitado.`

  const action = {
    active: 'reactivada',
    trial: 'activada en período de prueba',
    past_due: 'marcada con pago vencido',
    suspended: 'suspendida',
    cancelled: 'cancelada'
  }[status] || 'actualizada'

  return `Institución ${action} correctamente: ${institutionName}.`
}

export const createTenantStatusManager = (supabaseClient) => {
  if (typeof supabaseClient?.rpc !== 'function') {
    throw new TypeError('Se requiere un cliente de Supabase válido.')
  }

  const inFlight = new Map()

  const changeStatus = async ({ targetInstitutionId, newStatus, reason = null, observation = null }) => {
    if (!UUID_PATTERN.test(targetInstitutionId || '')) {
      throw new TenantStatusError('INVALID_INSTITUTION_ID', 'La institución indicada no es válida.')
    }
    if (!VALID_TENANT_STATUSES.has(newStatus)) {
      throw new TenantStatusError('INVALID_STATUS', 'El estado solicitado no es válido.')
    }

    const operationKey = `${targetInstitutionId}:${newStatus}`
    if (inFlight.has(operationKey)) {
      return { success: true, changed: false, skipped: true }
    }

    inFlight.set(operationKey, true)
    try {
      const { data, error } = await supabaseClient.rpc('set_tenant_status', {
        p_school_id: targetInstitutionId,
        p_new_status: newStatus,
        p_reason: reason,
        p_observation: observation
      })

      if (error) throw mapBackendError(error)
      if (!data?.success) throw mapBackendError({ code: data?.code, message: data?.message })
      return data
    } finally {
      inFlight.delete(operationKey)
    }
  }

  return { changeStatus }
}
