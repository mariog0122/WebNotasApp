import { test, expect } from '@playwright/test'

test.describe('Rutas protegidas', () => {
  test('sin sesión, /grades redirige a login', async ({ page }) => {
    await page.goto('/grades')
    await expect(page).toHaveURL(/\/login/)
  })
})
