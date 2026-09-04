<script setup>
import { ref } from 'vue'
import { 
  X, 
  Sparkles, 
  BookOpen, 
  FileText, 
  Users, 
  Edit3, 
  HelpCircle, 
  Layers, 
  CheckSquare, 
  ListChecks, 
  ClipboardCheck, 
  BarChart2, 
  Award, 
  TrendingUp, 
  Compass, 
  Copy, 
  Monitor, 
  Home, 
  WifiOff, 
  Send,
  Loader2
} from 'lucide-vue-next'
import { RESOURCE_TYPES } from '../../lib/ecuadorCurriculumCatalog'

const props = defineProps({
  plan: {
    type: Object,
    required: true
  },
  generating: {
    type: Boolean,
    default: false
  },
  onGenerateResource: {
    type: Function,
    required: true
  },
  onClose: {
    type: Function,
    required: true
  }
})

const selectedType = ref('ficha_trabajo')
const difficulty = ref('medio') // inicial | medio | avanzado | adaptado

const getResourceIcon = (iconName) => {
  switch (iconName) {
    case 'BookOpen': return BookOpen
    case 'FileText': return FileText
    case 'Sparkles': return Sparkles
    case 'Users': return Users
    case 'Edit3': return Edit3
    case 'HelpCircle': return HelpCircle
    case 'Layers': return Layers
    case 'CheckSquare': return CheckSquare
    case 'ListChecks': return ListChecks
    case 'ClipboardCheck': return ClipboardCheck
    case 'BarChart2': return BarChart2
    case 'Award': return Award
    case 'TrendingUp': return TrendingUp
    case 'Compass': return Compass
    case 'Copy': return Copy
    case 'Monitor': return Monitor
    case 'Home': return Home
    case 'WifiOff': return WifiOff
    case 'Send': return Send
    default: return FileText
  }
}

const handleCreate = () => {
  props.onGenerateResource(selectedType.value, difficulty.value)
}
</script>

<template>
  <div class="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-3 sm:p-5 overflow-y-auto">
    <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl shadow-2xl w-full max-w-3xl max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
      
      <!-- Header -->
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-900/80">
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-2xl bg-teal-500/10 text-teal-600 dark:text-teal-400 border border-teal-500/20">
            <Sparkles class="w-6 h-6" />
          </div>
          <div>
            <h2 class="text-base font-bold text-slate-900 dark:text-white">Crear Recurso Didáctico Vinculado</h2>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              Hereda automáticamente el tema: <strong class="text-slate-700 dark:text-slate-200">{{ plan.topic_title }}</strong>
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

      <!-- Resource Grid Body -->
      <div class="p-6 overflow-y-auto flex-1 custom-scrollbar space-y-6">
        
        <!-- Dificultad -->
        <div>
          <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-2">Nivel de Complejidad</label>
          <div class="grid grid-cols-4 gap-2">
            <button
              v-for="dif in [{ id: 'inicial', label: 'Inicial / Básico' }, { id: 'medio', label: 'Estándar' }, { id: 'avanzado', label: 'Profundización' }, { id: 'adaptado', label: 'Adaptado DUA' }]"
              :key="dif.id"
              @click="difficulty = dif.id"
              type="button"
              :class="[
                'py-2 px-3 rounded-xl border text-center text-xs font-bold transition-all',
                difficulty === dif.id
                  ? 'border-teal-500 bg-teal-500 text-white shadow-md'
                  : 'border-slate-200 dark:border-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-50'
              ]"
            >
              {{ dif.label }}
            </button>
          </div>
        </div>

        <!-- 17 Tipos de Recursos -->
        <div>
          <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-2">Selecciona el Tipo de Recurso a Generar</label>
          <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2.5 max-h-72 overflow-y-auto custom-scrollbar p-1">
            <button
              v-for="res in RESOURCE_TYPES"
              :key="res.id"
              @click="selectedType = res.id"
              type="button"
              :class="[
                'p-3 rounded-2xl border text-left transition-all text-xs flex items-start gap-3',
                selectedType === res.id
                  ? 'border-teal-500 bg-teal-50/60 dark:bg-teal-500/10 text-teal-900 dark:text-white ring-2 ring-teal-500'
                  : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'
              ]"
            >
              <div class="p-2 rounded-xl bg-slate-100 dark:bg-slate-800 text-teal-600 dark:text-teal-400 shrink-0">
                <component :is="getResourceIcon(res.icon)" class="w-4 h-4" />
              </div>
              <div class="min-w-0">
                <strong class="font-bold block truncate">{{ res.name }}</strong>
                <span class="text-[10px] text-slate-400 line-clamp-2 mt-0.5 leading-tight">{{ res.desc }}</span>
              </div>
            </button>
          </div>
        </div>

      </div>

      <!-- Footer -->
      <div class="px-6 py-4 border-t border-slate-200 dark:border-slate-800 flex items-center justify-end gap-3 bg-slate-50 dark:bg-slate-900/80">
        <button
          @click="onClose"
          type="button"
          class="px-4 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          Cancelar
        </button>

        <button
          @click="handleCreate"
          :disabled="generating"
          type="button"
          class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-gradient-to-r from-teal-600 to-teal-500 hover:from-teal-500 hover:to-teal-400 text-white text-xs font-bold shadow-lg shadow-teal-900/20 transition-all cursor-pointer disabled:opacity-50"
        >
          <Loader2 v-if="generating" class="w-4 h-4 animate-spin" />
          <Sparkles v-else class="w-4 h-4" />
          <span>{{ generating ? 'Generando Recurso...' : 'Generar Recurso con IA' }}</span>
        </button>
      </div>

    </div>
  </div>
</template>
