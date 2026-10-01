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

/**
 * Caché de URLs firmadas (reduce egress de Storage).
 * Una URL firmada nueva en cada pantalla trae un token distinto, así que el navegador
 * nunca reutiliza su caché HTTP y vuelve a descargar logo y fotos. Reutilizando la misma
 * URL mientras siga vigente, el navegador sirve la imagen desde su caché.
 */
const SIGNED_URL_REUSE_RATIO = 0.8
const signedUrlCache = new Map()
const signedUrlInFlight = new Map()

const signedUrlKey = (client, bucket, path) => `${client?.supabaseUrl || ''}|${bucket}|${path}`

const readCachedSignedUrl = (key) => {
  const hit = signedUrlCache.get(key)
  if (!hit) return ''
  if (hit.reuseUntil > Date.now()) return hit.url
  signedUrlCache.delete(key)
  return ''
}

const rememberSignedUrl = (key, url, expiresIn) => {
  signedUrlCache.set(key, { url, reuseUntil: Date.now() + expiresIn * 1000 * SIGNED_URL_REUSE_RATIO })
}

export const invalidateSignedUrl = (client, bucket, storedValue) => {
  const path = normalizeStoragePath(storedValue, bucket)
  if (path) signedUrlCache.delete(signedUrlKey(client, bucket, path))
}

export const clearSignedUrlCache = () => {
  signedUrlCache.clear()
  signedUrlInFlight.clear()
}

/** Firma varias rutas en UNA sola petición y deja las URLs en caché para resolvePrivateImageUrl. */
export const primeSignedUrls = async (client, bucket, storedValues, expiresIn = 3600) => {
  const paths = Array.from(new Set(
    (storedValues || [])
      .map((value) => (value && !/^(blob:|data:)/i.test(value) ? normalizeStoragePath(value, bucket) : ''))
      .filter((path) => path && !/^https?:\/\//i.test(path))
      .filter((path) => !readCachedSignedUrl(signedUrlKey(client, bucket, path))),
  ))
  if (paths.length === 0 || typeof client?.storage?.from(bucket)?.createSignedUrls !== 'function') return
  try {
    const { data, error } = await client.storage.from(bucket).createSignedUrls(paths, expiresIn)
    if (error) return
    for (const item of data || []) {
      if (item?.signedUrl && !item.error && item.path) {
        rememberSignedUrl(signedUrlKey(client, bucket, item.path), item.signedUrl, expiresIn)
      }
    }
  } catch (err) {
    console.warn(`[primeSignedUrls] Batch signing failed for ${bucket}:`, err)
  }
}

export const resolvePrivateImageUrl = async (client, bucket, storedValue, expiresIn = 3600) => {
  if (!storedValue) return ''
  if (/^(blob:|data:)/i.test(storedValue)) return storedValue

  const path = normalizeStoragePath(storedValue, bucket)
  if (!path) return ''

  if (/^https?:\/\//i.test(path)) return path

  const key = signedUrlKey(client, bucket, path)
  const cached = readCachedSignedUrl(key)
  if (cached) return cached

  let pending = signedUrlInFlight.get(key)
  if (!pending) {
    pending = (async () => {
      try {
        const { data, error } = await client.storage.from(bucket).createSignedUrl(path, expiresIn)
        if (!error && data?.signedUrl) {
          rememberSignedUrl(key, data.signedUrl, expiresIn)
          return data.signedUrl
        }
      } catch (err) {
        console.warn(`[resolvePrivateImageUrl] Signed URL failed for ${bucket}/${path}:`, err)
      }
      return ''
    })().finally(() => signedUrlInFlight.delete(key))
    signedUrlInFlight.set(key, pending)
  }
  const signedUrl = await pending
  if (signedUrl) return signedUrl

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

/**
 * Reduce el peso de una imagen antes de subirla (limita egress y almacenamiento).
 * Conserva el tipo MIME (la extensión del path no cambia). Devuelve el archivo
 * original si no hay soporte de canvas, si ya es liviano o si no se logra reducir.
 */
export const compressImageForUpload = async (file, { maxSide = 1024, quality = 0.82, minBytes = 150 * 1024 } = {}) => {
  if (!file || file.size <= minBytes) return file
  if (typeof document === 'undefined' || typeof createImageBitmap !== 'function') return file
  try {
    const bitmap = await createImageBitmap(file)
    const scale = Math.min(1, maxSide / Math.max(bitmap.width, bitmap.height))
    const canvas = document.createElement('canvas')
    canvas.width = Math.max(1, Math.round(bitmap.width * scale))
    canvas.height = Math.max(1, Math.round(bitmap.height * scale))
    const context = canvas.getContext('2d')
    if (!context) return file
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
    bitmap.close?.()
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, file.type, quality))
    if (!blob || blob.type !== file.type || blob.size >= file.size) return file
    return new File([blob], file.name, { type: file.type, lastModified: Date.now() })
  } catch (err) {
    console.warn('[compressImageForUpload] Se sube la imagen original:', err)
    return file
  }
}

export const uploadPrivateImage = async (client, bucket, originalFile, path) => {
  validateImageFile(originalFile)
  const file = await compressImageForUpload(originalFile)
  const mimeType = file.type || (path.endsWith('.png') ? 'image/png' : path.endsWith('.webp') ? 'image/webp' : 'image/jpeg')
  invalidateSignedUrl(client, bucket, path)
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

