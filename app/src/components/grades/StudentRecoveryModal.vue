<script setup>
import { ref, computed } from 'vue'
import { 
  X, 
  Sparkles, 
  HeartHandshake, 
  FileText, 
  CheckSquare, 
  Copy, 
  Share2, 
  Printer, 
  Save, 
  Loader2, 
  CheckCircle2, 
  AlertTriangle,
  User,
  BookOpen
} from 'lucide-vue-next'
import { EducationAIGateway } from '../../lib/ai/EducationAIGateway'
import { supabase } from '../../lib/supabase'

const props = defineProps({
  student: {
    type: Object,
    required: true
  },
  subjectName: {
    type: String,
    default: 'Asignatura'
  },
  score: {
    type: [Number, String],
    default: 0
  },
  courseName: {
    type: String,
    default: ''
  },
  onClose: {
    type: Function,
    required: true
  }
})

const recoveryType = ref('plan_refuerzo') // 'plan_refuerzo' | 'ficha_trabajo' | 'cuestionario_recuperacion'
const topicDescription = ref('')
const generating = ref(false)
const generatedContent = ref(null)
const copySuccess = ref(false)
const saveSuccess = ref(false)

const studentHasAdaptation = computed(() => !!props.student?.has_adaptation)
const adaptationGradeLabel = computed(() => {
  if (!props.student?.has_adaptation) return 'Sin adaptación curricular'
  const g = props.student.adaptation_grade
  if (g === '1') return 'Grado 1 (De Acceso)'
  if (g === '2') return 'Grado 2 (No Significativa)'
  if (g === '3') return 'Grado 3 (Significativa)'
  return `Grado ${g}`
})

const generateRecoveryWithAI = async () => {
  generating.value = true
  saveSuccess.value = false
  copySuccess.value = false

  try {
    const gateway = new EducationAIGateway({ isDemo: true })
    
    // Anonymize student before calling AI
    const rawInput = {
      studentName: props.student.full_name,
      studentId: props.student.id,
      subjectName: props.subjectName,
      score: props.score,
      courseName: props.courseName,
      hasAdaptation: studentHasAdaptation.value,
      adaptationGrade: props.student.adaptation_grade || '1',
      adaptationDetails: props.student.adaptation_details || '',
      recoveryType: recoveryType.value,
      topic: topicDescription.value || `Refuerzo de destrezas clave en ${props.subjectName}`
    }

    const { sanitizedInput, reverseMap } = gateway.anonymizeStudentInput(rawInput)
    const result = await gateway.generateStudentSupport(sanitizedInput)
    const rehydrated = gateway.rehydrateOutput(result, reverseMap)

    generatedContent.value = {
      title: recoveryType.value === 'plan_refuerzo'
        ? `Plan de Recuperación Pedagógica — ${props.student.full_name}`
        : recoveryType.value === 'ficha_trabajo'
        ? `Ficha de Trabajo Individualizada — ${props.student.full_name}`
        : `Cuestionario de Recuperación — ${props.student.full_name}`,
      student_name: props.student.full_name,
      subject: props.subjectName,
      score: props.score,
      adaptation_grade: adaptationGradeLabel.value,
      data: rehydrated
    }
  } catch (err) {
    console.error('Error generating recovery:', err)
  } finally {
    generating.value = false
  }
}

const copyToClipboard = async () => {
  if (!generatedContent.value) return
  let text = `*${generatedContent.value.title}*\n`
  text += `*Estudiante:* ${props.student.full_name}\n`
  text += `*Asignatura:* ${props.subjectName} (Calificación: ${props.score}/10)\n`
  if (studentHasAdaptation.value) {
    text += `*Adaptación Curricular:* ${adaptationGradeLabel.value}\n`
  }
  text += `\n*Diagnóstico Pedagógico:*\n${generatedContent.value.data.diagnostic}\n\n`
  text += `*Objetivos de Recuperación:*\n${(generatedContent.value.data.pedagogical_goals || []).map(g => `• ${g}`).join('\n')}\n\n`
  text += `*Plan Semanal de Trabajo:*\n`
  ;(generatedContent.value.data.weekly_plan || []).forEach(w => {
    text += `• Semana ${w.week}: ${w.focus} — ${w.activities?.join(', ')}\n`
  })

  await navigator.clipboard.writeText(text)
  copySuccess.value = true
  setTimeout(() => { copySuccess.value = false }, 2500)
}

