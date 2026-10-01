<template>
  <div class="p-4 sm:p-6 lg:p-8 max-w-4xl mx-auto space-y-6">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <router-link 
        to="/intelligence/cockpit"
        class="inline-flex items-center text-xs font-semibold text-slate-500 hover:text-indigo-600 transition"
      >
        <ArrowLeft class="w-4 h-4 mr-1" />
        Volver al Cockpit
      </router-link>

      <button 
        @click="printPassport"
        :disabled="isLoading || !!loadError"
        class="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-xl border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-xs font-semibold text-slate-700 dark:text-slate-300 transition"
      >
        <Printer class="w-3.5 h-3.5" />
        <span>Imprimir Pasaporte</span>
      </button>
    </div>

    <div v-if="isLoading" class="text-center py-16 text-sm text-slate-500">
      Cargando pasaporte de aprendizaje...
    </div>

    <div v-else-if="loadError" class="text-center py-16 px-6 rounded-3xl border border-rose-200 dark:border-rose-900 bg-rose-50 dark:bg-rose-950/20">
      <p class="font-semibold text-rose-800 dark:text-rose-200">No se pudo cargar el pasaporte</p>
      <p class="text-sm text-rose-700 dark:text-rose-300 mt-1">{{ loadError }}</p>
    </div>

    <!-- Main Passport Document Card -->
    <div v-else class="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200 dark:border-slate-800 shadow-xl overflow-hidden">
      <!-- Top Passport Header Ribbon -->
      <div class="bg-gradient-to-r from-indigo-900 via-indigo-800 to-purple-900 text-white p-6 sm:p-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center space-x-4">
            <div class="w-14 h-14 rounded-2xl bg-white/10 backdrop-blur border border-white/20 flex items-center justify-center font-black text-2xl shadow-lg">
              {{ studentData.name.charAt(0) }}
            </div>
            <div>
              <span class="text-xs font-semibold uppercase tracking-widest text-indigo-300">
                Pasaporte de Aprendizaje • LOGREVA
              </span>
              <h1 class="text-xl sm:text-2xl font-black">{{ studentData.name }}</h1>
              <p class="text-xs sm:text-sm text-indigo-200 mt-0.5">
                Curso: {{ studentData.courseName }}
              </p>
            </div>
          </div>

          <div class="bg-white/10 backdrop-blur rounded-2xl px-4 py-2.5 border border-white/15 text-center sm:text-right shrink-0">
            <span class="text-xs text-indigo-200 font-medium block">Estado Global</span>
            <span class="text-sm font-bold text-emerald-300 flex items-center justify-center sm:justify-end space-x-1 mt-0.5">
              <CheckCircle2 class="w-4 h-4" />
              <span>{{ globalStatus }}</span>
            </span>
          </div>
        </div>
      </div>

      <!-- Passport Content Body -->
      <div class="p-6 sm:p-8 space-y-8">
        <!-- 1. QUÉ PUEDE HACER (COMPETENCIAS DOMINADAS) -->
        <div class="space-y-3">
          <div class="flex items-center space-x-2 text-emerald-600 dark:text-emerald-400">
            <Award class="w-5 h-5" />
            <h2 class="text-base sm:text-lg font-bold">1. Lo que el estudiante ya domina con seguridad</h2>
          </div>
          <p class="text-xs text-slate-500">
            Habilidades demostradas de forma constante en diversas evaluaciones diagnósticas y prácticas.
          </p>

          <div v-if="studentData.mastered.length > 0" class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-2">
            <div 
              v-for="item in studentData.mastered"
              :key="item.code"
              class="p-4 rounded-2xl bg-emerald-50/60 dark:bg-emerald-950/20 border border-emerald-200/70 dark:border-emerald-900/40 space-y-1"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-mono font-bold text-emerald-700 dark:text-emerald-300">{{ item.code }}</span>
                <span class="text-xs font-bold px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-900 text-emerald-800 dark:text-emerald-200">Dominado</span>
              </div>
              <h3 class="text-sm font-bold text-slate-900 dark:text-white">{{ item.name }}</h3>
              <p class="text-xs text-slate-600 dark:text-slate-300">{{ item.desc }}</p>
            </div>
          </div>
          <div v-else class="p-6 rounded-2xl bg-slate-50 dark:bg-slate-800/40 border border-dashed border-slate-200 dark:border-slate-700 text-center py-6">
            <p class="text-xs text-slate-500 font-medium">Aún no se registran evaluaciones con nivel de dominio consolidado para este período.</p>
          </div>
        </div>

        <!-- 2. QUÉ ESTÁ APRENDIENDO AHORA (EN DESARROLLO) -->
        <div class="space-y-3">
          <div class="flex items-center space-x-2 text-indigo-600 dark:text-indigo-400">
            <BookOpen class="w-5 h-5" />
            <h2 class="text-base sm:text-lg font-bold">2. En qué está avanzando activamente en el aula</h2>
          </div>
          <p class="text-xs text-slate-500">
            Temas que el docente está guiando paso a paso para consolidar su autonomía.
          </p>

          <div v-if="studentData.inProgress.length > 0" class="space-y-3">
            <div 
              v-for="item in studentData.inProgress"
              :key="item.code"
              class="p-4 rounded-2xl bg-indigo-50/50 dark:bg-indigo-950/20 border border-indigo-200/60 dark:border-indigo-900/40 flex items-start space-x-3"
            >
              <div class="w-8 h-8 rounded-xl bg-indigo-100 dark:bg-indigo-900/60 text-indigo-600 dark:text-indigo-400 flex items-center justify-center font-bold text-sm shrink-0 mt-0.5">
                ✏️
              </div>
              <div class="flex-1">
                <div class="flex items-center justify-between">
                  <h3 class="text-sm font-bold text-slate-900 dark:text-white">{{ item.name }}</h3>
                  <span class="text-xs font-bold text-indigo-600 dark:text-indigo-400">En Consolidación</span>
                </div>
                <p class="text-xs text-slate-600 dark:text-slate-300 mt-0.5">{{ item.desc }}</p>
              </div>
            </div>
          </div>
          <div v-else class="p-6 rounded-2xl bg-slate-50 dark:bg-slate-800/40 border border-dashed border-slate-200 dark:border-slate-700 text-center py-6">
            <p class="text-xs text-slate-500 font-medium">No se detectaron brechas activas ni temas pendientes de nivelación.</p>
          </div>
        </div>

        <!-- 3. QUÉ PUEDE PRACTICAR EN CASA (CONSEJOS PARA LA FAMILIA) -->
        <div class="p-5 rounded-2xl bg-amber-50/70 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-900/40 space-y-3">
          <div class="flex items-center space-x-2 text-amber-700 dark:text-amber-400 font-bold">
            <HeartHandshake class="w-5 h-5" />
            <h2 class="text-base sm:text-lg">3. ¿Cómo apoyar desde casa esta semana?</h2>
          </div>
          <ul class="text-xs sm:text-sm text-amber-900 dark:text-amber-200 space-y-2 list-disc pl-5">
            <li v-for="recommendation in homeSupportRecommendations" :key="recommendation.title">
              <strong>{{ recommendation.title }}:</strong> {{ recommendation.text }}
            </li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, reactive, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '../../../stores/auth'
