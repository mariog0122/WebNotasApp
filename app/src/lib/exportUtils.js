/**
 * Utilidades para exportación y generación de archivos nativos Excel (.xlsx) y CSV
 * Compatible con Microsoft Excel, LibreOffice Calc y Google Sheets
 */

/**
 * Convierte array de objetos a CSV con codificación segura
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
            const escaped = String(val === null || val === undefined ? '' : val).replace(/"/g, '""')
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
 * Exporta datos a CSV compatible con Excel
 */
export const exportToExcel = (data, sheetName = 'Datos', filename = 'export.xlsx') => {
    const csvFilename = filename.replace(/\.xlsx$/i, '.csv')
    downloadCSV(`\uFEFF${arrayToCSV(data)}`, csvFilename)
}

/**
 * Genera y descarga un archivo nativo .xlsx en el navegador con estilos profesionales
 */
export const writeNativeXlsx = async (sheetData, columns, filename = 'documento.xlsx') => {
    try {
        const { default: writeExcelFile } = await import('write-excel-file/browser')
        await writeExcelFile(sheetData, { columns }).toFile(filename)
    } catch (err) {
        console.warn('writeExcelFile no disponible, usando fallback CSV:', err)
        if (sheetData && sheetData.length > 1) {
            const headers = sheetData[0].map(h => typeof h === 'object' ? h.value : h)
            const rows = sheetData.slice(1).map(row => {
                const obj = {}
                headers.forEach((h, idx) => {
                    const cell = row[idx]
                    obj[h] = typeof cell === 'object' ? cell?.value : (cell ?? '')
                })
                return obj
            })
            exportToExcel(rows, 'Datos', filename)
        }
    }
}

/**
 * Descarga plantilla oficial en formato CSV (.csv) para importación de personal docente
 */
export const downloadTeachersTemplate = () => {
    const teachersList = [
        {
            'No.': 1,
            'NOMBRES (OBLIGATORIO)': 'Carlos Alberto',
            'APELLIDOS (OBLIGATORIO)': 'Mendoza Ramos',
            'CORREO ELECTRÓNICO (OBLIGATORIO)': 'carlos.mendoza@colegio.edu.ec',
            'USUARIO (OPCIONAL)': 'cmendoza',
            'CONTRASEÑA (OPCIONAL)': 'Docente2026*',
            'ÁREA O ESPECIALIDAD (OPCIONAL)': 'Matemáticas',
            'TELÉFONO MÓVIL (OPCIONAL)': '0991234567'
        },
        {
            'No.': 2,
            'NOMBRES (OBLIGATORIO)': 'María Elena',
            'APELLIDOS (OBLIGATORIO)': 'Paredes Castro',
            'CORREO ELECTRÓNICO (OBLIGATORIO)': 'maria.paredes@colegio.edu.ec',
            'USUARIO (OPCIONAL)': 'mparedes',
            'CONTRASEÑA (OPCIONAL)': 'Docente2026*',
            'ÁREA O ESPECIALIDAD (OPCIONAL)': 'Lengua y Literatura',
            'TELÉFONO MÓVIL (OPCIONAL)': '0987654321'
        },
        {
            'No.': 3,
            'NOMBRES (OBLIGATORIO)': 'Jorge Luis',
            'APELLIDOS (OBLIGATORIO)': 'Zambrano Vera',
            'CORREO ELECTRÓNICO (OBLIGATORIO)': 'jorge.zambrano@colegio.edu.ec',
            'USUARIO (OPCIONAL)': 'jzambrano',
            'CONTRASEÑA (OPCIONAL)': 'Docente2026*',
            'ÁREA O ESPECIALIDAD (OPCIONAL)': 'Ciencias Naturales',
            'TELÉFONO MÓVIL (OPCIONAL)': '0998877665'
        },
        {
            'No.': 4,
            'NOMBRES (OBLIGATORIO)': 'Ana Lucía',
            'APELLIDOS (OBLIGATORIO)': 'Torres Morales',
            'CORREO ELECTRÓNICO (OBLIGATORIO)': 'ana.torres@colegio.edu.ec',
            'USUARIO (OPCIONAL)': 'atorres',
            'CONTRASEÑA (OPCIONAL)': 'Docente2026*',
            'ÁREA O ESPECIALIDAD (OPCIONAL)': 'Inglés',
            'TELÉFONO MÓVIL (OPCIONAL)': '0994433221'
        },
        {
            'No.': 5,
            'NOMBRES (OBLIGATORIO)': 'Roberto Carlos',
            'APELLIDOS (OBLIGATORIO)': 'Guerrero Ortiz',
            'CORREO ELECTRÓNICO (OBLIGATORIO)': 'roberto.guerrero@colegio.edu.ec',
            'USUARIO (OPCIONAL)': 'rguerrero',
            'CONTRASEÑA (OPCIONAL)': 'Docente2026*',
            'ÁREA O ESPECIALIDAD (OPCIONAL)': 'Educación Física',
            'TELÉFONO MÓVIL (OPCIONAL)': '0981122334'
        },
        {
            'No.': 6,
            'NOMBRES (OBLIGATORIO)': 'Diana Patricia',
            'APELLIDOS (OBLIGATORIO)': 'Salazar Gómez',
            'CORREO ELECTRÓNICO (OBLIGATORIO)': 'diana.salazar@colegio.edu.ec',
            'USUARIO (OPCIONAL)': 'dsalazar',
            'CONTRASEÑA (OPCIONAL)': 'Docente2026*',
            'ÁREA O ESPECIALIDAD (OPCIONAL)': 'Informática y Tecnología',
            'TELÉFONO MÓVIL (OPCIONAL)': '0983344556'
        }
    ]

    const csvContent = arrayToCSV(teachersList)
    downloadCSV(`\uFEFF${csvContent}`, 'Plantilla_Docentes_LOGREVA.csv')
}

