import { describe, expect, it } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8')
const walkVue = (directory) => fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
  const item = path.join(directory, entry.name)
  return entry.isDirectory() ? walkVue(item) : entry.name.endsWith('.vue') ? [item] : []
})

describe('P2 accessibility and performance contracts', () => {
  it('declares Spanish and exposes a keyboard skip target', () => {
    expect(read('index.html')).toContain('<html lang="es">')

    const layout = read('src/components/MainLayout.vue')
    expect(layout).toContain('href="#main-content"')
    expect(layout).toMatch(/<main[^>]+id="main-content"[^>]+tabindex="-1"/)
    expect(layout).toContain("'Abrir menú principal'")
    expect(read('src/components/Sidebar.vue')).toContain('id="main-sidebar"')
  })

  it('provides visible focus and honors reduced-motion preferences', () => {
    const styles = read('src/style.css')
    expect(styles).toContain(':focus-visible')
    expect(styles).toContain('@media (prefers-reduced-motion: reduce)')
    expect(styles).toContain('.skip-link')
  })

  it('gives commercial modals names and dialog semantics', () => {
    const tenants = read('src/views/superadmin/TenantsTab.vue')
    expect(tenants.match(/role="dialog"/g)?.length).toBeGreaterThanOrEqual(3)
    expect(tenants.match(/aria-modal="true"/g)?.length).toBeGreaterThanOrEqual(3)
    expect(tenants).toContain('aria-label="Cerrar registro de pago"')
    expect(tenants).toContain('aria-label="Registrar pago"')
  })

  it('hardens external links and avoids third-party decorative imagery', () => {
    const pricing = read('src/views/Pricing.vue')
    const externalLinks = [...pricing.matchAll(/<a\b[^>]*target="_blank"[^>]*>/g)].map(([tag]) => tag)
    expect(externalLinks.length).toBeGreaterThan(0)
    for (const tag of externalLinks) {
      expect(tag).toContain('rel="noopener noreferrer"')
    }
    expect(pricing).not.toContain('images.unsplash.com')
    expect(read('src/views/Login.vue')).not.toContain('images.unsplash.com')
  })

  it('loads the spreadsheet parser only when import is requested', () => {
    const courses = read('src/views/Courses.vue')
    expect(courses).not.toContain("import * as XLSX from 'xlsx'")
    expect(courses).toContain("await import('read-excel-file/browser')")
    expect(courses).not.toContain("import('xlsx')")
    expect(JSON.parse(read('package.json')).dependencies).not.toHaveProperty('xlsx')
    expect(read('src/lib/exportUtils.js')).not.toMatch(/from ['"]xlsx['"]|XLSX\./)
  })

  it('does not block rendering on third-party font stylesheets', () => {
    expect(read('index.html')).not.toContain('fonts.googleapis.com')
    expect(read('src/views/Reports.vue')).not.toContain('@import url(')
  })

  it('enforces compressed production asset budgets in CI', () => {
    const packageJson = JSON.parse(read('package.json'))
    expect(packageJson.scripts['check:bundle']).toBe('node scripts/check-bundle-budget.mjs')
    expect(read('../.github/workflows/ci.yml')).toContain('npm run check:bundle')
    expect(read('scripts/check-bundle-budget.mjs')).toContain('gzipSync')
  })

  it('keeps the optional Excel parser out of the offline precache', () => {
    const viteConfig = read('vite.config.js')
    expect(viteConfig).toContain("globIgnores: ['**/read-excel-file-*.js']")
    expect(viteConfig).toContain("id.includes('read-excel-file')")
  })

  it('gives every Vue image alt text and secures every new-tab link', () => {
    for (const file of walkVue(path.join(root, 'src'))) {
      const source = fs.readFileSync(file, 'utf8')
      for (const [image] of source.matchAll(/<img\b[\s\S]*?>/gi)) {
        expect(image, `${file}: image without alt`).toMatch(/\balt\s*=/i)
      }
      for (const [link] of source.matchAll(/<a\b[^>]*target="_blank"[^>]*>/gi)) {
        expect(link, `${file}: unsafe new-tab link`).toContain('rel="noopener noreferrer"')
      }
    }
    expect(read('src/views/Dashboard.vue')).not.toMatch(/<div[^>]*@click="navigateTo/)
  })
})
