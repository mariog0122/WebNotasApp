export const loadHtml2Pdf = () => {
  return new Promise((resolve, reject) => {
    if (window.html2pdf) {
      resolve(window.html2pdf)
      return
    }
    const script = document.createElement('script')
    script.src = 'https://cdn.jsdelivr.net/npm/html2pdf.js@0.10.1/dist/html2pdf.bundle.min.js'
    script.async = true
    script.onload = () => resolve(window.html2pdf)
    script.onerror = () => reject(new Error('No se pudo cargar el generador de PDF.'))
    document.head.appendChild(script)
  })
}
