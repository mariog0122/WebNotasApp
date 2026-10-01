import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { maskIdentifier, normalizeWhatsAppPhone } from '../src/lib/familyDirectory'

const source = readFileSync(resolve(__dirname, '../src/views/Families.vue'), 'utf8')

describe('directorio de familias', () => {
  it('minimiza los datos personales visibles', () => {
    expect(maskIdentifier('0912345678')).toBe('09******78')
    expect(maskIdentifier('1234')).toBe('****')
    expect(maskIdentifier('')).toBe('No registrada')
    expect(source).toContain('maskIdentifier(family.representative_cedula)')
    expect(source).not.toContain('student_address')
  })

  it('normaliza teléfonos ecuatorianos sin alterar números internacionales', () => {
    expect(normalizeWhatsAppPhone('099 123 4567')).toBe('593991234567')
    expect(normalizeWhatsAppPhone('+57 310 123 4567')).toBe('573101234567')
    expect(normalizeWhatsAppPhone('123')).toBe('')
  })

  it('cierra errores, limita resultados académicos por permiso y descarta respuestas obsoletas', () => {
    expect(source).toContain("hasAccessPermission(authStore.accessContext, 'grades.read')")
    expect(source).toContain("hasAccessPermission(authStore.accessContext, 'reports.read')")
    expect(source).toContain('const requestId = ++fetchSequence')
    expect(source).toContain('if (requestId !== fetchSequence) return')
    expect(source).toContain(".eq('school_id', schoolId)")
    expect(source).not.toContain('school_id.is.null')
    expect(source).toContain('clearCourseData()')
    expect(source).toContain('toast.error')
  })
})
