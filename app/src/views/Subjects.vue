<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useNetwork } from '../composables/useNetwork'

const subjects = ref([])
const loading = ref(true)
const showModal = ref(false)
const editingSubject = ref(null)
const { isOnline } = useNetwork()

const form = ref({
  name: ''
})

const fetchSubjects = async () => {
  loading.value = true
  const { data, error } = await supabase
    .from('subjects')
    .select('*')
    .order('name', { ascending: true })
  
  if (error) console.error('Error fetching subjects:', error)
  else subjects.value = data
  loading.value = false
}

const openModal = (subject = null) => {
  editingSubject.value = subject
  if (subject) {
    form.value = { ...subject }
  } else {
    form.value = {
      name: ''
    }
  }
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editingSubject.value = null
}

const confirmModal = ref({
  show: false,
  title: '',
  message: '',
  action: null,
  processing: false
})

const closeConfirmModal = () => {
  confirmModal.value.show = false
}

const executeConfirmAction = async () => {
  if (confirmModal.value.action) {
    confirmModal.value.processing = true
    await confirmModal.value.action()
    confirmModal.value.processing = false
    confirmModal.value.show = false
  }
}

const saveSubject = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  try {
    if (editingSubject.value) {
      const { error } = await supabase
        .from('subjects')
        .update(form.value)
        .eq('id', editingSubject.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase
        .from('subjects')
        .insert(form.value)
      if (error) throw error
    }
    await fetchSubjects()
    closeModal()
  } catch (error) {
    confirmModal.value = {
      show: true,
      title: 'Error',
      message: 'Error guardando asignatura: ' + error.message,
      processing: false,
      action: null
    }
  }
}

const deleteSubject = async (id) => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  confirmModal.value = {
    show: true,
    title: 'Eliminar Asignatura',
    message: '¿Estas seguro de eliminar esta asignatura? Se borrara de todos los cursos asignados.',
    processing: false,
    action: async () => {
      try {
        const { error } = await supabase
          .from('subjects')
          .delete()
          .eq('id', id)
        if (error) throw error
        await fetchSubjects()
      } catch (error) {
        confirmModal.value = {
          show: true,
          title: 'Error',
          message: 'Error eliminando asignatura: ' + error.message,
          processing: false,
          action: null
        }
      }
    }
  }
}

onMounted(() => {
  fetchSubjects()
})
</script>

<template>
  <div class="app-shell">
    <main class="app-container">
      <div class="px-2 sm:px-0">
        <div class="flex justify-between items-center mb-6">
          <h1 class="app-title">Gestión de Asignaturas</h1>
          <button @click="openModal()" class="app-btn app-btn-primary">
            + Nueva Asignatura
          </button>
        </div>

        <div class="app-card overflow-hidden">
          <table class="app-table">
            <thead>
              <tr>
                <th>Nombre de Asignatura</th>
                <th class="text-right">Acciones</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="loading">
                <td colspan="2" class="text-center py-8">
                  <span class="app-spinner mr-2"></span>
                  <span class="text-sm text-slate-500">Cargando...</span>
                </td>
              </tr>
              <tr v-else-if="subjects.length === 0">
                <td colspan="2" class="text-center text-sm text-slate-500 py-8">No hay asignaturas registradas.</td>
              </tr>
              <tr v-else v-for="subject in subjects" :key="subject.id">
                <td class="text-sm font-semibold text-slate-900">{{ subject.name }}</td>
                <td class="text-right">
                  <button @click="openModal(subject)" class="action-link action-link-blue">Editar</button>
                  <button @click="deleteSubject(subject.id)" class="action-link action-link-rose">Eliminar</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </main>

    <!-- Create/Edit Modal -->
    <div v-if="showModal" class="modal-container" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeModal"></div>
      <div class="modal-panel">
        <div class="modal-header modal-header-accent">
          <h3 class="modal-title" style="color:#fff">{{ editingSubject ? 'Editar Asignatura' : 'Nueva Asignatura' }}</h3>
          <p class="modal-subtitle">{{ editingSubject ? 'Modifica el nombre de la asignatura.' : 'Ingresa el nombre de la nueva asignatura.' }}</p>
        </div>
        <div class="modal-body">
          <div class="modal-field">
            <label class="modal-label">Nombre</label>
            <input v-model="form.name" type="text" class="app-input" placeholder="Ej: Matemáticas">
          </div>
        </div>
        <div class="modal-footer">
          <button @click="closeModal" class="app-btn app-btn-ghost">Cancelar</button>
          <button @click="saveSubject" class="app-btn app-btn-primary">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
            Guardar
          </button>
        </div>
      </div>
    </div>

    <!-- Confirm Modal -->
    <div v-if="confirmModal.show" class="modal-container" style="z-index:70" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeConfirmModal"></div>
      <div class="modal-panel" style="max-width:28rem;">
        <div class="modal-body text-center" style="padding:32px 24px;">
          <div class="confirm-icon-ring" :class="confirmModal.action ? 'danger' : 'warning'">
            <svg class="h-7 w-7" :class="confirmModal.action ? 'text-rose-600' : 'text-amber-600'" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <h3 class="modal-title text-center">{{ confirmModal.title }}</h3>
          <p class="text-sm text-slate-500 mt-2">{{ confirmModal.message }}</p>
        </div>
        <div class="modal-footer justify-center">
          <button @click="closeConfirmModal" :disabled="confirmModal.processing" class="app-btn app-btn-ghost">
            {{ confirmModal.action ? 'Cancelar' : 'Cerrar' }}
          </button>
          <button v-if="confirmModal.action" @click="executeConfirmAction" :disabled="confirmModal.processing" class="app-btn app-btn-danger disabled:opacity-50">
            {{ confirmModal.processing ? 'Procesando...' : 'Confirmar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
