<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useNetwork } from '../composables/useNetwork'
import { normalizeStoragePath, resolvePrivateImageUrl, uploadPrivateImage, validateImageFile } from '../lib/storageUtils'
import { isInstitutionAdmin } from '../lib/permissions'
import { resolveBillingProofUrl, uploadBillingProof } from '../lib/billingProofs'
import { getMfaStatus, enrollTotpFactor, verifyAndActivateFactor, unenrollFactor } from '../lib/mfa'
import { translateError } from '../lib/errorDictionary'
import { ShieldCheck, ShieldAlert, QrCode, Copy, Smartphone, KeyRound, Check, Trash2, X } from 'lucide-vue-next'

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
const subscriptionError = ref('')

const uploadingProof = ref(false)
const proofUrl = ref('')
const proofFile = ref(null)

const fetchSubscription = async () => {
  subscriptionError.value = ''
  tenantSubscription.value = null
  proofUrl.value = ''
  try {
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id || profile.value?.school_id
    if (!schoolId) return

    const [studentsResult, subscriptionResult, limitResult, schoolResult, billingResult] = await Promise.all([
      supabase.from('students').select('*', { count: 'exact', head: true }).eq('school_id', schoolId),
      supabase
        .from('subscriptions')
        .select('*, plans(name, code, monthly_price, annual_price, student_limit, trial_days)')
        .eq('school_id', schoolId)
        .maybeSingle(),
      supabase.from('tenant_limits').select('*').eq('school_id', schoolId).maybeSingle(),
      supabase.from('schools').select('name, status').eq('id', schoolId).maybeSingle(),
      supabase
        .from('tenant_billing_profiles')
        .select('latest_receipt_url')
        .eq('school_id', schoolId)
        .maybeSingle(),
    ])
    const failedResult = [studentsResult, subscriptionResult, limitResult, schoolResult, billingResult]
      .find(result => result.error)
    if (failedResult?.error) throw failedResult.error

    const { count } = studentsResult
    const sub = subscriptionResult.data
    const limit = limitResult.data
    const school = schoolResult.data
    const billing = billingResult.data
    studentCount.value = count ?? 0

    const status = sub?.status || school?.status || 'unconfigured'
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

    const priceVal = sub
      ? (sub.agreed_price ?? (sub.billing_cycle === 'yearly' ? sub.plans?.annual_price : sub.plans?.monthly_price) ?? null)
      : null

    tenantSubscription.value = {
      plan_name: sub?.plans?.name || (sub ? 'Plan sin catálogo asociado' : 'Sin plan asignado'),
      price: priceVal,
      billing_cycle: sub?.billing_cycle || null,
      status: status,
      is_trial: isTrial,
      days_remaining: daysRemaining,
      renewal_date: renewalDateStr,
      raw_renewal_date: effectiveDate,
      max_students: limit?.max_students ?? sub?.plans?.student_limit ?? null,
    }

    if (billing?.latest_receipt_url) {
      proofUrl.value = await resolveBillingProofUrl(supabase, billing.latest_receipt_url).catch(() => '')
    }
  } catch (err) {
    console.error('Error fetching subscription in Profile:', err)
    tenantSubscription.value = null
    subscriptionError.value = `No se pudo cargar la suscripción: ${translateError(err)}`
  }
}

const onProofFileChange = (e) => {
  const file = e.target.files?.[0]
  if (file) {
    proofFile.value = file
  }
}

