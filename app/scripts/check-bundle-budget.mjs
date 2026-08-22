import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { extname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { gzipSync } from 'node:zlib'

const distDir = fileURLToPath(new URL('../dist/', import.meta.url))
const budgets = new Map([
  ['.js', 150 * 1024],
  ['.css', 50 * 1024],
])

if (!existsSync(distDir)) {
  console.error('No existe dist/. Ejecuta npm run build antes del presupuesto.')
  process.exit(1)
}

const walk = (directory) => readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
  const file = join(directory, entry.name)
  return entry.isDirectory() ? walk(file) : [file]
})

const failures = []
const measured = []

for (const file of walk(distDir)) {
  const extension = extname(file)
  const limit = budgets.get(extension)
  if (!limit) continue

  const compressedBytes = gzipSync(readFileSync(file)).byteLength
  const name = relative(distDir, file).replaceAll('\\', '/')
  measured.push({ name, compressedBytes, limit })
  if (compressedBytes > limit) failures.push({ name, compressedBytes, limit })
}

for (const asset of measured.sort((a, b) => b.compressedBytes - a.compressedBytes).slice(0, 8)) {
  console.log(`${asset.name}: ${(asset.compressedBytes / 1024).toFixed(1)} KiB gzip / ${(asset.limit / 1024).toFixed(0)} KiB`)
}

if (failures.length) {
  console.error(`Presupuesto excedido en ${failures.length} recurso(s).`)
  process.exit(1)
}

console.log(`Presupuesto aprobado para ${measured.length} recursos JS/CSS.`)
