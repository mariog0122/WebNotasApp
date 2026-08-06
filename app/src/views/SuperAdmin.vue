<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { Plus, Save, Edit, Trash2, Building, Users } from 'lucide-vue-next'
import { toast } from 'vue-sonner'

const activeTab = ref('schools')
const schools = ref([])
const profiles = ref([])
const loading = ref(false)
const saving = ref(false)

const newSchoolName = ref('')
const newSchoolActive = ref(true)

const fetchSchools = async () => {
  const { data, error } = await supabase
    .from('schools')
    .select('*')
    .order('created_at', { ascending: false })
  
  if (error) {
    toast.error('Error al cargar colegios')
    console.error(error)
  } else {
    schools.value = data || []
  }
}

const fetchProfiles = async () => {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .order('created_at', { ascending: false })
  
  if (error) {
    toast.error('Error al cargar perfiles')
    console.error(error)
  } else {
    profiles.value = data || []
  }
}

const createSchool = async () => {
  if (!newSchoolName.value) {
    toast.error('El nombre del colegio es requerido')
    return
  }
  saving.value = true
  const { data, error } = await supabase
    .from('schools')
    .insert([{ name: newSchoolName.value, is_active: newSchoolActive.value }])
    .select()
    
  if (error) {
    toast.error('Error al crear colegio')
  } else {
    toast.success('Colegio creado exitosamente')
    newSchoolName.value = ''
    schools.value.unshift(data[0])
  }
  saving.value = false
}

const updateProfileRole = async (profile) => {
  const { error } = await supabase
    .from('profiles')
    .update({ role: profile.role })
    .eq('id', profile.id)
    
  if (error) {
    toast.error('Error actualizando rol')
  } else {
    toast.success('Rol actualizado')
  }
}

const updateProfileSchool = async (profile) => {
  const { error } = await supabase
    .from('profiles')
    .update({ school_id: profile.school_id })
    .eq('id', profile.id)
    
  if (error) {
    toast.error('Error actualizando colegio')
  } else {
    toast.success('Colegio asignado')
  }
}

