import { describe, expect, it, vi } from 'vitest'
import { resolveBillingProofUrl, uploadBillingProof, isPdfBillingProof } from '../src/lib/billingProofs'

const school = 'd0600000-0000-4000-8000-000000000001'
describe('private billing proofs', () => {
  it('resolves historical public URLs through authenticated signing and never returns a public fallback', async () => {
    const createSignedUrl = vi.fn(async () => ({ data: { signedUrl: 'https://example.invalid/signed' }, error: null }))
    const client = { storage: { from: () => ({ createSignedUrl }) } }
    const old = `https://example.supabase.co/storage/v1/object/public/billing-proofs/receipts/${school}_old.pdf`
    expect(await resolveBillingProofUrl(client, old)).toBe('https://example.invalid/signed')
    expect(createSignedUrl).toHaveBeenCalledWith(`receipts/${school}_old.pdf`, 3600)
    createSignedUrl.mockResolvedValue({ error: new Error('Forbidden') })
    await expect(resolveBillingProofUrl(client, old)).rejects.toThrow('Forbidden')
  })
  it('rejects external URLs and unsafe uploads before calling Storage', async () => {
    const from = vi.fn()
    const client = { storage: { from } }
    await expect(resolveBillingProofUrl(client, 'https://external.invalid/file.pdf')).rejects.toThrow()
    await expect(uploadBillingProof(client, school, { type: 'text/html', size: 100 })).rejects.toThrow()
    await expect(uploadBillingProof(client, school, { type: 'image/png', size: 11 * 1024 * 1024 })).rejects.toThrow()
    expect(from).not.toHaveBeenCalled()
  })
  it('preserves a stable private path instead of persisting expiring credentials', async () => {
    const upload = vi.fn(async () => ({ error: null }))
    const client = { storage: { from: () => ({ upload }) } }
    const path = await uploadBillingProof(client, school, { type: 'application/pdf', size: 100 })
    expect(path).toMatch(new RegExp(`^receipts/${school}_[a-f0-9-]+\\.pdf$`))
    expect(upload.mock.calls[0][2]).toMatchObject({ upsert: false, contentType: 'application/pdf' })
    expect(isPdfBillingProof(`https://example.supabase.co/storage/v1/object/sign/billing-proofs/${path}?token=test`)).toBe(true)
  })
})
