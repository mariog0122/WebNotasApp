# LOGREVA Brand and Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the approved LOGREVA identity across the Vue application and replace the login’s old starfield with a reusable, accessible premium galaxy background.

**Architecture:** Shared brand constants and a single `BrandLogo.vue` prevent text, contact and logo drift. A self-contained `GalaxyBackground.vue` owns Canvas/CSS rendering and cleanup, while `Login.vue` only composes existing authentication flows with the approved brand content. Static Vitest contracts protect global brand consistency and lifecycle behavior; Playwright verifies responsive rendering and links.

**Tech Stack:** Vue 3 Composition API, Vite, JavaScript, Tailwind CSS, Canvas 2D, SVG, Vitest, Playwright and the existing PWA plugin.

---

## File structure

**Create**

- `app/src/lib/brand.js`: canonical brand text, colors and commercial contact URL.
- `app/src/components/ui/BrandLogo.vue`: accessible Architect mark and wordmark variants.
- `app/src/components/ui/GalaxyBackground.vue`: Canvas/CSS animation and lifecycle.
- `app/public/logreva-mark.svg`: public vector mark.
- `app/scripts/generate-brand-assets.mjs`: deterministic PWA PNG generation using installed Playwright.
- `app/tests/brandIdentity.test.js`: global identity contracts.
- `app/e2e/login-logreva.spec.js`: responsive login and reduced-motion checks.

**Modify**

- `app/src/views/Login.vue`: brand copy, CTA/footer, background composition; auth logic unchanged.
- `app/src/App.vue`: auth loading brand.
- `app/src/components/Sidebar.vue`: LOGREVA descriptor and safe fallback.
- `app/src/views/Pricing.vue`: shared logo/contact and SEO name.
- `app/src/views/Terms.vue`, `app/src/views/Privacy.vue`: legal brand name only.
- `app/src/views/Reports.vue`: visible report kicker.
- `app/src/main.js`, `app/src/lib/supabase.js`: visible diagnostic prefixes.
- `app/index.html`, `app/vite.config.js`: metadata, theme and PWA identity.
- `app/README.md`: product name.
- `app/tests/accessibilityPerformance.test.js`: animation and integration contracts.

**Regenerate**

- `app/public/favicon.svg`
- `app/public/pwa-192x192.png`
- `app/public/pwa-512x512.png`
- `app/public/apple-touch-icon.png`

The internal key `webnotas-auth-token` is explicitly preserved.

### Task 1: Define failing brand contracts

**Files:**
- Create: `app/tests/brandIdentity.test.js`

- [ ] **Step 1: Write contracts for brand constants and geometry**

```js
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
})
```

- [ ] **Step 2: Run the test and verify RED**

Run: `npm test -- tests/brandIdentity.test.js --run`

Expected: FAIL because `src/lib/brand.js`, `BrandLogo.vue` and `logreva-mark.svg` do not exist.

### Task 2: Build the brand foundation and assets

**Files:**
- Create: `app/src/lib/brand.js`
- Create: `app/src/components/ui/BrandLogo.vue`
- Create: `app/public/logreva-mark.svg`
- Create: `app/scripts/generate-brand-assets.mjs`
- Modify: `app/public/favicon.svg`
- Regenerate: `app/public/pwa-192x192.png`, `app/public/pwa-512x512.png`, `app/public/apple-touch-icon.png`

- [ ] **Step 1: Add canonical brand constants**

