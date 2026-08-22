import { uploadPrivateImage } from './storageUtils'

/**
 * Utilidades compartidos para gestión de estudiantes
 * Funciones reutilizables para validación y subida de fotos
 */

/**
 * Valida que una cédula ecuatoriana sea válida
 * @param {string} cedula - Número de cédula a validar
 * @returns {boolean} - True si es válida
 */
export const isValidEcuadorCedula = (cedula) => {
    if (!cedula || cedula.length !== 10 || !isDigits(cedula)) return false
    const province = parseInt(cedula.slice(0, 2), 10)
    if (province < 1 || province > 24) return false
    const third = parseInt(cedula[2], 10)
    if (third > 5) return false
    const digits = cedula.split('').map(Number)
    const coeffs = [2, 1, 2, 1, 2, 1, 2, 1, 2]
    let sum = 0
    for (let i = 0; i < 9; i++) {
        let val = digits[i] * coeffs[i]
        if (val > 9) val -= 9
        sum += val
    }
    const check = (10 - (sum % 10)) % 10
    return check === digits[9]
}

/**
 * Valida que un string contenga solo dígitos
 * @param {string} value - Valor a validar
 * @returns {boolean}
 */
export const isDigits = (value) => /^[0-9]+$/.test(value)

/**
 * Valida un formulario de estudiante completo
 * @param {Object} form - Objeto con los campos del formulario
 * @returns {string[]} - Array de mensajes de error (vacío si es válido)
 */
export const validateStudentForm = (form) => {
    const errors = []
    if (!form.full_name?.trim()) errors.push('El nombre completo es obligatorio.')
    if (!form.course_id) errors.push('Debe seleccionar un curso.')

    if (form.student_cedula && !isValidEcuadorCedula(form.student_cedula)) {
        errors.push('La cedula del estudiante no es valida en Ecuador.')
    }
    if (form.representative_cedula && !isValidEcuadorCedula(form.representative_cedula)) {
        errors.push('La cedula del representante no es valida en Ecuador.')
    }

    if (form.student_phone && (!isDigits(form.student_phone) || form.student_phone.length < 7 || form.student_phone.length > 15)) {
        errors.push('El telefono del estudiante debe tener entre 7 y 15 digitos.')
    }
    if (form.representative_phone && (!isDigits(form.representative_phone) || form.representative_phone.length < 7 || form.representative_phone.length > 15)) {
        errors.push('El telefono principal del representante debe tener entre 7 y 15 digitos.')
    }
    if (form.representative_alt_phone && (!isDigits(form.representative_alt_phone) || form.representative_alt_phone.length < 7 || form.representative_alt_phone.length > 15)) {
        errors.push('El telefono alterno del representante debe tener entre 7 y 15 digitos.')
    }

    if (form.student_birthdate) {
        const birth = new Date(form.student_birthdate)
        const today = new Date()
        if (birth >= today) errors.push('La fecha de nacimiento debe ser anterior a hoy.')
    }

    return errors
}

/**
 * Verifica si un estudiante tiene todos los campos completos
 * @param {Object} student - Objeto estudiante
 * @returns {boolean}
 */
export const isStudentComplete = (student) => {
    return Boolean(
        student.full_name &&
        student.course_id &&
        student.student_cedula &&
        student.student_birthdate &&
        student.student_phone &&
        student.student_address &&
        student.representative_name &&
        student.representative_cedula &&
        student.representative_phone &&
        student.student_photo_url &&
        student.representative_photo_url
    )
}

/**
 * Obtiene la extensión de un archivo
 * @param {File} file - Objeto File
 * @returns {string} - Extensión en minúsculas
 */
export const getFileExt = (file) => {
    const parts = file.name.split('.')
    return parts.length > 1 ? parts.pop().toLowerCase() : 'jpg'
}

/**
 * Sube una foto al bucket student-photos (InsForge Storage; API compatible en lib/supabase.js).
 * @param {Object} supabase - Cliente (capa de compatibilidad)
 * @param {File} file - Archivo a subir
 * @param {string} path - Ruta destino en el bucket
 * @returns {Promise<string>} - Ruta persistente del objeto privado
 */
