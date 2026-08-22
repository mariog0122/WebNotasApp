import { useQuery } from '@tanstack/vue-query'
import { computed, unref } from 'vue'
import { supabase } from '../lib/supabase'
import { InstitutionConfigSchema } from '../lib/zodSchemas'
import { useAuthStore } from '../stores/auth'
import { isInstitutionAdmin } from '../lib/permissions'

const useActiveSchool = () => {
  const authStore = useAuthStore()
  return computed(() => authStore.activeSchoolId || authStore.profile?.school_id || null)
}

export function useAcademicYearsQuery() {
  const schoolId = useActiveSchool()
  return useQuery({
    queryKey: computed(() => ['academic_years', schoolId.value]),
    enabled: computed(() => Boolean(schoolId.value)),
    queryFn: async () => {
      if (!schoolId.value) return []
      let query = supabase
        .from('academic_years')
        .select('*')
        .order('start_year', { ascending: false })
      
      query = query.or(`school_id.eq.${schoolId.value},school_id.is.null`)
      const { data, error } = await query
      if (error) throw new Error(error.message)
      return data || []
    }
  })
}

export function useQuartersQuery() {
  const schoolId = useActiveSchool()
  return useQuery({
    queryKey: computed(() => ['quarters', schoolId.value]),
    enabled: computed(() => Boolean(schoolId.value)),
    queryFn: async () => {
      if (!schoolId.value) return []
      let query = supabase
        .from('quarters')
        .select('id, name, is_active, is_locked')
        .order('name')
      
      query = query.or(`school_id.eq.${schoolId.value},school_id.is.null`)
      const { data, error } = await query
      if (error) throw new Error(error.message)
      return data || []
    }
  })
}

export function useCoursesQuery(academicYearRef) {
  const schoolId = useActiveSchool()
  const authStore = useAuthStore()
  const yearVal = computed(() => {
    const raw = unref(academicYearRef)
    return typeof raw === 'string' ? raw : (raw || null)
  })

  return useQuery({
    queryKey: computed(() => [
      'courses',
      schoolId.value,
      yearVal.value,
      authStore.user?.id,
      isInstitutionAdmin(authStore.accessContext)
    ]),
    enabled: computed(() => Boolean(schoolId.value)),
    queryFn: async () => {
      if (!schoolId.value) return []
      let query = supabase
        .from('courses')
        .select('id, name, academic_year, level, track, tutor_name, created_at')
        .order('name')
      
      query = query.or(`school_id.eq.${schoolId.value},school_id.is.null`)
      
      if (yearVal.value) {
        query = query.eq('academic_year', yearVal.value)
      }
      
      let { data, error } = await query
      // Fallback if tutor_name column is not in DB schema yet
      if (error && error.message && error.message.includes('tutor_name')) {
        let fallbackQuery = supabase
          .from('courses')
          .select('id, name, academic_year, level, track, created_at')
          .order('name')
        fallbackQuery = fallbackQuery.or(`school_id.eq.${schoolId.value},school_id.is.null`)
        if (yearVal.value) {
          fallbackQuery = fallbackQuery.eq('academic_year', yearVal.value)
        }
        const fallbackRes = await fallbackQuery
        data = fallbackRes.data
        error = fallbackRes.error
      }
      if (error) throw new Error(error.message)
      
      let result = data || []
      const userId = authStore.user?.id || authStore.profile?.id
      const isAdmin = isInstitutionAdmin(authStore.accessContext)

      if (!isAdmin && userId) {
        const { data: assignedLinks } = await supabase
          .from('course_subjects')
          .select('course_id')
          .eq('teacher_id', userId)

        const assignedCourseIds = new Set((assignedLinks || []).map(l => l.course_id))
        result = result.filter(c => assignedCourseIds.has(c.id))
      }

      return result
    }
  })
}

export function useInstitutionConfigQuery() {
  const schoolId = useActiveSchool()
  return useQuery({
    queryKey: computed(() => ['institution_config', schoolId.value]),
    enabled: computed(() => Boolean(schoolId.value)),
    queryFn: async () => {
      if (!schoolId.value) return InstitutionConfigSchema.parse({})
      const { data, error } = await supabase
        .from('system_config')
        .select('*')
        .eq('school_id', schoolId.value)
      if (error && error.code !== 'PGRST116') throw new Error(error.message)
      const map = Object.fromEntries((data || []).map(item => [item.key, item.value]))
      return InstitutionConfigSchema.parse(map || {})
    }
  })
}

export function useStudentsQuery(searchTermRef, pageRef, pageSize = 50) {
  const schoolId = useActiveSchool()
  const termVal = computed(() => {
    const raw = unref(searchTermRef)
    return (typeof raw === 'string' ? raw : '').trim()
  })
  const pageVal = computed(() => {
    const raw = unref(pageRef)
    return typeof raw === 'number' ? raw : 1
  })

  return useQuery({
    queryKey: computed(() => ['students', schoolId.value, termVal.value, pageVal.value]),
    enabled: computed(() => Boolean(schoolId.value)),
    queryFn: async () => {
      if (!schoolId.value) return { data: [], count: 0 }
      const term = termVal.value
      const page = pageVal.value
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

      query = query.or(`school_id.eq.${schoolId.value},school_id.is.null`)

      const userIds = [authStore.user?.id, authStore.profile?.id].filter(Boolean)
      const isAdmin = isInstitutionAdmin(authStore.accessContext)

      if (!isAdmin && userIds.length > 0) {
        const { data: assignedLinks } = await supabase
          .from('course_subjects')
          .select('course_id')
          .in('teacher_id', userIds)

        const assignedCourseIds = Array.from(new Set((assignedLinks || []).map(l => l.course_id).filter(Boolean)))
        if (assignedCourseIds.length === 0) {
          return { data: [], count: 0 }
        }
        query = query.in('course_id', assignedCourseIds)
      }

      if (term) {
        query = query.or(`full_name.ilike.%${term}%,student_cedula.ilike.%${term}%`)
      }

      const { data, error, count } = await query
      if (error) throw new Error(error.message)
      return { data: data || [], count: count || 0 }
    }
  })
}

export function useSubjectsQuery() {
  const schoolId = useActiveSchool()
  return useQuery({
    queryKey: computed(() => ['subjects', schoolId.value]),
    enabled: computed(() => Boolean(schoolId.value)),
    queryFn: async () => {
      if (!schoolId.value) return []
      let query = supabase
        .from('subjects')
        .select('*')
        .order('name', { ascending: true })
      
      query = query.or(`school_id.eq.${schoolId.value},school_id.is.null`)
      const { data, error } = await query
      if (error) throw new Error(error.message)
      return data || []
    }
  })
}
