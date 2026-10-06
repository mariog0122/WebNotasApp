import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { downloadTeachersTemplate, exportTeachersToExcel } from '../src/lib/exportUtils'

describe('Teachers Excel Template and Bulk Import', () => {
  it('exports downloadTeachersTemplate and exportTeachersToExcel functions', () => {
    expect(typeof downloadTeachersTemplate).toBe('function')
    expect(typeof exportTeachersToExcel).toBe('function')
  })

  it('contains downloadTeachersTemplate and proper CSV (.csv) filename in exportUtils.js', () => {
    const source = readFileSync(
      new URL('../src/lib/exportUtils.js', import.meta.url),
      'utf8'
    )

    expect(source).toContain('downloadTeachersTemplate')
    expect(source).toContain('Plantilla_Docentes_LOGREVA.csv')
    expect(source).toContain('NOMBRES (OBLIGATORIO)')
    expect(source).toContain('APELLIDOS (OBLIGATORIO)')
    expect(source).toContain('CORREO ELECTRÓNICO (OBLIGATORIO)')
  })

  it('integrates template download in Dashboard.vue toolbar and bulk modal', () => {
    const dashboardSource = readFileSync(
      new URL('../src/views/Dashboard.vue', import.meta.url),
      'utf8'
    )

    expect(dashboardSource).toContain("import { downloadTeachersTemplate } from '../lib/exportUtils'")
    expect(dashboardSource).toContain('@click="downloadTeachersTemplate"')
    expect(dashboardSource).toContain('Descargar Plantilla CSV')
    expect(dashboardSource).toContain('Plantilla CSV')
  })

  it('contains downloadSubjectsTemplate in CSV format in exportUtils.js and Subjects.vue', () => {
    const exportSource = readFileSync(
      new URL('../src/lib/exportUtils.js', import.meta.url),
      'utf8'
    )
    const subjectsSource = readFileSync(
      new URL('../src/views/Subjects.vue', import.meta.url),
      'utf8'
    )

    expect(exportSource).toContain('downloadSubjectsTemplate')
    expect(exportSource).toContain('Plantilla_Asignaturas_LOGREVA.csv')
    expect(subjectsSource).toContain('downloadSubjectsTemplate')
    expect(subjectsSource).toContain('Descargar Plantilla CSV')
  })

  it('supports custom passwords in teacher CSV and dispatches credentials to .site mailer with Hostinger login URL', () => {
    const exportSource = readFileSync(new URL('../src/lib/exportUtils.js', import.meta.url), 'utf8')
    const dashboardSource = readFileSync(new URL('../src/views/Dashboard.vue', import.meta.url), 'utf8')
    const functionSource = readFileSync(new URL('../../supabase/functions/manage-tenant-user/index.ts', import.meta.url), 'utf8')
    const mailerSource = readFileSync(new URL('../public/api/send-email.php', import.meta.url), 'utf8')

    expect(exportSource).toContain('CONTRASEÑA (OPCIONAL)')
    expect(dashboardSource).toContain("val.includes('CONTRASE')")
    expect(dashboardSource).toContain('https://sandybrown-alpaca-347737.hostingersite.com/login?reason=access')
    expect(functionSource).toContain('https://sandybrown-alpaca-347737.hostingersite.com/login?reason=access')
    expect(functionSource).toContain('adminClient.auth.admin.createUser')
    expect(functionSource).toContain('send-email.php')
    expect(mailerSource).toContain('adyronweb.site')
    expect(mailerSource).toContain('notificaciones@')
  })
})

