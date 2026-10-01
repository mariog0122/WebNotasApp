import { expect } from '@playwright/test'

// Entirely synthetic identities and data. No request to a real API is continued.
export const IDS = {
  user: '00000000-0000-4000-8000-000000000001',
  school: '00000000-0000-4000-8000-000000000002',
  course: '00000000-0000-4000-8000-000000000003',
  student: '00000000-0000-4000-8000-000000000004',
  subject: '00000000-0000-4000-8000-000000000005',
}

export async function mockInstitution(page, {
  role = 'teacher',
  permissions = [
    'students.read', 'grades.read', 'reports.read',
    'attendance.read', 'attendance.manage',
    'wellbeing.read', 'wellbeing.create',
  ],
  timezone = 'America/Guayaquil',
} = {}) {
  const unexpected = []
  const errors = []
  const requests = []
  const writes = []
  let attendance = []
  page.on('pageerror', error => errors.push(error.message))
  page.on('console', message => {
    if (message.type() === 'error') errors.push(message.text())
  })
  const user = { id: IDS.user, email: 'docente@example.invalid', aud: 'authenticated', role: 'authenticated', app_metadata: {}, user_metadata: {} }
  await page.addInitScript(({ user }) => {
    const token = [btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' })), btoa(JSON.stringify({ sub: user.id, exp: 4102444800 })), 'synthetic-signature'].join('.')
    localStorage.setItem('webnotas-auth-token', JSON.stringify({ access_token: token, refresh_token: 'synthetic-refresh', expires_at: 4102444800, expires_in: 3600, token_type: 'bearer', user }))
  }, { user })

  const student = { id: IDS.student, course_id: IDS.course, full_name: 'Estudiante de Prueba', student_cedula: '0000000000', representative_name: 'Representante de Prueba', representative_phone: '' }
  const course = { id: IDS.course, name: 'Octavo A de Prueba', level: 'EGB', academic_year: '2026-2027' }
  const tables = {
    profiles: { ...user, full_name: 'Docente de Prueba', role, school_id: IDS.school, photo_url: null },
    academic_years: [{ id: 'year-fixture', name: '2026-2027', start_year: 2026, end_year: 2027, is_current: true, is_locked: false }],
    system_config: [{ key: 'institution_name', value: 'Institución Simulada E2E' }],
    schools: { id: IDS.school, name: 'Institución Simulada E2E', timezone, is_active: true, status: 'active' },
    courses: [course], students: [student], subjects: [],
    course_subjects: [{ id: 'assignment-fixture', course_id: IDS.course, teacher_id: IDS.user, subject_id: IDS.subject, subjects: { id: IDS.subject, name: 'Matemáticas' } }],
    quarters: [{ id: 'quarter-fixture', name: 'Primer trimestre', is_active: true, is_locked: false }],
    teacher_reports: [], student_alerts: [],
    grade_definitions: [], grades: [], project_settings: [],
    project_subject_grades: [], supplementary_exams: [],
  }

  await page.context().route('**/*', async route => {
    const request = route.request()
    const url = new URL(request.url())
    const method = request.method()
    // Permit only the local application and its static assets.
    if (['localhost', '127.0.0.1'].includes(url.hostname) && method === 'GET' && !url.pathname.startsWith('/api/')) return route.continue()
    if (['fonts.googleapis.com', 'fonts.gstatic.com'].includes(url.hostname)) return route.fulfill({ status: 200, contentType: 'text/css', body: '' })
    const reply = (data, headers = {}) => route.fulfill({ status: 200, contentType: 'application/json', headers, body: method === 'HEAD' ? '' : JSON.stringify(data) })
    requests.push({ method, path: url.pathname, query: url.search })
    if (url.pathname === '/auth/v1/user') return reply(user)
    if (url.pathname === '/rest/v1/rpc/get_my_access_context') return reply({ user_id: IDS.user, default_school_id: IDS.school, memberships: [{ school_id: IDS.school, role, permissions }] })
    if (url.pathname === '/rest/v1/rpc/create_academic_year' && method === 'POST') {
      const payload = request.postDataJSON()
      const created = {
        id: 'year-created-fixture',
        school_id: IDS.school,
        name: payload.p_name,
        start_year: payload.p_start_year,
        end_year: payload.p_end_year,
        is_active: payload.p_make_current,
        is_current: payload.p_make_current,
        is_locked: false,
      }
      writes.push({ rpc: 'create_academic_year', payload })
      tables.academic_years = [created, ...tables.academic_years]
      return reply(created)
    }
    if (url.pathname === '/rest/v1/rpc/save_attendance_batch' && method === 'POST') {
      const payload = request.postDataJSON()
      writes.push({ rpc: 'save_attendance_batch', payload })
      attendance = payload.p_records.map((record, index) => ({ ...record, id: `attendance-${index}`, attendance_date: payload.p_date, course_id: payload.p_course_id, hour_block: payload.p_hour_block, subject_id: payload.p_subject_id }))
      return reply({ success: true, saved_count: attendance.length, date: payload.p_date, course_id: payload.p_course_id })
    }
    if (url.pathname === '/rest/v1/rpc/save_teacher_report' && method === 'POST') {
      const payload = request.postDataJSON()
      writes.push({ rpc: 'save_teacher_report', payload })
      tables.teacher_reports = [{ ...payload.p_report, id: 'report-fixture', students: student, courses: course, created_at: '2026-09-01T04:30:00Z' }]
      return reply('report-fixture')
    }
    const table = url.pathname.replace('/rest/v1/', '')
    if (['GET', 'HEAD'].includes(method) && url.pathname.startsWith('/rest/v1/')) {
      if (table === 'attendance_records') return reply(attendance)
      if (Object.hasOwn(tables, table)) {
        const rows = tables[table]
        return reply(rows, { 'content-range': `0-${Math.max(0, rows.length - 1)}/${Array.isArray(rows) ? rows.length : 1}` })
      }
    }
    unexpected.push(`${method} ${url.origin}${url.pathname}`)
    return route.fulfill({ status: 501, contentType: 'application/json', body: JSON.stringify({ message: 'No synthetic fixture registered for this request' }) })
  })
  return {
    errors, requests, writes, unexpected,
    async assertClean() {
      expect(unexpected, 'All API calls must be explicitly simulated').toEqual([])
      expect(errors, 'No browser console or uncaught application errors').toEqual([])
    },
  }
}

export async function expectNoPageOverflow(page) {
  const dimensions = await page.evaluate(() => {
    const viewport = document.documentElement.clientWidth
    const overflowing = [...document.querySelectorAll('body *')]
      .map(element => {
        const rect = element.getBoundingClientRect()
        return {
          tag: element.tagName.toLowerCase(),
          className: typeof element.className === 'string' ? element.className : '',
          text: element.textContent?.trim().replace(/\s+/g, ' ').slice(0, 80) || '',
          left: Math.round(rect.left),
          right: Math.round(rect.right),
          width: Math.round(rect.width),
        }
      })
      .filter(element => element.right > viewport + 1 || element.left < -1)
      .slice(0, 8)

    return { scroll: document.documentElement.scrollWidth, viewport, overflowing }
  })
  expect(
    dimensions.scroll,
    `Elementos fuera del viewport: ${JSON.stringify(dimensions.overflowing)}`,
  ).toBeLessThanOrEqual(dimensions.viewport)
}
