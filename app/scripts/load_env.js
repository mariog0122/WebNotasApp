import fs from 'fs'
import path from 'path'

const parseLine = (line) => {
  const trimmed = line.trim()
  if (!trimmed || trimmed.startsWith('#')) return null
  const eqIndex = trimmed.indexOf('=')
  if (eqIndex === -1) return null
  const key = trimmed.slice(0, eqIndex).trim()
  let value = trimmed.slice(eqIndex + 1).trim()
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1)
  }
  return { key, value }
}

export const loadEnv = (paths) => {
  const env = { ...process.env }

  paths.forEach((p) => {
    const fullPath = path.resolve(process.cwd(), p)
    if (!fs.existsSync(fullPath)) return
    const lines = fs.readFileSync(fullPath, 'utf8').split(/\r?\n/)
    lines.forEach((line) => {
      const parsed = parseLine(line)
      if (!parsed) return
      if (env[parsed.key] === undefined) {
        env[parsed.key] = parsed.value
      }
    })
  })

  return env
}
