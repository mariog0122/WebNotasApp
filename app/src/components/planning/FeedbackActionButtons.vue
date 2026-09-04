<script setup>
import { ref } from 'vue'
import { ThumbsUp, ThumbsDown, Edit3, Check } from 'lucide-vue-next'

const props = defineProps({
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
  size: {
    type: String,
    default: 'sm' // 'sm' | 'xs'
  }
})

const emit = defineEmits(['feedback-submitted', 'open-modal'])

const submittedPositive = ref(false)

const onPositiveClick = () => {
  submittedPositive.value = true
  emit('feedback-submitted', {
    targetType: props.targetType,
    targetId: props.targetId,
    sectionKey: props.sectionKey,
    rating: 5,
    category: 'pedagogical',
    tags: ['util', 'buena_calidad'],
    comment: 'Planificación útil y pertinente.'
  })
}

const onNegativeClick = () => {
  emit('open-modal', {
    targetType: props.targetType,
    targetId: props.targetId,
    sectionKey: props.sectionKey,
    initialRating: 2,
    mode: 'negative'
  })
}

const onCorrectionClick = () => {
  emit('open-modal', {
    targetType: props.targetType,
    targetId: props.targetId,
    sectionKey: props.sectionKey,
    initialRating: 3,
    mode: 'correction'
  })
}
</script>

<template>
  <div class="inline-flex items-center gap-1 bg-slate-100/80 dark:bg-slate-800/80 border border-slate-200 dark:border-slate-700/60 rounded-xl p-1 shadow-sm backdrop-blur-xs">
    <!-- Feedback positivo rápido -->
    <button
      @click="onPositiveClick"
      type="button"
      :disabled="submittedPositive"
      :class="[
        'inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-semibold transition-all cursor-pointer',
        submittedPositive
          ? 'bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30'
          : 'text-slate-600 dark:text-slate-300 hover:text-emerald-600 hover:bg-emerald-50 dark:hover:bg-emerald-500/10'
      ]"
      title="Marcar como útil y de calidad"
    >
      <Check v-if="submittedPositive" class="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
      <ThumbsUp v-else class="w-3.5 h-3.5" />
      <span class="hidden sm:inline">Útil</span>
    </button>

    <span class="text-slate-300 dark:text-slate-700 select-none">|</span>

    <!-- Necesita mejora -->
    <button
      @click="onNegativeClick"
      type="button"
      class="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-semibold text-slate-600 dark:text-slate-300 hover:text-amber-600 hover:bg-amber-50 dark:hover:bg-amber-500/10 transition-all cursor-pointer"
      title="Indicar que necesita mejoras pedagógicas o de formato"
    >
      <ThumbsDown class="w-3.5 h-3.5" />
      <span class="hidden sm:inline">Necesita mejora</span>
    </button>

    <span class="text-slate-300 dark:text-slate-700 select-none">|</span>

    <!-- Sugerir corrección -->
    <button
      @click="onCorrectionClick"
      type="button"
      class="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-semibold text-slate-600 dark:text-slate-300 hover:text-indigo-600 hover:bg-indigo-50 dark:hover:bg-indigo-500/10 transition-all cursor-pointer"
      title="Sugerir una corrección o ajuste específico"
    >
      <Edit3 class="w-3.5 h-3.5" />
      <span class="hidden sm:inline">Sugerir corrección</span>
    </button>
  </div>
</template>
