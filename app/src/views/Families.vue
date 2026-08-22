<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useCoursesQuery, useQuartersQuery } from '../composables/useQueries'
import { useAuthStore } from '../stores/auth'
import { useAcademicYearStore } from '../stores/academicYear'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'

import { computeProjectAverage, computeSubjectTotal, truncate2, computeFinalAnnual } from '../lib/reporting'

const router = useRouter()
const authStore = useAuthStore()
const academicYearStore = useAcademicYearStore()

const { data: coursesData, refetch: refetchCourses } = useCoursesQuery(computed(() => academicYearStore.selectedYearName))
const courses = computed(() => coursesData.value || [])

const { data: quartersData, refetch: refetchQuarters } = useQuartersQuery()
const quarters = computed(() => quartersData.value || [])

const selectedCourse = ref(null)
const selectedQuarter = ref(null)
const loading = ref(false)

// Raw Data
const students = ref([])
const courseSubjects = ref([])
const definitionsByQuarter = ref({})
const gradesByStudent = ref({})
const projectSettingsByQuarter = ref({})
const projectGradesByQuarter = ref({})
const supplementaryScores = ref({})

// Search state
const searchQuery = ref('')

const fetchCourseData = async () => {
  if (!selectedCourse.value) return
  loading.value = true
  
  try {
    const courseId = selectedCourse.value
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    
    // Fetch students with all metadata
    let stusQuery = supabase
      .from('students')
      .select('id, full_name, representative_name, representative_cedula, representative_phone, student_address')
      .eq('course_id', courseId)
      .order('full_name')
    if (sId) {
      stusQuery = stusQuery.or(`school_id.eq.${sId},school_id.is.null`)
    }
    const { data: stus, error: stusError } = await stusQuery
      
    if (stusError) throw stusError
    students.value = stus || []

    let csQuery = supabase
      .from('course_subjects')
      .select('id, subject_id, subjects (name)')
      .eq('course_id', courseId)
    if (sId) {
      csQuery = csQuery.or(`school_id.eq.${sId},school_id.is.null`)
    }
    const { data: cs, error: csError } = await csQuery
    if (csError) throw csError
    courseSubjects.value = cs || []

    const courseSubjectIds = (cs || []).map(x => x.id)

    if (courseSubjectIds.length > 0) {
      // Definitions
      let defsQuery = supabase
        .from('grade_definitions')
        .select('id, course_subject_id, quarter_id, name, category, sort_order')
        .in('course_subject_id', courseSubjectIds)
      if (sId) {
        defsQuery = defsQuery.or(`school_id.eq.${sId},school_id.is.null`)
      }
      const { data: defs } = await defsQuery
      
      const defIds = (defs || []).map(d => d.id)
      
      // Grades
      let gradeList = []
      if (defIds.length > 0) {
        const { data: g } = await supabase
          .from('grades')
          .select('student_id, grade_definition_id, score')
          .in('grade_definition_id', defIds)
        gradeList = g || []
      }

      // Structure Maps (same exact shape used by lib/reporting logic)
      const defsByQuarterMap = {}
      ;(defs || []).forEach(d => {
        if (!defsByQuarterMap[d.quarter_id]) defsByQuarterMap[d.quarter_id] = {}
        if (!defsByQuarterMap[d.quarter_id][d.course_subject_id]) defsByQuarterMap[d.quarter_id][d.course_subject_id] = []
        defsByQuarterMap[d.quarter_id][d.course_subject_id].push(d)
      })
      definitionsByQuarter.value = defsByQuarterMap

      const gradesMap = {}
      ;(gradeList || []).forEach(g => {
        if (!gradesMap[g.student_id]) gradesMap[g.student_id] = {}
        gradesMap[g.student_id][g.grade_definition_id] = g.score
      })
      gradesByStudent.value = gradesMap

      // Projects
      const projectSettingsMap = {}
      const projectGradesMap = {}
      for (const q of quarters.value) {
         const { data: ps } = await supabase.from('project_settings').select('subject_id').eq('course_id', courseId).eq('quarter_id', q.id)
         projectSettingsMap[q.id] = (ps || []).map(p => p.subject_id)

         const { data: pg } = await supabase.from('project_subject_grades').select('student_id, subject_id, score').eq('course_id', courseId).eq('quarter_id', q.id)
         const pgMap = {}
         ;(pg || []).forEach(g => {
           if (!pgMap[g.student_id]) pgMap[g.student_id] = {}
           pgMap[g.student_id][g.subject_id] = g.score
         })
         projectGradesMap[q.id] = pgMap
      }
      projectSettingsByQuarter.value = projectSettingsMap
      projectGradesByQuarter.value = projectGradesMap
      
      // Supletorios
      const { data: supData } = await supabase
          .from('supplementary_exams')
          .select('student_id, course_subject_id, score')
          .in('course_subject_id', courseSubjectIds)
      const supMap = {}
      ;(supData || []).forEach(s => {
        if (!supMap[s.student_id]) supMap[s.student_id] = {}
        supMap[s.student_id][s.course_subject_id] = s.score
      })
      supplementaryScores.value = supMap
    }
  } catch (error) {
    console.error("Error loading families dataset:", error)
  }
  loading.value = false
}

