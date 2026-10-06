import { describe, expect, it } from 'vitest'
import { EMAIL_ALREADY_REGISTERED_MESSAGE, normalizeUserEmailConflict } from '../src/lib/errorDictionary'

describe('normalizeUserEmailConflict', () => {
  it.each([
    'El correo electrónico ya pertenece a un usuario registrado.',
    'Este correo electrónico ya se encuentra registrado en el sistema.',
    'El correo ya pertenece a otro usuario o institución.',
    'A user with this email address has already been registered',
  ])('asks for another email when: %s', (message) => {
    expect(normalizeUserEmailConflict(message)).toBe(EMAIL_ALREADY_REGISTERED_MESSAGE)
    expect(EMAIL_ALREADY_REGISTERED_MESSAGE).toMatch(/otra institución.*correo.*diferente/i)
  })

  it('leaves unrelated messages untouched', () => {
    expect(normalizeUserEmailConflict('El teléfono ya está registrado.')).toBe('El teléfono ya está registrado.')
    expect(normalizeUserEmailConflict('')).toBe('')
  })
})