const sendWhatsApp = () => {
  const phone = props.student.representative_phone || props.student.student_phone || ''
  const cleanPhone = phone.replace(/\D/g, '')
  let text = `Estimado representante de ${props.student.full_name}:\nLe compartimos el plan de refuerzo pedagógico en la asignatura de ${props.subjectName}.\n\n`
  text += `*Calificación actual:* ${props.score}/10\n`
  text += `*Objetivo:* ${(generatedContent.value?.data?.pedagogical_goals?.[0] || 'Mejorar el desempeño académico')}\n\n`
  text += `Agradecemos su acompañamiento en casa.`

  const url = cleanPhone 
    ? `https://api.whatsapp.com/send?phone=${cleanPhone}&text=${encodeURIComponent(text)}`
    : `https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`

  window.open(url, '_blank')
}

const saveToDatabase = async () => {
  if (!generatedContent.value) return
  try {
    const { error } = await supabase.from('student_support_plans').insert({
      student_id: props.student.id,
      school_id: props.student.school_id,
      subject_name: props.subjectName,
      status: 'propuesta',
      content: generatedContent.value
    })
    if (!error) {
      saveSuccess.value = true
      setTimeout(() => { saveSuccess.value = false }, 2500)
    }
  } catch (e) {
    console.warn('Error saving recovery plan:', e)
  }
}
</script>

