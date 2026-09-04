<script setup>
import { ref, computed } from 'vue'
import { 
  X, 
  Send, 
  ShieldCheck, 
  Sparkles, 
  AlertCircle, 
  ThumbsDown, 
  Edit3, 
  Loader2,
  CheckCircle2
} from 'lucide-vue-next'
import { AIPrivacySanitizer } from '../../lib/ai/AIPrivacySanitizer'

const props = defineProps({
  show: {
    type: Boolean,
    default: false
  },
  targetType: {
    type: String,
    default: 'lesson_plan'
  },
  targetId: {
    type: String,
    required: true
  },
  sectionKey: {
    type: String,
    default: null
  },
  initialRating: {
    type: Number,
    default: 2
  },
  mode: {
    type: String,
    default: 'negative' // 'negative' | 'correction'
  },
  knownStudentNames: {
    type: Array,
    default: () => []
  },
  loading: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['close', 'submit'])

const rating = ref(props.initialRating)
const selectedCategory = ref('pedagogical')
const selectedTags = ref([])
const commentText = ref('')
const submittedSuccess = ref(false)

const quickCategories = [
  { id: 'error_conceptual', label: 'Error conceptual', category: 'factual_error' },
  { id: 'no_curso', label: 'No corresponde al curso', category: 'curriculum' },
  { id: 'no_edad', label: 'No corresponde a la edad', category: 'difficulty' },
  { id: 'no_competencia', label: 'No cumple la competencia', category: 'curriculum' },
  { id: 'metodologia_incorrecta', label: 'Metodología incorrecta', category: 'methodology' },
  { id: 'demasiado_complejo', label: 'Demasiado complejo', category: 'difficulty' },
  { id: 'demasiado_basico', label: 'Demasiado básico', category: 'difficulty' },
  { id: 'falta_contexto', label: 'Falta contextualización', category: 'pedagogical' },
  { id: 'formato_incorrecto', label: 'Formato institucional incorrecto', category: 'format' },
  { id: 'desactualizada', label: 'Información desactualizada', category: 'curriculum' },
  { id: 'otro', label: 'Otro', category: 'other' }
]

const toggleTag = (cat) => {
  const idx = selectedTags.value.indexOf(cat.id)
  if (idx !== -1) {
    selectedTags.value.splice(idx, 1)
  } else {
    selectedTags.value.push(cat.id)
    selectedCategory.value = cat.category
  }
}

// Detección de privacidad en tiempo real en el cliente
const livePrivacyPreview = computed(() => {
  if (!commentText.value) return null
  return AIPrivacySanitizer.redactPII(commentText.value, props.knownStudentNames)
})

const onSubmit = () => {
  const sanitization = AIPrivacySanitizer.sanitizeFeedbackPayload(
    { comment: commentText.value },
    props.knownStudentNames
  )

  emit('submit', {
    targetType: props.targetType,
    targetId: props.targetId,
    sectionKey: props.sectionKey,
    rating: rating.value,
    category: selectedCategory.value,
    tags: selectedTags.value,
    comment: sanitization.sanitizedComment,
    piiRedactedCount: sanitization.piiRedactedCount
  })

  submittedSuccess.value = true
  setTimeout(() => {
    submittedSuccess.value = false
    emit('close')
  }, 1200)
}
</script>

<template>
  <div v-if="show" class="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-xs flex items-center justify-center p-3 sm:p-4 overflow-y-auto">
    <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl shadow-2xl w-full max-w-lg overflow-hidden animate-in fade-in zoom-in-95 duration-200">
      
      <!-- Header -->
      <div class="px-6 py-4 border-b border-slate-100 dark:border-slate-800/80 flex items-center justify-between">
        <div class="flex items-center gap-2.5">
          <div :class="[
            'p-2 rounded-xl text-white',
            mode === 'correction' ? 'bg-indigo-600' : 'bg-amber-600'
          ]">
            <Edit3 v-if="mode === 'correction'" class="w-4 h-4" />
            <ThumbsDown v-else class="w-4 h-4" />
          </div>
          <div>
            <h3 class="text-sm font-bold text-slate-900 dark:text-white">
              {{ mode === 'correction' ? 'Sugerir Corrección Pedagógica' : 'Retroalimentar IA' }}
            </h3>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              Tus observaciones nos ayudan a pulir futuras recomendaciones.
            </p>
          </div>
        </div>

        <button
          @click="emit('close')"
          class="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
        >
          <X class="w-4 h-4" />
        </button>
      </div>

      <!-- Body -->
      <div class="p-6 space-y-5">
        
        <!-- Categorías Rápidas -->
        <div>
          <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-2">
            Selecciona el motivo principal:
          </label>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="cat in quickCategories"
              :key="cat.id"
              @click="toggleTag(cat)"
              type="button"
              :class="[
                'px-2.5 py-1 rounded-full text-xs font-medium transition-all cursor-pointer border',
                selectedTags.includes(cat.id)
                  ? 'bg-indigo-600 text-white border-indigo-600 shadow-xs'
                  : 'bg-slate-50 dark:bg-slate-800/60 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600'
              ]"
            >
              {{ cat.label }}
            </button>
          </div>
        </div>

        <!-- Campo Opcional: ¿Qué cambiarías? -->
        <div>
          <div class="flex items-center justify-between mb-1.5">
            <label class="text-xs font-bold text-slate-700 dark:text-slate-300">
              ¿Qué cambiarías o qué sugerencia darías a la IA?
            </label>
            <span class="text-[10px] text-slate-400 uppercase font-semibold">Opcional</span>
          </div>

          <textarea
            v-model="commentText"
            rows="3"
            maxlength="500"
            placeholder="Ejemplo: Para este nivel sugiero incluir un ejercicio con materiales del entorno escolar..."
            class="w-full text-xs rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-950 p-3 text-slate-800 dark:text-slate-200 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-indigo-500/30 transition-all resize-none"
          ></textarea>

          <!-- Privacy Indicator & Live Redaction Preview -->
          <div class="mt-2 p-2.5 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200 dark:border-slate-800 flex items-start gap-2">
            <ShieldCheck class="w-4 h-4 text-emerald-500 shrink-0 mt-0.5" />
            <div class="text-[11px] leading-relaxed text-slate-500 dark:text-slate-400">
              <span class="font-bold text-slate-700 dark:text-slate-300">Privacidad Activa:</span>
              Cédulas, nombres de menores y diagnósticos clínicos son automáticamente anonimizados antes de ser procesados.
              
              <div v-if="livePrivacyPreview && livePrivacyPreview.piiCount > 0" class="mt-1 font-mono text-[10px] text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/40 p-1.5 rounded border border-emerald-200 dark:border-emerald-800/40">
                Anonimización aplicada ({{ livePrivacyPreview.piiCount }} elemento/s): "{{ livePrivacyPreview.sanitizedText }}"
              </div>
            </div>
          </div>
        </div>

        <!-- Acciones -->
        <div class="flex items-center justify-end gap-2 pt-2 border-t border-slate-100 dark:border-slate-800/80">
          <button
            @click="emit('close')"
            type="button"
            class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
          >
            Cancelar
          </button>

          <button
            @click="onSubmit"
            :disabled="loading || submittedSuccess"
            type="button"
            class="inline-flex items-center gap-1.5 px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-md transition-all cursor-pointer disabled:opacity-50"
          >
            <Loader2 v-if="loading" class="w-3.5 h-3.5 animate-spin" />
            <CheckCircle2 v-else-if="submittedSuccess" class="w-3.5 h-3.5 text-emerald-300" />
            <Send v-else class="w-3.5 h-3.5" />
            <span>{{ submittedSuccess ? '¡Enviado!' : 'Enviar Retroalimentación' }}</span>
          </button>
        </div>

      </div>

    </div>
  </div>
</template>
