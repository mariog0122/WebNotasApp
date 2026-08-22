const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp'])
export const MAX_IMAGE_BYTES = 5 * 1024 * 1024

export const validateImageFile = (file) => {
  if (!file || !ALLOWED_IMAGE_TYPES.has(String(file.type || '').toLowerCase())) {
    throw new Error('Selecciona una imagen JPEG, PNG o WebP válida.')
  }
  if (!Number.isFinite(file.size) || file.size <= 0 || file.size > MAX_IMAGE_BYTES) {
    throw new Error('La imagen debe pesar como máximo 5 MB.')
  }
  return true
}

export const normalizeStoragePath = (value, bucket) => {
  if (!value) return ''
  const raw = String(value)
  let cleanPath = raw

  if (/^https?:\/\//i.test(raw)) {
    const markers = [
      `/storage/v1/object/public/${bucket}/`,
      `/storage/v1/object/sign/${bucket}/`,
      `/storage/v1/object/authenticated/${bucket}/`,
      `/storage/v1/render/image/public/${bucket}/`,
      `/storage/v1/render/image/authenticated/${bucket}/`,
    ]
    try {
      const url = new URL(raw)
      const marker = markers.find((candidate) => url.pathname.includes(candidate))
      if (marker) {
        cleanPath = decodeURIComponent(url.pathname.split(marker)[1] || '').replace(/^\/+/, '')
      } else {
        return raw
      }
    } catch {
      return raw
    }
  } else {
    cleanPath = raw.replace(/^\/+/, '')
    if (bucket && cleanPath.startsWith(`${bucket}/`)) {
      cleanPath = cleanPath.substring(bucket.length + 1)
    }
  }

  return cleanPath.split('?')[0]
}

export const resolvePrivateImageUrl = async (client, bucket, storedValue, expiresIn = 3600) => {
  if (!storedValue) return ''
  if (/^(blob:|data:)/i.test(storedValue)) return storedValue

  const path = normalizeStoragePath(storedValue, bucket)
  if (!path) return ''

  if (/^https?:\/\//i.test(path)) return path

  try {
    const { data, error } = await client.storage.from(bucket).createSignedUrl(path, expiresIn)
    if (!error && data?.signedUrl) {
      return data.signedUrl
    }
  } catch (err) {
    console.warn(`[resolvePrivateImageUrl] Signed URL failed for ${bucket}/${path}:`, err)
  }

  try {
    const { data } = client.storage.from(bucket).getPublicUrl(path)
    if (data?.publicUrl) {
      return data.publicUrl
    }
  } catch (err) {
    console.warn(`[resolvePrivateImageUrl] Public URL failed for ${bucket}/${path}:`, err)
  }

  return ''
}

export const uploadPrivateImage = async (client, bucket, file, path) => {
  validateImageFile(file)
  const mimeType = file.type || (path.endsWith('.png') ? 'image/png' : path.endsWith('.webp') ? 'image/webp' : 'image/jpeg')
  const { error } = await client.storage.from(bucket).upload(path, file, {
    cacheControl: '3600',
    contentType: mimeType,
    upsert: true,
  })
  if (error) {
    if (error.message?.includes('Bucket not found') || error.error === 'Bucket not found') {
      throw new Error(`El contenedor de archivos (${bucket}) no está listo en Supabase.`)
    }
    throw error
  }
  return path
}

