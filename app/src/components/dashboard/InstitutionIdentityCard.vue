<script setup>
defineProps({
  isAdmin: {
    type: Boolean,
    default: false
  },
  institutionName: {
    type: String,
    default: ''
  },
  institutionRectorName: {
    type: String,
    default: ''
  },
  saving: {
    type: Boolean,
    default: false
  },
  saveMessage: {
    type: String,
    default: ''
  },
  saveError: {
    type: String,
    default: ''
  }
})

const emit = defineEmits([
  'update:institutionName',
  'update:institutionRectorName',
  'logo-change',
  'save'
])
</script>

<template>
  <div class="app-card p-6 mb-8">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
      <h2 class="text-lg font-semibold text-slate-900 dark:text-white">Identidad de la Institución</h2>
      <span v-if="!isAdmin" class="text-xs text-amber-700 bg-amber-100 border border-amber-200 px-2 py-1 rounded">
        Solo administradores pueden editar
      </span>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <label class="block text-sm font-medium text-slate-600 dark:text-slate-300">Nombre de la Institución</label>
        <input 
          :value="institutionName" 
          @input="emit('update:institutionName', $event.target.value)" 
          :disabled="!isAdmin" 
          type="text" 
          class="app-input mt-1 disabled:opacity-60"
        >
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-600 dark:text-slate-300">Logo (PNG/JPG)</label>
        <input 
          type="file" 
          accept="image/*" 
          @change="emit('logo-change', $event)" 
          :disabled="!isAdmin" 
          class="mt-1 block w-full text-sm text-slate-500 disabled:opacity-60" 
        />
        <p class="text-xs text-slate-500 mt-1">Se mostrará en el panel y reportes.</p>
      </div>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
      <div>
        <label class="block text-sm font-medium text-slate-600 dark:text-slate-300">Nombre del Rector</label>
        <input 
          :value="institutionRectorName" 
          @input="emit('update:institutionRectorName', $event.target.value)" 
          :disabled="!isAdmin" 
          type="text" 
          class="app-input mt-1 disabled:opacity-60"
        >
      </div>
    </div>
    <div class="mt-4 flex items-center gap-3">
      <button 
        @click="emit('save')" 
        :disabled="saving || !isAdmin" 
        class="app-btn app-btn-primary disabled:opacity-50"
      >
        {{ saving ? 'Guardando...' : 'Guardar Cambios' }}
      </button>
      <span v-if="saveMessage" class="text-sm text-emerald-600">{{ saveMessage }}</span>
      <span v-if="saveError" class="text-sm text-rose-600">{{ saveError }}</span>
    </div>
  </div>
</template>
