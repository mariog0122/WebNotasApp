import { describe, it, expect } from 'vitest'
import { 
    isValidEcuadorCedula, 
    isDigits, 
    validateStudentForm,
    isStudentComplete,
    getFileExt,
    createPhotoPreview
} from '../src/lib/studentUtils'

describe('studentUtils.js', () => {
    describe('isValidEcuadorCedula', () => {
        it('debería validar cédulas ecuatorianas válidas', () => {
            expect(isValidEcuadorCedula('1725054066')).toBe(true) // Cédula con dígito verificador válido
        })

        it('debería rechazar cédulas con longitud incorrecta', () => {
            expect(isValidEcuadorCedula('12345')).toBe(false)
            expect(isValidEcuadorCedula('12345678901')).toBe(false)
        })

        it('debería rechazar cédulas con caracteres no numéricos', () => {
            expect(isValidEcuadorCedula('171234567a')).toBe(false)
        })

        it('debería rechazar provincias inválidas', () => {
            expect(isValidEcuadorCedula('3012345676')).toBe(false) // Provincia 30 no existe
        })

        it('debería retornar false para cédula vacía o null', () => {
            expect(isValidEcuadorCedula('')).toBe(false)
            expect(isValidEcuadorCedula(null)).toBe(false)
            expect(isValidEcuadorCedula(undefined)).toBe(false)
        })
    })

    describe('isDigits', () => {
        it('debería retornar true para strings solo con dígitos', () => {
            expect(isDigits('1234567890')).toBe(true)
        })

        it('debería retornar false para strings con no dígitos', () => {
            expect(isDigits('12345a')).toBe(false)
            expect(isDigits('')).toBe(false)
        })
    })

    describe('validateStudentForm', () => {
        it('debería retornar errores para formulario vacío', () => {
            const form = {
                full_name: '',
                course_id: null,
                student_cedula: '',
                student_phone: '',
                representative_phone: '',
                representative_alt_phone: '',
                student_birthdate: ''
            }
            
            const errors = validateStudentForm(form)
            
            expect(errors.length).toBeGreaterThan(0)
            expect(errors.some(e => e.includes('nombre completo'))).toBe(true)
            expect(errors.some(e => e.includes('curso'))).toBe(true)
        })

        it('debería retornar error para teléfono con longitud inválida', () => {
            const form = {
                full_name: 'Juan Pérez',
                course_id: '123',
                student_phone: '123', // Muy corto
                representative_phone: '',
                representative_alt_phone: '',
                student_birthdate: ''
            }
            
            const errors = validateStudentForm(form)
            
            expect(errors.some(e => e.includes('telefono'))).toBe(true)
        })

        it('debería retornar error para fecha de nacimiento futura', () => {
            const futureDate = new Date()
            futureDate.setDate(futureDate.getDate() + 1)
            
            const form = {
                full_name: 'Juan Pérez',
                course_id: '123',
                student_phone: '0999999999',
                representative_phone: '',
                representative_alt_phone: '',
                student_birthdate: futureDate.toISOString().split('T')[0]
            }
            
            const errors = validateStudentForm(form)
            
            expect(errors.some(e => e.includes('fecha de nacimiento'))).toBe(true)
        })

        it('debería retornar array vacío para formulario válido', () => {
            const form = {
                full_name: 'Juan Pérez',
                course_id: '123',
                student_phone: '0999999999',
                representative_phone: '0988888888',
                representative_alt_phone: '',
                student_birthdate: '2000-01-01'
            }
            
            const errors = validateStudentForm(form)
            
            expect(errors).toEqual([])
        })
    })

    describe('isStudentComplete', () => {
        it('debería retornar true si todos los campos están completos', () => {
            const student = {
                full_name: 'Juan Pérez',
                course_id: '123',
                student_cedula: '1712345676',
                student_birthdate: '2000-01-01',
                student_phone: '0999999999',
                student_address: 'Calle Principal',
                representative_name: 'María Pérez',
                representative_cedula: '1712345677',
                representative_phone: '0988888888',
                student_photo_url: 'https://example.com/photo.jpg',
                representative_photo_url: 'https://example.com/photo2.jpg'
            }
            
            expect(isStudentComplete(student)).toBe(true)
        })

        it('debería retornar false si falta algún campo', () => {
            const student = {
                full_name: 'Juan Pérez',
                course_id: null, // Falta curso
                student_cedula: '1712345676'
            }
            
            expect(isStudentComplete(student)).toBe(false)
        })
    })

    describe('getFileExt', () => {
        it('debería retornar la extensión en minúsculas', () => {
            const file = { name: 'photo.JPG' }
            expect(getFileExt(file)).toBe('jpg')
        })

        it('debería retornar "jpg" si no hay extensión', () => {
            const file = { name: 'photo' }
            expect(getFileExt(file)).toBe('jpg')
        })
    })

    describe('createPhotoPreview', () => {
        it('debería retornar fallbackUrl si file es null', () => {
            const result = createPhotoPreview(null, 'https://example.com/fallback.jpg')
            expect(result).toBe('https://example.com/fallback.jpg')
        })

        it('debería retornar string vacío si no hay file ni fallback', () => {
            const result = createPhotoPreview(null)
            expect(result).toBe('')
        })
    })
})