watch(() => authStore.activeSchoolId, async () => {
  selectedCourse.value = null
  await refetchCourses()
  await refetchQuarters()
})

watch(courses, (newCourses) => {
  if (newCourses && newCourses.length > 0) {
    if (!selectedCourse.value || !newCourses.some(c => c.id === selectedCourse.value)) {
      selectedCourse.value = newCourses[0].id
    }
  } else {
    selectedCourse.value = null
    students.value = []
  }
}, { immediate: true })

watch(quarters, (newVal) => {
  if (newVal && newVal.length > 0) {
    if (!selectedQuarter.value || !newVal.some(q => q.id === selectedQuarter.value)) {
      const active = newVal.find(q => q.is_active) || newVal[0]
      if (active) selectedQuarter.value = active.id
    }
  }
}, { immediate: true })

watch(selectedCourse, (newVal) => {
  if (newVal) {
    fetchCourseData()
  }
})

onMounted(() => {
  if (courses.value && courses.value.length > 0 && !selectedCourse.value) {
    selectedCourse.value = courses.value[0].id
  }
  if (selectedCourse.value) {
    fetchCourseData()
  }
})

// === Computed Families Array ===
const groupedFamilies = computed(() => {
  if (students.value.length === 0) return []
  const map = {}
  
  students.value.forEach(stu => {
    // If missing explicit cedula, treat each separately to prevent colliding
    const groupingKey = stu.representative_cedula?.trim() || `stu-${stu.id}`
    
    if (!map[groupingKey]) {
      map[groupingKey] = {
        representative_cedula: stu.representative_cedula || '-',
        representative_name: stu.representative_name || 'Desconocido',
        representative_phone: stu.representative_phone || '',
        student_address: stu.student_address || 'No registrada',
        students: []
      }
    }
    map[groupingKey].students.push(stu)
  })

  let result = Object.values(map).sort((a,b) => a.representative_name.localeCompare(b.representative_name))
  
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    result = result.filter(f => 
      f.representative_name.toLowerCase().includes(q) || 
      f.representative_cedula.toLowerCase().includes(q) ||
      f.students.some(s => s.full_name.toLowerCase().includes(q))
    )
  }
  
  return result
})

// === Top 3 Cuadro de Honor ===
const top3Students = computed(() => {
  if (!selectedCourse.value || students.value.length === 0) return []
  if (Object.keys(gradesByStudent.value).length === 0) return []

  const metrics = students.value.map(stu => {
    let finalAverage = 0
    if (courseSubjects.value.length > 0 && quarters.value.length > 0) {
      const subjectAverages = courseSubjects.value.map(cs => {
        const periodScores = quarters.value.map(q => {
          const defs = definitionsByQuarter.value[q.id]?.[cs.id] || []
          const projectSubjects = projectSettingsByQuarter.value[q.id] || []
          const projectGrades = projectGradesByQuarter.value[q.id] || {}
          const projectAvg = computeProjectAverage(projectGrades, projectSubjects, stu.id)
          const subjectIsProject = projectSubjects.includes(cs.subject_id)
          const totals = computeSubjectTotal(defs, gradesByStudent.value[stu.id], projectAvg, subjectIsProject)
          return totals.total
        }).filter(v => v !== null && v !== undefined && !isNaN(v))

        const p = periodScores.length ? truncate2(periodScores.reduce((s, v) => s + v, 0) / periodScores.length) : null
        const rawS = supplementaryScores.value?.[stu.id]?.[cs.id]
        const sVal = rawS === '' || rawS === null || rawS === undefined ? null : parseFloat(rawS)
        return computeFinalAnnual(p, sVal)
      }).filter(v => v !== null && v !== undefined && !isNaN(v))

      if (subjectAverages.length > 0) {
        finalAverage = subjectAverages.reduce((sum, v) => sum + v, 0) / subjectAverages.length
      }
    }

    return {
      student: stu,
      average: finalAverage !== null && finalAverage !== undefined && !isNaN(finalAverage) ? finalAverage : 0
    }
  })

  // Sort descending by average
  const sorted = metrics.sort((a,b) => b.average - a.average)
  // Get top 3
  return sorted.slice(0, 3).filter(s => s.average > 0)
})

