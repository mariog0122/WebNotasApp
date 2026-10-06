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

      <span class="text-xs font-medium px-2.5 py-1 rounded-full bg-indigo-50 dark:bg-indigo-950/40 text-indigo-600 dark:text-indigo-400 border border-indigo-200/50 dark:border-indigo-800">
        Evaluación Formativa Adaptativa
      </span>
    </div>

    <!-- Active Diagnostic Session Card -->
    <div v-if="store.currentSession.isActive && store.currentDiagnosticItem" class="bg-white dark:bg-slate-900 rounded-3xl p-6 sm:p-8 border border-slate-200 dark:border-slate-800 shadow-xl space-y-6">
      <!-- Progress Bar -->
      <div>
        <div class="flex justify-between text-xs font-semibold text-slate-500 mb-2">
          <span>Pregunta {{ store.currentSession.currentIndex + 1 }} de {{ store.currentSession.items.length }}</span>
          <span>{{ Math.round(((store.currentSession.currentIndex + 1) / store.currentSession.items.length) * 100) }}% completado</span>
        </div>
        <div class="w-full h-2 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden">
          <div 
            class="h-full bg-indigo-600 rounded-full transition-all duration-300"
            :style="{ width: `${((store.currentSession.currentIndex + 1) / store.currentSession.items.length) * 100}%` }"
          ></div>
        </div>
      </div>

      <!-- Question Stem -->
      <div class="space-y-3">
        <span class="text-xs font-bold uppercase tracking-wider text-indigo-600 dark:text-indigo-400">
          {{ store.currentDiagnosticItem.subject_area }} • {{ store.currentDiagnosticItem.grade_level }}
        </span>
        <h2 class="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white leading-relaxed">
          {{ store.currentDiagnosticItem.stem }}
        </h2>
      </div>

      <!-- Options Grid -->
      <div class="space-y-3">
        <button
          v-for="opt in store.currentDiagnosticItem.options"
          :key="opt.key"
          @click="selectedOption = opt.key"
          :class="[
            'w-full text-left p-4 rounded-2xl border text-sm sm:text-base font-medium transition flex items-center space-x-3',
            selectedOption === opt.key 
              ? 'border-indigo-600 bg-indigo-50/70 dark:bg-indigo-950/40 text-indigo-900 dark:text-indigo-200 shadow-sm'
              : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/60 text-slate-800 dark:text-slate-200'
          ]"
        >
          <div 
            :class="[
              'w-8 h-8 rounded-xl flex items-center justify-center font-bold text-sm shrink-0',
              selectedOption === opt.key ? 'bg-indigo-600 text-white' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400'
            ]"
          >
            {{ opt.key }}
          </div>
          <span>{{ opt.text }}</span>
        </button>
      </div>

      <!-- Bottom Controls -->
      <div class="pt-4 border-t border-slate-100 dark:border-slate-800 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <button 
          @click="openSocraticTutor"
          type="button"
          class="inline-flex items-center justify-center space-x-2 px-4 py-2.5 rounded-xl bg-amber-50 dark:bg-amber-950/30 text-amber-700 dark:text-amber-400 border border-amber-200/60 dark:border-amber-900/40 hover:bg-amber-100 font-semibold text-xs transition"
        >
          <HelpCircle class="w-4 h-4" />
          <span>No entiendo, pedir pista socrática</span>
        </button>

        <button 
          @click="submitAnswer"
          :disabled="!selectedOption || isSubmitting"
          class="inline-flex items-center justify-center space-x-2 px-6 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-sm shadow-md disabled:opacity-50 transition"
        >
          <span>{{ store.isLastDiagnosticItem ? 'Finalizar Diagnóstico' : 'Confirmar y Siguiente' }}</span>
          <ChevronRight class="w-4 h-4" />
        </button>
      </div>
    </div>

    <!-- Diagnostic Results Summary -->
    <div v-else-if="store.currentSession.sessionResults" class="bg-white dark:bg-slate-900 rounded-3xl p-6 sm:p-10 border border-slate-200 dark:border-slate-800 shadow-xl text-center space-y-6">
      <div class="w-16 h-16 rounded-full bg-emerald-100 dark:bg-emerald-950/50 text-emerald-600 dark:text-emerald-400 flex items-center justify-center mx-auto shadow-lg shadow-emerald-500/10">
        <CheckCircle2 class="w-8 h-8" />
      </div>

      <div>
        <h2 class="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white">
          ¡Diagnóstico Completado con Éxito!
        </h2>
        <p class="text-slate-500 text-sm mt-1 max-w-md mx-auto">
          Tus evidencias han sido procesadas para estimar el dominio por competencia de forma trazable.
        </p>
      </div>

      <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 max-w-lg mx-auto">
        <div class="bg-slate-50 dark:bg-slate-800/60 p-4 rounded-2xl border border-slate-200/60 dark:border-slate-800">
          <span class="text-xs text-slate-500">Reactivos respondidos</span>
          <p class="text-xl font-bold text-slate-900 dark:text-white mt-0.5">
            {{ store.currentSession.sessionResults.totalItems }}
          </p>
        </div>
        <div class="bg-slate-50 dark:bg-slate-800/60 p-4 rounded-2xl border border-slate-200/60 dark:border-slate-800">
          <span class="text-xs text-slate-500">Aciertos</span>
          <p class="text-xl font-bold text-emerald-600 dark:text-emerald-400 mt-0.5">
            {{ store.currentSession.sessionResults.correctAnswers }}
          </p>
        </div>
        <div class="col-span-2 sm:col-span-1 bg-slate-50 dark:bg-slate-800/60 p-4 rounded-2xl border border-slate-200/60 dark:border-slate-800">
          <span class="text-xs text-slate-500">Dominio Estimado</span>
          <p class="text-xl font-bold text-indigo-600 dark:text-indigo-400 mt-0.5">
            {{ store.currentSession.sessionResults.percentage }}%
          </p>
        </div>
      </div>

      <div class="p-4 bg-indigo-50/60 dark:bg-indigo-950/30 rounded-2xl border border-indigo-200/50 dark:border-indigo-900/50 max-w-xl mx-auto text-left flex items-start space-x-3">
        <Sparkles class="w-5 h-5 text-indigo-600 dark:text-indigo-400 shrink-0 mt-0.5" />
        <p class="text-xs sm:text-sm text-indigo-900 dark:text-indigo-200">
          {{ store.currentSession.sessionResults.recommendation }}
        </p>
      </div>

      <div class="pt-4 flex justify-center space-x-3">
        <router-link
          to="/intelligence/cockpit"
          class="px-6 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-sm shadow transition"
        >
          Ir al Cockpit Docente
        </router-link>
        <button 
          @click="startNewSession"
          class="px-6 py-2.5 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 text-slate-700 dark:text-slate-300 font-bold text-sm transition"
        >
          Reiniciar Diagnóstico
        </button>
      </div>
    </div>

    <div v-else-if="diagnosticError" class="text-center py-16 px-6 rounded-3xl border border-rose-200 dark:border-rose-900 bg-rose-50 dark:bg-rose-950/20">
      <AlertTriangle class="w-8 h-8 text-rose-600 dark:text-rose-400 mx-auto mb-3" />
      <p class="font-semibold text-rose-800 dark:text-rose-200">No se pudo iniciar el diagnóstico</p>
      <p class="text-sm text-rose-700 dark:text-rose-300 mt-1">{{ diagnosticError }}</p>
    </div>

    <!-- Empty / Loading State -->
    <div v-else class="text-center py-16">
      <Loader2 class="w-8 h-8 animate-spin text-indigo-600 mx-auto mb-3" />
      <p class="text-sm text-slate-500">Cargando sesión diagnóstica adaptativa...</p>
    </div>

    <SocraticTutorDrawer />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useIntelligenceStore } from '../stores/useIntelligenceStore'
