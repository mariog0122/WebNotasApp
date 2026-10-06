/**
 * Llena las plantillas Word institucionales (public/plantillas) con docxtemplater.
 * El diseño (logos, encabezados, pies, tablas) es el de la plantilla; aquí solo se reemplazan marcadores.
 */
import PizZip from 'pizzip'
import Docxtemplater from 'docxtemplater'

export const TEMPLATES = Object.freeze({
  anual: 'plantillas/pca.docx',
  micro: 'plantillas/micro.docx',
})

/** Rellena una plantilla (ArrayBuffer/Uint8Array) y devuelve el .docx como Uint8Array. */
export function renderDocx(templateBytes, data) {
  const zip = new PizZip(templateBytes)
  const doc = new Docxtemplater(zip, {
    delimiters: { start: '{{', end: '}}' },
    paragraphLoop: true,
    linebreaks: true,
    // Un marcador sin dato queda vacío en vez de imprimir "undefined".
    nullGetter: () => '',
  })
  doc.render(data)
  return doc.getZip().generate({ type: 'uint8array', compression: 'DEFLATE' })
}

export async function fetchTemplate(kind) {
  const base = import.meta.env.BASE_URL || '/'
  const response = await fetch(`${base}${TEMPLATES[kind]}`)
  if (!response.ok) throw new Error('No se pudo cargar la plantilla institucional.')
  return new Uint8Array(await response.arrayBuffer())
}

export function downloadBytes(bytes, filename) {
  const blob = new Blob([bytes], { type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

export async function exportPlanDocx(kind, data, filename) {
  const template = await fetchTemplate(kind)
  downloadBytes(renderDocx(template, data), filename)
}

export const safeFileName = text => String(text || 'planificacion')
  .normalize('NFD').replace(/[̀-ͯ]/g, '')
  .replace(/[^\w-]+/g, '_').replace(/_+/g, '_').replace(/^_|_$/g, '')
  .slice(0, 80) || 'planificacion'
