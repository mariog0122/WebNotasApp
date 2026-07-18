<script setup>
import { inject } from 'vue'
import { useRouter } from 'vue-router'
import { gradesPageInjectionKey } from '../../composables/useGradesPage'
import SkeletonTable from '../ui/SkeletonTable.vue'

const router = useRouter()
const gp = inject(gradesPageInjectionKey)
if (!gp) throw new Error('gradesPageInjectionKey no provisto')

const gradeColorClass = (val) => {
  if (val === null || val === undefined || isNaN(val)) return ''
  const n = Number(val)
  if (n >= 9) return 'text-emerald-400 drop-shadow-[0_0_4px_rgba(52,211,153,0.5)]'
  if (n >= 7) return 'text-teal-300'
  if (n >= 5) return 'text-amber-400'
  return 'text-rose-400 drop-shadow-[0_0_4px_rgba(251,113,133,0.5)]'
}

const gradeBgClass = (val) => {
  if (val === null || val === undefined || isNaN(val)) return 'bg-slate-700'
  const n = Number(val)
  if (n >= 9) return 'bg-emerald-900/40'
  if (n >= 7) return 'bg-teal-900/30'
  if (n >= 5) return 'bg-amber-900/30'
  return 'bg-rose-900/40'
}
</script>

<template>
  <div>
    <div v-if="gp.selectedCourse && gp.subjects.length > 0" class="space-y-4">
      <div
        v-for="subject in gp.subjects"
        :key="subject.course_subject_id"
        class="rounded-xl border border-slate-200 bg-slate-900 shadow-md overflow-hidden ring-1 ring-black/5"
      >
        <button
          type="button"
          class="w-full px-4 py-4 flex justify-between items-center text-left cursor-pointer hover:bg-slate-800/90 transition-colors border-l-4 border-teal-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-teal-400 bg-slate-900"
          @click="gp.openGradeSheet(subject)"
        >
          <div>
            <h3 class="text-lg font-semibold text-white">{{ subject.name }}</h3>
            <span class="text-xs text-slate-400">Clic para desplegar el acta</span>
          </div>
          <div>
            <span v-if="gp.activeSubjectId === subject.course_subject_id" class="text-teal-300 text-sm font-medium">
              Ocultar acta
            </span>
            <span v-else class="text-slate-400 text-sm font-medium">
              Ver acta
            </span>
          </div>
        </button>

        <div
          v-if="gp.activeSubjectId === subject.course_subject_id"
          class="border-t border-slate-700 p-4 overflow-x-auto bg-slate-950/80 animate-fade-in-down print-page"
        >
          <div v-if="gp.loadingGrades" class="py-4">
            <SkeletonTable :rows="8" :columns="8" class="border-0" />
          </div>

          <div v-else>
            <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3 mb-4 no-print">
              <div class="text-sm text-slate-400">
                Estudiantes en acta: <span class="text-white font-bold tabular-nums">{{ gp.students.length }}</span>
              </div>
              <div class="flex flex-wrap items-center gap-3">
                <button
                  type="button"
                  class="rounded-lg border border-slate-600 bg-slate-800 px-3 py-2 text-xs font-semibold text-white hover:bg-slate-700"
                  @click="gp.handlePrint"
                >
                  Imprimir
                </button>
                <button
                  type="button"
                  class="inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow hover:bg-emerald-500 disabled:cursor-not-allowed disabled:opacity-60"
                  :disabled="gp.saving"
                  @click="gp.saveCurrentGrades"
                >
                  <span v-if="gp.saving" class="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" aria-hidden="true" />
                  {{ gp.saving ? 'Guardando…' : 'Guardar cambios' }}
                </button>
              </div>
            </div>

            <div class="rounded-lg border border-slate-700 bg-slate-900/80 p-4 mb-4">
              <div class="flex items-center gap-4 print-header">
                <div class="h-12 w-12 rounded-lg border border-slate-700 bg-slate-950 overflow-hidden flex items-center justify-center">
                  <img
                    v-if="gp.institutionLogoUrl"
                    :src="gp.institutionLogoUrl"
                    alt="Logo institución"
                    class="h-full w-full object-contain p-1"
                  />
                  <span v-else class="text-xs text-slate-500">Logo</span>
                </div>
                <div>
                  <div class="text-lg font-semibold text-white">{{ gp.institutionName || 'Institución' }}</div>
                  <div class="text-xs text-slate-400 print-subtitle">
                    ACTA DE CALIFICACIONES<br />
                    Curso: {{ gp.getCourseName() }} &nbsp;|&nbsp; Periodo: {{ gp.getQuarterName() }} &nbsp;|&nbsp; Materia:
                    {{ gp.activeSubject?.name }}
                  </div>
                </div>
              </div>
            </div>

            <div v-if="gp.students.length === 0" class="text-center py-6 text-slate-400 bg-slate-900 rounded-lg border border-slate-700">
              No hay estudiantes en este curso. Agrega estudiantes para generar el acta.
            </div>

            <div
              v-else-if="!gp.isQualitativeCourse && gp.gradeDefinitions.length === 0"
              class="text-center py-6 text-slate-400 bg-slate-900 rounded-lg border border-slate-700"
            >
              No hay columnas de calificación para este periodo.
            </div>

            <div
              v-else-if="gp.isQualitativeCourse"
              class="min-w-full bg-slate-900 border border-slate-700 rounded-lg overflow-hidden flex flex-col"
            >
              <div class="bg-slate-800 flex border-b border-slate-700">
                <div class="px-4 py-3 text-left text-xs font-medium text-slate-300 uppercase tracking-wider w-16">#</div>
                <div class="px-4 py-3 text-left text-xs font-medium text-slate-300 uppercase tracking-wider flex-1">Estudiante</div>
                <div class="px-4 py-3 text-left text-xs font-medium text-slate-300 uppercase tracking-wider w-[350px]">
                  Calificación cualitativa (MINEDUC)
                </div>
              </div>
              <RecycleScroller
                page-mode
                :items="gp.students"
                :item-size="56"
                key-field="id"
                v-slot="{ item: student, index: idx }"
              >
                <div class="flex items-center border-b border-slate-700/50 hover:bg-slate-800/50 transition-colors">
                  <div class="px-4 py-3 text-xs text-slate-400 tabular-nums w-16">
                    {{ idx + 1 }}
                  </div>
                  <div class="px-4 py-3 text-sm text-white font-normal text-left flex-1 truncate">{{ student.full_name }}</div>
                  <div class="px-4 py-2 w-[350px]">
                    <select
                      v-model="gp.qualitativeScores[student.id]"
                      class="w-full max-w-md rounded-md border border-slate-600 bg-slate-950 text-white text-sm px-3 py-2 focus:ring-2 focus:ring-teal-500 focus:border-teal-500"
                    >
                      <option value="">Seleccionar</option>
                      <option v-for="opt in gp.QUALITATIVE_OPTIONS" :key="opt.value" :value="opt.value">
                        {{ opt.label }}
                      </option>
                    </select>
                  </div>
                </div>
              </RecycleScroller>
            </div>

            <div v-else class="overflow-x-auto border border-slate-700 rounded-lg shadow-lg bg-slate-950 custom-scrollbar flex flex-col h-[600px]">
              <!-- CABECERAS FLEX -->
              <div class="min-w-max flex flex-col bg-slate-800 z-30 sticky top-0 border-b-2 border-slate-700">
                <!-- Fila Superior: Grupos -->
                <div class="flex text-xs text-white uppercase font-semibold">
                  <div class="p-2 border-r border-slate-700 sticky left-0 bg-slate-800 z-40 w-10 shrink-0 text-center shadow-[2px_0_4px_rgba(0,0,0,0.1)]">#</div>
                  <div class="p-2 border-r border-slate-700 sticky left-10 bg-slate-800 z-40 w-64 shrink-0 shadow-[2px_0_4px_rgba(0,0,0,0.1)]">Estudiante</div>
                  <div
                    class="p-2 border-r border-slate-700 bg-blue-900/50 text-center"
                    :style="{ width: (gp.gradeDefinitions.filter(d => d.category === 'INDIVIDUAL').length * 100) + 'px' }"
                  >
                    Individual
                  </div>
                  <div class="p-2 border-r border-slate-700 bg-blue-800/50 w-16 shrink-0 text-center">AVG</div>
                  <div
                    class="p-2 border-r border-slate-700 bg-purple-900/50 text-center"
                    :style="{ width: (gp.gradeDefinitions.filter(d => d.category === 'GRUPAL').length * 100) + 'px' }"
                  >
                    Grupal
                  </div>
                  <div class="p-2 border-r border-slate-700 bg-purple-800/50 w-16 shrink-0 text-center">AVG</div>
                  <template v-if="gp.gradeDefinitions.some(d => d.category === 'REFUERZO')">
                    <div
                      class="p-2 border-r border-slate-700 bg-amber-900/40 text-center"
                      :style="{ width: (gp.gradeDefinitions.filter(d => d.category === 'REFUERZO').length * 100) + 'px' }"
                    >
                      Refuerzo
                    </div>
                  </template>
                  <div class="p-2 border-r border-slate-700 bg-slate-700 w-16 shrink-0 text-center">70%</div>
                  <div
                    class="p-2 border-r border-slate-700 bg-emerald-900/50 text-center"
                    :style="{ width: (gp.gradeDefinitions.filter(d => d.category === 'SUMATIVA').length * 100) + 'px' }"
                  >
                    Sumativa (30%)
                  </div>
                  <div class="p-2 border-r border-slate-700 bg-emerald-800/50 w-16 shrink-0 text-center">AVG</div>
                  <div class="p-2 bg-slate-600 w-20 shrink-0 text-center">100%</div>
                </div>

                <!-- Fila Inferior: Columnas Específicas -->
                <div class="flex text-xs text-slate-300">
                  <div class="p-2 border-r border-slate-700 sticky left-0 bg-slate-800 z-40 w-10 shrink-0 shadow-[2px_0_4px_rgba(0,0,0,0.1)]"></div>
                  <div class="p-2 border-r border-slate-700 sticky left-10 bg-slate-800 z-40 w-64 shrink-0 shadow-[2px_0_4px_rgba(0,0,0,0.1)]"></div>
                  <div
                    v-for="def in gp.gradeDefinitions.filter(d => d.category === 'INDIVIDUAL')"
                    :key="'h'+def.id"
                    class="p-1 border-r border-slate-700 text-center truncate cursor-pointer hover:bg-slate-700 w-[100px] shrink-0"
                    @click="gp.editHeader(def)"
                  >
                    {{ def.name }}
                  </div>
                  <div class="border-r border-slate-700 bg-slate-800 w-16 shrink-0 text-center py-1">Ind.</div>
                  <div
                    v-for="def in gp.gradeDefinitions.filter(d => d.category === 'GRUPAL')"
                    :key="'h2'+def.id"
                    class="p-1 border-r border-slate-700 text-center truncate cursor-pointer hover:bg-slate-700 w-[100px] shrink-0"
                    @click="gp.editHeader(def)"
                  >
                    {{ def.name }}
                  </div>
                  <div class="border-r border-slate-700 bg-slate-800 w-16 shrink-0 text-center py-1">Grup.</div>
                  <template v-if="gp.gradeDefinitions.some(d => d.category === 'REFUERZO')">
                    <div
                      v-for="def in gp.gradeDefinitions.filter(d => d.category === 'REFUERZO')"
                      :key="'h3'+def.id"
                      class="p-1 border-r border-slate-700 text-center truncate cursor-pointer hover:bg-slate-700 w-[100px] shrink-0"
                      @click="gp.editHeader(def)"
                    >
                      {{ def.name }}
                    </div>
                  </template>
                  <div class="border-r border-slate-700 bg-slate-800 w-16 shrink-0 text-center py-1">70%</div>
                  <div
                    v-for="def in gp.gradeDefinitions.filter(d => d.category === 'SUMATIVA')"
                    :key="'h4'+def.id"
                    class="p-1 border-r border-slate-700 text-center truncate cursor-pointer hover:bg-slate-700 w-[100px] shrink-0"
                    @click="gp.editHeader(def)"
                  >
                    {{ def.name }}
                  </div>
                  <div class="border-r border-slate-700 bg-slate-800 w-16 shrink-0 text-center py-1">AVG</div>
                  <div class="bg-slate-800 w-20 shrink-0 text-center py-1">100%</div>
                </div>
              </div>

              <!-- CUERPO VIRTUALIZADO -->
              <RecycleScroller
                class="min-w-max flex-1"
                :items="gp.students"
                :item-size="44"
                key-field="id"
                v-slot="{ item: student, index: idx }"
              >
                <div class="flex items-center hover:bg-slate-800/50 transition-colors border-b border-slate-700 group h-[44px]">
                  <div class="p-2 border-r border-slate-700 text-center sticky left-0 bg-slate-900 group-hover:bg-slate-800 z-10 font-mono text-xs text-slate-500 w-10 shrink-0 shadow-[2px_0_4px_rgba(0,0,0,0.1)] h-full flex items-center justify-center">
                    {{ idx + 1 }}
                  </div>
                  <div class="p-2 border-r border-slate-700 sticky left-10 bg-slate-900 group-hover:bg-slate-800 z-10 font-medium text-slate-200 w-64 shrink-0 shadow-[2px_0_4px_rgba(0,0,0,0.1)] h-full flex items-center justify-between">
                    <span class="truncate pr-1 text-sm">{{ student.full_name }}</span>
                    <div class="flex items-center gap-1 no-print">
                      <button
                        type="button"
                        class="text-blue-400 hover:text-blue-300 p-1 rounded-full hover:bg-blue-400/10 transition-colors"
                        @click="router.push({ name: 'reports', query: { studentId: student.id, courseId: gp.selectedCourse, quarterId: gp.selectedQuarter } })"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                      </button>
                      <button
                        v-if="((gp.studentAveragesMap[student.id]?.total ?? null) !== null ? gp.studentAveragesMap[student.id].total < 7 : (gp.studentAveragesMap[student.id]?.formative ?? null) !== null ? gp.studentAveragesMap[student.id].formative < 7 : false)"
                        type="button"
                        class="text-emerald-500 hover:text-emerald-400 p-1 rounded-full hover:bg-emerald-500/10 transition-colors"
                        @click="gp.sendStudentWhatsapp(student)"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="currentColor" viewBox="0 0 448 512">
                          <path d="M380.9 97.1C339 55.1 283.2 32 223.9 32c-122.4 0-222 99.6-222 222 0 39.1 10.2 77.3 29.6 111L0 480l117.7-30.9c32.7 17.8 69.7 27.2 106.2 27.2h.1c122.3 0 222-99.6 222-222 0-59.3-23-115.1-65.1-157.1zM223.9 445.8c-33.1 0-65.7-8.9-94.1-25.7l-6.7-4-69.8 18.3L72 365.9l-4.4-7c-18.5-29.4-28.2-63.3-28.2-98.2 0-101.7 82.8-184.5 184.6-184.5 49.3 0 95.6 19.2 130.4 54.1 34.8 34.9 56.2 81.2 56.1 130.5 0 101.8-82.7 184.6-184.5 184.7zm100.6-137.5c-5.5-2.7-32.6-16.1-37.7-17.9-5.1-1.8-8.8-2.7-12.5 2.7-3.7 5.5-14.3 17.9-17.6 21.6-3.2 3.7-6.5 4.1-12 1.4-5.5-2.7-23.2-8.5-44.2-27.2-16.4-14.6-27.4-32.7-30.6-38.2-3.2-5.5-.3-8.5 2.4-11.2 2.5-2.6 5.5-6.5 8.2-9.7 2.7-3.2 3.7-5.5 5.5-9.2 1.8-3.7 .9-6.9-.5-9.7-1.4-2.7-12.5-30.1-17.1-41.2-4.5-10.8-9.1-9.3-12.5-9.5-3.2-.2-6.9-.2-10.6-.2-3.7 0-9.7 1.4-14.8 6.9-5.1 5.6-19.4 19-19.4 46.3 0 27.3 19.9 53.7 22.6 57.4 2.8 3.7 39.1 59.7 94.8 83.8 13.2 5.7 23.5 9.2 31.6 11.8 13.3 4.2 25.4 3.6 35 2.2 10.7-1.6 32.6-13.3 37.2-26.2 4.6-12.9 4.6-24 3.2-26.2-1.4-2.2-5.1-3.6-10.6-6.3z"/>
                        </svg>
                      </button>
                    </div>
                  </div>
                  <!-- INDIVIDUAL INPUTS -->
                  <div
                    v-for="def in gp.gradeDefinitions.filter(d => d.category === 'INDIVIDUAL')"
                    :key="'c'+def.id"
                    class="border-r border-slate-800 w-[100px] shrink-0 h-full flex items-center"
                  >
                    <input
                      type="number" step="0.01" min="0" max="10"
                      class="w-full bg-transparent text-center text-sm px-1 focus:bg-blue-900/30 focus:outline-none focus:ring-1 focus:ring-blue-500 text-blue-200 h-full"
                      placeholder="-" :value="gp.grades[student.id][def.id]"
                      @input="(e) => gp.onGradeInput(student.id, def.id, e)"
                    />
                  </div>
                  <div class="bg-slate-800/30 text-center text-blue-300 font-bold border-r border-slate-700 text-sm tabular-nums w-16 shrink-0 h-full flex items-center justify-center">
                    {{ gp.formatGrade(gp.studentAveragesMap[student.id]?.avgIndividual) }}
                  </div>
                  <!-- GRUPAL INPUTS -->
                  <div
                    v-for="def in gp.gradeDefinitions.filter(d => d.category === 'GRUPAL')"
                    :key="'c2'+def.id"
                    class="border-r border-slate-800 w-[100px] shrink-0 h-full flex items-center"
                  >
                    <input
                      type="number" step="0.01" min="0" max="10"
                      class="w-full bg-transparent text-center text-sm px-1 focus:bg-purple-900/30 focus:outline-none focus:ring-1 focus:ring-purple-500 text-purple-200 h-full"
                      placeholder="-" :value="gp.grades[student.id][def.id]"
                      @input="(e) => gp.onGradeInput(student.id, def.id, e)"
                    />
                  </div>
                  <div class="bg-slate-800/30 text-center text-purple-300 font-bold border-r border-slate-700 text-sm tabular-nums w-16 shrink-0 h-full flex items-center justify-center">
                    {{ gp.formatGrade(gp.studentAveragesMap[student.id]?.avgGroup) }}
                  </div>
                  <!-- REFUERZO INPUTS -->
                  <template v-if="gp.gradeDefinitions.some(d => d.category === 'REFUERZO')">
                    <div
                      v-for="def in gp.gradeDefinitions.filter(d => d.category === 'REFUERZO')"
                      :key="'c3'+def.id"
                      class="border-r border-slate-800 w-[100px] shrink-0 h-full flex items-center"
                    >
                      <input
                        type="number" step="0.01" min="0" max="10"
                        class="w-full bg-transparent text-center text-sm px-1 focus:bg-amber-900/30 focus:outline-none focus:ring-1 focus:ring-amber-500 text-amber-100 h-full"
                        placeholder="-" :value="gp.grades[student.id][def.id]"
                        @input="(e) => gp.onGradeInput(student.id, def.id, e)"
                      />
                    </div>
                  </template>
                  <!-- 70% FORMATIVE -->
                  <div class="bg-slate-900 border-r border-slate-700 font-bold text-center tabular-nums w-16 shrink-0 h-full flex items-center justify-center" :class="gradeColorClass(gp.studentAveragesMap[student.id]?.weightedFormative)">
                    {{ gp.formatGrade(gp.studentAveragesMap[student.id]?.weightedFormative) }}
                  </div>
                  <!-- SUMATIVA INPUTS -->
                  <div
                    v-for="def in gp.gradeDefinitions.filter(d => d.category === 'SUMATIVA')"
                    :key="'c4'+def.id"
                    class="border-r border-slate-800 w-[100px] shrink-0 h-full flex items-center"
                  >
                    <input
                      type="number" step="0.01" min="0" max="10"
                      class="w-full bg-transparent text-center text-sm px-1 focus:bg-emerald-900/30 focus:outline-none focus:ring-1 focus:ring-emerald-500 text-emerald-100 disabled:text-slate-500 h-full"
                      placeholder="-"
                      :disabled="def.name.toLowerCase().includes('proyecto') && gp.projectSubjects.has(gp.activeSubject?.subject_id)"
                      :value="def.name.toLowerCase().includes('proyecto') && gp.projectSubjects.has(gp.activeSubject?.subject_id) ? gp.getProjectValue(student.id, gp.activeSubject?.subject_id) ?? '' : gp.grades[student.id][def.id]"
                      @input="(e) => { if (!def.name.toLowerCase().includes('proyecto') || !gp.projectSubjects.has(gp.activeSubject?.subject_id)) gp.onGradeInput(student.id, def.id, e) }"
                    />
                  </div>
                  <div class="bg-slate-800/30 text-center font-bold border-r border-slate-700 text-sm tabular-nums w-16 shrink-0 h-full flex items-center justify-center" :class="gradeColorClass(gp.studentAveragesMap[student.id]?.avgSum)">
                    {{ gp.formatGrade(gp.studentAveragesMap[student.id]?.avgSum) }}
                  </div>
                  <!-- 100% TOTAL -->
                  <div class="text-center font-bold text-base tabular-nums transition-colors w-20 shrink-0 h-full flex items-center justify-center" :class="[gradeBgClass(gp.studentAveragesMap[student.id]?.total), gradeColorClass(gp.studentAveragesMap[student.id]?.total)]">
                    {{ gp.formatGrade(gp.studentAveragesMap[student.id]?.total) }}
                  </div>
                </div>
              </RecycleScroller>

              <!-- TFOOT PROMEDIOS -->
              <div class="min-w-max flex text-xs text-white bg-slate-800/80 font-bold border-t-2 border-slate-600 sticky bottom-0 z-30">
                <div class="p-2 border-r border-slate-700 sticky left-0 bg-slate-800 z-40 text-right shadow-[2px_0_4px_rgba(0,0,0,0.1)] w-10 shrink-0"></div>
                <div class="p-2 border-r border-slate-700 sticky left-10 bg-slate-800 z-40 text-right shadow-[2px_0_4px_rgba(0,0,0,0.1)] w-64 shrink-0 flex items-center justify-end">PROMEDIO DE AULA</div>
                <div
                  v-for="def in gp.gradeDefinitions.filter(d => d.category === 'INDIVIDUAL')"
                  :key="'f'+def.id"
                  class="p-2 border-r border-slate-700 text-center text-blue-200 tabular-nums w-[100px] shrink-0"
                >
                  {{ gp.formatGrade(gp.getClassroomAverages()[def.id]) }}
                </div>
                <div class="p-2 border-r border-slate-700 text-center text-blue-300 bg-blue-900/20 tabular-nums w-16 shrink-0">
                  {{ gp.formatGrade(gp.getClassroomAverages().avgIndividual) }}
                </div>
                <div
                  v-for="def in gp.gradeDefinitions.filter(d => d.category === 'GRUPAL')"
                  :key="'f2'+def.id"
                  class="p-2 border-r border-slate-700 text-center text-purple-200 tabular-nums w-[100px] shrink-0"
                >
                  {{ gp.formatGrade(gp.getClassroomAverages()[def.id]) }}
                </div>
                <div class="p-2 border-r border-slate-700 text-center text-purple-300 bg-purple-900/20 tabular-nums w-16 shrink-0">
                  {{ gp.formatGrade(gp.getClassroomAverages().avgGroup) }}
                </div>
                <template v-if="gp.gradeDefinitions.some(d => d.category === 'REFUERZO')">
                  <div
                    v-for="def in gp.gradeDefinitions.filter(d => d.category === 'REFUERZO')"
                    :key="'f3'+def.id"
                    class="p-2 border-r border-slate-700 text-center text-amber-100 tabular-nums w-[100px] shrink-0"
                  >
                    {{ gp.formatGrade(gp.getClassroomAverages()[def.id]) }}
                  </div>
                </template>
                <div class="p-2 border-r border-slate-700 text-center bg-slate-800 text-white tabular-nums w-16 shrink-0">-</div>
                <div
                  v-for="def in gp.gradeDefinitions.filter(d => d.category === 'SUMATIVA')"
                  :key="'f4'+def.id"
                  class="p-2 border-r border-slate-700 text-center text-emerald-100 tabular-nums w-[100px] shrink-0"
                >
                  {{ gp.formatGrade(gp.getClassroomAverages()[def.id]) }}
                </div>
                <div class="p-2 border-r border-slate-700 text-center text-emerald-300 bg-emerald-900/20 tabular-nums w-16 shrink-0">
                  {{ gp.formatGrade(gp.getClassroomAverages().avgSum) }}
                </div>
                <div class="p-2 text-center text-white bg-slate-700 text-base tabular-nums w-20 shrink-0 flex items-center justify-center">
                  {{ gp.formatGrade(gp.getClassroomAverages().total) }}
                </div>
              </div>
            </div>



            <div class="mt-6 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-6 print-footer">
              <div class="text-sm text-slate-300">
                Fecha: <span class="font-semibold text-white">{{ new Date().toLocaleDateString('es-EC') }}</span>
              </div>
              <div class="text-xs text-slate-400 print-page-number">
                Página <span class="print-page-current"></span> de <span class="print-page-total"></span>
              </div>
              <div class="flex flex-1 gap-6">
                <div class="flex-1">
                  <div class="border-t border-slate-600 pt-2 text-xs text-slate-400 text-center">
                    {{ gp.institutionTutorName || 'Docente' }}
                  </div>
                </div>
                <div class="flex-1">
                  <div class="border-t border-slate-600 pt-2 text-xs text-slate-400 text-center">
                    {{ gp.institutionRectorName || 'Rector/a' }}
                  </div>
                </div>
                <div class="flex-1">
                  <div class="border-t border-slate-600 pt-2 text-xs text-slate-400 text-center">Secretario/a</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div
      v-else-if="gp.selectedCourse"
      class="text-center py-12 text-slate-500 bg-slate-50 rounded-xl border border-dashed border-slate-200"
    >
      Este curso no tiene asignaturas. Asigna materias en <strong class="text-slate-700">Cursos</strong>.
    </div>

    <div v-else class="text-center py-12 text-slate-500 mt-6 rounded-xl border border-dashed border-slate-200 bg-slate-50/50">
      Selecciona un curso y un periodo para comenzar.
    </div>
  </div>