import { useAuthStore } from '../../../stores/auth'
import SocraticTutorDrawer from '../components/tutor/SocraticTutorDrawer.vue'
import { ArrowLeft, HelpCircle, ChevronRight, CheckCircle2, Sparkles, Loader2, AlertTriangle } from 'lucide-vue-next'

const store = useIntelligenceStore()
const authStore = useAuthStore()
const route = useRoute()
const selectedOption = ref(null)
const diagnosticError = ref('')
const isSubmitting = ref(false)

const selectedStudentId = () => typeof route.query.studentId === 'string'
  ? route.query.studentId.trim()
  : ''
const selectedSubject = () => typeof route.query.subject === 'string'
  ? route.query.subject.trim()
  : ''
const selectedGradeLevel = () => typeof route.query.gradeLevel === 'string'
  ? route.query.gradeLevel.trim()
  : ''

onMounted(async () => {
  if (!selectedStudentId() || !selectedSubject() || !selectedGradeLevel()) {
    diagnosticError.value = 'Selecciona un estudiante, una asignatura y un nivel desde el Panel Docente.'
    return
  }
  try {
    await store.startDiagnosticSession(selectedSubject(), authStore.activeSchoolId, selectedGradeLevel())
  } catch (err) {
    console.error('Error iniciando diagnóstico:', err)
    diagnosticError.value = 'No fue posible cargar las preguntas. Inténtalo nuevamente.'
  }
})

function openSocraticTutor() {
  store.openSocraticTutor(store.currentDiagnosticItem)
}

async function submitAnswer() {
  if (!selectedOption.value || isSubmitting.value) return
  diagnosticError.value = ''
  isSubmitting.value = true
  try {
    await store.submitAnswer(selectedOption.value, selectedStudentId(), authStore.activeSchoolId)
    selectedOption.value = null
  } catch (err) {
    console.error('Error guardando respuesta diagnóstica:', err)
    diagnosticError.value = 'La respuesta no se guardó. Revisa tu conexión o tus permisos e inténtalo nuevamente.'
  } finally {
    isSubmitting.value = false
  }
}

async function startNewSession() {
  diagnosticError.value = ''
  try {
    await store.startDiagnosticSession(selectedSubject(), authStore.activeSchoolId, selectedGradeLevel())
  } catch (err) {
    console.error('Error reiniciando diagnóstico:', err)
    diagnosticError.value = 'No fue posible reiniciar el diagnóstico.'
  }
}
</script>
