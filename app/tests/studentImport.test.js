import { describe, it, expect } from 'vitest'
import { parseStudentCsvText, sanitizeDate, normalizeHeader } from '../src/lib/studentUtils'
import { downloadStudentsTemplate } from '../src/lib/exportUtils'

describe('Student CSV Import Parser', () => {
    it('normalizes headers correctly', () => {
        expect(normalizeHeader('  Nombres y Apellidos (Obligatorio) ')).toBe('NOMBRES Y APELLIDOS (OBLIGATORIO)')
        expect(normalizeHeader('CÉDULA ESTUDIANTE')).toBe('CEDULA ESTUDIANTE')
        expect(normalizeHeader('FECHA DE NACIMIENTO')).toBe('FECHA DE NACIMIENTO')
    })

    it('sanitizes date formats safely', () => {
        expect(sanitizeDate('2009-04-15')).toBe('2009-04-15')
        expect(sanitizeDate('15/04/2009')).toBe('2009-04-15')
        expect(sanitizeDate('15-04-2009')).toBe('2009-04-15')
        expect(sanitizeDate('')).toBeNull()
        expect(sanitizeDate(null)).toBeNull()
        expect(sanitizeDate('invalid-date')).toBeNull()
    })

    it('correctly parses the official exported template CSV without column overlap', () => {
        const officialCsv = `\uFEFF"No.","NOMBRES Y APELLIDOS (OBLIGATORIO)","CÉDULA ESTUDIANTE (OPCIONAL)","FECHA NACIMIENTO [AAAA-MM-DD] (OPCIONAL)","TELÉFONO ESTUDIANTE (OPCIONAL)","DIRECCIÓN DOMICILIARIA (OPCIONAL)","NOMBRE REPRESENTANTE (OPCIONAL)","CÉDULA REPRESENTANTE (OPCIONAL)","TELÉFONO REPRESENTANTE (OPCIONAL)","TELÉFONO ALTERNATIVO REPRESENTANTE (OPCIONAL)"
"1","ACOSTA CANTOS IXIN RUBEN","0958024747","2009-04-15","0981234567","Mz. 12 Sl. 4 Los Esteros","Ruben Acosta Solís","0912345678","0997654321","042123456"
"2","ALAVA CARRANZA ALEX EDUARDO","0957686561","2009-07-22","0987654321","Cdla. Las Acacias Mz. B V. 10","Eduardo Alava Mendoza","0923456789","0991122334","042987654"
"3","ALCIVAR NUÑEZ CRISTOPHER ALEXANDER","0950299792","2009-11-05","0995544332","Barrio Centenario Calle 5ta","Martha Nuñez López","0934567890","0988776655",""`

        const { entries, errors } = parseStudentCsvText(officialCsv)
        expect(errors).toHaveLength(0)
        expect(entries).toHaveLength(3)

        expect(entries[0].full_name).toBe('ACOSTA CANTOS IXIN RUBEN')
        expect(entries[0].student_cedula).toBe('0958024747')
        expect(entries[0].student_birthdate).toBe('2009-04-15')
        expect(entries[0].student_phone).toBe('0981234567')
        expect(entries[0].student_address).toBe('Mz. 12 Sl. 4 Los Esteros')
        expect(entries[0].representative_name).toBe('Ruben Acosta Solís')
        expect(entries[0].representative_cedula).toBe('0912345678')
        expect(entries[0].representative_phone).toBe('0997654321')
        expect(entries[0].representative_alt_phone).toBe('042123456')

        expect(entries[1].full_name).toBe('ALAVA CARRANZA ALEX EDUARDO')
        expect(entries[1].student_cedula).toBe('0957686561')

        expect(entries[2].full_name).toBe('ALCIVAR NUÑEZ CRISTOPHER ALEXANDER')
    })

    it('handles semicolon delimiter and minimal columns', () => {
        const semicolonCsv = `Nombre;Cedula;Telefono
Carlos Zambrano;0912345678;0987654321
Maria Belen Loor;0923456789;0991122334`

        const { entries, errors } = parseStudentCsvText(semicolonCsv)
        expect(errors).toHaveLength(0)
        expect(entries).toHaveLength(2)
        expect(entries[0].full_name).toBe('Carlos Zambrano')
        expect(entries[0].student_cedula).toBe('0912345678')
        expect(entries[1].full_name).toBe('Maria Belen Loor')
    })
})