/**
 * Descarga plantilla oficial en formato CSV (.csv) para importación de Instituciones
 */
export const downloadInstitutionsTemplate = () => {
    const institutionsList = [
        {
            'No.': 1,
            'NOMBRE DE LA INSTITUCIÓN (OBLIGATORIO)': 'Unidad Educativa Fiscal Guayaquil',
            'RUC / CÓDIGO AMIE (OPCIONAL)': '09H00123',
            'DIRECCIÓN (OPCIONAL)': 'Av. 9 de Octubre y Boyacá',
            'TELÉFONO (OPCIONAL)': '042123456',
            'EMAIL CONTACTO (OPCIONAL)': 'contacto@ueguayaquil.edu.ec',
            'NOMBRE RECTOR/ADMIN (OBLIGATORIO)': 'Msc. Gonzalo Andrade',
            'EMAIL RECTOR/ADMIN (OBLIGATORIO)': 'rector@ueguayaquil.edu.ec',
            'CONTRASEÑA INICIAL (OPCIONAL)': 'Admin2026*'
        },
        {
            'No.': 2,
            'NOMBRE DE LA INSTITUCIÓN (OBLIGATORIO)': 'Colegio Experimental 24 de Mayo',
            'RUC / CÓDIGO AMIE (OPCIONAL)': '17H00456',
            'DIRECCIÓN (OPCIONAL)': 'Av. 6 de Diciembre y Orellana',
            'TELÉFONO (OPCIONAL)': '022987654',
            'EMAIL CONTACTO (OPCIONAL)': 'contacto@24demayo.edu.ec',
            'NOMBRE RECTOR/ADMIN (OBLIGATORIO)': 'Dra. Carmen Villacís',
            'EMAIL RECTOR/ADMIN (OBLIGATORIO)': 'rectorado@24demayo.edu.ec',
            'CONTRASEÑA INICIAL (OPCIONAL)': 'Admin2026*'
        }
    ]

    const csvContent = arrayToCSV(institutionsList)
    downloadCSV(`\uFEFF${csvContent}`, 'Plantilla_Instituciones_LOGREVA.csv')
}

/**
 * Exporta el personal docente a un archivo Excel nativo (.xlsx)
 */