export const uploadPhoto = async (supabase, file, path) => {
    return uploadPrivateImage(supabase, 'student-photos', file, path)
}

/**
 * Crea un preview URL para un archivo local
 * @param {File|null} file - Archivo seleccionado
 * @param {string} fallbackUrl - URL fallback si no hay archivo
 * @returns {string} - URL del preview
 */
export const createPhotoPreview = (file, fallbackUrl = '') => {
    if (file) {
        return URL.createObjectURL(file)
    }
    return fallbackUrl || ''
}

export const normalizeHeader = (value) => {
    return String(value || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/\s+/g, ' ')
        .toUpperCase()
        .trim()
}

export const sanitizeDate = (val) => {
    if (!val) return null
    if (val instanceof Date && !isNaN(val)) {
        return val.toISOString().split('T')[0]
    }
    const str = String(val).trim()
    if (!str) return null
    if (/^\d{4}-\d{2}-\d{2}$/.test(str)) return str
    const parts = str.split(/[/.-]/)
    if (parts.length === 3) {
        if (parts[0].length === 4) {
            return `${parts[0]}-${parts[1].padStart(2, '0')}-${parts[2].padStart(2, '0')}`
        } else if (parts[2].length === 4) {
            return `${parts[2]}-${parts[1].padStart(2, '0')}-${parts[0].padStart(2, '0')}`
        }
    }
    return null
}

/**
 * Parsea el contenido en texto de un archivo CSV para extraer estudiantes.
 * @param {string} text - Contenido crudo del archivo CSV
 * @returns {{ entries: Array, errors: Array }}
 */