const uploadProof = async () => {
  if (uploadingProof.value) return
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
    const filePath = await uploadBillingProof(supabase, targetSchoolId, proofFile.value)

    const { data: rpcRes, error: rpcErr } = await supabase.rpc('upload_tenant_payment_proof', {
      p_school_id: targetSchoolId,
      p_receipt_url: filePath,
      p_notes: 'Comprobante subido por usuario contratante'
    })

    if (rpcErr || !rpcRes?.success) {
      throw (rpcErr || new Error(rpcRes?.message || 'No se pudo registrar el comprobante.'))
    }

    proofUrl.value = await resolveBillingProofUrl(supabase, filePath)
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
  await loadMfaStatus()
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

// ==========================================
// ESTADO Y MÉTODOS 2FA / MFA (TOTP)
// ==========================================
const mfaLoading = ref(false)
const mfaEnrolled = ref(false)
const mfaFactors = ref([])
const showEnrollModal = ref(false)
const showUnenrollModal = ref(false)

const enrollData = ref({
  factorId: '',
  qrCode: '',
  secret: '',
  uri: '',
})
const verificationCode = ref('')
const verifyingCode = ref(false)
const unenrolling = ref(false)
const copiedSecret = ref(false)

const loadMfaStatus = async () => {
  mfaLoading.value = true
  try {
    const status = await getMfaStatus()
    mfaEnrolled.value = status.isEnrolled
    mfaFactors.value = status.verifiedFactors || []
  } catch (err) {
    console.error('Error al consultar estado MFA:', err)
  } finally {
    mfaLoading.value = false
  }
}

const startEnrollment = async () => {
  mfaLoading.value = true
  verificationCode.value = ''
  try {
    const res = await enrollTotpFactor({ issuer: 'LOGREVA' })
    enrollData.value = res
    showEnrollModal.value = true
  } catch (err) {
    toast.error('No se pudo iniciar la configuración 2FA', {
      description: err?.message || 'Inténtalo nuevamente en unos momentos.'
    })
  } finally {
    mfaLoading.value = false
  }
}

const copySecretToClipboard = async () => {
  if (!enrollData.value.secret) return
  try {
    await navigator.clipboard.writeText(enrollData.value.secret)
    copiedSecret.value = true
    toast.success('Clave copiada al portapapeles')
    setTimeout(() => {
      copiedSecret.value = false
    }, 3000)
  } catch {
    toast.info('Clave secreta', { description: enrollData.value.secret })
  }
}

const confirmEnrollment = async () => {
  const code = verificationCode.value.trim().replace(/\s+/g, '')
  if (!code || code.length !== 6) {
    toast.warning('Código inválido', { description: 'Ingresa los 6 dígitos que muestra tu app autenticadora.' })
    return
  }

  verifyingCode.value = true
  try {
    await verifyAndActivateFactor({ factorId: enrollData.value.factorId, code })
    toast.success('¡Autenticación en Dos Pasos activada!', {
      description: 'Tu cuenta ahora está protegida con verificación TOTP.'
    })
    showEnrollModal.value = false
    verificationCode.value = ''
    enrollData.value = { factorId: '', qrCode: '', secret: '', uri: '' }
    await loadMfaStatus()
  } catch (err) {
    toast.error('Código incorrecto', {
      description: 'El código no coincide o ha expirado. Verifica la hora de tu celular e inténtalo nuevamente.'
    })
  } finally {
    verifyingCode.value = false
  }
}

const confirmUnenroll = async () => {
  const factor = mfaFactors.value[0]
  if (!factor?.id) return

  unenrolling.value = true
  try {
    await unenrollFactor({ factorId: factor.id })
    toast.success('2FA desactivado', { description: 'Se ha eliminado el factor de autenticación.' })
    showUnenrollModal.value = false
    await loadMfaStatus()
  } catch (err) {
    toast.error('Error al desactivar 2FA', { description: err?.message || 'Inténtalo nuevamente.' })
  } finally {
    unenrolling.value = false
  }
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
            <div v-if="isRectorOrAdmin && subscriptionError" class="pt-6 border-t border-slate-200 dark:border-slate-800">
              <div class="rounded-xl bg-rose-50 dark:bg-rose-950/50 border border-rose-200 dark:border-rose-800 p-4">
                <p class="text-sm text-rose-700 dark:text-rose-300">{{ subscriptionError }}</p>
              </div>
            </div>

            <div v-else-if="isRectorOrAdmin && tenantSubscription" class="pt-6 border-t border-slate-200 dark:border-slate-800">
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
                    <span v-if="tenantSubscription.price !== null" class="text-xs text-indigo-600 dark:text-indigo-400 font-semibold">
                      ${{ tenantSubscription.price }} USD / {{ tenantSubscription.billing_cycle === 'yearly' ? 'año' : 'mes' }}
                    </span>
                    <span v-else class="text-xs text-slate-500 dark:text-slate-400">Precio pendiente de configuración</span>
                  </div>

                  <div>
                    <span class="text-xs text-slate-400 font-medium block">Uso de Estudiantes</span>
                    <strong class="text-slate-900 dark:text-white text-sm block font-bold">{{ studentCount }} / {{ tenantSubscription.max_students ?? 'Sin límite asignado' }}</strong>
                    <div v-if="tenantSubscription.max_students > 0" class="w-full bg-slate-200 dark:bg-slate-800 h-2 rounded-full mt-1.5 overflow-hidden">
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
                    <span v-else-if="tenantSubscription.billing_cycle" class="text-xs text-slate-500 dark:text-slate-400">
                      Ciclo {{ tenantSubscription.billing_cycle === 'yearly' ? 'Anual' : 'Mensual' }}
                    </span>
                    <span v-else class="text-xs text-slate-500 dark:text-slate-400">Ciclo pendiente de configuración</span>
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

        <!-- TARJETA DE SEGURIDAD 2FA (TOTP) -->
        <div class="mt-8 app-card p-8 md:p-10 shadow-sm rounded-2xl border border-slate-200/60 dark:border-slate-800 bg-white dark:bg-slate-900">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-6 border-b border-slate-200 dark:border-slate-800">
            <div class="flex items-start gap-3">
              <div class="p-2.5 rounded-xl bg-indigo-50 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400">
                <ShieldCheck class="w-6 h-6" />
              </div>
              <div>
                <h3 class="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
                  Seguridad y Autenticación en Dos Pasos (2FA)
                  <span
                    v-if="mfaEnrolled"
                    class="text-xs px-2.5 py-0.5 rounded-full font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800"
                  >
                    ACTIVO
                  </span>
                  <span
                    v-else
                    class="text-xs px-2.5 py-0.5 rounded-full font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300 border border-amber-300 dark:border-amber-800"
                  >
                    NO CONFIGURADO
                  </span>
                </h3>
                <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
                  Protege tu cuenta institucional agregando un segundo paso de verificación mediante Google Authenticator, Microsoft Authenticator o Authy.
                </p>
              </div>
            </div>

            <div class="flex items-center gap-3">
              <button
                v-if="!mfaEnrolled"
                type="button"
                @click="startEnrollment"
                :disabled="mfaLoading"
                class="px-4 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-sm font-semibold shadow-sm transition-all flex items-center gap-2"
              >
                <Smartphone class="w-4 h-4" />
                <span>Configurar 2FA</span>
              </button>
              <button
                v-else
                type="button"
                @click="showUnenrollModal = true"
                class="px-4 py-2 bg-rose-50 hover:bg-rose-100 dark:bg-rose-950/40 dark:hover:bg-rose-900/60 text-rose-700 dark:text-rose-300 border border-rose-200 dark:border-rose-800 rounded-xl text-sm font-semibold transition-all flex items-center gap-2"
              >
                <Trash2 class="w-4 h-4" />
                <span>Desactivar 2FA</span>
              </button>
            </div>
          </div>

          <div class="pt-6 grid grid-cols-1 md:grid-cols-3 gap-4 text-xs text-slate-500 dark:text-slate-400">
            <div class="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200/60 dark:border-slate-800 flex items-start gap-3">
              <div class="text-indigo-500 font-bold text-base">1</div>
              <div>
                <p class="font-bold text-slate-800 dark:text-slate-200 text-sm">Mayor Protección</p>
                <p class="mt-0.5">Evita accesos no autorizados aunque tu contraseña se vea comprometida.</p>
              </div>
            </div>
            <div class="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200/60 dark:border-slate-800 flex items-start gap-3">
              <div class="text-indigo-500 font-bold text-base">2</div>
              <div>
                <p class="font-bold text-slate-800 dark:text-slate-200 text-sm">Estándar TOTP</p>
                <p class="mt-0.5">Compatible con cualquier aplicación estándar RFC 6238 en tu celular o tablet.</p>
              </div>
            </div>
            <div class="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200/60 dark:border-slate-800 flex items-start gap-3">
              <div class="text-indigo-500 font-bold text-base">3</div>
              <div>
                <p class="font-bold text-slate-800 dark:text-slate-200 text-sm">Auditoría y Confianza</p>
                <p class="mt-0.5">Cumple con las mejores prácticas de ciberseguridad para datos educativos.</p>
              </div>
            </div>
          </div>
        </div>

        <!-- MODAL DE ENROLAMIENTO 2FA -->
        <div
          v-if="showEnrollModal"
          class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-sm"
          role="dialog"
          aria-modal="true"
          aria-label="Configurar Autenticación en Dos Pasos"
        >
          <div class="bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 max-w-md w-full p-6 sm:p-8 relative space-y-6">
            <button
              type="button"
              @click="showEnrollModal = false"
              class="absolute top-4 right-4 p-2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 rounded-lg"
              aria-label="Cerrar modal"
            >
              <X class="w-5 h-5" />
            </button>

            <div class="text-center space-y-2">
              <div class="inline-flex p-3 rounded-2xl bg-indigo-50 dark:bg-indigo-950/70 text-indigo-600 dark:text-indigo-400">
                <QrCode class="w-8 h-8" />
              </div>
              <h3 class="text-xl font-bold text-slate-900 dark:text-white">Configurar Autenticador</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400 max-w-sm mx-auto">
                Escanea el código QR con Google Authenticator, Microsoft Authenticator o Authy.
              </p>
            </div>

            <!-- Visualización del QR (SVG provisto por GoTrue) -->
            <div class="p-4 bg-slate-50 dark:bg-slate-950 rounded-2xl border border-slate-200/80 dark:border-slate-800 flex flex-col items-center">
              <div
                v-if="enrollData.qrCode"
                class="w-48 h-48 bg-white p-2 rounded-xl shadow-inner flex items-center justify-center [&>svg]:w-full [&>svg]:h-full"
                v-html="enrollData.qrCode"
              ></div>
              <div v-else class="w-48 h-48 flex items-center justify-center text-slate-400 text-xs">
                Generando código...
              </div>

              <!-- Clave secreta manual -->
              <div class="mt-4 w-full">
                <p class="text-[11px] text-slate-400 text-center mb-1">¿No puedes escanear? Ingresa la clave manualmente:</p>
                <div class="flex items-center gap-2 bg-white dark:bg-slate-900 p-2 rounded-xl border border-slate-200 dark:border-slate-700">
                  <span class="font-mono text-xs text-slate-700 dark:text-slate-300 flex-1 truncate select-all px-1">
                    {{ enrollData.secret }}
                  </span>
                  <button
                    type="button"
                    @click="copySecretToClipboard"
                    class="px-2.5 py-1 text-xs font-semibold rounded-lg bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 flex items-center gap-1 transition-colors"
                  >
                    <Check v-if="copiedSecret" class="w-3.5 h-3.5 text-emerald-600" />
                    <Copy v-else class="w-3.5 h-3.5" />
                    <span>{{ copiedSecret ? 'Copiado' : 'Copiar' }}</span>
                  </button>
                </div>
              </div>
            </div>

            <!-- Paso de confirmación con código de 6 dígitos -->
            <form @submit.prevent="confirmEnrollment" class="space-y-4">
              <div>
                <label for="verify-mfa-code" class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1 text-center">
                  Ingresa el código de 6 dígitos que muestra tu app:
                </label>
                <input
                  id="verify-mfa-code"
                  v-model="verificationCode"
                  type="text"
                  inputmode="numeric"
                  pattern="[0-9]*"
                  maxlength="6"
                  required
                  placeholder="000000"
                  class="app-input text-center font-mono tracking-[0.25em] text-lg font-bold"
                  autofocus
                />
              </div>

              <div class="flex items-center gap-3">
                <button
                  type="button"
                  @click="showEnrollModal = false"
                  class="flex-1 px-4 py-2.5 text-sm font-semibold rounded-xl border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  :disabled="verifyingCode || verificationCode.trim().length < 6"
                  class="flex-1 px-4 py-2.5 text-sm font-bold rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white disabled:opacity-50 transition-colors"
                >
                  {{ verifyingCode ? 'Verificando...' : 'Activar 2FA' }}
                </button>
              </div>
            </form>
          </div>
        </div>

        <!-- MODAL DESACTIVAR 2FA -->
        <div
          v-if="showUnenrollModal"
          class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-sm"
          role="dialog"
          aria-modal="true"
          aria-label="Confirmar desactivación de 2FA"
        >
          <div class="bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 max-w-sm w-full p-6 text-center space-y-4">
            <div class="inline-flex p-3 rounded-2xl bg-rose-50 dark:bg-rose-950/70 text-rose-600 dark:text-rose-400">
              <ShieldAlert class="w-8 h-8" />
            </div>
            <h3 class="text-lg font-bold text-slate-900 dark:text-white">¿Desactivar Verificación 2FA?</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              Tu cuenta ya no requerirá el código temporal de tu autenticador para iniciar sesión. Podrás volver a configurarlo en cualquier momento.
            </p>
            <div class="flex items-center gap-3 pt-2">
              <button
                type="button"
                @click="showUnenrollModal = false"
                class="flex-1 px-4 py-2.5 text-sm font-semibold rounded-xl border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
              >
                Mantener 2FA
              </button>
              <button
                type="button"
                @click="confirmUnenroll"
                :disabled="unenrolling"
                class="flex-1 px-4 py-2.5 text-sm font-bold rounded-xl bg-rose-600 hover:bg-rose-700 text-white disabled:opacity-50 transition-colors"
              >
                {{ unenrolling ? 'Desactivando...' : 'Sí, desactivar' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>
