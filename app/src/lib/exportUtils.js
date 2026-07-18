/**
 * Utilidades para exportación de datos a CSV/Excel
 * Permite backup de información del sistema
 */

import * as XLSX from 'xlsx'

/**
 * Convierte array de objetos a CSV
 * @param {Array} data - Array de objetos
 * @param {string[]} headers - Headers opcionales
 * @returns {string} - CSV string
 */
export const arrayToCSV = (data, headers = null) => {
    if (!data || data.length === 0) return ''
    
    const keys = headers || Object.keys(data[0])
    const csvRows = []
    
    // Agregar headers
    csvRows.push(keys.join(','))
    
    // Agregar filas
    for (const row of data) {
        const values = keys.map(key => {
            const val = row[key]
            const escaped = String(val === null || val === undefined ? '' : val).replace(/"/g, '\\"')
            return `"${escaped}"`
        })
        csvRows.push(values.join(','))
    }
    
    return csvRows.join('\n')
}

/**
 * Descarga un archivo CSV
 * @param {string} csv - Contenido CSV
 * @param {string} filename - Nombre del archivo
 */
export const downloadCSV = (csv, filename) => {
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    const url = URL.createObjectURL(blob)
    
    link.setAttribute('href', url)
    link.setAttribute('download', filename)
    link.style.visibility = 'hidden'
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
}

/**
 * Exporta datos a Excel
 * @param {Array} data - Array de objetos
 * @param {string} sheetName - Nombre de la hoja
 * @param {string} filename - Nombre del archivo
 */
export const exportToExcel = (data, sheetName = 'Datos', filename = 'export.xlsx') => {
    const worksheet = XLSX.utils.json_to_sheet(data)
    const workbook = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(workbook, worksheet, sheetName)
    XLSX.writeFile(workbook, filename)
}

/**
 * Exporta estudiantes a Excel
 * @param {Array} students - Datos de estudiantes con cursos
 */
export const exportStudentsToExcel = (students) => {
    const data = students.map(s => ({
        'Nombre Completo': s.full_name,
        'Cédula': s.student_cedula || '',
        'Curso': s.courses?.name || 'Sin asignar',
        'Teléfono': s.student_phone || '',
        'Dirección': s.student_address || '',
        'Fecha Nacimiento': s.student_birthdate || '',
        'Representante': s.representative_name || '',
        'Cédula Representante': s.representative_cedula || '',
        'Teléfono Representante': s.representative_phone || '',
        'Teléfono Alterno': s.representative_alt_phone || ''
    }))
    
    const date = new Date().toISOString().split('T')[0]
    exportToExcel(data, 'Estudiantes', `Estudiantes_${date}.xlsx`)
}

/**
 * Exporta estudiantes a CSV
 * @param {Array} students - Datos de estudiantes
 */
export const exportStudentsToCSV = (students) => {
    const csv = arrayToCSV(students.map(s => ({
        nombre: s.full_name,
        cedula: s.student_cedula || '',
        curso: s.courses?.name || 'Sin asignar',
        telefono: s.student_phone || '',
        representante: s.representative_name || ''
    })))
    
    const date = new Date().toISOString().split('T')[0]
    downloadCSV(csv, `Estudiantes_${date}.csv`)
}

/**
 * Exporta cursos a Excel
 * @param {Array} courses - Datos de cursos
 */
export const exportCoursesToExcel = (courses) => {
    const data = courses.map(c => ({
        'Nombre': c.name,
        'Año Académico': c.academic_year,
        'Nivel': c.level || '',
        'Paralelo': c.track || '',
        'Fecha Creación': new Date(c.created_at).toLocaleDateString('es-EC')
    }))
    
    const date = new Date().toISOString().split('T')[0]
    exportToExcel(data, 'Cursos', `Cursos_${date}.xlsx`)
}

/**
 * Exporta calificaciones a Excel
 * @param {Object} gradeData - Estructura completa de calificaciones
 */
export const exportGradesToExcel = (gradeData) => {
    const workbook = XLSX.utils.book_new()
    
    // Hoja de resumen
    const summaryData = gradeData.students?.map(s => ({
        'Estudiante': s.full_name,
        'Promedio Individual': s.averages?.avgIndividual?.toFixed(2) || 'N/A',
        'Promedio Grupal': s.averages?.avgGroup?.toFixed(2) || 'N/A',
        'Promedio Formative': s.averages?.formative?.toFixed(2) || 'N/A',
        'Promedio Sumativa': s.averages?.avgSum?.toFixed(2) || 'N/A',
        'Total': s.averages?.total?.toFixed(2) || 'N/A'
    })) || []
    
    const summarySheet = XLSX.utils.json_to_sheet(summaryData)
    XLSX.utils.book_append_sheet(workbook, summarySheet, 'Resumen')
    
    // Hoja detallada si existe
    if (gradeData.detailed) {
        const detailSheet = XLSX.utils.json_to_sheet(gradeData.detailed)
        XLSX.utils.book_append_sheet(workbook, detailSheet, 'Detalle')
    }
    
    const date = new Date().toISOString().split('T')[0]
    XLSX.writeFile(workbook, `Calificaciones_${date}.xlsx`)
}
