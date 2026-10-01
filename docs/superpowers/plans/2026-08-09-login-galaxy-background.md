# Login Galaxy Background Implementation Plan

> Superseded by `2026-08-09-logreva-brand-and-login.md`, which combines the approved global LOGREVA identity with this animation.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing 300-star login Canvas with a reusable, accessible and lightweight premium galaxy background without changing the login layout or content.

**Architecture:** A self-contained Vue component owns all decorative Canvas/CSS rendering and lifecycle cleanup. `Login.vue` only renders that component inside the existing desktop-only left panel. Static contract tests guard lifecycle and accessibility requirements, while Playwright verifies desktop visibility, mobile preservation, reduced motion and overflow.

**Tech Stack:** Vue 3 Composition API, Vite, JavaScript, Canvas 2D, scoped CSS, Tailwind CSS, Vitest and Playwright.

---

## File structure

- Create `app/src/components/ui/GalaxyBackground.vue`: Canvas engine, CSS nebula, parallax, reduced-motion behavior and complete cleanup.
- Modify `app/src/views/Login.vue`: replace only the old inline Canvas implementation with `<GalaxyBackground />`.
- Modify `app/tests/accessibilityPerformance.test.js`: add source-level contracts for integration, accessibility and cleanup.
- Create `app/e2e/login-galaxy.spec.js`: verify responsive behavior, overflow, visible content and reduced motion.

No dependency, authentication, global style or mobile layout file changes are required.

### Task 1: Add failing component contracts

**Files:**
- Modify: `app/tests/accessibilityPerformance.test.js`

- [ ] **Step 1: Add a failing contract test**

Append this test inside the existing `describe` block:

```js
  it('isolates the login galaxy and cleans up every animation resource', () => {
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
    expect(galaxy).toContain(':data-motion="reducedMotion ? \'reduced\' : \'full\'"')
  })
```

- [ ] **Step 2: Run the focused test and verify failure**

Run: `npm test -- tests/accessibilityPerformance.test.js --run`

Expected: FAIL because `src/components/ui/GalaxyBackground.vue` does not exist.

### Task 2: Build the reusable Canvas/CSS component

**Files:**
- Create: `app/src/components/ui/GalaxyBackground.vue`

- [ ] **Step 1: Create the component shell and lifecycle state**

Use `<script setup>` with `ref`, `onMounted` and `onUnmounted`. Define refs for the root and Canvas, one animation frame id, one resize observer, one media query, dimensions, reduced-motion state, pointer target/current values, particles, energy travelers, ambient meteors and the single featured shooting star.

The component template must be:

```vue
<template>
  <div
    ref="rootRef"
    class="galaxy-background"
    aria-hidden="true"
    :data-motion="reducedMotion ? 'reduced' : 'full'"
  >
    <div class="galaxy-nebula galaxy-nebula-a"></div>
    <div class="galaxy-nebula galaxy-nebula-b"></div>
    <canvas ref="canvasRef" class="galaxy-canvas"></canvas>
    <div class="galaxy-content-shield"></div>
  </div>
</template>
```

- [ ] **Step 2: Implement deterministic resource setup**

Implement `resizeCanvas()` so it:

```js
const ratio = Math.min(window.devicePixelRatio || 1, 1.5)
const rect = rootRef.value.getBoundingClientRect()
width = Math.max(1, Math.round(rect.width))
height = Math.max(1, Math.round(rect.height))
canvas.width = Math.round(width * ratio)
canvas.height = Math.round(height * ratio)
canvas.style.width = `${width}px`
canvas.style.height = `${height}px`
context.setTransform(ratio, 0, 0, ratio, 0, 0)
```

Rebuild 40–70 particles only when the component size changes. Assign each particle a depth layer, normalized position, radius, drift, twinkle phase and one color from the approved palette. Keep bright particles out of the normalized content-safe rectangle `{ x: 0.08–0.72, y: 0.10–0.82 }`.

- [ ] **Step 3: Implement all drawing layers in one frame**

The frame order must be:

```js
context.clearRect(0, 0, width, height)
updateParallax()
drawEnergyStreams(time)
drawParticles(time)
drawAmbientMeteors(delta, time)
drawFeaturedShootingStar(delta)
animationFrameId = requestAnimationFrame(renderFrame)
```

Use three quadratic/Bézier energy paths limited to the lower 36% and rightmost 30% of the panel. Use `globalCompositeOperation = 'lighter'` only while drawing glow layers, then restore it to `source-over`.

Ambient meteors use gradient tails and low alpha. The featured star is the only high-intensity meteor and receives `nextShootingStarAt = time + randomBetween(4000, 8000)` after completion.

- [ ] **Step 4: Implement interaction, visibility and reduced motion**

`handlePointerMove` must map the pointer to `[-1, 1]`; the smoothed parallax offsets cannot exceed 8 px. `handlePointerLeave` resets the target to zero.

`handleMotionPreference` must stop the continuous frame and call `drawStaticScene()` when reduced motion is active. `handleVisibilityChange` must stop the frame while hidden and restart exactly one frame when visible.

- [ ] **Step 5: Implement complete teardown**

The unmount hook must contain:

