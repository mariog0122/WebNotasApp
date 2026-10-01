import { test, expect } from '@playwright/test'

const USER_ID = '00000000-0000-4000-8000-000000000010'
const TENANT_A = '00000000-0000-4000-8000-000000000011'
const TENANT_B = '00000000-0000-4000-8000-000000000012'

async function mockSuperadmin(page) {
  const errors = []
  const statusWrites = []
  const unexpectedRequests = []
  const user = {
    id: USER_ID,
    email: 'superadmin@example.invalid',
    aud: 'authenticated',
    role: 'authenticated',
    app_metadata: {},
    user_metadata: {}
  }
  const schools = [
    { id: TENANT_A, name: 'Institución A', code: 'A001', country: 'Ecuador', province: 'Guayas', city: 'Milagro', status: 'suspended', created_at: '2026-01-01T00:00:00Z' },
    { id: TENANT_B, name: 'Institución B', code: 'B001', country: 'Ecuador', province: 'Guayas', city: 'Milagro', status: 'active', created_at: '2026-01-02T00:00:00Z' }
  ]

  page.on('pageerror', error => errors.push(error.message))
  page.on('console', message => {
    if (message.type() === 'error') errors.push(message.text())
  })

  await page.addInitScript(({ user, activeSchoolId }) => {
    const token = [btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' })), btoa(JSON.stringify({ sub: user.id, exp: 4102444800 })), 'synthetic-signature'].join('.')
    localStorage.setItem('webnotas-auth-token', JSON.stringify({ access_token: token, refresh_token: 'synthetic-refresh', expires_at: 4102444800, expires_in: 3600, token_type: 'bearer', user }))
    localStorage.setItem('webnotas-active-school-id', activeSchoolId)
  }, { user, activeSchoolId: TENANT_B })

  await page.context().route('**/*', async route => {
    const request = route.request()
    const url = new URL(request.url())
    const method = request.method()
    if (['localhost', '127.0.0.1'].includes(url.hostname) && method === 'GET' && !url.pathname.startsWith('/api/')) return route.continue()
    if (['fonts.googleapis.com', 'fonts.gstatic.com'].includes(url.hostname)) return route.fulfill({ status: 200, contentType: 'text/css', body: '' })

    const reply = (data, headers = {}) => route.fulfill({ status: 200, contentType: 'application/json', headers, body: method === 'HEAD' ? '' : JSON.stringify(data) })
    if (url.pathname === '/auth/v1/user') return reply(user)
    if (url.pathname === '/rest/v1/rpc/get_my_access_context') {
      return reply({
        user_id: USER_ID,
        default_school_id: TENANT_B,
        is_platform_admin: true,
        is_platform_owner: true,
        platform_roles: ['platform_owner'],
        memberships: []
      })
    }
    if (url.pathname === '/rest/v1/rpc/set_tenant_status' && method === 'POST') {
      const payload = request.postDataJSON()
      statusWrites.push(payload)
      const school = schools.find(item => item.id === payload.p_school_id)
      const previous = school?.status
      if (school) school.status = payload.p_new_status
      return reply({ success: true, changed: previous !== payload.p_new_status, previous_status: previous, new_status: payload.p_new_status })
    }
    if (url.pathname === '/rest/v1/rpc/is_intelligence_module_enabled' && method === 'POST') return reply(false)
    if (url.pathname === '/rest/v1/schools') return reply(schools)
    if (url.pathname === '/rest/v1/profiles') {
      if (url.searchParams.has('id')) return reply({ id: USER_ID, email: user.email, full_name: 'Superadmin E2E', role: 'superadmin', school_id: null, is_active: true })
      return reply([
        { id: '00000000-0000-4000-8000-000000000013', school_id: TENANT_A, full_name: 'Admin A', email: 'a@example.invalid', role: 'admin' },
        { id: '00000000-0000-4000-8000-000000000014', school_id: TENANT_B, full_name: 'Admin B', email: 'b@example.invalid', role: 'admin' }
      ])
    }
    if (url.pathname === '/rest/v1/subscriptions') return reply([])
    if (url.pathname === '/rest/v1/tenant_billing_profiles') return reply([])
    if (url.pathname === '/rest/v1/students') return reply([])
    if (url.pathname === '/rest/v1/payments') return reply([])
    if (url.pathname.startsWith('/rest/v1/') && ['GET', 'HEAD'].includes(method)) return reply([], { 'content-range': '0-0/0' })
    unexpectedRequests.push(`${method} ${url.pathname}`)
    return route.fulfill({ status: 501, contentType: 'application/json', body: JSON.stringify({ message: 'Unregistered synthetic request' }) })
  })

  return { errors, statusWrites, unexpectedRequests }
}

for (const width of [390, 1366]) {
  test(`reactiva la fila pulsada sin usar el contexto institucional a ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    const fixture = await mockSuperadmin(page)
    await page.goto('/superadmin')
    await page.getByRole('button', { name: 'Instituciones', exact: true }).click()

    const targetRow = page.getByRole('row').filter({ hasText: 'Institución A' })
    const unrelatedRow = page.getByRole('row').filter({ hasText: 'Institución B' })
    await expect(targetRow.locator('td').nth(4).getByText('Suspendida', { exact: true })).toBeVisible()
    await expect(unrelatedRow.locator('td').nth(4).getByText('Activa', { exact: true })).toBeVisible()

    await targetRow.getByRole('button', { name: 'Reactivar institución' }).dblclick()
    await expect.poll(() => fixture.statusWrites.length).toBe(1)
    expect(fixture.statusWrites[0].p_school_id).toBe(TENANT_A)
    expect(fixture.statusWrites[0].p_school_id).not.toBe(TENANT_B)

    await expect(targetRow.locator('td').nth(4).getByText('Activa', { exact: true })).toBeVisible()
    await expect(unrelatedRow.locator('td').nth(4).getByText('Activa', { exact: true })).toBeVisible()
    await expect(page.getByText('Institución reactivada correctamente: Institución A.')).toBeVisible()
    expect(fixture.unexpectedRequests).toEqual([])
    expect(fixture.errors, `Solicitudes sintéticas sin registrar: ${fixture.unexpectedRequests.join(', ')}`).toEqual([])
  })
}
