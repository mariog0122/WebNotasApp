import { z } from 'zod'

export const StudentSchema = z.object({
  id: z.string().uuid().optional().catch(undefined),
  full_name: z.string().min(1).catch('Estudiante sin nombre'),
  course_id: z.string().uuid().nullable().catch(null),
  student_cedula: z.string().nullable().catch(null),
  student_birthdate: z.string().nullable().catch(null),
  student_phone: z.string().nullable().catch(null),
  student_address: z.string().nullable().catch(null),
  representative_name: z.string().nullable().catch(null),
  representative_cedula: z.string().nullable().catch(null),
  representative_phone: z.string().nullable().catch(null),
  representative_alt_phone: z.string().nullable().catch(null),
  student_photo_url: z.string().nullable().catch(null),
  representative_photo_url: z.string().nullable().catch(null),
  created_at: z.string().nullable().catch(null),
  courses: z.object({
    name: z.string().catch('Curso desconocido'),
    level: z.string().nullable().catch(null),
    track: z.string().nullable().catch(null),
  }).nullable().catch(null)
}).catch((ctx) => ({
  id: undefined,
  full_name: 'Estudiante corrupto',
  course_id: null,
  courses: null
}))

export const CourseSchema = z.object({
  id: z.string().uuid().catch(''),
  name: z.string().min(1).catch('Curso sin nombre'),
  academic_year: z.string().nullable().catch(null),
  level: z.string().nullable().catch(null),
  track: z.string().nullable().catch(null),
  created_at: z.string().nullable().catch(null),
}).catch({
  id: '',
  name: 'Datos corruptos',
})

export const GradeSchema = z.record(
  z.string(), // student_id
  z.record(
    z.string(), // grade_definition_id
    z.union([z.string(), z.number()]).nullable().catch(null)
  ).catch({})
).catch({})

export const QualitativeGradeSchema = z.record(
  z.string(), // student_id
  z.record(
    z.string(), // behavior or something
    z.string().nullable().catch(null)
  ).catch({})
).catch({})

export const InstitutionConfigSchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().catch('Institución sin nombre'),
  address: z.string().nullable().catch(null),
  phone: z.string().nullable().catch(null),
  logo_url: z.string().nullable().catch(null),
  principal_name: z.string().nullable().catch(null),
  secretary_name: z.string().nullable().catch(null),
  created_at: z.string().nullable().catch(null),
}).catch({
  name: 'Error de configuración'
})

// Utilities for array parsing
export const parseStudents = (data) => z.array(StudentSchema).catch([]).parse(data)
export const parseCourses = (data) => z.array(CourseSchema).catch([]).parse(data)