export const parseStudentCsvText = (text) => {
    if (!text || !text.trim()) {
        return { entries: [], errors: ['El contenido está vacío.'] }
    }
    const cleanText = text.replace(/^\uFEFF/, '')
    const lines = cleanText.split(/\r\n|\n|\r/).filter(l => l.trim().length > 0)
    if (lines.length === 0) {
        return { entries: [], errors: ['No hay líneas de texto.'] }
    }

    const sample = lines.slice(0, Math.min(5, lines.length)).join('\n')
    let delimiter = ','
    const commaCount = (sample.match(/,/g) || []).length
    const semiCount = (sample.match(/;/g) || []).length
    const tabCount = (sample.match(/\t/g) || []).length
    const pipeCount = (sample.match(/\|/g) || []).length
    if (semiCount > commaCount && semiCount > tabCount) delimiter = ';'
    else if (tabCount > commaCount && tabCount > semiCount) delimiter = '\t'
    else if (pipeCount > commaCount) delimiter = '|'

    const rawRows = lines.map(line => {
        const row = []
        let current = ''
        let inQuotes = false
        for (let i = 0; i < line.length; i++) {
            const char = line[i]
            if (char === '"') {
                if (inQuotes && line[i + 1] === '"') {
                    current += '"'
                    i++
                } else {
                    inQuotes = !inQuotes
                }
            } else if (char === delimiter && !inQuotes) {
                row.push(current.trim().replace(/^["']|["']$/g, ''))
                current = ''
            } else {
                current += char
            }
        }
        row.push(current.trim().replace(/^["']|["']$/g, ''))
        return row
    })

    let headerIdx = -1
    let colName = -1, colCedula = -1, colBirth = -1, colPhone = -1, colAddress = -1
    let colRepName = -1, colRepCedula = -1, colRepPhone = -1, colRepAltPhone = -1

    for (let r = 0; r < Math.min(rawRows.length, 10); r++) {
        const row = rawRows[r]
        if (!Array.isArray(row)) continue
        let foundNameCol = false
        row.forEach((cell, cIdx) => {
            const h = normalizeHeader(cell)
            if (!h) return

            if (h.includes('REPRESENTANTE') || h.includes('APODERADO') || h.includes('TUTOR') || h.includes('PADRE') || h.includes('MADRE')) {
                if (h.includes('CEDULA') || h.includes('DNI') || h.includes('IDENTIFICACION') || h.includes('DOC')) {
                    colRepCedula = cIdx
                } else if (h.includes('ALT') || h.includes('OTRO') || h.includes('FIJO') || h.includes('CONVENCIONAL')) {
                    colRepAltPhone = cIdx
                } else if (h.includes('TEL') || h.includes('CEL') || h.includes('MOVIL') || h.includes('WHATSAPP')) {
                    colRepPhone = cIdx
                } else if (h.includes('NOMBRE') || h.includes('APELLIDO') || h.includes('COMPLETO')) {
                    colRepName = cIdx
                }
            } else {
                if (h.includes('CEDULA') || h.includes('DNI') || h.includes('IDENTIFICACION') || h.includes('DOC')) {
                    colCedula = cIdx
                } else if (h.includes('NACIMIENTO') || h.includes('FECHA') || h.includes('CUMPLE')) {
                    colBirth = cIdx
                } else if (h.includes('TELEFONO') || h.includes('CELULAR') || h.includes('MOVIL') || h.includes('WHATSAPP') || h.includes('TEL')) {
                    colPhone = cIdx
                } else if (h.includes('DIRECCION') || h.includes('DOMICILIO') || h.includes('RESIDENCIA') || h.includes('UBICACION')) {
                    colAddress = cIdx
                } else if (h.includes('NOMBRE') || h.includes('APELLIDO') || h.includes('ESTUDIANTE') || h.includes('ALUMNO')) {
                    colName = cIdx
                    foundNameCol = true
                }
            }
        })

        if (foundNameCol || colName !== -1) {
            headerIdx = r
            break
        }
    }

    if (colName === -1) {
        for (let r = 0; r < rawRows.length; r++) {
            const row = rawRows[r]
            if (!Array.isArray(row)) continue
            for (let c = 0; c < row.length; c++) {
                const val = String(row[c] || '').trim()
                if (val && isNaN(Number(val)) && val.length > 5 && val.includes(' ')) {
                    colName = c
                    headerIdx = r > 0 ? r - 1 : 0
                    break
                }
            }
            if (colName !== -1) break
        }
    }

    if (colName === -1) {
        return { entries: [], errors: ['No se encontró columna de NOMBRES COMPLETOS de estudiantes en el archivo.'] }
    }

    const entries = []
    const errors = []
    const startRow = headerIdx !== -1 ? headerIdx + 1 : 0

    for (let i = startRow; i < rawRows.length; i++) {
        const row = rawRows[i]
        if (!Array.isArray(row)) continue

        const name = colName !== -1 && row[colName] != null ? String(row[colName]).trim() : ''
        const cedula = colCedula !== -1 && row[colCedula] != null ? String(row[colCedula]).trim() : ''
        const birth = colBirth !== -1 && row[colBirth] != null ? sanitizeDate(row[colBirth]) : null
        const phone = colPhone !== -1 && row[colPhone] != null ? String(row[colPhone]).trim() : ''
        const address = colAddress !== -1 && row[colAddress] != null ? String(row[colAddress]).trim() : ''
        const repName = colRepName !== -1 && row[colRepName] != null ? String(row[colRepName]).trim() : ''
        const repCedula = colRepCedula !== -1 && row[colRepCedula] != null ? String(row[colRepCedula]).trim() : ''
        const repPhone = colRepPhone !== -1 && row[colRepPhone] != null ? String(row[colRepPhone]).trim() : ''
        const repAltPhone = colRepAltPhone !== -1 && row[colRepAltPhone] != null ? String(row[colRepAltPhone]).trim() : ''

        if (!name || name.length < 2) continue
        if (!isNaN(Number(name)) && !name.includes(' ')) continue

        const upper = normalizeHeader(name)
        if (['NOMBRES', 'APELLIDOS', 'NOMBRES COMPLETOS', 'NOMBRES Y APELLIDOS', 'NO.', 'N°', 'NOMBRE', 'ESTUDIANTE'].includes(upper)) continue

        entries.push({
            full_name: name,
            student_cedula: cedula || null,
            student_birthdate: birth || null,
            student_phone: phone || '',
            student_address: address || '',
            representative_name: repName || '',
            representative_cedula: repCedula || '',
            representative_phone: repPhone || '',
            representative_alt_phone: repAltPhone || ''
        })
    }

    if (entries.length === 0) {
        return { entries: [], errors: ['No se detectaron filas de estudiantes válidas en el archivo.'] }
    }

    return { entries, errors }
}
