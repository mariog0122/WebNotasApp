import { ref, computed, watch } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './auth'

export const useAcademicYearStore = defineStore('academicYear', () => {
  const authStore = useAuthStore()
  
  const academicYears = ref([])
  const selectedYearId = ref(null)
  const loading = ref(false)
  const error = ref(null)
  const isInitialized = ref(false)

  const schoolId = computed(() => authStore.activeSchoolId || authStore.profile?.school_id || null)

  const storageKey = () => {
    const sId = schoolId.value || 'default'
    return `logreva-selected-academic-year:${sId}`
  }

  const readStoredYearId = () => {
    if (typeof globalThis.localStorage === 'undefined') return null
    return globalThis.localStorage.getItem(storageKey())
  }

  const selectedYear = computed(() => {
    if (!selectedYearId.value) return null
    return academicYears.value.find(y => y.id === selectedYearId.value) || null
  })

  const currentYear = computed(() => {
    return academicYears.value.find(y => y.is_current) || academicYears.value[0] || null
  })

  const selectedYearName = computed(() => {
    if (selectedYear.value) return selectedYear.value.name
    if (currentYear.value) return currentYear.value.name
    return ''
  })

  const isCurrentYear = computed(() => {
    if (!selectedYear.value) return true
    return Boolean(selectedYear.value.is_current)
  })

  const isLocked = computed(() => {
    return Boolean(selectedYear.value?.is_locked)
  })

  const setSelectedYearId = (id) => {
    if (!id) return
    const exists = academicYears.value.some(y => y.id === id)
    if (!exists && academicYears.value.length > 0) return

    selectedYearId.value = id
    if (typeof globalThis.localStorage !== 'undefined') {
      globalThis.localStorage.setItem(storageKey(), id)
    }

    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('academic-year-changed', {
        detail: {
          id,
          name: selectedYearName.value,
          is_current: isCurrentYear.value,
          is_locked: isLocked.value
        }
      }))
    }
  }

  const toggleAcademicYearLock = async (targetId = null, nextLockedState = null) => {
    const yearId = targetId || selectedYearId.value
    if (!yearId) throw new Error('No se ha seleccionado un año lectivo.')

    const currentYearObj = academicYears.value.find(y => y.id === yearId)
    const targetStatus = typeof nextLockedState === 'boolean'
      ? nextLockedState
      : !currentYearObj?.is_locked

    let updatedData = null

    // Intento 1: Ejecutar RPC seguro con validación de roles en Postgres
    try {
      const { data, error: rpcErr } = await supabase
        .rpc('toggle_academic_year_lock', {
          target_year_id: yearId,
          lock_status: targetStatus
        })

      if (rpcErr) throw rpcErr
      updatedData = data
    } catch (rpcError) {
      console.warn('RPC toggle_academic_year_lock no disponible, ejecutando actualización directa:', rpcError)
      // Intento 2: Fallback directo a la tabla con RLS
      const { data, error: updateErr } = await supabase
        .from('academic_years')
        .update({ is_locked: targetStatus })
        .eq('id', yearId)
        .select()
        .single()

      if (updateErr) throw updateErr
      updatedData = data
    }

    // Actualizar estado reactivo local en el store
    const idx = academicYears.value.findIndex(y => y.id === yearId)
    if (idx !== -1) {
      academicYears.value[idx] = {
        ...academicYears.value[idx],
        is_locked: targetStatus
      }
      // Forzar reactividad
      academicYears.value = [...academicYears.value]
    }

    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('academic-year-lock-changed', {
        detail: {
          id: yearId,
          name: selectedYearName.value,
          is_locked: targetStatus
        }
      }))
    }

    return updatedData || { id: yearId, is_locked: targetStatus }
  }

  const fetchAcademicYears = async (force = false) => {
    if (loading.value && !force) return academicYears.value
    loading.value = true
    error.value = null

    try {
      const sId = schoolId.value
      let query = supabase
        .from('academic_years')
        .select('*')
        .order('start_year', { ascending: false })

      if (sId) {
        query = query.or(`school_id.eq.${sId},school_id.is.null`)
      }

      const { data, error: fetchErr } = await query

      if (fetchErr) {
        throw fetchErr
      }

      academicYears.value = data || []

      // Determine the active year selection
      const storedId = readStoredYearId()
      const storedExists = storedId && academicYears.value.some(y => y.id === storedId)

      if (storedExists) {
        selectedYearId.value = storedId
      } else {
        const defaultCurrent = academicYears.value.find(y => y.is_current) || academicYears.value[0]
        if (defaultCurrent) {
          selectedYearId.value = defaultCurrent.id
          if (typeof globalThis.localStorage !== 'undefined') {
            globalThis.localStorage.setItem(storageKey(), defaultCurrent.id)
          }
        } else {
          selectedYearId.value = null
        }
      }

      isInitialized.value = true
      return academicYears.value
    } catch (err) {
      console.error('Error fetching academic years:', err)
      error.value = err.message || 'Error al cargar años lectivos'
      return []
    } finally {
      loading.value = false
    }
  }

  const createAcademicYear = async (name, isCurrent = false) => {
    const sId = schoolId.value
    const parts = name.split('-').map(p => parseInt(p.trim(), 10)).filter(p => !isNaN(p))
    const startYear = parts[0] || new Date().getFullYear()
    const endYear = parts[1] || (startYear + 1)

    const payload = {
      name: name.trim(),
      start_year: startYear,
      end_year: endYear,
      is_current: isCurrent,
      is_locked: false
    }
    if (sId) {
      payload.school_id = sId
    }

    const { data, error: insertErr } = await supabase
      .from('academic_years')
      .insert(payload)
      .select()
      .single()

    if (insertErr) {
      throw insertErr
    }

    await fetchAcademicYears(true)
    if (data?.id) {
      setSelectedYearId(data.id)
    }

    return data
  }

  // Watch for school change or auth initialization
  watch(
    () => schoolId.value,
    (newSchoolId) => {
      if (newSchoolId) {
        fetchAcademicYears(true)
      }
    },
    { immediate: true }
  )

  return {
    academicYears,
    selectedYearId,
    selectedYear,
    selectedYearName,
    currentYear,
    isCurrentYear,
    isLocked,
    loading,
    error,
    isInitialized,
    fetchAcademicYears,
    setSelectedYearId,
    toggleAcademicYearLock,
    createAcademicYear
  }
})
