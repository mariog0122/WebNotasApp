import { useQuery } from '@tanstack/vue-query'
import { supabase } from '../lib/supabase'
import { parseStudents, parseCourses, InstitutionConfigSchema } from '../lib/zodSchemas'

export function useAcademicYearsQuery() {
  return useQuery({
    queryKey: ['academic_years'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('academic_years')
        .select('*')
        .order('start_year', { ascending: false })
      if (error) throw new Error(error.message)
      return data || []
    }
  })
}

export function useQuartersQuery() {
  return useQuery({
    queryKey: ['quarters'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('quarters')
        .select('id, name, is_active')
        .order('name')
      if (error) throw new Error(error.message)
      return data || []
    }
  })
}

export function useCoursesQuery(academicYearRef) {
  return useQuery({
    queryKey: ['courses', academicYearRef],
    queryFn: async () => {
      let query = supabase
        .from('courses')
        .select('id, name, academic_year, level, track, created_at')
        .order('name')
      
      const val = academicYearRef?.value || academicYearRef
      if (val) {
        query = query.eq('academic_year', val)
      }
      
      const { data, error } = await query
      if (error) throw new Error(error.message)
      return parseCourses(data || [])
    }
  })
}

export function useInstitutionConfigQuery() {
  return useQuery({
    queryKey: ['institution_config'],
    queryFn: async () => {
      const { data, error } = await supabase.from('institution_config').select('*').single()
      if (error && error.code !== 'PGRST116') throw new Error(error.message)
      return InstitutionConfigSchema.parse(data || {})
    }
  })
}

export function useStudentsQuery(searchTermRef, pageRef, pageSize = 50) {
  return useQuery({
    queryKey: ['students', searchTermRef, pageRef],
    queryFn: async () => {
      const term = (searchTermRef?.value || searchTermRef || '').trim()
      const page = pageRef?.value || pageRef || 1
      const from = (page - 1) * pageSize
      const to = from + pageSize - 1
      
      let query = supabase
        .from('students')
        .select(`
          id, full_name, course_id, student_cedula, student_birthdate,
          student_phone, student_address, representative_name, representative_cedula,
          representative_phone, representative_alt_phone, student_photo_url,
          representative_photo_url, created_at,
          courses (name, level, track)
        `, { count: 'exact' })
        .order('full_name', { ascending: true })
        .range(from, to)

      if (term) {
        query = query.or(`full_name.ilike.%${term}%,student_cedula.ilike.%${term}%`)
      }

      const { data, error, count } = await query
      if (error) throw new Error(error.message)
      return { data: parseStudents(data || []), count: count || 0 }
    }
  })
}