```js
export const BRAND_NAME = 'LOGREVA'
export const BRAND_DISPLAY_NAME = 'Logreva'
export const BRAND_DESCRIPTOR = 'GESTIÓN EDUCATIVA'
export const BRAND_ACCESSIBLE_NAME = 'Logreva, gestión educativa'
export const BRAND_COPYRIGHT_YEAR = 2026
export const SALES_WHATSAPP_NUMBER = '593989121871'
export const DEMO_REQUEST_MESSAGE = 'Hola, quiero solicitar una demostración de LOGREVA para mi institución educativa.'
export const DEMO_REQUEST_URL = `https://wa.me/${SALES_WHATSAPP_NUMBER}?text=${encodeURIComponent(DEMO_REQUEST_MESSAGE)}`
```

- [ ] **Step 2: Create `BrandLogo.vue`**

Props:

```js
const props = defineProps({
  variant: { type: String, default: 'horizontal', validator: (value) => ['horizontal', 'compact', 'mark'].includes(value) },
  tone: { type: String, default: 'dark', validator: (value) => ['dark', 'light', 'mono'].includes(value) },
  decorative: { type: Boolean, default: false },
  descriptor: { type: String, default: BRAND_DESCRIPTOR },
})
```

Render an SVG with `viewBox="0 0 72 72"` and the two approved paths. Horizontal/compact variants render `LOGREVA`; only horizontal renders the descriptor. Set `role="img"` and `aria-label="Logreva, gestión educativa"` unless decorative, in which case set `aria-hidden="true"`.

- [ ] **Step 3: Create the public SVG sources**

`logreva-mark.svg` and `favicon.svg` must use the same paths and colors. The favicon uses a `72 × 72` navy background with a safe inset around a scaled white/cyan mark.

- [ ] **Step 4: Create and run the existing-dependency asset generator**

`generate-brand-assets.mjs` imports `chromium` from `@playwright/test`, renders the SVG into square pages and writes exact 192, 512 and 512 PNG screenshots. It must close the browser in `finally`.

Run: `node scripts/generate-brand-assets.mjs`

Expected: three PNG files are replaced and each has non-zero size.

- [ ] **Step 5: Run the brand test**

Run: `npm test -- tests/brandIdentity.test.js --run`

Expected: 3 tests PASS.

### Task 3: Add failing global consistency contracts

**Files:**
- Modify: `app/tests/brandIdentity.test.js`

- [ ] **Step 1: Add global visible-source assertions**

```js
  it('replaces legacy product names in user-facing application sources', () => {
    const visibleFiles = [
      'index.html', 'vite.config.js', 'src/App.vue', 'src/main.js',
      'src/components/Sidebar.vue', 'src/views/Login.vue', 'src/views/Pricing.vue',
      'src/views/Terms.vue', 'src/views/Privacy.vue', 'src/views/Reports.vue',
    ]
    for (const file of visibleFiles) {
      const source = read(file)
      expect(source, file).not.toMatch(/EduCore|WebNotas/i)
    }
    expect(read('src/lib/supabase.js')).toContain('[Logreva]')
    expect(read('src/lib/supabase.js')).toContain("storageKey: 'webnotas-auth-token'")
  })

  it('uses shared branding and contact in public commercial surfaces', () => {
    const login = read('src/views/Login.vue')
    const pricing = read('src/views/Pricing.vue')
    expect(login).toContain("import BrandLogo from '../components/ui/BrandLogo.vue'")
    expect(login).toContain('DEMO_REQUEST_URL')
    expect(pricing).toContain("import BrandLogo from '../components/ui/BrandLogo.vue'")
    expect(pricing).toContain('DEMO_REQUEST_URL')
    expect(pricing).not.toContain('const salesContactUrl =')
  })

  it('brands metadata and PWA without changing commercial plan data', () => {
    expect(read('index.html')).toContain('<title>LOGREVA — Gestión educativa para instituciones</title>')
    const vite = read('vite.config.js')
    expect(vite).toContain("name: 'LOGREVA Gestión Educativa'")
    expect(vite).toContain("short_name: 'LOGREVA'")
    expect(read('src/lib/commercialPlans.js')).toContain("monthlyPrice: 89")
  })
```

- [ ] **Step 2: Run the test and verify RED**

Run: `npm test -- tests/brandIdentity.test.js --run`

Expected: the new tests FAIL on legacy visible names and missing shared imports.

### Task 4: Apply LOGREVA globally

**Files:**
- Modify: `app/index.html`
- Modify: `app/vite.config.js`
- Modify: `app/src/App.vue`
- Modify: `app/src/main.js`
- Modify: `app/src/lib/supabase.js`
- Modify: `app/src/components/Sidebar.vue`
- Modify: `app/src/views/Pricing.vue`
- Modify: `app/src/views/Terms.vue`
- Modify: `app/src/views/Privacy.vue`
- Modify: `app/src/views/Reports.vue`
- Modify: `app/README.md`

- [ ] **Step 1: Rebrand metadata and PWA**

Use the approved title, description and `#0B1530` theme color in `index.html`. Change manifest name/short name/description/theme color in `vite.config.js`; keep existing icon filenames and caching rules.

- [ ] **Step 2: Rebrand loading and diagnostics**

Use `<BrandLogo variant="compact" tone="dark" />` in the auth flash. Change the PWA offline-ready log to `[PWA] LOGREVA lista para trabajar sin conexión.` Change only the visible Supabase error prefix to `[Logreva]`; preserve `webnotas-auth-token` exactly.

- [ ] **Step 3: Rebrand navigation without hiding the institution**

Set the institution fallback to `Logreva` and the descriptor to `LOGREVA · Gestión Académica`. Preserve uploaded institution logo and name behavior, navigation items, collapse state and mobile behavior.

