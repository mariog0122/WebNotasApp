<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { translateError } from '../lib/errorDictionary'

const router = useRouter()
const authStore = useAuthStore()

const navigateTo = (path) => {
  router.push(path)
}

const institutionName = ref('')
const institutionLogoUrl = ref('')
const institutionTutorName = ref('')
const institutionRectorName = ref('')
const logoFile = ref(null)
const logoPreview = ref('')
const saving = ref(false)
const saveError = ref('')
const saveMessage = ref('')
const isAdmin = computed(() => authStore.profile?.role === 'admin')

const fetchInstitutionConfig = async () => {
  const { data, error } = await supabase
    .from('system_config')
    .select('key, value')
    .in('key', ['institution_name', 'institution_logo_url', 'institution_tutor_name', 'institution_rector_name'])
  if (error) {
    saveError.value = 'Error cargando configuracion: ' + translateError(error)
    return
  }
  const map = Object.fromEntries((data || []).map(item => [item.key, item.value]))
  institutionName.value = map.institution_name || ''
  institutionLogoUrl.value = map.institution_logo_url || ''
  institutionTutorName.value = map.institution_tutor_name || ''
  institutionRectorName.value = map.institution_rector_name || ''
  logoPreview.value = institutionLogoUrl.value || ''
}

const getFileExt = (file) => {
  const parts = file.name.split('.')
  return parts.length > 1 ? parts.pop().toLowerCase() : 'jpg'
}

const uploadLogo = async (file, path) => {
  const { error } = await supabase.storage.from('institution-assets').upload(path, file, { upsert: true })
  if (error) throw error
  const { data } = supabase.storage.from('institution-assets').getPublicUrl(path)
  return data.publicUrl
}

const onLogoChange = (event) => {
  const file = event.target.files?.[0] || null
  logoFile.value = file
  if (file) {
    logoPreview.value = URL.createObjectURL(file)
  } else {
    logoPreview.value = institutionLogoUrl.value || ''
  }
}

const saveInstitution = async () => {
  saveError.value = ''
  saveMessage.value = ''
  if (!isAdmin.value) {
    saveError.value = 'Solo administradores pueden actualizar la institucion.'
    return
  }
  if (!institutionName.value.trim()) {
    saveError.value = 'El nombre de la institucion es obligatorio.'
    return
  }
  saving.value = true
  try {
    let logoUrl = institutionLogoUrl.value
    if (logoFile.value) {
      const ext = getFileExt(logoFile.value)
      const path = `institution/logo-${Date.now()}.${ext}`
      logoUrl = await uploadLogo(logoFile.value, path)
    }

    const payload = [
      { key: 'institution_name', value: institutionName.value.trim(), description: 'Nombre de la institucion' },
      { key: 'institution_logo_url', value: logoUrl || '', description: 'Logo de la institucion' },
      { key: 'institution_tutor_name', value: institutionTutorName.value.trim(), description: 'Nombre del tutor' },
      { key: 'institution_rector_name', value: institutionRectorName.value.trim(), description: 'Nombre del rector' }
    ]
    const { error } = await supabase
      .from('system_config')
      .upsert(payload, { onConflict: 'key' })
    if (error) throw error
    institutionLogoUrl.value = logoUrl || ''
    logoPreview.value = institutionLogoUrl.value || ''
    logoFile.value = null
    saveMessage.value = 'Datos actualizados correctamente.'
  } catch (error) {
    saveError.value = 'Error guardando configuracion: ' + translateError(error)
  }
  saving.value = false
}

onMounted(() => {
  fetchInstitutionConfig()
})
</script>