<template>
  <div class="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-3 sm:p-5 overflow-y-auto">
    <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl shadow-2xl w-full max-w-3xl max-h-[92vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
      
      <!-- Header -->
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-gradient-to-r from-indigo-50/50 via-slate-50 to-white dark:from-indigo-950/30 dark:via-slate-900 dark:to-slate-900">
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-2xl bg-indigo-600 text-white shadow-lg shadow-indigo-600/30">
            <Sparkles class="w-5 h-5" />
          </div>
          <div>
            <div class="flex items-center gap-2">
              <h2 class="text-base font-bold text-slate-900 dark:text-white">Generador de Recuperación Pedagógica con IA</h2>
              <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-500/20">
                Nota: {{ score }} / 10
              </span>
            </div>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ student.full_name }} · {{ subjectName }} · Normativa MINEDEC
            </p>
          </div>
        </div>

        <button
          @click="onClose"
          type="button"
          class="p-2 rounded-xl text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <!-- Body -->
      <div class="p-6 overflow-y-auto flex-1 custom-scrollbar space-y-5">
        
        <!-- Ficha de Adaptación Curricular del Estudiante (Si aplica) -->
        <div 
          :class="[
            'p-4 rounded-2xl border flex items-start gap-3',
            studentHasAdaptation 
              ? 'bg-teal-50/60 dark:bg-teal-950/20 border-teal-200 dark:border-teal-800/60 text-teal-900 dark:text-teal-200'
              : 'bg-slate-50 dark:bg-slate-800/40 border-slate-200 dark:border-slate-700/60 text-slate-700 dark:text-slate-300'
          ]"
        >
          <HeartHandshake :class="['w-5 h-5 shrink-0 mt-0.5', studentHasAdaptation ? 'text-teal-600 dark:text-teal-400' : 'text-slate-400']" />
          <div class="space-y-1 text-xs">
            <div class="flex items-center gap-2">
              <strong class="font-bold">Estado de Adaptación Curricular:</strong>
              <span :class="['px-2 py-0.5 rounded text-[10px] font-bold', studentHasAdaptation ? 'bg-teal-600 text-white' : 'bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-300']">
                {{ adaptationGradeLabel }}
              </span>
            </div>
            <p v-if="studentHasAdaptation && student.adaptation_details" class="text-[11px] text-teal-800 dark:text-teal-300">
              <strong>Especificaciones:</strong> {{ student.adaptation_details }}
            </p>
            <p v-else-if="!studentHasAdaptation" class="text-[11px] text-slate-500">
              Este estudiante no tiene registrada adaptación curricular especial. Se aplicará refuerzo estándar con andamiaje.
            </p>
          </div>
        </div>

        <!-- Tipo de Recuperación a Generar -->
        <div>
          <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-2">Selecciona el Tipo de Recurso Individualizado</label>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <button
              v-for="opt in [
                { id: 'plan_refuerzo', title: 'Plan de Refuerzo', desc: 'Objetivos, diagnóstico y plan semanal tutorizado.' },
                { id: 'ficha_trabajo', title: 'Ficha de Trabajo', desc: 'Actividades guiadas con ejemplos y andamiaje.' },
                { id: 'cuestionario_recuperacion', title: 'Cuestionario', desc: '5 preguntas clave con rúbrica de calificación.' }
              ]"
              :key="opt.id"
              @click="recoveryType = opt.id"
              type="button"
              :class="[
                'p-3.5 rounded-2xl border text-left transition-all text-xs flex flex-col justify-between',
                recoveryType === opt.id
                  ? 'border-indigo-600 bg-indigo-50/60 dark:bg-indigo-500/10 ring-2 ring-indigo-500 text-indigo-900 dark:text-white'
                  : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'
              ]"
            >
              <strong class="font-bold text-xs">{{ opt.title }}</strong>
              <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1 leading-snug">{{ opt.desc }}</p>
            </button>
          </div>
        </div>

        <!-- Tema o Dificultad Observada (Opcional) -->
        <div>
          <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Tema o Dificultad Específica (Opcional)</label>
          <input
            v-model="topicDescription"
            type="text"
            placeholder="Ej: Resolución de fracciones heterogéneas, comprensión lectora inferencial..."
            class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3.5 py-2 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
          />
        </div>

        <!-- Botón Generar con IA -->
        <div class="pt-1">
          <button
            @click="generateRecoveryWithAI"
            :disabled="generating"
            type="button"
            class="w-full py-3 rounded-2xl bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white font-bold text-xs shadow-lg shadow-indigo-600/20 flex items-center justify-center gap-2 cursor-pointer transition-all disabled:opacity-50"
          >
            <Loader2 v-if="generating" class="w-4 h-4 animate-spin" />
            <Sparkles v-else class="w-4 h-4" />
            <span>{{ generating ? 'Generando recurso individualizado...' : 'Generar Recuperación con IA (MINEDEC)' }}</span>
          </button>
        </div>

        <!-- Resultados Generados -->
        <div v-if="generatedContent" class="space-y-4 pt-2 border-t border-slate-200 dark:border-slate-800 animate-in fade-in duration-300">
          <div class="flex items-center justify-between">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300">
              {{ generatedContent.title }}
            </h3>

            <div class="flex items-center gap-2">
              <button
                @click="copyToClipboard"
                type="button"
                class="inline-flex items-center gap-1 px-3 py-1.5 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              >
                <CheckCircle2 v-if="copySuccess" class="w-3.5 h-3.5 text-emerald-500" />
                <Copy v-else class="w-3.5 h-3.5" />
                <span>{{ copySuccess ? 'Copiado' : 'Copiar' }}</span>
              </button>

              <button
                @click="sendWhatsApp"
                type="button"
                class="inline-flex items-center gap-1 px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow transition-colors"
              >
                <Share2 class="w-3.5 h-3.5" />
                <span>WhatsApp</span>
              </button>
            </div>
          </div>

          <!-- Tarjeta de Contenido -->
          <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-950 space-y-3 text-xs leading-relaxed">
            <div>
              <span class="text-[10px] font-bold uppercase text-slate-400">Diagnóstico & Estrategia</span>
              <p class="text-slate-800 dark:text-slate-200 mt-0.5">{{ generatedContent.data.diagnostic }}</p>
            </div>

            <div>
              <span class="text-[10px] font-bold uppercase text-slate-400">Objetivos Pedagógicos</span>
              <ul class="list-disc list-inside space-y-1 text-slate-700 dark:text-slate-300 mt-1">
                <li v-for="(g, gIdx) in (generatedContent.data.pedagogical_goals || [])" :key="gIdx">{{ g }}</li>
              </ul>
            </div>

            <div>
              <span class="text-[10px] font-bold uppercase text-slate-400">Cronograma de Acompañamiento</span>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 mt-1">
                <div v-for="w in (generatedContent.data.weekly_plan || [])" :key="w.week" class="p-2.5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800">
                  <strong class="font-bold block text-indigo-600 dark:text-indigo-400">Semana {{ w.week }}: {{ w.focus }}</strong>
                  <p class="text-[11px] text-slate-600 dark:text-slate-400 mt-0.5">{{ w.activities?.join(', ') }}</p>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div>

      <!-- Footer -->
      <div class="px-6 py-3.5 border-t border-slate-200 dark:border-slate-800 flex items-center justify-end gap-2 bg-slate-50 dark:bg-slate-900/80">
        <button
          @click="onClose"
          type="button"
          class="px-4 py-2 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          Cerrar
        </button>
      </div>

    </div>
  </div>
</template>
