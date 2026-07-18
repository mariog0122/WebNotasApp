<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useNetwork } from '../composables/useNetwork'

const authStore = useAuthStore()
const { isOnline } = useNetwork()
const loading = ref(true)
const saving = ref(false)
const saveSuccess = ref(false)
const saveError = ref('')
const uploadProgress = ref(0)

const profile = ref({
  full_name: '',
  email: '',
  phone: '',
  address: '',
  specialization: '',
  hire_date: '',
  photo_url: ''
})

const photoFile = ref(null)
const photoPreview = ref('')
const newPhotoUrl = ref('')

const SPECIALIZATION_OPTIONS = [
  'Lengua y Literatura',
  'Matematica',
  'Ciencias Naturales',
  'Estudios Sociales',
  'Educacion Cultural y Artistica',
  'Educacion Fisica',
  'Fisica',
  'Quimica',
  'Biologia',
  'Historia',
  'Geografia',
  'Filosofia',
  'Lengua Extranjera',
  'Informatica',
  'Religion',
  'Proyecto Interdisciplinario',
  'Orientacion Vocacional',
  'Otro'
]

onMounted(async () => {
  await fetchProfile()
})

const fetchProfile = async () => {
  loading.value = true
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (user) {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single()

      if (error) throw error

      if (data) {
        profile.value = {
          full_name: data.full_name || '',
          email: data.email || user.email,
          phone: data.phone || '',
          address: data.address || '',
          specialization: data.specialization || '',
          hire_date: data.hire_date || '',
          photo_url: data.photo_url || ''
        }
        photoPreview.value = data.photo_url || ''
      }
    }
  } catch (error) {
    console.error('Error fetching profile:', error)
    saveError.value = 'Error cargando perfil'
  }
  loading.value = false
}

const onPhotoChange = (event) => {
  const file = event.target.files?.[0] || null
  if (!file) return

  if (!file.type.startsWith('image/')) {
    saveError.value = 'Por favor selecciona una imagen'
    return
  }

  if (file.size > 5 * 1024 * 1024) {
    saveError.value = 'La imagen debe ser menor a 5MB'
    return
  }

  photoFile.value = file
  newPhotoUrl.value = ''

  const reader = new FileReader()
  reader.onload = (e) => {
    photoPreview.value = e.target?.result || ''
  }
  reader.readAsDataURL(file)
}

const uploadPhoto = async (userId) => {
  if (!photoFile.value) return null

  const ext = photoFile.value.name.split('.').pop()
  const fileName = `${userId}/profile-${Date.now()}.${ext}`
  const filePath = `profile-photos/${fileName}`

  const { data, error } = await supabase.storage
    .from('profile-photos')
    .upload(fileName, photoFile.value, {
      cacheControl: '3600',
      upsert: true
    })

  if (error) throw error

  const { data: { publicUrl } } = supabase.storage
    .from('profile-photos')
    .getPublicUrl(fileName)

  return publicUrl
}

const saveProfile = async () => {
  if (!isOnline.value) {
    saveError.value = 'Acción no permitida: Estás trabajando sin conexión.'
    return
  }
  saving.value = true
  saveError.value = ''
  saveSuccess.value = false

  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error('No hay usuario autenticado')

    let photoUrl = profile.value.photo_url

    if (photoFile.value) {
      photoUrl = await uploadPhoto(user.id)
    }

    const updates = {
      id: user.id,
      full_name: profile.value.full_name,
      phone: profile.value.phone || null,
      address: profile.value.address || null,
      specialization: profile.value.specialization || null,
      hire_date: profile.value.hire_date || null,
      photo_url: photoUrl || null
    }

    const { error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', user.id)

    if (error) throw error

    profile.value.photo_url = photoUrl
    photoFile.value = null
    saveSuccess.value = true

    setTimeout(() => {
      saveSuccess.value = false
    }, 3000)
  } catch (error) {
    console.error('Error saving profile:', error)
    saveError.value = error.message || 'Error guardando perfil'
  }

  saving.value = false
}

const removePhoto = () => {
  photoFile.value = null
  photoPreview.value = profile.value.photo_url || ''
  newPhotoUrl.value = ''
}
</script>

