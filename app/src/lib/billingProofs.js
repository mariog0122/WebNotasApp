import { normalizeStoragePath } from './storageUtils'

const extensions = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'application/pdf': 'pdf' }
const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i

export const billingProofPath = value => {
  if (!value) return ''
  const path = normalizeStoragePath(value, 'billing-proofs')
  if (!/^receipts\/[0-9a-f-]{36}_[^/]+$/i.test(path)) throw new Error('Comprobante no válido.')
  return path
}

export const isPdfBillingProof = value => /\.pdf$/i.test(normalizeStoragePath(value, 'billing-proofs'))

export async function resolveBillingProofUrl(client, value) {
  const path = billingProofPath(value)
  if (!path) return ''
  const { data, error } = await client.storage.from('billing-proofs').createSignedUrl(path, 3600)
  if (error) throw error
  if (!data?.signedUrl) throw new Error('No se pudo abrir el comprobante.')
  return data.signedUrl
}

export async function uploadBillingProof(client, schoolId, file) {
  const extension = extensions[file?.type]
  if (!uuid.test(schoolId || '') || !extension || !Number.isFinite(file?.size) || file.size <= 0 || file.size > 10 * 1024 * 1024) {
    throw new Error('Selecciona un comprobante PDF, JPEG, PNG o WebP de hasta 10 MB.')
  }
  const path = `receipts/${schoolId}_${crypto.randomUUID()}.${extension}`
  const { error } = await client.storage.from('billing-proofs').upload(path, file, { upsert: false, contentType: file.type })
  if (error) throw error
  return path
}
