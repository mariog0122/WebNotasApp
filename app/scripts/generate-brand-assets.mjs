import { chromium } from '@playwright/test'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const outputs = [
  { file: 'pwa-192x192.png', size: 192 },
  { file: 'pwa-512x512.png', size: 512 },
  { file: 'apple-touch-icon.png', size: 512 },
]

const iconMarkup = (size) => `
  <svg id="icon" xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 72 72">
    <rect width="72" height="72" rx="15" fill="#0B1530"/>
    <g transform="translate(7.2 7.2) scale(.8)">
      <path d="M10 7H21V42C21 49.5 24.5 53 32 53H37V64H30C16.5 64 10 57.5 10 44V7Z" fill="#FFFFFF"/>
      <path d="M27 39L37 50L57 18L66 24L38 67L18 45L27 39Z" fill="#22D3EE"/>
    </g>
  </svg>
`

const browser = await chromium.launch({ headless: true })

try {
  for (const output of outputs) {
    const page = await browser.newPage({ viewport: { width: output.size, height: output.size } })
    await page.setContent(`<style>*{margin:0}html,body{width:${output.size}px;height:${output.size}px;overflow:hidden}</style>${iconMarkup(output.size)}`)
    await page.locator('#icon').screenshot({ path: path.join(projectRoot, 'public', output.file) })
    await page.close()
  }
} finally {
  await browser.close()
}