export const exportTeachersToExcel = async (teachers) => {
    const HEADER_STYLE = {
        fontWeight: 'bold',
        backgroundColor: '#0F172A',
        textColor: '#FFFFFF',
        align: 'left',
        height: 24
    }

    const sheetData = [
        [
            { value: 'N°', ...HEADER_STYLE, align: 'center' },
            { value: 'Nombre Completo', ...HEADER_STYLE },
            { value: 'Correo Electrónico', ...HEADER_STYLE },
            { value: 'Rol Asignado', ...HEADER_STYLE }
        ]
    ]

    teachers.forEach((t, idx) => {
        sheetData.push([
            { value: idx + 1, align: 'center' },
            { value: t.full_name || 'Sin nombre', fontWeight: 'bold' },
            { value: t.email || '-' },
            { value: t.role === 'admin' ? 'Rector / Administrador' : (t.role === 'inspector' ? 'Inspector' : (t.role === 'secretary' ? 'Secretaría' : 'Docente')) }
        ])
    })

    const columns = [
        { width: 8 },
        { width: 40 },
        { width: 42 },
        { width: 25 }
    ]

    const date = new Date().toISOString().split('T')[0]
    await writeNativeXlsx(sheetData, columns, `Docentes_LOGREVA_${date}.xlsx`)
}

/**
 * Descarga plantilla oficial en formato CSV (.csv) para importación de asignaturas
 */
export const downloadSubjectsTemplate = () => {
    const subjectsList = [
        { 'No.': 1, 'Nombre de la Asignatura (Obligatorio)': 'Matemáticas', 'Área o Campo Académico (Opcional)': 'Ciencias Exactas', 'Observaciones / Nivel (Opcional)': 'Tronco Común' },
        { 'No.': 2, 'Nombre de la Asignatura (Obligatorio)': 'Lengua y Literatura', 'Área o Campo Académico (Opcional)': 'Comunicación y Lenguaje', 'Observaciones / Nivel (Opcional)': 'Tronco Común' },
        { 'No.': 3, 'Nombre de la Asignatura (Obligatorio)': 'Ciencias Naturales', 'Área o Campo Académico (Opcional)': 'Ciencias Experimentales', 'Observaciones / Nivel (Opcional)': 'Tronco Común' },
        { 'No.': 4, 'Nombre de la Asignatura (Obligatorio)': 'Estudios Sociales', 'Área o Campo Académico (Opcional)': 'Ciencias Sociales', 'Observaciones / Nivel (Opcional)': 'Tronco Común' },
        { 'No.': 5, 'Nombre de la Asignatura (Obligatorio)': 'Inglés', 'Área o Campo Académico (Opcional)': 'Lengua Extranjera', 'Observaciones / Nivel (Opcional)': 'Tronco Común' },
        { 'No.': 6, 'Nombre de la Asignatura (Obligatorio)': 'Educación Física', 'Área o Campo Académico (Opcional)': 'Cultura Física y Deporte', 'Observaciones / Nivel (Opcional)': 'Tronco Común' },
        { 'No.': 7, 'Nombre de la Asignatura (Obligatorio)': 'Educación Cultural y Artística', 'Área o Campo Académico (Opcional)': 'Artes y Creatividad', 'Observaciones / Nivel (Opcional)': 'Tronco Común' },
        { 'No.': 8, 'Nombre de la Asignatura (Obligatorio)': 'Física', 'Área o Campo Académico (Opcional)': 'Ciencias Exactas', 'Observaciones / Nivel (Opcional)': 'Bachillerato' },
        { 'No.': 9, 'Nombre de la Asignatura (Obligatorio)': 'Química', 'Área o Campo Académico (Opcional)': 'Ciencias Experimentales', 'Observaciones / Nivel (Opcional)': 'Bachillerato' },
        { 'No.': 10, 'Nombre de la Asignatura (Obligatorio)': 'Informática Aplicada', 'Área o Campo Académico (Opcional)': 'Tecnología e Innovación', 'Observaciones / Nivel (Opcional)': 'Materia Complementaria' }
    ]

    const csvContent = arrayToCSV(subjectsList)
    downloadCSV(`\uFEFF${csvContent}`, 'Plantilla_Asignaturas_LOGREVA.csv')
}

/**
 * Exporta el catálogo actual de asignaturas a un archivo Excel nativo (.xlsx)
 */
