import { test, expect } from '@playwright/test'
import { expectNoPageOverflow, mockInstitution } from './fixtures/institution'

test.describe('Gestión de años lectivos — API completamente simulada', () => {
  test('Rector crea un año en su institución desde móvil sin enviar school_id', async ({ page }) => {
    await page.setViewportSize({ width: 360, height: 800 })
    const fixture = await mockInstitution(page, {
      role: 'rector',
      permissions: [
        'academic_year.read',
        'academic_year.create',
        'academic_year.update',
        'students.read',
      ],
    })

    await page.goto('/courses')
    await expect(page.getByRole('heading', { name: 'Gestión de Cursos' })).toBeVisible()
    await page.getByRole('button', { name: '+ Nuevo Año' }).click()
    await expect(page.getByRole('dialog', { name: 'Crear Nuevo Año Lectivo' })).toBeVisible()
    await page.getByLabel('Periodo académico').fill('2027-2028')
    await page.getByRole('button', { name: 'Crear Año Lectivo' }).click()

    await expect.poll(() => fixture.writes.filter(write => write.rpc === 'create_academic_year').length).toBe(1)
    const creation = fixture.writes.find(write => write.rpc === 'create_academic_year')
    expect(creation.payload).toEqual({
      p_name: '2027-2028',
      p_start_year: 2027,
      p_end_year: 2028,
      p_make_current: false,
    })
    await expect(page.getByText('Copiar Cursos de Otro Año Lectivo')).toBeVisible()
    await expectNoPageOverflow(page)
    await fixture.assertClean()
  })

  test('un docente no obtiene permiso de creación en el contexto de acceso', async ({ page }) => {
    const fixture = await mockInstitution(page, {
      role: 'teacher',
      permissions: ['academic_year.read'],
    })
    await page.goto('/courses')
    await expect(page).toHaveURL(/\/acceso-denegado/)
    await expect(page.getByRole('button', { name: '+ Nuevo Año' })).toHaveCount(0)
    await fixture.assertClean()
  })
})
