import { test, expect } from '@playwright/test'

test.describe('Acceso institucional LOGREVA', () => {
  test('muestra la experiencia premium completa en escritorio', async ({ page }) => {
    const consoleErrors = []
    page.on('console', (message) => {
      if (message.type() === 'error') consoleErrors.push(message.text())
    })

    await page.goto('/login')

    await expect(page.getByTestId('login-brand-panel')).toBeVisible()
    await expect(page.getByTestId('login-card')).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Bienvenido a Logreva' })).toBeVisible()
    await expect(page.getByRole('heading', { name: /Gestión Académica\s+Centralizada/ })).toBeVisible()
    await expect(page.locator('canvas')).toHaveCount(1)
    await expect(page.getByRole('link', { name: 'Solicita una demo' })).toHaveAttribute('href', /wa\.me\/593989121871/)

    const overflow = await page.evaluate(() => ({
      documentWidth: document.documentElement.scrollWidth,
      viewportWidth: document.documentElement.clientWidth,
    }))
    expect(overflow.documentWidth).toBeLessThanOrEqual(overflow.viewportWidth)
    expect(consoleErrors).toEqual([])
  })

  test('mantiene el acceso usable y sin desbordamiento en móvil', async ({ page }) => {
    await page.setViewportSize({ width: 360, height: 800 })
    await page.goto('/login')

    await expect(page.getByTestId('login-brand-panel')).toBeHidden()
    await expect(page.getByTestId('login-card')).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Bienvenido a Logreva' })).toBeVisible()

    const password = page.locator('#login-password')
    await expect(password).toHaveAttribute('type', 'password')
    await page.getByRole('button', { name: 'Mostrar contraseña' }).click()
    await expect(password).toHaveAttribute('type', 'text')
    await expect(page.getByRole('button', { name: 'Ocultar contraseña' })).toBeVisible()

    const overflow = await page.evaluate(() => ({
      documentWidth: document.documentElement.scrollWidth,
      viewportWidth: document.documentElement.clientWidth,
    }))
    expect(overflow.documentWidth).toBeLessThanOrEqual(overflow.viewportWidth)
  })
})
