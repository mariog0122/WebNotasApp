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
 * @returns {Promise<string>} - URL pública de la foto
 */
export const uploadPhoto = async (supabase, file, path) => {
    const { error } = await supabase.storage.from('student-photos').upload(path, file, { upsert: true })
    if (error) throw error
    const { data } = supabase.storage.from('student-photos').getPublicUrl(path)
    return data.publicUrl
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