// Actions
const generateIndividualReport = (studentId) => {
  // Deep route to Reports to download HTML2PDF immediately
  router.push({ name: 'reports', query: { course_id: selectedCourse.value, student_id: studentId, download: '1' } })
}

const sendWhatsApp = (phoneStr, parentName, studentNames) => {
  if (!phoneStr) {
     alert('Este representante no tiene teléfono registrado.')
     return
  }
  const cleanPhone = phoneStr.replace(/\D/g, '')
  const text = `Hola ${parentName}, le escribo de parte de la institución educativa, en relación al estudiante ${studentNames.join(', ')}.`
  window.open(`https://wa.me/${cleanPhone}?text=${encodeURIComponent(text)}`, '_blank')
}
</script>

<template>
  <div class="app-shell min-h-screen">
    <main class="app-container">
      <!-- Academic Year Banner -->
      <AcademicYearBanner module-name="Familias" />

      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="font-extrabold text-3xl text-slate-900 dark:text-white tracking-tight">Familias & Panel de Control</h1>
          <p class="text-slate-500 dark:text-slate-400 mt-1">Busca padres, envía WhatsApps rápidos y revisa el Cuadro de Honor.</p>
        </div>
      </div>

      <!-- Controls -->
      <div class="app-card bg-white dark:bg-slate-900/90 border border-slate-200 dark:border-slate-800 shadow-sm p-5 mb-8 flex flex-col md:flex-row gap-4 items-end rounded-2xl">
        <div class="flex-1 w-full max-w-xs">
          <label class="app-label">Curso Activo</label>
          <select class="app-input w-full" v-model="selectedCourse">
            <option :value="null">Selecciona un curso</option>
            <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
        <div class="flex-1 w-full max-w-xs">
          <label class="app-label">Buscador</label>
          <input type="text" class="app-input w-full" v-model="searchQuery" placeholder="Nombre o cédula..." />
        </div>
      </div>
      
      <div v-if="loading" class="text-center py-10">
         <span class="text-teal-600 dark:text-teal-400 font-semibold animate-pulse">Procesando base de datos...</span>
      </div>

      <!-- TOP 3 Cuadro de Honor -->
      <div v-if="!loading && selectedCourse && top3Students.length > 0" class="mb-10">
         <h2 class="text-xl font-extrabold text-slate-900 dark:text-white flex items-center gap-2 mb-4">
           <svg class="w-6 h-6 text-amber-500" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"></path></svg>
           Cuadro de Honor (Promedio Anual)
         </h2>
         
         <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div 
               v-for="(top, index) in top3Students" 
               :key="top.student.id"
               class="bg-white dark:bg-slate-900/90 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-800 overflow-hidden relative p-6 flex flex-col items-center text-center transform transition-all hover:-translate-y-1 hover:shadow-lg"
            >
               <!-- Medal Badge -->
               <div 
                  class="absolute top-0 right-0 w-12 h-12 flex flex-col items-center justify-center font-bold text-white rounded-bl-2xl shadow-sm"
                  :class="{
                     'bg-amber-400': index === 0,
                     'bg-slate-400': index === 1,
                     'bg-amber-700': index === 2
                  }"
               >
                 #{{index + 1}}
               </div>
               
               <div class="w-16 h-16 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center mb-4 border-2" :class="{
                  'border-amber-400 text-amber-500': index === 0,
                  'border-slate-300 dark:border-slate-600 text-slate-400 dark:text-slate-300': index === 1,
                  'border-amber-700 text-amber-600 dark:text-amber-500': index === 2
               }">
                  <span class="text-2xl font-bold font-mono text-slate-900 dark:text-white">{{ top.average.toFixed(2) }}</span>
               </div>
               
               <h3 class="font-bold text-slate-900 dark:text-white mb-1 leading-tight">{{ top.student.full_name }}</h3>
               <button @click="generateIndividualReport(top.student.id)" class="text-xs text-teal-600 dark:text-teal-400 hover:text-teal-800 dark:hover:text-teal-300 font-semibold mt-2 inline-flex items-center gap-1">
                  Obtener Libreta
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"></path></svg>
               </button>
            </div>
         </div>
      </div>
      
      <!-- Families Table -->
      <div v-if="!loading && selectedCourse" class="bg-white dark:bg-slate-900/90 border flex flex-col border-slate-200 dark:border-slate-800 rounded-2xl overflow-hidden shadow-sm">
        <div class="px-6 py-4 border-b border-slate-200/80 dark:border-slate-800 flex justify-between items-center bg-slate-50/80 dark:bg-slate-950/80">
          <h2 class="font-bold text-slate-900 dark:text-white">Directorio de Familias <span class="text-xs ml-2 font-medium text-slate-600 dark:text-slate-300 bg-slate-200/80 dark:bg-slate-800 px-2.5 py-0.5 rounded-full border border-slate-300/50 dark:border-slate-700/50">{{ groupedFamilies.length }} núcleos</span></h2>
        </div>
        
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-slate-500 dark:text-slate-400">
            <thead class="text-xs font-semibold text-slate-600 dark:text-slate-300 uppercase bg-slate-100/70 dark:bg-slate-950 border-b border-slate-200 dark:border-slate-800">
              <tr>
                <th scope="col" class="px-6 py-4 font-semibold tracking-wider">Representante</th>
                <th scope="col" class="px-6 py-4 font-semibold tracking-wider">Estudiantes Asignados</th>
                <th scope="col" class="px-6 py-4 font-semibold tracking-wider">Contacto</th>
                <th scope="col" class="px-6 py-4 font-semibold tracking-wider text-right">Comunicaciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 dark:divide-slate-800/60">
              <tr v-if="groupedFamilies.length === 0">
                 <td colspan="4" class="px-6 py-8 text-center text-slate-400 dark:text-slate-500">
                    No se encontraron familias en este curso. Revisa que los perfiles de estudiante tengan datos de representante.
                 </td>
              </tr>
              <tr v-for="family in groupedFamilies" :key="family.representative_cedula" class="hover:bg-slate-50/80 dark:hover:bg-slate-800/40 transition-colors">
                
                <td class="px-6 py-4 align-top">
                  <div class="font-bold text-slate-900 dark:text-white text-base mb-0.5">{{ family.representative_name }}</div>
                  <div class="text-xs font-mono text-slate-500 dark:text-slate-400">CI: {{ family.representative_cedula }}</div>
                </td>
                
                <td class="px-6 py-4 align-top border-l border-slate-100 dark:border-slate-800/60">
                  <ul class="space-y-2">
                     <li v-for="stu in family.students" :key="stu.id" class="flex flex-col sm:flex-row sm:items-center justify-between bg-slate-100/80 dark:bg-slate-800/70 border border-slate-200/60 dark:border-slate-700/60 p-2.5 rounded-xl gap-2">
                        <span class="font-semibold text-slate-800 dark:text-slate-200 text-xs truncate max-w-xs">{{ stu.full_name }}</span>
                        <button class="mt-1 sm:mt-0 text-[10px] uppercase font-bold text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/80 border border-teal-200/80 dark:border-teal-700/80 hover:bg-teal-100 dark:hover:bg-teal-900/60 px-2.5 py-1 rounded-lg transition-all whitespace-nowrap shadow-sm" @click="generateIndividualReport(stu.id)">
                           Generar Libreta
                        </button>
                     </li>
                  </ul>
                </td>
                
                <td class="px-6 py-4 align-top border-l border-slate-100 dark:border-slate-800/60">
                  <div class="flex items-center gap-1.5 text-slate-700 dark:text-slate-200 font-medium mb-1" v-if="family.representative_phone">
                     <svg class="w-4 h-4 text-slate-400 dark:text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"></path></svg>
                     {{ family.representative_phone }}
                  </div>
                  <div class="text-xs text-slate-500 dark:text-slate-400 max-w-[200px] leading-snug">
                     {{ family.student_address }}
                  </div>
                </td>
                
                <td class="px-6 py-4 align-top text-right border-l border-slate-100 dark:border-slate-800/60">
                   <button 
                     @click="sendWhatsApp(family.representative_phone, family.representative_name, family.students.map(s => s.full_name))"
                     class="inline-flex items-center justify-center gap-1.5 bg-[#25D366] hover:bg-[#20bd5a] text-white px-3.5 py-1.5 rounded-xl text-xs font-bold shadow-sm transition-transform active:scale-95"
                   >
                      <svg class="w-4 h-4 fill-current" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51a12.8 12.8 0 00-.57-.01c-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347zM12.001 22.024c-1.696 0-3.357-.456-4.814-1.319l-.345-.205-3.579.938.955-3.488-.225-.357A9.975 9.975 0 011.996 12C1.996 6.486 6.487 2 12.001 2c2.673 0 5.183 1.042 7.072 2.93A9.957 9.957 0 0122.006 12c0 5.513-4.49 10.024-10.005 10.024z"></path></svg>
                      WhatsApp
                   </button>
                   <div v-if="!family.representative_phone" class="text-xs text-slate-400 dark:text-slate-500 mt-2">Sin teléfono</div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      
    </main>
  </div>
</template>

<style scoped>
/* Ensure layout inherits smoothly */
</style>
