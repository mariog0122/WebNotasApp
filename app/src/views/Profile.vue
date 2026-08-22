<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useNetwork } from '../composables/useNetwork'
import { normalizeStoragePath, resolvePrivateImageUrl, uploadPrivateImage, validateImageFile } from '../lib/storageUtils'
import { isInstitutionAdmin } from '../lib/permissions'

import { toast } from 'vue-sonner'

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
const photoStoragePath = ref('')

const isSchoolAdmin = computed(() => isInstitutionAdmin(authStore.accessContext))
const isRectorOrAdmin = computed(() => {
  const currentRole = profile.value?.role || authStore.accessContext?.activeMembership?.role || authStore.userRole
  if (currentRole === 'teacher') return false
  return ['admin', 'school_admin', 'rector'].includes(currentRole) || authStore.accessContext?.isPlatformAdmin === true
})

const tenantSubscription = ref(null)
const studentCount = ref(0)

const uploadingProof = ref(false)
const proofUrl = ref('')
const proofFile = ref(null)

const fetchSubscription = async () => {
  if (!authStore.activeSchoolId) return
  try {
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id || profile.value?.school_id
    if (!schoolId) return

    const { count } = await supabase.from('students').select('*', { count: 'exact', head: true }).eq('school_id', schoolId)
    studentCount.value = count || 0

    const { data: sub } = await supabase
      .from('subscriptions')
      .select('*, plans(name, code, monthly_price, annual_price, student_limit, trial_days)')
      .eq('school_id', schoolId)
      .maybeSingle()
    const { data: limit } = await supabase.from('tenant_limits').select('*').eq('school_id', schoolId).maybeSingle()
    const { data: school } = await supabase.from('schools').select('name, status').eq('id', schoolId).maybeSingle()

    const status = sub?.status || school?.status || 'trial'
    const isTrial = status === 'trial'
    const effectiveDate = isTrial ? (sub?.trial_ends_at || sub?.next_billing_date) : sub?.next_billing_date

    let renewalDateStr = 'Sin fecha programada'
    let daysRemaining = null

    if (effectiveDate) {
      const dt = new Date(effectiveDate)
      renewalDateStr = dt.toLocaleDateString('es-EC', { year: 'numeric', month: 'short', day: 'numeric' })
      const diffMs = dt.getTime() - Date.now()
      daysRemaining = Math.ceil(diffMs / (1000 * 60 * 60 * 24))
    }

    const priceVal = sub?.agreed_price ?? (sub?.billing_cycle === 'yearly' ? sub?.plans?.annual_price : sub?.plans?.monthly_price) ?? 89

    tenantSubscription.value = {
      plan_name: sub?.plans?.name || 'Plan Institucional Estándar',
      price: priceVal,
      billing_cycle: sub?.billing_cycle || 'monthly',
      status: status,
      is_trial: isTrial,
      days_remaining: daysRemaining,
      renewal_date: renewalDateStr,
      raw_renewal_date: effectiveDate,
      max_students: limit?.max_students || sub?.plans?.student_limit || 500
    }

    const { data: billing } = await supabase
      .from('tenant_billing_profiles')
      .select('latest_receipt_url')
      .eq('school_id', schoolId)
      .maybeSingle()
    if (billing?.latest_receipt_url) {
      proofUrl.value = billing.latest_receipt_url
    }
  } catch (err) {
    console.error('Error fetching subscription in Profile:', err)
  }
}

const onProofFileChange = (e) => {
  const file = e.target.files?.[0]
  if (file) {
    proofFile.value = file
  }
}

const uploadProof = async () => {
  if (!proofFile.value) {
    toast.error('Selecciona una foto o imagen del comprobante de pago.')
    return
  }
  const targetSchoolId = authStore.activeSchoolId || authStore.profile?.school_id || profile.value?.school_id
  if (!targetSchoolId) {
    toast.error('No se pudo identificar la institución asociada a tu perfil.')
    return
  }

  uploadingProof.value = true
  try {
    const fileExt = proofFile.value.name.split('.').pop()
    const filePath = `receipts/${targetSchoolId}_${Date.now()}.${fileExt}`
    
    const { error: uploadErr } = await supabase.storage
      .from('billing-proofs')
      .upload(filePath, proofFile.value, { upsert: true })

    if (uploadErr) throw uploadErr

    const { data: publicUrlData } = supabase.storage
      .from('billing-proofs')
      .getPublicUrl(filePath)

    const publicUrl = publicUrlData?.publicUrl || filePath

    // 1. Invocar RPC canónico
    const { data: rpcRes, error: rpcErr } = await supabase.rpc('upload_tenant_payment_proof', {
      p_school_id: targetSchoolId,
      p_receipt_url: publicUrl,
      p_notes: 'Comprobante subido por usuario contratante'
    })

    if (rpcErr || !rpcRes?.success) {
      // 2. Fallback de inserción/actualización directa
      const { error: upsertErr } = await supabase
        .from('tenant_billing_profiles')
        .upsert({
          school_id: targetSchoolId,
          latest_receipt_url: publicUrl,
          updated_at: new Date().toISOString()
        }, { onConflict: 'school_id' })

      if (upsertErr) throw (rpcErr || upsertErr)
    }

    proofUrl.value = publicUrl
    toast.success('¡Foto de comprobante de pago cargada exitosamente!')
    proofFile.value = null
  } catch (err) {
    toast.error('Error al subir el comprobante: ' + (err.message || 'Verifica la conexión'))
  } finally {
    uploadingProof.value = false
  }
}