- [ ] **Step 4: Rebrand Pricing without changing offers**

Import `BrandLogo` and `DEMO_REQUEST_URL`. Replace the hand-built old header logo and mockup logo with `BrandLogo`; bind all existing commercial WhatsApp links to `DEMO_REQUEST_URL`; use `LOGREVA` in JSON-LD and visible footer. Do not modify `COMMERCIAL_PLANS`, prices, trial days or plan limits.

- [ ] **Step 5: Rebrand legal and reporting copy**

Replace only product names in Terms/Privacy. Change the report kicker from `Sistema de Notas` to `Logreva · Gestión Académica`. Do not add a legal entity or certification.

- [ ] **Step 6: Update the application README title and visible name references**

Use `# LOGREVA — Gestión Educativa` and describe it as the current Vue/Vite educational SaaS. Historical implementation details can remain if they are not presented as the product name.

- [ ] **Step 7: Run the brand suite**

Run: `npm test -- tests/brandIdentity.test.js tests/commercialPlans.test.js tests/securityConfig.test.js --run`

Expected: all tests PASS and prices/security invariants remain unchanged.

### Task 5: Add failing galaxy and login contracts

**Files:**
- Modify: `app/tests/accessibilityPerformance.test.js`

- [ ] **Step 1: Add the animation lifecycle contract**

```js
  it('isolates the login galaxy and cleans up animation resources', () => {
    const login = read('src/views/Login.vue')
    const galaxy = read('src/components/ui/GalaxyBackground.vue')
    expect(login).toContain("import GalaxyBackground from '../components/ui/GalaxyBackground.vue'")
    expect(login).toContain('<GalaxyBackground />')
    expect(login).not.toContain('canvasRef')
    expect(login).not.toContain('initCanvas')
    expect(galaxy).toContain('aria-hidden="true"')
    expect(galaxy).toContain("matchMedia('(prefers-reduced-motion: reduce)')")
    expect(galaxy).toContain('cancelAnimationFrame(animationFrameId)')
    expect(galaxy).toContain("removeEventListener('pointermove', handlePointerMove)")
    expect(galaxy).toContain("removeEventListener('visibilitychange', handleVisibilityChange)")
    expect(galaxy).toContain('resizeObserver?.disconnect()')
    expect(galaxy).toContain('Math.min(window.devicePixelRatio || 1, 1.5)')
  })
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `npm test -- tests/accessibilityPerformance.test.js --run`

Expected: FAIL because `GalaxyBackground.vue` does not exist and Login still owns the old Canvas.

### Task 6: Implement `GalaxyBackground.vue`

**Files:**
- Create: `app/src/components/ui/GalaxyBackground.vue`

- [ ] **Step 1: Create the decorative component shell**

The root is absolute, inset, overflow hidden, pointer-events none, `aria-hidden="true"`, and exposes `:data-motion="reducedMotion ? 'reduced' : 'full'"`. It contains two CSS nebula layers, one Canvas and one content shield.

- [ ] **Step 2: Implement adaptive particles and protected content zone**

Cap DPR with `Math.min(window.devicePixelRatio || 1, 1.5)`. Rebuild 40–70 persistent particles on resize, with three depth layers. Prevent bright particles and featured meteor origins inside the normalized safe rectangle covering the central content.

- [ ] **Step 3: Implement one render loop**

Frame order: clear Canvas, smooth parallax, draw energy paths/travelers, draw particles, draw ambient meteors, draw at most one featured shooting star. Schedule the next featured star 4–8 seconds after the current one finishes. Restore Canvas blend mode after glow operations.

- [ ] **Step 4: Implement accessibility and lifecycle**

Reduced motion draws one static scene and never schedules a continuous frame. Visibility changes stop/restart exactly one frame. Mount pointer, visibility, resize and media-query handlers; unmount cancels frame, removes all handlers and disconnects observer.

- [ ] **Step 5: Run the focused contract test**

Run: `npm test -- tests/accessibilityPerformance.test.js --run`

Expected: component assertions pass; Login integration assertions still FAIL.

### Task 7: Recompose the login without changing authentication

**Files:**
- Modify: `app/src/views/Login.vue`

- [ ] **Step 1: Remove only the obsolete Canvas engine**

Delete `canvasRef`, `animationId`, `initCanvas`, its mount call and Canvas cleanup. Keep Supabase recovery detection, sign-in, password recovery and password update logic unchanged.

- [ ] **Step 2: Import shared presentation**

Import `BrandLogo`, `GalaxyBackground`, `DEMO_REQUEST_URL`, `BRAND_DISPLAY_NAME`, `BRAND_COPYRIGHT_YEAR`, and the needed existing Lucide icons. Do not add dependencies.

- [ ] **Step 3: Apply approved desktop copy and visual hierarchy**

Render `BrandLogo` in dark mode, the exact approved heading/tagline/three benefits, and the existing Access Secure card copy. Insert `<GalaxyBackground />` behind all content. Keep the left panel `hidden lg:flex` and all background elements behind `z-10` content.

- [ ] **Step 4: Apply approved form, CTA and footer**

Normal state heading: `Bienvenido a Logreva`; subtitle: `Ingresa tus credenciales institucionales`. Preserve recovery/update-state headings. Add a secure external demo link to `DEMO_REQUEST_URL`, route links to plans/terms/privacy and the Ecuador/LatAm footer. Use `BrandLogo` in the existing mobile header; do not expose the galaxy on mobile.

- [ ] **Step 5: Run focused unit contracts**

Run: `npm test -- tests/accessibilityPerformance.test.js tests/brandIdentity.test.js tests/securityConfig.test.js --run`

Expected: all focused tests PASS.

### Task 8: Add responsive browser verification

**Files:**
- Create: `app/e2e/login-logreva.spec.js`

- [ ] **Step 1: Add desktop, mobile and reduced-motion tests**

```js
import { test, expect } from '@playwright/test'

