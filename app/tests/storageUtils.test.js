import { describe, expect, it, vi } from 'vitest'
import {
  clearSignedUrlCache,
  compressImageForUpload,
  invalidateSignedUrl,
  normalizeStoragePath,
  primeSignedUrls,
  resolvePrivateImageUrl,
  uploadPrivateImage,
  validateImageFile,
} from '../src/lib/storageUtils'

describe('private storage helpers', () => {
  it('extracts a path from a legacy public URL', () => {
    expect(normalizeStoragePath(
      'https://project.supabase.co/storage/v1/object/public/student-photos/students/a/photo.jpg',
      'student-photos',
    )).toBe('students/a/photo.jpg')
  })

  it('rejects non-image and oversized files', () => {
    expect(() => validateImageFile({ type: 'text/html', size: 20 })).toThrow(/imagen/i)
    expect(() => validateImageFile({ type: 'image/png', size: 6 * 1024 * 1024 })).toThrow(/5 MB/i)
  })

  it('creates a short-lived signed URL without changing the stored path', async () => {
    const createSignedUrl = vi.fn().mockResolvedValue({
      data: { signedUrl: 'https://signed.example/photo.jpg?token=short' },
      error: null,
    })
    const client = { storage: { from: () => ({ createSignedUrl }) } }

    const result = await resolvePrivateImageUrl(client, 'student-photos', 'tenant/student.jpg')

    expect(result).toContain('token=short')
    expect(createSignedUrl).toHaveBeenCalledWith('tenant/student.jpg', 3600)
  })
})

describe('signed URL cache (egress)', () => {
  const makeClient = (createSignedUrl, createSignedUrls) => ({
    supabaseUrl: 'https://test.supabase.co',
    storage: { from: () => ({ createSignedUrl, createSignedUrls }) },
  })

  it('reuses the same signed URL so the browser can cache the image', async () => {
    clearSignedUrlCache()
    const createSignedUrl = vi.fn().mockResolvedValue({ data: { signedUrl: 'https://s/logo?token=a' }, error: null })
    const client = makeClient(createSignedUrl)

    const [first, second] = await Promise.all([
      resolvePrivateImageUrl(client, 'institution-assets', 'school/logo.png'),
      resolvePrivateImageUrl(client, 'institution-assets', 'school/logo.png'),
    ])
    const third = await resolvePrivateImageUrl(client, 'institution-assets', 'school/logo.png')

    expect(first).toBe(second)
    expect(third).toBe(first)
    expect(createSignedUrl).toHaveBeenCalledTimes(1)
  })

  it('signs a whole list in one request and serves later lookups from cache', async () => {
    clearSignedUrlCache()
    const createSignedUrl = vi.fn()
    const createSignedUrls = vi.fn().mockResolvedValue({
      data: [
        { path: 'a.jpg', signedUrl: 'https://s/a?t=1', error: null },
        { path: 'b.jpg', signedUrl: 'https://s/b?t=1', error: null },
      ],
      error: null,
    })
    const client = makeClient(createSignedUrl, createSignedUrls)

    await primeSignedUrls(client, 'student-photos', ['a.jpg', 'b.jpg', 'a.jpg', '', null])

    expect(createSignedUrls).toHaveBeenCalledTimes(1)
    expect(createSignedUrls.mock.calls[0][0]).toEqual(['a.jpg', 'b.jpg'])
    expect(await resolvePrivateImageUrl(client, 'student-photos', 'b.jpg')).toBe('https://s/b?t=1')
    expect(createSignedUrl).not.toHaveBeenCalled()
  })

  it('signs again after the entry is invalidated', async () => {
    clearSignedUrlCache()
    const createSignedUrl = vi.fn()
      .mockResolvedValueOnce({ data: { signedUrl: 'https://s/x?t=1' }, error: null })
      .mockResolvedValueOnce({ data: { signedUrl: 'https://s/x?t=2' }, error: null })
    const client = makeClient(createSignedUrl)

    await resolvePrivateImageUrl(client, 'profile-photos', 'u/x.jpg')
    invalidateSignedUrl(client, 'profile-photos', 'u/x.jpg')

    expect(await resolvePrivateImageUrl(client, 'profile-photos', 'u/x.jpg')).toBe('https://s/x?t=2')
  })
})

describe('compressImageForUpload', () => {
  it('returns the original file when canvas is unavailable or the file is small', async () => {
    const small = { type: 'image/jpeg', size: 10 * 1024, name: 'a.jpg' }
    const big = { type: 'image/jpeg', size: 4 * 1024 * 1024, name: 'b.jpg' }
    expect(await compressImageForUpload(small)).toBe(small)
    expect(await compressImageForUpload(big)).toBe(big)
  })

  it('uploads the compressed file and invalidates the cached URL', async () => {
    const upload = vi.fn().mockResolvedValue({ error: null })
    const client = { storage: { from: () => ({ upload }) } }
    const file = { type: 'image/png', size: 2048, name: 'l.png' }
    await uploadPrivateImage(client, 'institution-assets', file, 'school/logo.png')
    expect(upload).toHaveBeenCalledWith('school/logo.png', file, expect.objectContaining({ contentType: 'image/png', upsert: true }))
  })
})
