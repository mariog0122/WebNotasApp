import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick, ref } from 'vue'
import { renderComponent } from './helpers/renderComponent'

const STUDENTS = [
  { id: 's1', full_name: 'Ana Pérez', representative_name: 'Rosa Pérez', representative_cedula: '0912345678', representative_phone: '0991234567' },
  { id: 's2', full_name: 'Luis Pérez', representative_name: 'Rosa Pérez', representative_cedula: '0912345678', representative_phone: '0991234567' },
]

const state = vi.hoisted(() => ({
  courses: null,
  quarters: null,
  studentQueries: 0,
}))

vi.mock('../src/lib/supabase', () => ({
  supabase: {
    from: (table) => {
      const query = {
        select: () => query,
        eq: () => query,
        in: () => query,
        order: () => {
          if (table === 'students') state.studentQueries += 1
          return Promise.resolve({ data: table === 'students' ? STUDENTS : [], error: null })
        },
      }
      return query
    },
  },
}))

vi.mock('../src/composables/useQueries', () => ({
  useCoursesQuery: () => ({ data: state.courses, refetch: vi.fn() }),
  useQuartersQuery: () => ({ data: state.quarters, refetch: vi.fn() }),
}))

vi.mock('../src/stores/auth', () => ({
  useAuthStore: () => ({ activeSchoolId: 'school-1', accessContext: {} }),
}))

vi.mock('../src/stores/academicYear', () => ({
  useAcademicYearStore: () => ({ selectedYearName: '2026-2027' }),
}))

// Sin permiso académico: la prueba se centra en la carga de la nómina de familias.
vi.mock('../src/lib/permissions', () => ({ hasAccessPermission: () => false }))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))
vi.mock('vue-sonner', () => ({ toast: { error: vi.fn(), success: vi.fn() } }))

import Families from '../src/views/Families.vue'

const flush = async () => {
  for (let i = 0; i < 6; i += 1) {
    await Promise.resolve()
    await nextTick()
  }
}

let mounted

beforeEach(() => {
  state.studentQueries = 0
  state.courses = ref([{ id: 'c1', name: '8vo A' }, { id: 'c2', name: '8vo B' }])
  state.quarters = ref([{ id: 'q1', name: 'Primer Trimestre', is_active: true }])
})

afterEach(() => mounted?.unmount())

describe('Familias: carga del curso seleccionado', () => {
  it('carga los estudiantes del primer curso aunque los cursos ya estuvieran en caché al montar', async () => {
    mounted = renderComponent(Families)
    await flush()

    expect(mounted.state.selectedCourse).toBe('c1')
    expect(state.studentQueries).toBeGreaterThanOrEqual(1)
    expect(mounted.state.students).toHaveLength(2)
    expect(mounted.state.groupedFamilies).toHaveLength(1)
  })

  it('carga los estudiantes cuando los cursos llegan después de montar', async () => {
    state.courses = ref([])
    mounted = renderComponent(Families)
    await flush()
    expect(mounted.state.students).toHaveLength(0)

    state.courses.value = [{ id: 'c1', name: '8vo A' }]
    await flush()

    expect(mounted.state.selectedCourse).toBe('c1')
    expect(mounted.state.students).toHaveLength(2)
  })

  it('vuelve a cargar al cambiar de curso', async () => {
    mounted = renderComponent(Families)
    await flush()
    const before = state.studentQueries

    mounted.state.selectedCourse = 'c2'
    await flush()

    expect(state.studentQueries).toBeGreaterThan(before)
    expect(mounted.state.students).toHaveLength(2)
  })

  it('recarga los datos si los trimestres llegan después que el curso (notas de proyecto)', async () => {
    state.quarters = ref([])
    mounted = renderComponent(Families)
    await flush()
    const before = state.studentQueries

    state.quarters.value = [{ id: 'q1', name: 'Primer Trimestre', is_active: true }]
    await flush()

    expect(state.studentQueries).toBeGreaterThan(before)
  })
})