const loadData = async () => {
  loading.value = true
  await Promise.all([fetchSchools(), fetchProfiles()])
  loading.value = false
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="p-4 md:p-8 max-w-7xl mx-auto space-y-6">
    <div>
      <h1 class="text-3xl font-bold text-white tracking-tight">Panel de Súper Administrador</h1>
      <p class="text-slate-400 mt-1">Gestiona los colegios y sus administradores en la plataforma SaaS.</p>
    </div>

    <!-- Tabs -->
    <div class="flex space-x-2 border-b border-slate-700/50">
      <button 
        @click="activeTab = 'schools'" 
        :class="['px-4 py-2 font-medium text-sm flex items-center gap-2 border-b-2 transition-colors', activeTab === 'schools' ? 'border-indigo-500 text-indigo-400' : 'border-transparent text-slate-400 hover:text-white']"
      >
        <Building class="w-4 h-4" />
        Colegios
      </button>
      <button 
        @click="activeTab = 'profiles'" 
        :class="['px-4 py-2 font-medium text-sm flex items-center gap-2 border-b-2 transition-colors', activeTab === 'profiles' ? 'border-indigo-500 text-indigo-400' : 'border-transparent text-slate-400 hover:text-white']"
      >
        <Users class="w-4 h-4" />
        Usuarios (Perfiles)
      </button>
    </div>

    <div v-if="loading" class="text-center py-10">
      <div class="animate-spin w-8 h-8 border-4 border-indigo-500 border-t-transparent rounded-full mx-auto"></div>
    </div>
    
    <div v-else>
      <!-- SCHOOLS TAB -->
      <div v-if="activeTab === 'schools'" class="space-y-6">
        <!-- Create School -->
        <div class="bg-slate-800/40 p-4 rounded-xl border border-slate-700/50 flex gap-4 items-end">
          <div class="flex-1">
            <label class="block text-xs font-medium text-slate-400 mb-1">Nombre del Nuevo Colegio</label>
            <input v-model="newSchoolName" type="text" placeholder="Ej. Colegio San José" class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-indigo-500 outline-none" />
          </div>
          <div>
            <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer h-10 px-2">
              <input v-model="newSchoolActive" type="checkbox" class="rounded border-slate-600 bg-slate-900 text-indigo-500 focus:ring-indigo-500">
              Activo
            </label>
          </div>
          <button @click="createSchool" :disabled="saving" class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg font-medium transition-colors flex items-center gap-2 disabled:opacity-50 h-[42px]">
            <Plus class="w-4 h-4" />
            Registrar Colegio
          </button>
        </div>

        <!-- Schools List -->
        <div class="bg-slate-800/40 border border-slate-700/50 rounded-xl overflow-hidden">
          <table class="w-full text-left text-sm">
            <thead class="bg-slate-900/50 text-slate-400 border-b border-slate-700/50">
              <tr>
                <th class="px-4 py-3 font-medium">ID (UUID)</th>
                <th class="px-4 py-3 font-medium">Nombre</th>
                <th class="px-4 py-3 font-medium">Estado</th>
                <th class="px-4 py-3 font-medium">Fecha Creación</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-700/50 text-slate-300">
              <tr v-for="school in schools" :key="school.id" class="hover:bg-slate-800/60 transition-colors">
                <td class="px-4 py-3 font-mono text-xs text-slate-500">{{ school.id }}</td>
                <td class="px-4 py-3 font-medium text-white">{{ school.name }}</td>
                <td class="px-4 py-3">
                  <span :class="['px-2 py-1 rounded text-xs font-medium', school.is_active ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400']">
                    {{ school.is_active ? 'Activo' : 'Inactivo' }}
                  </span>
                </td>
                <td class="px-4 py-3 text-slate-400">{{ new Date(school.created_at).toLocaleDateString() }}</td>
              </tr>
              <tr v-if="schools.length === 0">
                <td colspan="4" class="px-4 py-8 text-center text-slate-500">No hay colegios registrados.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- PROFILES TAB -->
      <div v-if="activeTab === 'profiles'" class="space-y-6">
        <div class="bg-slate-800/40 border border-slate-700/50 rounded-xl overflow-x-auto">
          <table class="w-full text-left text-sm min-w-[800px]">
            <thead class="bg-slate-900/50 text-slate-400 border-b border-slate-700/50">
              <tr>
                <th class="px-4 py-3 font-medium">Usuario / Email</th>
                <th class="px-4 py-3 font-medium">Rol</th>
                <th class="px-4 py-3 font-medium">Colegio Asignado</th>
                <th class="px-4 py-3 font-medium text-center">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-700/50 text-slate-300">
              <tr v-for="profile in profiles" :key="profile.id" class="hover:bg-slate-800/60 transition-colors">
                <td class="px-4 py-3">
                  <div class="font-medium text-white">{{ profile.full_name || 'Sin Nombre' }}</div>
                  <div class="text-xs text-slate-400">{{ profile.email || profile.id }}</div>
                </td>
                <td class="px-4 py-3">
                  <select 
                    v-model="profile.role" 
                    @change="updateProfileRole(profile)"
                    class="bg-slate-900 border border-slate-700 rounded px-2 py-1 text-sm text-white focus:ring-1 focus:ring-indigo-500 outline-none"
                  >
                    <option value="teacher">Teacher (Docente)</option>
                    <option value="admin">Admin (Rector)</option>
                    <option value="superadmin">Super Admin (Dueño)</option>
                  </select>
                </td>
                <td class="px-4 py-3">
                  <select 
                    v-model="profile.school_id" 
                    @change="updateProfileSchool(profile)"
                    class="bg-slate-900 border border-slate-700 rounded px-2 py-1 text-sm text-white focus:ring-1 focus:ring-indigo-500 outline-none max-w-[200px]"
                  >
                    <option :value="null">-- Ninguno --</option>
                    <option v-for="s in schools" :key="s.id" :value="s.id">{{ s.name }}</option>
                  </select>
                </td>
                <td class="px-4 py-3 text-center">
                  <span class="text-xs text-slate-500">Se guarda al cambiar</span>
                </td>
              </tr>
              <tr v-if="profiles.length === 0">
                <td colspan="4" class="px-4 py-8 text-center text-slate-500">No hay perfiles registrados.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
