import { describe, expect, it, vi } from 'vitest'
import {
  normalizeStoragePath,
  resolvePrivateImageUrl,
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