<template>
  <div class="app-shell">
    <main class="app-container">
      <div class="max-w-3xl mx-auto">
        <div class="mb-8">
          <h1 class="app-title">Mi Perfil</h1>
          <p class="text-slate-500 mt-1">Completa tu informacion personal y profesional</p>
        </div>

        <div v-if="loading" class="text-center py-12">
          <div class="animate-spin h-8 w-8 border-4 border-teal-500 border-t-transparent rounded-full mx-auto"></div>
          <p class="text-slate-500 mt-4">Cargando perfil...</p>
        </div>

        <div v-else class="app-card p-8 md:p-12 shadow-sm rounded-2xl border border-slate-200/60 bg-white">
          <form @submit.prevent="saveProfile" class="space-y-10">
            <!-- Foto de Perfil -->
            <div class="flex flex-col items-center pb-6 border-b border-slate-200">
              <div class="relative">
                <div class="h-32 w-32 rounded-full overflow-hidden bg-slate-200 border-4 border-white shadow-lg">
                  <img
                    v-if="photoPreview"
                    :src="photoPreview"
                    alt="Foto de perfil"
                    class="h-full w-full object-cover"
                  />
                  <div v-else class="h-full w-full flex items-center justify-center">
                    <svg class="h-16 w-16 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                  </div>
                </div>
                <label class="absolute bottom-0 right-0 h-10 w-10 bg-teal-500 hover:bg-teal-600 text-white rounded-full flex items-center justify-center cursor-pointer shadow-lg transition-colors">
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                  <input type="file" accept="image/*" class="hidden" @change="onPhotoChange" />
                </label>
              </div>
              <p class="text-sm text-slate-500 mt-3">Foto de perfil (max 5MB)</p>
              <button
                v-if="photoPreview && !photoFile"
                type="button"
                @click="removePhoto"
                class="text-sm text-rose-600 hover:text-rose-700 mt-1"
              >
                Eliminar foto
              </button>
            </div>

            <!-- Datos Personales -->
            <div>
              <h3 class="text-lg font-semibold text-slate-900 mb-4">Datos Personales</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="md:col-span-2">
                  <label class="block text-sm font-medium text-slate-700 mb-1">Nombre Completo</label>
                  <input
                    v-model="profile.full_name"
                    type="text"
                    required
                    class="app-input"
                    placeholder="Ingresa tu nombre completo"
                  />
                </div>

                <div class="md:col-span-2">
                  <label class="block text-sm font-medium text-slate-700 mb-1">Correo Electronico</label>
                  <input
                    v-model="profile.email"
                    type="email"
                    disabled
                    class="app-input bg-slate-100 cursor-not-allowed opacity-60"
                  />
                  <p class="text-xs text-slate-400 mt-1">El correo no se puede cambiar</p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-slate-700 mb-1">Telefono</label>
                  <input
                    v-model="profile.phone"
                    type="tel"
                    class="app-input"
                    placeholder="Ej: 0991234567"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-slate-700 mb-1">Fecha de Contratacion</label>
                  <input
                    v-model="profile.hire_date"
                    type="date"
                    class="app-input"
                  />
                </div>

                <div class="md:col-span-2">
                  <label class="block text-sm font-medium text-slate-700 mb-1">Direccion</label>
                  <textarea
                    v-model="profile.address"
                    rows="2"
                    class="app-input"
                    placeholder="Direccion de residencia"
                  ></textarea>
                </div>
              </div>
            </div>

            <!-- Datos Profesionales -->
            <div>
              <h3 class="text-lg font-semibold text-slate-900 mb-4">Datos Profesionales</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="md:col-span-2">
                  <label class="block text-sm font-medium text-slate-700 mb-1">Especializacion / Materia que Dicta</label>
                  <select v-model="profile.specialization" class="app-input">
                    <option value="">Selecciona una especializacion</option>
                    <option v-for="spec in SPECIALIZATION_OPTIONS" :key="spec" :value="spec">
                      {{ spec }}
                    </option>
                  </select>
                  <p class="text-xs text-slate-400 mt-1">Selecciona la materia principal que enseas</p>
                </div>
              </div>
            </div>

            <!-- Mensajes de estado -->
            <div v-if="saveError" class="rounded-xl bg-rose-50 border border-rose-200 p-4">
              <p class="text-sm text-rose-700">{{ saveError }}</p>
            </div>

            <div v-if="saveSuccess" class="rounded-xl bg-emerald-50 border border-emerald-200 p-4">
              <p class="text-sm text-emerald-700 flex items-center gap-2">
                <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Perfil guardado exitosamente
              </p>
            </div>

            <!-- Boton Guardar -->
            <div class="flex justify-end pt-4 border-t border-slate-200">
              <button
                type="submit"
                :disabled="saving"
                class="app-btn app-btn-primary px-8 disabled:opacity-60"
              >
                <svg v-if="saving" class="animate-spin h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                {{ saving ? 'Guardando...' : 'Guardar Perfil' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </main>
  </div>
</template>