export const exportSubjectsToExcel = async (subjects) => {
    const HEADER_STYLE = {
        fontWeight: 'bold',
        backgroundColor: '#0F172A',
        textColor: '#FFFFFF',
        align: 'left',
        height: 24
    }

    const sheetData = [
        [
            { value: 'N°', ...HEADER_STYLE, align: 'center' },
            { value: 'Nombre de la Asignatura', ...HEADER_STYLE },
            { value: 'Fecha de Registro', ...HEADER_STYLE }
        ]
    ]

    subjects.forEach((s, idx) => {
        sheetData.push([
            { value: idx + 1, align: 'center' },
            { value: s.name, fontWeight: 'bold' },
            { value: s.created_at ? new Date(s.created_at).toLocaleDateString('es-EC') : '-' }
        ])
    })

    const columns = [
        { width: 8 },
        { width: 45 },
        { width: 22 }
    ]

    const date = new Date().toISOString().split('T')[0]
    await writeNativeXlsx(sheetData, columns, `Asignaturas_LOGREVA_${date}.xlsx`)
}

/**
 * Descarga plantilla oficial en formato CSV (.csv) para importación de estudiantes por curso
 * Incluye todos los campos de estudiante y representante requeridos por la institución (sin notas).
 */
export const downloadStudentsTemplate = () => {
    const studentsList = [
        {
            'No.': 1,
            'NOMBRES Y APELLIDOS (OBLIGATORIO)': 'ACOSTA CANTOS IXIN RUBEN',
            'CÉDULA ESTUDIANTE (OPCIONAL)': '0958024747',
            'FECHA NACIMIENTO [AAAA-MM-DD] (OPCIONAL)': '2009-04-15',
            'TELÉFONO ESTUDIANTE (OPCIONAL)': '0981234567',
            'DIRECCIÓN DOMICILIARIA (OPCIONAL)': 'Mz. 12 Sl. 4 Los Esteros',
            'NOMBRE REPRESENTANTE (OPCIONAL)': 'Ruben Acosta Solís',
            'CÉDULA REPRESENTANTE (OPCIONAL)': '0912345678',
            'TELÉFONO REPRESENTANTE (OPCIONAL)': '0997654321',
            'TELÉFONO ALTERNATIVO REPRESENTANTE (OPCIONAL)': '042123456'
        },
        {
            'No.': 2,
            'NOMBRES Y APELLIDOS (OBLIGATORIO)': 'ALAVA CARRANZA ALEX EDUARDO',
            'CÉDULA ESTUDIANTE (OPCIONAL)': '0957686561',
            'FECHA NACIMIENTO [AAAA-MM-DD] (OPCIONAL)': '2009-07-22',
            'TELÉFONO ESTUDIANTE (OPCIONAL)': '0987654321',
            'DIRECCIÓN DOMICILIARIA (OPCIONAL)': 'Cdla. Las Acacias Mz. B V. 10',
            'NOMBRE REPRESENTANTE (OPCIONAL)': 'Eduardo Alava Mendoza',
            'CÉDULA REPRESENTANTE (OPCIONAL)': '0923456789',
            'TELÉFONO REPRESENTANTE (OPCIONAL)': '0991122334',
            'TELÉFONO ALTERNATIVO REPRESENTANTE (OPCIONAL)': '042987654'
        },
        {
            'No.': 3,
            'NOMBRES Y APELLIDOS (OBLIGATORIO)': 'ALCIVAR NUÑEZ CRISTOPHER ALEXANDER',
            'CÉDULA ESTUDIANTE (OPCIONAL)': '0950299792',
            'FECHA NACIMIENTO [AAAA-MM-DD] (OPCIONAL)': '2009-11-05',
            'TELÉFONO ESTUDIANTE (OPCIONAL)': '0995544332',
            'DIRECCIÓN DOMICILIARIA (OPCIONAL)': 'Barrio Centenario Calle 5ta',
            'NOMBRE REPRESENTANTE (OPCIONAL)': 'Martha Nuñez López',
            'CÉDULA REPRESENTANTE (OPCIONAL)': '0934567890',
            'TELÉFONO REPRESENTANTE (OPCIONAL)': '0988776655',
            'TELÉFONO ALTERNATIVO REPRESENTANTE (OPCIONAL)': ''
        },
        {
            'No.': 4,
            'NOMBRES Y APELLIDOS (OBLIGATORIO)': 'ANTEPARA MEZA DANILO ALEJANDRO',
            'CÉDULA ESTUDIANTE (OPCIONAL)': '0953376753',
            'FECHA NACIMIENTO [AAAA-MM-DD] (OPCIONAL)': '2009-02-18',
            'TELÉFONO ESTUDIANTE (OPCIONAL)': '0984433221',
            'DIRECCIÓN DOMICILIARIA (OPCIONAL)': 'Guasmo Central Av. Principal',
            'NOMBRE REPRESENTANTE (OPCIONAL)': 'Danilo Antepara Cárdenas',
            'CÉDULA REPRESENTANTE (OPCIONAL)': '0945678901',
            'TELÉFONO REPRESENTANTE (OPCIONAL)': '0993344556',
            'TELÉFONO ALTERNATIVO REPRESENTANTE (OPCIONAL)': ''
        },
        {
            'No.': 5,
            'NOMBRES Y APELLIDOS (OBLIGATORIO)': 'ANTEPARA MEZA MARIA ALEJANDRA',
            'CÉDULA ESTUDIANTE (OPCIONAL)': '0952897858',
            'FECHA NACIMIENTO [AAAA-MM-DD] (OPCIONAL)': '2009-02-18',
            'TELÉFONO ESTUDIANTE (OPCIONAL)': '0984433221',
            'DIRECCIÓN DOMICILIARIA (OPCIONAL)': 'Guasmo Central Av. Principal',
            'NOMBRE REPRESENTANTE (OPCIONAL)': 'Danilo Antepara Cárdenas',
            'CÉDULA REPRESENTANTE (OPCIONAL)': '0945678901',
            'TELÉFONO REPRESENTANTE (OPCIONAL)': '0993344556',
            'TELÉFONO ALTERNATIVO REPRESENTANTE (OPCIONAL)': ''
        }
    ]

    const csvContent = arrayToCSV(studentsList)
    downloadCSV(`\uFEFF${csvContent}`, 'Plantilla_Estudiantes_LOGREVA.csv')
}