<template>
  <div class="app-shell">
    <main class="app-container">
      <div class="px-2 sm:px-0">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
          <div class="flex items-center gap-4">
            <div class="h-16 w-16 rounded-2xl border border-slate-200 bg-white flex items-center justify-center overflow-hidden shadow-sm">
              <img v-if="logoPreview" :src="logoPreview" alt="Logo institucion" class="h-full w-full object-contain p-1" />
              <span v-else class="text-slate-500 text-xs">Logo</span>
            </div>
            <div>
              <h1 class="app-title">Panel de Control</h1>
              <p class="app-subtitle">{{ institutionName || 'Nombre de Institucion' }}</p>
            </div>
          </div>
        </div>

        <div class="app-card p-6 mb-8">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold text-slate-900 dark:text-white">Identidad de la Institucion</h2>
            <span v-if="!isAdmin" class="text-xs text-amber-700 bg-amber-100 border border-amber-200 px-2 py-1 rounded">
              Solo administradores pueden editar
            </span>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-600">Nombre de la Institucion</label>
              <input v-model="institutionName" :disabled="!isAdmin" type="text" class="app-input mt-1 disabled:opacity-60">
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-600">Logo (PNG/JPG)</label>
              <input type="file" accept="image/*" @change="onLogoChange" :disabled="!isAdmin" class="mt-1 block w-full text-sm text-slate-500 disabled:opacity-60" />
              <p class="text-xs text-slate-500 mt-1">Se mostrara en el panel y reportes.</p>
            </div>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            <div>
              <label class="block text-sm font-medium text-slate-600">Nombre del Tutor</label>
              <input v-model="institutionTutorName" :disabled="!isAdmin" type="text" class="app-input mt-1 disabled:opacity-60">
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-600">Nombre del Rector</label>
              <input v-model="institutionRectorName" :disabled="!isAdmin" type="text" class="app-input mt-1 disabled:opacity-60">
            </div>
          </div>
          <div class="mt-4 flex items-center gap-3">
            <button @click="saveInstitution" :disabled="saving || !isAdmin" class="app-btn app-btn-primary disabled:opacity-50">
              {{ saving ? 'Guardando...' : 'Guardar Cambios' }}
            </button>
            <span v-if="saveMessage" class="text-sm text-emerald-600">{{ saveMessage }}</span>
            <span v-if="saveError" class="text-sm text-rose-600">{{ saveError }}</span>
          </div>
        </div>

        <div class="app-card-soft p-5 mb-8">
          <h2 class="text-lg font-semibold text-teal-900 mb-4 flex items-center gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-teal-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Guía de Flujo de Trabajo
          </h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 1</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Configuración</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Configure los datos de la institución (Nombre, Logo, Autoridades) en este mismo panel.</p>
            </div>
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 2</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Catálogos</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Vaya a <strong>Asignaturas</strong> y <strong>Cursos</strong> para definir las materias y paralelos disponibles.</p>
            </div>
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 3</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Matriculación</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Vaya a <strong>Estudiantes</strong> para registrar a los alumnos y asignarlos a sus cursos.</p>
            </div>
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 4</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Calificaciones</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">En <strong>Docentes / Notas</strong>, seleccione el curso y asignatura para ingresar los insumos y notas.</p>
            </div>
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 5</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Reportes</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">El sistema calcula promedios automáticamente. Genere actas y libretas desde la sección de Notas.</p>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div @click="navigateTo('/courses')" class="app-card p-1 cursor-pointer group hover:shadow-xl hover:-translate-y-1 transition-all duration-300">
            <div class="px-5 py-6 relative overflow-hidden rounded-2xl">
              <div class="absolute inset-0 bg-gradient-to-br from-teal-500/5 to-teal-600/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-2xl"></div>
              <div class="relative flex items-center">
                <div class="flex-shrink-0 bg-gradient-to-br from-teal-600 to-teal-500 rounded-2xl p-3.5 shadow-lg shadow-teal-600/20">
                  <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dt class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Gestión Académica</dt>
                  <dd class="mt-1"><div class="text-2xl font-bold text-slate-900 dark:text-white">Cursos</div></dd>
                </div>
              </div>
              <div class="relative mt-4"><span class="text-sm font-semibold text-teal-700 group-hover:text-teal-600 transition-colors">Ver listado &rarr;</span></div>
            </div>
          </div>

          <div @click="navigateTo('/subjects')" class="app-card p-1 cursor-pointer group hover:shadow-xl hover:-translate-y-1 transition-all duration-300">
            <div class="px-5 py-6 relative overflow-hidden rounded-2xl">
              <div class="absolute inset-0 bg-gradient-to-br from-emerald-500/5 to-emerald-600/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-2xl"></div>
              <div class="relative flex items-center">
                <div class="flex-shrink-0 bg-gradient-to-br from-emerald-500 to-emerald-600 rounded-2xl p-3.5 shadow-lg shadow-emerald-500/20">
                  <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dt class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Catálogo</dt>
                  <dd class="mt-1"><div class="text-2xl font-bold text-slate-900 dark:text-white">Asignaturas</div></dd>
                </div>
              </div>
              <div class="relative mt-4"><span class="text-sm font-semibold text-emerald-600 group-hover:text-emerald-500 transition-colors">Administrar &rarr;</span></div>
            </div>
          </div>

          <div @click="navigateTo('/students')" class="app-card p-1 cursor-pointer group hover:shadow-xl hover:-translate-y-1 transition-all duration-300">
            <div class="px-5 py-6 relative overflow-hidden rounded-2xl">
              <div class="absolute inset-0 bg-gradient-to-br from-amber-500/5 to-amber-600/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-2xl"></div>
              <div class="relative flex items-center">
                <div class="flex-shrink-0 bg-gradient-to-br from-amber-500 to-amber-600 rounded-2xl p-3.5 shadow-lg shadow-amber-500/20">
                  <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dt class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Registro</dt>
                  <dd class="mt-1"><div class="text-2xl font-bold text-slate-900 dark:text-white">Estudiantes</div></dd>
                </div>
              </div>
              <div class="relative mt-4"><span class="text-sm font-semibold text-amber-600 group-hover:text-amber-500 transition-colors">Inscribir estudiantes &rarr;</span></div>
            </div>
          </div>

          <div @click="navigateTo('/grades')" class="app-card p-1 cursor-pointer group hover:shadow-xl hover:-translate-y-1 transition-all duration-300 col-span-full md:col-span-2 lg:col-span-1">
            <div class="px-5 py-6 relative overflow-hidden rounded-2xl">
              <div class="absolute inset-0 bg-gradient-to-br from-rose-500/5 to-rose-600/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-2xl"></div>
              <div class="relative flex items-center">
                <div class="flex-shrink-0 bg-gradient-to-br from-rose-500 to-rose-600 rounded-2xl p-3.5 shadow-lg shadow-rose-500/20">
                  <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dt class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Docentes</dt>
                  <dd class="mt-1"><div class="text-2xl font-bold text-slate-900 dark:text-white">Notas y Actas</div></dd>
                </div>
              </div>
              <div class="relative mt-4"><span class="text-sm font-semibold text-rose-600 group-hover:text-rose-500 transition-colors">Ingresar calificaciones &rarr;</span></div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>
