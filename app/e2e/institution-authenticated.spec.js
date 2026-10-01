import { test, expect } from '@playwright/test'
import { mockInstitution, expectNoPageOverflow, IDS } from './fixtures/institution'

test.describe('Flujos institucionales — API completamente simulada', () => {
  test.use({ timezoneId: 'America/Guayaquil' })

  test('fecha de asistencia y mes corresponden al día institucional al fin de mes', async ({ page }) => {
    const fixture = await mockInstitution(page)
    await page.clock.setFixedTime(new Date('2026-09-01T04:30:00Z'))
    await page.goto('/attendance')
    await expect(page.getByRole('heading', { name: 'Control de Asistencia' })).toBeVisible()
    await expect(page.getByRole('textbox', { name: 'Seleccionar fecha' })).toHaveValue('2026-08-31')
    await page.getByRole('button', { name: '3. Sábana Mensual' }).click()
    await expect(page.locator('input[type="month"]')).toHaveValue('2026-08')
    await fixture.assertClean()
  })

  test('menu mantiene enlaces nombrados e iconos y permite navegar a asistencia e informes', async ({ page }) => {
    const fixture = await mockInstitution(page)
    await page.goto('/attendance')
    const menu = page.getByRole('complementary', { name: 'Navegación principal' })
    for (const [name, path, heading] of [
      ['Informes Docentes', '/teacher-reports', 'Informes Docentes'],
      ['Asistencia', '/attendance', 'Control de Asistencia'],
      ['Bienestar Estudiantil', '/alerts', 'Bienestar Estudiantil'],
      ['Familias', '/families', 'Familias y Representantes'],
    ]) {
      const link = menu.getByRole('link', { name: new RegExp(name) })
      await expect(link).toHaveAttribute('href', path)
      await expect(link.locator('svg')).toBeVisible()
      await link.click()
      await expect(page).toHaveURL(new RegExp(`${path}$`))
      await expect(page.getByRole('heading', { name: heading, exact: true })).toBeVisible()
    }
    await page.getByRole('button', { name: 'Contraer menú lateral' }).click()
    await expect(menu.getByRole('link', { name: /Asistencia/ })).toBeVisible()
    await expect(menu.getByRole('link', { name: /Informes Docentes/ })).toBeVisible()
    await fixture.assertClean()
  })

  test('un rol sin permisos no ve módulos académicos y no entra por URL directa', async ({ page }) => {
    const fixture = await mockInstitution(page, { role: 'parent', permissions: [] })
    await page.goto('/attendance')
    await expect(page).toHaveURL(/\/acceso-denegado/)
    await expect(page.locator('#main-sidebar a[href="/attendance"]')).toHaveCount(0)
    await expect(page.locator('#main-sidebar a[href="/teacher-reports"]')).toHaveCount(0)
    await expect(page.locator('#main-sidebar a[href="/alerts"]')).toHaveCount(0)
    await page.goto('/teacher-reports')
    await expect(page).toHaveURL(/\/acceso-denegado/)
    await page.goto('/superadmin')
    await expect(page).toHaveURL(/\/acceso-denegado/)
    await fixture.assertClean()
  })

  for (const scenario of [
    { permissions: ['grades.read'], denied: '/teacher-reports' },
    { permissions: ['grades.read'], denied: '/attendance' },
    { permissions: ['attendance.read'], denied: '/alerts' },
  ]) {
    test(`el menú respeta la denegación de ${scenario.denied} con ${scenario.permissions}`, async ({ page }) => {
      const fixture = await mockInstitution(page, { permissions: scenario.permissions })
      await page.goto(scenario.denied)
      await expect(page).toHaveURL(/\/acceso-denegado/)
      await expect(page.locator(`#main-sidebar a[href="${scenario.denied}"]`)).toHaveCount(0)
      await fixture.assertClean()
    })
  }

  test('citación usa la fecha institucional y guarda solo en el simulador', async ({ page }) => {
    const fixture = await mockInstitution(page)
    await page.clock.setFixedTime(new Date('2026-09-01T04:30:00Z'))
    await page.goto('/teacher-reports')
    await page.getByRole('button', { name: 'Nuevo Documento / Citación' }).click()
    await expect(page.locator('input[type="date"]')).toHaveValue('2026-08-31')
    const studentSelector = page.locator('select').filter({ has: page.locator(`option[value="${IDS.student}"]`) })
    await studentSelector.selectOption(IDS.student)
    await page.getByRole('button', { name: 'Guardar Borrador', exact: true }).click()
    await expect.poll(() => fixture.writes.length).toBe(1)
    expect(fixture.writes[0].payload.p_report).toMatchObject({ student_id: IDS.student, citation_date: '2026-08-31', status: 'borrador' })
    await expect(page.getByText('Informe guardado como borrador')).toBeVisible()
    await fixture.assertClean()
  })

  for (const width of [320, 360, 375, 390, 414, 768, 1366, 1920]) {
    test(`asistencia e informes usables a ${width}px`, async ({ page }, testInfo) => {
      await page.setViewportSize({ width, height: 900 })
      const fixture = await mockInstitution(page)
      await page.goto('/attendance')
      await expect(page.getByRole('button', { name: 'Guardar Asistencia' })).toBeEnabled()
      await expectNoPageOverflow(page)
      await page.getByRole('button', { name: 'Marcar como Atraso', exact: true }).click()
      await page.getByRole('button', { name: 'Guardar Asistencia' }).click()
      await expect.poll(() => fixture.writes.length).toBe(1)
      expect(fixture.writes[0].payload.p_records).toEqual([{ student_id: IDS.student, status: 'atraso', observations: null }])
      await expect(page.getByText('Asistencia guardada correctamente')).toBeVisible()
      await page.screenshot({ path: testInfo.outputPath(`asistencia-${width}.png`), fullPage: true, animations: 'disabled' })
      await page.goto('/teacher-reports')
      await expect(page.getByRole('heading', { name: 'Informes Docentes', exact: true })).toBeVisible()
      await expectNoPageOverflow(page)
      await page.screenshot({ path: testInfo.outputPath(`informes-${width}.png`), fullPage: true, animations: 'disabled' })
      await page.goto('/alerts')
      await expect(page.getByRole('heading', { name: 'Bienestar Estudiantil', exact: true })).toBeVisible()
      await expect(page.getByRole('button', { name: 'Nueva Alerta' })).toBeVisible()
      await expectNoPageOverflow(page)
      await page.screenshot({ path: testInfo.outputPath(`bienestar-${width}.png`), fullPage: true, animations: 'disabled' })
      await page.goto('/families')
      await expect(page.getByRole('heading', { name: 'Familias y Representantes', exact: true })).toBeVisible()
      await expectNoPageOverflow(page)
      await page.screenshot({ path: testInfo.outputPath(`familias-${width}.png`), fullPage: true, animations: 'disabled' })
      await fixture.assertClean()
    })
  }
})