/**
 * Exporta estudiantes a Excel nativo (.xlsx)
 */
export const exportStudentsToExcel = async (students) => {
    const HEADER_STYLE = {
        fontWeight: 'bold',
        backgroundColor: '#0F172A',
        textColor: '#FFFFFF',
        align: 'left',
        height: 24
    }

    const sheetData = [
        [
            { value: 'N°', ...HEADER_STYLE, align: 'center' },
            { value: 'Nombre Completo', ...HEADER_STYLE },
            { value: 'Cédula', ...HEADER_STYLE, align: 'center' },
            { value: 'Curso', ...HEADER_STYLE },
            { value: 'Teléfono', ...HEADER_STYLE },
            { value: 'Representante', ...HEADER_STYLE },
            { value: 'Teléfono Representante', ...HEADER_STYLE }
        ]
    ]

    students.forEach((s, idx) => {
        sheetData.push([
            { value: idx + 1, align: 'center' },
            { value: s.full_name, fontWeight: 'bold' },
            { value: s.student_cedula || '-', align: 'center' },
            { value: s.courses?.name || 'Sin asignar' },
            { value: s.student_phone || '-' },
            { value: s.representative_name || '-' },
            { value: s.representative_phone || '-' }
        ])
    })

    const columns = [
        { width: 6 },
        { width: 40 },
        { width: 16 },
        { width: 28 },
        { width: 16 },
        { width: 35 },
        { width: 22 }
    ]

    const date = new Date().toISOString().split('T')[0]
    await writeNativeXlsx(sheetData, columns, `Estudiantes_${date}.xlsx`)
}

/**
 * Descarga plantilla oficial para importación masiva de cursos en formato Excel (.xlsx)
 */