test.describe('Login LOGREVA', () => {
  test('muestra la marca y limita la galaxia al panel izquierdo', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.goto('/login')
    await expect(page.locator('.galaxy-background')).toBeVisible()
    await expect(page.getByText('LOGREVA', { exact: true }).first()).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Bienvenido a Logreva' })).toBeVisible()
    await expect(page.getByRole('link', { name: 'Solicita una demo' })).toHaveAttribute('href', /wa\.me\/593989121871/)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth)).toBe(true)
  })

  test('mantiene móvil sin galaxia y con marca accesible', async ({ page }) => {
    await page.setViewportSize({ width: 360, height: 800 })
    await page.goto('/login')
    await expect(page.locator('.galaxy-background')).toBeHidden()
    await expect(page.getByRole('heading', { name: 'Bienvenido a Logreva' })).toBeVisible()
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth)).toBe(true)
  })

  test('reduce el movimiento a una escena estática', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.goto('/login')
    await expect(page.locator('.galaxy-background')).toHaveAttribute('data-motion', 'reduced')
  })
})
```

- [ ] **Step 2: Run the focused E2E file**

Run: `npx playwright test e2e/login-logreva.spec.js`

Expected: 3 passed.

### Task 9: Full verification and visual evidence

**Files:**
- Verify only; no planned source changes.

- [ ] **Step 1: Run all Vitest tests**

Run: `npm test -- --run`

Expected: all tests pass.

- [ ] **Step 2: Build and enforce bundle budget**

Run: `npm run build`

Run: `npm run check:bundle`

Expected: both commands pass with no new dependency chunk.

- [ ] **Step 3: Run all Playwright tests**

Run: `npm run test:e2e`

Expected: all E2E tests pass.

- [ ] **Step 4: Capture and inspect approved breakpoints**

Capture `/login` at 1440 × 900, 1024 × 768 and 360 × 800. Confirm Architect logo proportions, clean content zone, restrained galaxy, footer wrapping, no layout shift and no horizontal overflow. Inspect 192/512 PWA PNGs.

- [ ] **Step 5: Search for legacy visible names**

Run: `rg -n -i --glob '!node_modules/**' --glob '!dist/**' --glob '!build_log.txt' '(EduCore|WebNotas)' src index.html vite.config.js README.md`

Expected: no user-facing legacy brand occurrence; `webnotas-auth-token` remains only as the deliberate compatibility exception.

- [ ] **Step 6: Review scoped diff**

Run: `git diff -- app/index.html app/vite.config.js app/src/App.vue app/src/main.js app/src/lib/brand.js app/src/lib/supabase.js app/src/components/ui/BrandLogo.vue app/src/components/ui/GalaxyBackground.vue app/src/components/Sidebar.vue app/src/views/Login.vue app/src/views/Pricing.vue app/src/views/Terms.vue app/src/views/Privacy.vue app/src/views/Reports.vue app/public app/tests app/e2e/login-logreva.spec.js app/README.md docs/superpowers`

Expected: only approved brand, login animation, tests, assets and documentation changes. Do not stage, commit or deploy without explicit authorization.