```js
if (animationFrameId !== null) {
  cancelAnimationFrame(animationFrameId)
  animationFrameId = null
}
rootRef.value?.removeEventListener('pointermove', handlePointerMove)
rootRef.value?.removeEventListener('pointerleave', handlePointerLeave)
document.removeEventListener('visibilitychange', handleVisibilityChange)
motionQuery?.removeEventListener('change', handleMotionPreference)
resizeObserver?.disconnect()
```

Do not use `setInterval`, video, GIF, WebGL or external images.

- [ ] **Step 6: Add scoped CSS**

Use absolute positioning and pointer isolation:

```css
.galaxy-background { position: absolute; inset: 0; overflow: hidden; pointer-events: none; background: #020617; }
.galaxy-canvas { position: absolute; inset: 0; width: 100%; height: 100%; }
.galaxy-nebula { position: absolute; inset: -12%; opacity: .24; transform: translate3d(0,0,0); }
.galaxy-content-shield { position: absolute; inset: 0; background: radial-gradient(ellipse at 38% 44%, rgba(2,6,23,.48) 0%, rgba(2,6,23,.18) 42%, transparent 68%); }
@media (prefers-reduced-motion: reduce) { .galaxy-nebula { animation: none !important; } }
```

Nebula animations must use only transform and opacity, last at least 18 seconds and remain subtle.

- [ ] **Step 7: Run the focused contract test**

Run: `npm test -- tests/accessibilityPerformance.test.js --run`

Expected: still FAIL because `Login.vue` has not been integrated yet, while component lifecycle assertions pass.

### Task 3: Integrate without changing the login

**Files:**
- Modify: `app/src/views/Login.vue`

- [ ] **Step 1: Import the component**

Add:

```js
import GalaxyBackground from '../components/ui/GalaxyBackground.vue'
```

- [ ] **Step 2: Remove only the obsolete Canvas engine**

Delete `canvasRef`, `animationId`, `initCanvas()`, the `initCanvas()` mount call and Canvas cleanup code. Keep the existing auth mount logic intact. Remove `onUnmounted` from the Vue import only if it has no remaining use.

- [ ] **Step 3: Replace the old decorative layers**

Inside the existing desktop-only left panel, replace the gradient wrapper and `<canvas>` with:

```vue
<GalaxyBackground />
```

Do not change any class or child after the background component.

- [ ] **Step 4: Run the focused contract test**

Run: `npm test -- tests/accessibilityPerformance.test.js --run`

Expected: PASS.

### Task 4: Add responsive browser verification

**Files:**
- Create: `app/e2e/login-galaxy.spec.js`

- [ ] **Step 1: Add desktop and mobile tests**

```js
import { test, expect } from '@playwright/test'

test.describe('Fondo galáctico del login', () => {
  test('se limita al panel izquierdo sin alterar el contenido', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.goto('/login')
    await expect(page.locator('.galaxy-background')).toBeVisible()
    await expect(page.getByRole('heading', { name: /Gestión Académica/i })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Bienvenido' })).toBeVisible()
    await expect(page.locator('.galaxy-background canvas')).toBeVisible()
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth)
    expect(overflow).toBe(true)
  })

  test('mantiene el login móvil sin panel decorativo visible', async ({ page }) => {
    await page.setViewportSize({ width: 360, height: 800 })
    await page.goto('/login')
    await expect(page.locator('.galaxy-background')).toBeHidden()
    await expect(page.getByRole('heading', { name: 'Bienvenido' })).toBeVisible()
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth)
    expect(overflow).toBe(true)
  })

  test('respeta la preferencia de movimiento reducido', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.goto('/login')
    await expect(page.locator('.galaxy-background')).toHaveAttribute('data-motion', 'reduced')
  })
})
```

- [ ] **Step 2: Run the focused E2E test**

Run: `npx playwright test e2e/login-galaxy.spec.js`

Expected: 3 passed.

### Task 5: Full verification and visual review

**Files:**
- Verify only; no planned file changes.

- [ ] **Step 1: Run all unit tests**

Run: `npm test -- --run`

Expected: all tests pass.

- [ ] **Step 2: Build and check the production bundle**

Run: `npm run build`

Expected: Vite build completes without warnings introduced by the component.

Run: `npm run check:bundle`

Expected: compressed asset budgets pass.

- [ ] **Step 3: Run all Playwright tests**

Run: `npm run test:e2e`

Expected: all E2E tests pass.

- [ ] **Step 4: Inspect screenshots at approved sizes**

Capture `/login` at 1440 × 900 and 1024 × 768. Verify the content safe zone, restrained glow, lower/right energy flow, unchanged form/layout and no horizontal overflow.

- [ ] **Step 5: Review the diff scope**

Run: `git diff -- app/src/components/ui/GalaxyBackground.vue app/src/views/Login.vue app/tests/accessibilityPerformance.test.js app/e2e/login-galaxy.spec.js docs/superpowers/specs/2026-08-09-login-galaxy-background-design.md docs/superpowers/plans/2026-08-09-login-galaxy-background.md`

Expected: only the approved background component, its narrow integration, tests and documentation appear. Do not stage or commit without explicit user authorization.