export const downloadCoursesTemplate = async () => {
    const HEADER_STYLE = {
        fontWeight: 'bold',
        backgroundColor: '#0F172A',
        textColor: '#FFFFFF',
        align: 'left',
        height: 24
    }

    const sheetData = [
        [
            { value: 'No.', ...HEADER_STYLE, align: 'center' },
            { value: 'Nombre del Curso (Obligatorio)', ...HEADER_STYLE },
            { value: 'Nivel (Opcional)', ...HEADER_STYLE },
            { value: 'Itinerario / Especialidad (Opcional)', ...HEADER_STYLE },
            { value: 'Docente Tutor (Opcional)', ...HEADER_STYLE }
        ],
        [ { value: 1, align: 'center' }, { value: '1ro Bachillerato Ciencias A', fontWeight: 'bold' }, { value: 'BACHILLERATO' }, { value: 'CIENCIAS' }, { value: 'Lic. Carlos Mendoza' } ],
        [ { value: 2, align: 'center' }, { value: '1ro Bachillerato Ciencias B', fontWeight: 'bold' }, { value: 'BACHILLERATO' }, { value: 'CIENCIAS' }, { value: 'Msc. María Paredes' } ],
        [ { value: 3, align: 'center' }, { value: '2do Bachillerato Técnico A', fontWeight: 'bold' }, { value: 'BACHILLERATO' }, { value: 'TECNICO' }, { value: 'Ing. Jorge Zambrano' } ],
        [ { value: 4, align: 'center' }, { value: '3ro Bachillerato Ciencias A', fontWeight: 'bold' }, { value: 'BACHILLERATO' }, { value: 'CIENCIAS' }, { value: 'Lic. Ana Torres' } ],
        [ { value: 5, align: 'center' }, { value: '8vo EGB Superior A', fontWeight: 'bold' }, { value: 'SUPERIOR' }, { value: 'BASICA' }, { value: 'Prof. Roberto Guerrero' } ],
        [ { value: 6, align: 'center' }, { value: '9no EGB Superior A', fontWeight: 'bold' }, { value: 'SUPERIOR' }, { value: 'BASICA' }, { value: 'Lic. Diana Salazar' } ],
        [ { value: 7, align: 'center' }, { value: '10mo EGB Superior A', fontWeight: 'bold' }, { value: 'SUPERIOR' }, { value: 'BASICA' }, { value: '' } ],
        [ { value: 8, align: 'center' }, { value: '5to EGB Media A', fontWeight: 'bold' }, { value: 'MEDIA' }, { value: 'BASICA' }, { value: '' } ],
        [ { value: 9, align: 'center' }, { value: '2do EGB Elemental A', fontWeight: 'bold' }, { value: 'ELEMENTAL' }, { value: 'BASICA' }, { value: '' } ],
        [ { value: 10, align: 'center' }, { value: 'Inicial 2 A', fontWeight: 'bold' }, { value: 'INICIAL' }, { value: 'BASICA' }, { value: '' } ]
    ]

    const columns = [
        { width: 8 },
        { width: 38 },
        { width: 22 },
        { width: 32 },
        { width: 30 }
    ]

    await writeNativeXlsx(sheetData, columns, 'Plantilla_Cursos_LOGREVA.xlsx')
}

/**
 * Descarga plantilla oficial para importación masiva de cursos en formato CSV (.csv)
 */