</template>

<style scoped>
@media print {
  @page {
    size: A4 landscape;
    margin: 12mm;
  }

  button,
  .no-print {
    display: none !important;
  }

  .bg-slate-900,
  .bg-slate-800,
  .bg-slate-700,
  .bg-gray-900,
  .bg-gray-800,
  .bg-gray-700 {
    background: white !important;
  }

  .text-white,
  .text-slate-400,
  .text-slate-300,
  .text-slate-200,
  .text-slate-500,
  .text-gray-400,
  .text-gray-300,
  .text-gray-200,
  .text-gray-500 {
    color: #111827 !important;
  }

  .border-slate-700,
  .border-slate-600,
  .border-gray-700,
  .border-gray-600 {
    border-color: #e5e7eb !important;
  }

  table {
    font-size: 10px;
    border-collapse: collapse !important;
  }

  .shadow,
  .shadow-lg,
  .shadow-md,
  .shadow-sm,
  .shadow-2xl {
    box-shadow: none !important;
  }

  .rounded,
  .rounded-lg,
  .rounded-md,
  .rounded-xl {
    border-radius: 0 !important;
  }

  th,
  td {
    border: 1px solid #d1d5db !important;
    padding: 4px !important;
  }

  input {
    color: #111827 !important;
    background: transparent !important;
    border: none !important;
    box-shadow: none !important;
    padding: 0 !important;
  }

  .sticky {
    position: static !important;
    left: auto !important;
    z-index: auto !important;
  }

  .overflow-x-auto {
    overflow: visible !important;
  }

  .border-l-4 {
    border-left-width: 1px !important;
  }

  .text-amber-200,
  .text-yellow-500,
  .text-yellow-400,
  .text-blue-200,
  .text-purple-200,
  .text-green-200,
  .text-emerald-200,
  .text-indigo-400,
  .text-red-400 {
    color: #111827 !important;
  }

  .print-page {
    page-break-after: always;
    break-after: page;
  }

  .print-page:last-of-type {
    page-break-after: auto;
    break-after: auto;
  }

  .print-header {
    justify-content: center !important;
    text-align: center !important;
  }

  .print-header > div:last-child {
    text-align: center !important;
  }

  .print-subtitle {
    margin-top: 4px !important;
    line-height: 1.3 !important;
  }

  .print-footer {
    margin-top: 12mm !important;
  }

  .print-page-number {
    display: inline-block !important;
  }

  .print-page-number .print-page-current:before {
    content: counter(page);
  }

  .print-page-number .print-page-total:before {
    content: counter(pages);
  }

  table th,
  table td {
    vertical-align: middle !important;
  }

  table .w-20,
  table .w-12,
  .w-16,
  table .w-64 {
    width: auto !important;
  }
}

.overflow-x-auto.custom-scrollbar::-webkit-scrollbar {
  height: 12px;
}
.overflow-x-auto.custom-scrollbar::-webkit-scrollbar-track {
  background: #0f172a;
}
.overflow-x-auto.custom-scrollbar::-webkit-scrollbar-thumb {
  background: #475569;
  border-radius: 6px;
}
.overflow-x-auto.custom-scrollbar::-webkit-scrollbar-thumb:hover {
  background: #64748b;
}

table input {
  min-width: 3rem;
}
</style>
