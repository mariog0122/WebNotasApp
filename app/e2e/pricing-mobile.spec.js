import { test, expect } from '@playwright/test'

test.describe('Planes en móvil', () => {
  test.use({ viewport: { width: 360, height: 800 } })

  test('no desborda y mantiene controles accesibles', async ({ page }) => {
    await page.goto('/planes')
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()

    const overflow = await page.evaluate(() => ({
      documentWidth: document.documentElement.scrollWidth,
      viewportWidth: document.documentElement.clientWidth,
    }))
    expect(overflow.documentWidth).toBeLessThanOrEqual(overflow.viewportWidth)

    const unnamedControls = await page.locator('a[href]:visible, button:visible').evaluateAll((nodes) =>
      nodes
        .filter((node) => !((node.getAttribute('aria-label') || node.textContent || '').trim()))
        .map((node) => node.outerHTML),
    )
    expect(unnamedControls).toEqual([])

    const billingSwitch = page.getByRole('switch', { name: 'Facturación anual' })
    await expect(billingSwitch).toHaveAttribute('aria-checked', 'true')
    await billingSwitch.click()
    await expect(billingSwitch).toHaveAttribute('aria-checked', 'false')
  })
})