import { intelligenceService } from '../services/intelligenceService'
import { 
  ArrowLeft, 
  Printer, 
  Award, 
  BookOpen, 
  HeartHandshake, 
  CheckCircle2
} from 'lucide-vue-next'

const route = useRoute()
const authStore = useAuthStore()
const isLoading = ref(true)
const loadError = ref('')

const studentData = reactive({
  name: '',
  courseName: 'Sin curso asignado',
  mastered: [],
  inProgress: [],
  resolvedGaps: [],
  activeGaps: []
})

const globalStatus = computed(() => {
  if (studentData.activeGaps.length > 0) return 'En acompañamiento'
  if (studentData.mastered.length > 0 || studentData.resolvedGaps.length > 0) return 'Progreso registrado'
  return 'Sin evidencia suficiente'
})

const homeSupportRecommendations = computed(() => {
  if (studentData.inProgress.length > 0) {
    return studentData.inProgress.slice(0, 3).map(item => ({
      title: item.name,
      text: 'Pídele que explique con sus propias palabras lo aprendido y revise junto a un adulto la retroalimentación enviada por el docente.'
    }))
  }

  if (studentData.mastered.length > 0) {
    return [{
      title: 'Mantener lo aprendido',
      text: `Invítale a explicar cómo aplica ${studentData.mastered[0].name} en una situación cotidiana y reconoce el proceso que utilizó.`
    }]
  }

  return [{
    title: 'Coordinar con el docente',
    text: 'Consulta qué competencia conviene practicar esta semana; todavía no existe evidencia suficiente para recomendar una actividad específica.'
  }]
})

async function loadPassportData() {
  const studentId = route.params.studentId
  const sId = authStore.activeSchoolId
  if (!studentId || !sId) {
    loadError.value = 'Falta seleccionar un estudiante o una institución activa.'
    isLoading.value = false
    return
  }

  isLoading.value = true
  loadError.value = ''
  try {
    const data = await intelligenceService.fetchStudentLongitudinalPassport({
      studentId,
      schoolId: sId
    })

    if (data?.student?.fullName) {
      studentData.name = data.student.fullName
      studentData.courseName = data.student.courseName || 'Curso Asignado'
    }

    if (Array.isArray(data?.mastery_records)) {
      studentData.mastered = data?.mastery_records
        .filter(m => ['MASTERED', 'COMPETENT', 'mastered'].includes(m.state))
        .map(m => ({
          code: m.competency_code,
          name: m.competency_name,
          desc: `Demostró dominio en evaluaciones formativas (Nivel: ${Math.round(m.mastery_score * 100)}%).`
        }))

      studentData.inProgress = data?.mastery_records
        .filter(m => !['MASTERED', 'COMPETENT', 'mastered'].includes(m.state))
        .map(m => ({
          code: m.competency_code,
          name: m.competency_name,
          desc: `En proceso de consolidación en aula (Nivel: ${Math.round(m.mastery_score * 100)}%).`
        }))
    }

    if (Array.isArray(data?.resolved_gaps)) {
      studentData.resolvedGaps = data?.resolved_gaps
    }
    if (Array.isArray(data?.active_gaps)) {
      studentData.activeGaps = data.active_gaps
    }
  } catch (err) {
    console.warn('Error cargando pasaporte longitudinal:', err)
    loadError.value = 'Revisa tu conexión o tus permisos e inténtalo nuevamente.'
  } finally {
    isLoading.value = false
  }
}

function printPassport() {
  window.print()
}

onMounted(() => {
  loadPassportData()
})
</script>