const SPECIALIZATION_OPTIONS = [
  'Rector / Rectora',
  'Vicerrector / Vicerrectora',
  'Inspector(a) General / Inspección',
  'Psicólogo(a) / DECE',
  'Secretaría / Colecturía',
  'Lengua y Literatura',
  'Matemática',
  'Ciencias Naturales',
  'Estudios Sociales',
  'Educación Cultural y Artística',
  'Educación Física',
  'Física',
  'Química',
  'Biología',
  'Historia',
  'Geografía',
  'Filosofía',
  'Lengua Extranjera (Inglés)',
  'Informática / Computación',
  'Religión / Formación Cristiana',
  'Proyecto Interdisciplinario',
  'Orientación Vocacional',
  'Otro'
]

onMounted(async () => {
  await fetchProfile()
  await fetchSubscription()
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
        photoStoragePath.value = normalizeStoragePath(data.photo_url, 'profile-photos')
        const signedPhotoUrl = await resolvePrivateImageUrl(
          supabase,
          'profile-photos',
          photoStoragePath.value,
        ).catch(() => '')
        profile.value = {
          role: data.role || 'teacher',
          full_name: data.full_name || '',
          email: data.email || user.email,
          phone: data.phone || '',
          address: data.address || '',
          specialization: data.specialization || '',
          hire_date: data.hire_date || '',
          photo_url: signedPhotoUrl
        }
        photoPreview.value = signedPhotoUrl
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

  try {
    validateImageFile(file)
  } catch (error) {
    saveError.value = error.message
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
  return uploadPrivateImage(supabase, 'profile-photos', photoFile.value, fileName)
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

    let photoPath = photoStoragePath.value

    if (photoFile.value) {
      photoPath = await uploadPhoto(user.id)
    }

    const updates = {
      id: user.id,
      full_name: profile.value.full_name,
      phone: profile.value.phone || null,
      address: profile.value.address || null,
      specialization: profile.value.specialization || null,
      hire_date: profile.value.hire_date || null,
      photo_url: photoPath || null
    }

    const { error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', user.id)

    if (error) throw error

    photoStoragePath.value = photoPath
    profile.value.photo_url = await resolvePrivateImageUrl(supabase, 'profile-photos', photoPath).catch(() => '')
    photoPreview.value = profile.value.photo_url
    if (authStore.profile) authStore.profile.photo_url = profile.value.photo_url
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
  photoPreview.value = ''
  newPhotoUrl.value = ''
}
</script>

<template>
  <div class="app-shell">
    <main class="app-container">
      <div class="max-w-3xl mx-auto">
        <div class="mb-8">
          <h1 class="app-title text-slate-900 dark:text-white">Mi Perfil</h1>
          <p class="text-slate-500 dark:text-slate-400 mt-1">Completa tu información personal y profesional</p>
        </div>

        <div v-if="loading" class="text-center py-12">
          <div class="animate-spin h-8 w-8 border-4 border-teal-500 border-t-transparent rounded-full mx-auto"></div>
          <p class="text-slate-500 dark:text-slate-400 mt-4">Cargando perfil...</p>
        </div>

        <div v-else class="app-card p-8 md:p-12 shadow-sm rounded-2xl border border-slate-200/60 dark:border-slate-800 bg-white dark:bg-slate-900">
          <form @submit.prevent="saveProfile" class="space-y-10">
            <!-- Foto de Perfil -->
            <div class="flex flex-col items-center pb-6 border-b border-slate-200 dark:border-slate-800">
              <div class="relative">
                <div class="h-32 w-32 rounded-full overflow-hidden bg-slate-200 dark:bg-slate-800 border-4 border-white dark:border-slate-700 shadow-lg">
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
              <p class="text-sm text-slate-500 dark:text-slate-400 mt-3">Foto de perfil (max 5MB)</p>
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
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">Datos Personales</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="md:col-span-2">
                  <label class="block text-sm font-semibold text-slate-700 dark:text-slate-200 mb-1">Nombre Completo</label>
                  <input
                    v-model="profile.full_name"
                    type="text"
                    required
                    class="app-input"
                    placeholder="Ingresa tu nombre completo"
                  />
                </div>

                <div class="md:col-span-2">
                  <label class="block text-sm font-semibold text-slate-700 dark:text-slate-200 mb-1">Correo Electrónico</label>
                  <input
                    v-model="profile.email"
                    type="email"
                    disabled
                    class="app-input bg-slate-100 dark:bg-slate-800/80 cursor-not-allowed opacity-60"
                  />
                  <p class="text-xs text-slate-400 mt-1">El correo no se puede cambiar</p>
                </div>

                <div>
                  <label class="block text-sm font-semibold text-slate-700 dark:text-slate-200 mb-1">Teléfono</label>
                  <input
                    v-model="profile.phone"
                    type="tel"
                    class="app-input"
                    placeholder="Ej: 0991234567"
                  />
                </div>

                <div>
                  <label class="block text-sm font-semibold text-slate-700 dark:text-slate-200 mb-1">Fecha de Contratación</label>
                  <input
                    v-model="profile.hire_date"
                    type="date"
                    class="app-input"
                  />
                </div>

                <div class="md:col-span-2">
                  <label class="block text-sm font-semibold text-slate-700 dark:text-slate-200 mb-1">Dirección</label>
                  <textarea
                    v-model="profile.address"
                    rows="2"
                    class="app-input"
                    placeholder="Dirección de residencia"
                  ></textarea>
                </div>
              </div>
            </div>

            <!-- Datos Profesionales -->
            <div>
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">Datos Profesionales</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="md:col-span-2">
                  <label class="block text-sm font-semibold text-slate-700 dark:text-slate-200 mb-1">Especialización / Materia que Dicta</label>
                  <select v-model="profile.specialization" class="app-input">
                    <option value="">Selecciona una especialización</option>
                    <option v-for="spec in SPECIALIZATION_OPTIONS" :key="spec" :value="spec">
                      {{ spec }}
                    </option>
                  </select>
                  <p class="text-xs text-slate-400 mt-1">Selecciona la materia principal que enseñas</p>
                </div>
              </div>
            </div>

            <!-- SUSCRIPCIÓN E INFORMACIÓN DE PLAN (Rector / Administrador Institucional únicamente) -->
            <div v-if="isRectorOrAdmin && tenantSubscription" class="pt-6 border-t border-slate-200 dark:border-slate-800">
              <div class="flex items-center justify-between mb-4">
                <div>
                  <h3 class="text-lg font-bold text-slate-900 dark:text-white">Suscripción & Plan Institucional</h3>
                  <p class="text-xs text-slate-500 dark:text-slate-400">Gestión de la licencia de uso y límites de estudiantes de tu colegio</p>
                </div>
                <span :class="[
                  'px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider border',
                  tenantSubscription.status === 'active' ? 'bg-emerald-100 dark:bg-emerald-950/80 text-emerald-800 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800' :
                  tenantSubscription.status === 'trial' ? 'bg-sky-100 dark:bg-sky-950/80 text-sky-800 dark:text-sky-300 border-sky-200 dark:border-sky-800' :
                  'bg-amber-100 dark:bg-amber-950/80 text-amber-800 dark:text-amber-300 border-amber-200 dark:border-amber-800'
                ]">
                  {{ tenantSubscription.status === 'trial' ? 'Período de Prueba' : tenantSubscription.status === 'active' ? 'Suscripción Activa' : tenantSubscription.status === 'past_due' ? 'Pago Vencido' : tenantSubscription.status === 'suspended' ? 'Suspendida' : tenantSubscription.status }}
                </span>
              </div>

              <div class="bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 space-y-4">
                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div>
                    <span class="text-xs text-slate-400 font-medium block">Plan Contratado</span>
                    <strong class="text-slate-900 dark:text-white text-sm block font-bold">{{ tenantSubscription.plan_name }}</strong>
                    <span class="text-xs text-indigo-600 dark:text-indigo-400 font-semibold">
                      ${{ tenantSubscription.price }} USD / {{ tenantSubscription.billing_cycle === 'yearly' ? 'año' : 'mes' }}
                    </span>
                  </div>

                  <div>
                    <span class="text-xs text-slate-400 font-medium block">Uso de Estudiantes</span>
                    <strong class="text-slate-900 dark:text-white text-sm block font-bold">{{ studentCount }} / {{ tenantSubscription.max_students }}</strong>
                    <div class="w-full bg-slate-200 dark:bg-slate-800 h-2 rounded-full mt-1.5 overflow-hidden">
                      <div class="bg-indigo-600 h-full rounded-full" :style="{ width: Math.min(100, (studentCount / tenantSubscription.max_students) * 100) + '%' }"></div>
                    </div>
                  </div>

                  <div>
                    <span class="text-xs text-slate-400 font-medium block">
                      {{ tenantSubscription.is_trial ? 'Fin de Período de Prueba' : 'Próxima Renovación' }}
                    </span>
                    <strong class="text-slate-900 dark:text-white text-sm block font-bold">{{ tenantSubscription.renewal_date }}</strong>
                    <span v-if="tenantSubscription.is_trial && tenantSubscription.days_remaining !== null" :class="tenantSubscription.days_remaining <= 3 ? 'text-rose-500 font-bold' : 'text-sky-500 font-semibold'" class="text-xs">
                      {{ tenantSubscription.days_remaining > 0 ? `${tenantSubscription.days_remaining} días restantes` : 'Prueba finalizada' }}
                    </span>
                    <span v-else class="text-xs text-slate-500 dark:text-slate-400">
                      Ciclo {{ tenantSubscription.billing_cycle === 'yearly' ? 'Anual' : 'Mensual' }}
                    </span>
                  </div>
                </div>

                <div class="pt-4 border-t border-slate-200/80 dark:border-slate-800 space-y-3">
                  <div class="flex items-center justify-between">
                    <div>
                      <span class="text-xs font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wider block">Comprobante de Pago o Factura</span>
                      <span class="text-xs text-slate-500 dark:text-slate-400 block">Sube una foto o imagen del recibo/transferencia bancaria para verificación del superadmin.</span>
                    </div>
                  </div>

                  <div v-if="proofUrl" class="p-3 bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800/60 rounded-xl flex items-center justify-between gap-3 text-xs">
                    <span class="text-emerald-800 dark:text-emerald-300 font-semibold flex items-center gap-1.5">
                      ✓ Foto de comprobante cargada
                    </span>
                    <a :href="proofUrl" target="_blank" rel="noopener noreferrer" class="font-bold text-emerald-700 dark:text-emerald-400 underline hover:text-emerald-900">
                      Ver comprobante 👁️
                    </a>
                  </div>

                  <div class="flex flex-col sm:flex-row items-center gap-3">
                    <input 
                      type="file" 
                      accept="image/jpeg,image/png,image/webp,application/pdf"
                      @change="onProofFileChange"
                      class="block w-full text-xs text-slate-500 dark:text-slate-400 file:mr-3 file:py-2 file:px-4 file:rounded-xl file:border-0 file:text-xs file:font-semibold file:bg-indigo-50 dark:file:bg-indigo-950 file:text-indigo-700 dark:file:text-indigo-300 hover:file:bg-indigo-100"
                    />
                    <button 
                      type="button" 
                      @click="uploadProof"
                      :disabled="uploadingProof || !proofFile"
                      class="w-full sm:w-auto whitespace-nowrap px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl font-bold text-xs shadow-sm disabled:opacity-50 transition-all flex items-center justify-center gap-1.5"
                    >
                      {{ uploadingProof ? 'Subiendo…' : '📤 Cargar Comprobante' }}
                    </button>
                  </div>
                </div>

                <div class="pt-3 border-t border-slate-200/80 dark:border-slate-800 flex flex-wrap items-center justify-between gap-3 text-xs">
                  <span class="text-slate-500 dark:text-slate-400">Para cambios de plan o ampliación de estudiantes, contáctanos directamente.</span>
                  <div class="flex items-center gap-3">
                    <router-link to="/planes" class="font-bold text-indigo-600 dark:text-indigo-400 hover:text-indigo-700">Ver planes disponibles →</router-link>
                  </div>
                </div>
              </div>
            </div>

            <!-- Mensajes de estado -->
            <div v-if="saveError" class="rounded-xl bg-rose-50 dark:bg-rose-950/50 border border-rose-200 dark:border-rose-800 p-4">
              <p class="text-sm text-rose-700 dark:text-rose-300">{{ saveError }}</p>
            </div>

            <div v-if="saveSuccess" class="rounded-xl bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800 p-4">
              <p class="text-sm text-emerald-700 dark:text-emerald-300 flex items-center gap-2">
                <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Perfil guardado exitosamente
              </p>
            </div>

            <!-- Botón Guardar -->
            <div class="flex justify-end pt-4 border-t border-slate-200 dark:border-slate-800">
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
