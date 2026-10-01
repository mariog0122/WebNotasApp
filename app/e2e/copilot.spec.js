import { test, expect } from '@playwright/test'
import { mockInstitution, expectNoPageOverflow } from './fixtures/institution'

for (const width of [320, 390, 1366]) {
  test(`copiloto consulta sin inventar datos a ${width}px`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width, height: 900 })
    const fixture = await mockInstitution(page)
    await page.goto('/attendance')
    await page.getByRole('button', { name: 'Abrir Asistente Logreva' }).click()
    const input = page.getByPlaceholder('Escribe una instrucción o pregunta a Logreva...')
    await input.fill('¿Qué estudiantes faltaron hoy?')
    await input.press('Enter')
    await expect(page.getByText(/No hay novedades de asistencia registradas/)).toBeVisible()
    await input.fill('tareas pendientes')
    await input.press('Enter')
    await expect(page.getByText(/todavía no dispone de una agenda de tareas conectada/)).toBeVisible()
    await expect(input, 'the composer must remain visible after responses').toBeInViewport()
    if (width < 1024) {
      const chat = input.locator('xpath=../preceding-sibling::div[1]')
      const capabilitySections = [
        page.getByText('Gestión y Consulta', { exact: true }).locator('..'),
        page.getByText('Operaciones del Plantel', { exact: true }).locator('..'),
      ]
      const chatBox = await chat.boundingBox()
      expect(chatBox).not.toBeNull()
      for (const section of capabilitySections) {
        const sectionBox = await section.boundingBox()
        expect(sectionBox).not.toBeNull()
        expect(sectionBox.y, 'capability cards must start after the mobile chat').toBeGreaterThanOrEqual(chatBox.y + chatBox.height)
      }
    }
    await expectNoPageOverflow(page)
    expect(fixture.writes).toEqual([])
    await page.screenshot({ path: testInfo.outputPath(`copilot-${width}.png`), fullPage: true, animations: 'disabled' })
    await fixture.assertClean()
  })
}