export const downloadCoursesCsvTemplate = () => {
    const coursesList = [
        { 'No.': 1, 'Nombre del Curso (Obligatorio)': '1ro Bachillerato Ciencias A', 'Nivel (Opcional)': 'BACHILLERATO', 'Itinerario / Especialidad (Opcional)': 'CIENCIAS', 'Docente Tutor (Opcional)': 'Lic. Carlos Mendoza' },
        { 'No.': 2, 'Nombre del Curso (Obligatorio)': '1ro Bachillerato Ciencias B', 'Nivel (Opcional)': 'BACHILLERATO', 'Itinerario / Especialidad (Opcional)': 'CIENCIAS', 'Docente Tutor (Opcional)': 'Msc. María Paredes' },
        { 'No.': 3, 'Nombre del Curso (Obligatorio)': '2do Bachillerato Técnico A', 'Nivel (Opcional)': 'BACHILLERATO', 'Itinerario / Especialidad (Opcional)': 'TECNICO', 'Docente Tutor (Opcional)': 'Ing. Jorge Zambrano' },
        { 'No.': 4, 'Nombre del Curso (Obligatorio)': '3ro Bachillerato Ciencias A', 'Nivel (Opcional)': 'BACHILLERATO', 'Itinerario / Especialidad (Opcional)': 'CIENCIAS', 'Docente Tutor (Opcional)': 'Lic. Ana Torres' },
        { 'No.': 5, 'Nombre del Curso (Obligatorio)': '8vo EGB Superior A', 'Nivel (Opcional)': 'SUPERIOR', 'Itinerario / Especialidad (Opcional)': 'BASICA', 'Docente Tutor (Opcional)': 'Prof. Roberto Guerrero' },
        { 'No.': 6, 'Nombre del Curso (Obligatorio)': '9no EGB Superior A', 'Nivel (Opcional)': 'SUPERIOR', 'Itinerario / Especialidad (Opcional)': 'BASICA', 'Docente Tutor (Opcional)': 'Lic. Diana Salazar' },
        { 'No.': 7, 'Nombre del Curso (Obligatorio)': '10mo EGB Superior A', 'Nivel (Opcional)': 'SUPERIOR', 'Itinerario / Especialidad (Opcional)': 'BASICA', 'Docente Tutor (Opcional)': '' },
        { 'No.': 8, 'Nombre del Curso (Obligatorio)': '5to EGB Media A', 'Nivel (Opcional)': 'MEDIA', 'Itinerario / Especialidad (Opcional)': 'BASICA', 'Docente Tutor (Opcional)': '' },
        { 'No.': 9, 'Nombre del Curso (Obligatorio)': '2do EGB Elemental A', 'Nivel (Opcional)': 'ELEMENTAL', 'Itinerario / Especialidad (Opcional)': 'BASICA', 'Docente Tutor (Opcional)': '' },
        { 'No.': 10, 'Nombre del Curso (Obligatorio)': 'Inicial 2 A', 'Nivel (Opcional)': 'INICIAL', 'Itinerario / Especialidad (Opcional)': 'BASICA', 'Docente Tutor (Opcional)': '' }
    ]
    const csvContent = arrayToCSV(coursesList)
    downloadCSV(`\uFEFF${csvContent}`, 'Plantilla_Cursos_LOGREVA.csv')
}

/**
 * Exporta cursos a Excel nativo (.xlsx)
 */
export const exportCoursesToExcel = async (courses) => {
    const HEADER_STYLE = {
        fontWeight: 'bold',
        backgroundColor: '#0F172A',
        textColor: '#FFFFFF',
        align: 'left',
        height: 24
    }

    const sheetData = [
        [
            { value: 'N°', ...HEADER_STYLE, align: 'center' },
            { value: 'Nombre del Curso', ...HEADER_STYLE },
            { value: 'Año Académico', ...HEADER_STYLE },
            { value: 'Nivel', ...HEADER_STYLE },
            { value: 'Paralelo', ...HEADER_STYLE },
            { value: 'Tutor', ...HEADER_STYLE }
        ]
    ]

    courses.forEach((c, idx) => {
        sheetData.push([
            { value: idx + 1, align: 'center' },
            { value: c.name, fontWeight: 'bold' },
            { value: c.academic_year || '-' },
            { value: c.level || '-' },
            { value: c.track || '-' },
            { value: c.tutor_name || '-' }
        ])
    })

    const columns = [
        { width: 6 },
        { width: 35 },
        { width: 18 },
        { width: 20 },
        { width: 14 },
        { width: 30 }
    ]

    const date = new Date().toISOString().split('T')[0]
    await writeNativeXlsx(sheetData, columns, `Cursos_${date}.xlsx`)
}

/**
 * Exporta calificaciones a CSV/Excel
 */
export const exportGradesToExcel = (gradeData) => {
    const summaryData = gradeData.students?.map(s => ({
        'Estudiante': s.full_name,
        'Promedio Individual': s.averages?.avgIndividual?.toFixed(2) || 'N/A',
        'Promedio Grupal': s.averages?.avgGroup?.toFixed(2) || 'N/A',
        'Promedio Formative': s.averages?.formative?.toFixed(2) || 'N/A',
        'Promedio Sumativa': s.averages?.avgSum?.toFixed(2) || 'N/A',
        'Total': s.averages?.total?.toFixed(2) || 'N/A'
    })) || []

    const date = new Date().toISOString().split('T')[0]
    downloadCSV(`\uFEFF${arrayToCSV(summaryData)}`, `Calificaciones_Resumen_${date}.csv`)
    if (gradeData.detailed?.length) {
        downloadCSV(`\uFEFF${arrayToCSV(gradeData.detailed)}`, `Calificaciones_Detalle_${date}.csv`)
    }
}
