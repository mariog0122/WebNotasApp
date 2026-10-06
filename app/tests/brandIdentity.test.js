import { describe, expect, it } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8')

describe('LOGREVA brand identity', () => {
  it('centralizes the approved name, descriptor and demo contact', async () => {
    const brand = await import('../src/lib/brand.js')

    expect(brand.BRAND_NAME).toBe('LOGREVA')
    expect(brand.BRAND_DESCRIPTOR).toBe('GESTIÓN EDUCATIVA')
    expect(brand.BRAND_COPYRIGHT_YEAR).toBe(2026)
    expect(brand.SALES_WHATSAPP_NUMBER).toBe('593989121871')
    expect(brand.DEMO_REQUEST_URL).toContain('wa.me/593989121871')
    expect(decodeURIComponent(brand.DEMO_REQUEST_URL)).toContain('demostración de LOGREVA')
  })

  it('uses the approved Architect geometry in one reusable component', () => {
    const logo = read('src/components/ui/BrandLogo.vue')

    expect(logo).toContain('M10 7H21V42C21 49.5 24.5 53 32 53H37V64H30C16.5 64 10 57.5 10 44V7Z')
    expect(logo).toContain('M27 39L37 50L57 18L66 24L38 67L18 45L27 39Z')
    expect(logo).toContain("default: 'horizontal'")
    expect(logo).toContain("default: 'dark'")
    expect(logo).toContain('Logreva, gestión educativa')
  })

  it('ships rebranded browser and PWA assets', () => {
    expect(read('public/logreva-mark.svg')).toContain('viewBox="0 0 72 72"')
    expect(read('public/favicon.svg')).toContain('#079AB7')

    for (const file of ['public/pwa-192x192.png', 'public/pwa-512x512.png', 'public/apple-touch-icon.png']) {
      expect(fs.statSync(path.join(root, file)).size).toBeGreaterThan(1000)
    }
  })

  it('keeps the visible product identity consistent across the application', () => {
    const visibleBrandFiles = [
      'index.html',
      'vite.config.js',
      'src/main.js',
      'src/App.vue',
      'src/components/Sidebar.vue',
      'src/views/Login.vue',
      'src/views/Pricing.vue',
      'src/views/Reports.vue',
      'src/views/Terms.vue',
      'src/views/Privacy.vue',
    ]

    for (const file of visibleBrandFiles) {
      expect(read(file), `${file} todavía contiene una marca anterior`).not.toMatch(/EduCore|WebNotas|Sistema de Notas/i)
    }

    expect(read('index.html')).toContain('<title>LOGREVA — Gestión Educativa</title>')
    expect(read('vite.config.js')).toContain("name: 'LOGREVA — Gestión Educativa'")
    expect(read('vite.config.js')).toContain("short_name: 'LOGREVA'")
  })

  it('reuses the central brand and demo URL without changing active sessions', () => {
    const login = read('src/views/Login.vue')
    const pricing = read('src/views/Pricing.vue')
    const supabase = read('src/lib/supabase.js')

    expect(login).toContain("import BrandLogo from '../components/ui/BrandLogo.vue'")
    expect(login).toContain("import { DEMO_REQUEST_URL } from '../lib/brand'")
    expect(pricing).toContain("import BrandLogo from '../components/ui/BrandLogo.vue'")
    expect(pricing).toContain("import { BRAND_NAME, DEMO_REQUEST_URL } from '../lib/brand'")
    expect(pricing).not.toContain('salesContactUrl')
    expect(supabase).toContain('[Logreva]')
    expect(supabase).toContain("storageKey: 'webnotas-auth-token'")
  })

  it('moves the premium galaxy into a reusable, efficient component', () => {
    const login = read('src/views/Login.vue')
    const galaxy = read('src/components/ui/GalaxyBackground.vue')

    expect(login).toContain("import GalaxyBackground from '../components/ui/GalaxyBackground.vue'")
    expect(login).toContain('<GalaxyBackground')
    expect(login).not.toContain('canvasRef')
    expect(login).not.toContain('initCanvas')

    expect(galaxy).toContain('requestAnimationFrame')
    expect(galaxy).toContain('cancelAnimationFrame')
    expect(galaxy).toContain("document.addEventListener('visibilitychange'")
    expect(galaxy).toContain("document.removeEventListener('visibilitychange'")
    expect(galaxy).toContain("window.matchMedia('(prefers-reduced-motion: reduce)')")
    expect(galaxy).toContain('resizeObserver.disconnect()')
    expect(galaxy).toContain('Math.min(window.devicePixelRatio || 1, 1.5)')
    expect(galaxy).toContain('pointer-events: none')
  })

  it('presents the approved premium login hierarchy and commercial paths', () => {
    const login = read('src/views/Login.vue')

    expect(login).toContain('data-testid="login-brand-panel"')
    expect(login).toContain('data-testid="login-card"')
    expect(login).toContain('Donde cada institución logra su excelencia académica.')
    expect(login).toContain('Control académico en tiempo real')
    expect(login).toContain('Trazabilidad lista para auditoría')
    expect(login).toContain('Reportes claros para decidir mejor')
    expect(login).toContain('Bienvenido a Logreva')
    expect(login).toContain('Solicita una demo')
    expect(login).toContain('Creado en Ecuador para Latinoamérica 🇪🇨')
    expect(login).toContain('aria-label="Mostrar contraseña"')
  })
})
