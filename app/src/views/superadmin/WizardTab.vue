<script setup>
import { computed, ref, onMounted } from 'vue'
import { supabase } from '../../lib/supabase'
import { Building2, User, CreditCard, Receipt, CheckCircle2, ChevronRight, ChevronLeft, Save, Eye, EyeOff } from 'lucide-vue-next'
import { toast } from 'vue-sonner'
import { getProvinces, getCantons, getParishes } from '../../data/ecuadorData'

const emit = defineEmits(['completed'])

const currentStep = ref(1)
const saving = ref(false)
const showAdminPassword = ref(false)

const plans = ref([])

const selectedPlan = computed(() => plans.value.find((plan) => plan.id === form.value.planId) || null)
const selectedPrice = computed(() => {
  if (!selectedPlan.value) return 0

  return form.value.billingCycle === 'yearly'
    ? Number(selectedPlan.value.annual_price ?? selectedPlan.value.price * 10)
    : Number(selectedPlan.value.monthly_price ?? selectedPlan.value.price)
})

const form = ref({
  // PASO 1
  name: '',
  tradeName: '',
  code: '',
  country: 'Ecuador',
  province: 'Santa Elena',
  city: 'Santa Elena',
  parish: 'Santa Elena (Cabecera)',
  timezone: 'America/Guayaquil',

  // PASO 2
  adminName: '',
  adminEmail: '',
  adminPassword: '',
  adminPhone: '+593 ',

  // PASO 3
  planId: '',
  billingCycle: 'monthly',

  // PASO 4
  paymentMethod: 'transfer',
  startDate: new Date().toISOString().split('T')[0]
})

const provincesList = computed(() => getProvinces())

const cantonsList = computed(() => {
  if (form.value.country !== 'Ecuador') return []
  return getCantons(form.value.province)
})

const parishesList = computed(() => {
  if (form.value.country !== 'Ecuador') return []
  return getParishes(form.value.province, form.value.city)
})

const onProvinceChange = () => {
  if (form.value.country === 'Ecuador') {
    const cantons = getCantons(form.value.province)
    if (cantons.length > 0) {
      form.value.city = cantons[0]
      onCityChange()
    } else {
      form.value.city = ''
      form.value.parish = ''
    }
  }
}

const onCityChange = () => {
  if (form.value.country === 'Ecuador') {
    const parishes = getParishes(form.value.province, form.value.city)
    form.value.parish = parishes.length > 0 ? parishes[0] : ''
  }
}

const fetchPlans = async () => {
  const { data } = await supabase
    .from('plans')
    .select('*')
    .eq('active', true)
    .neq('code', 'trial')
    .order('student_limit')
  plans.value = data || []
  if (plans.value.length > 0) {
    form.value.planId = plans.value[0].id
  }
}

const onPlanSelect = (plan) => {
  form.value.planId = plan.id
}

const nextStep = async () => {
  if (currentStep.value === 1) {
    if (!form.value.name?.trim()) {
      toast.error('El nombre institucional es obligatorio.')
      return
    }
  }
  if (currentStep.value === 2) {
    if (!form.value.adminName?.trim()) {
      toast.error('Ingresa los nombres completos del administrador.')
      return
    }
    if (!form.value.adminEmail?.trim() || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.value.adminEmail.trim())) {
      toast.error('Ingresa un correo electrónico válido para el administrador.')
      return
    }
    const cleanPhone = (form.value.adminPhone || '').trim()
    const digitsOnly = cleanPhone.replace(/\D/g, '')
    if (!cleanPhone || cleanPhone === '+593' || digitsOnly.length < 8) {
      toast.error('El número de teléfono del administrador es obligatorio.')
      return
    }
    if ((form.value.adminPassword || '').length < 8) {
      toast.error('La contraseña debe tener al menos 8 caracteres.')
      return
    }

    // Verificar en Supabase si el número de teléfono ya está registrado
    saving.value = true
    try {
      const { data: existingProfiles, error: phoneErr } = await supabase
        .from('profiles')
        .select('id, full_name, email, phone')
        .or(`phone.eq.${cleanPhone},phone.eq.${digitsOnly}`)
        .limit(1)

      if (!phoneErr && existingProfiles && existingProfiles.length > 0) {
        toast.error(`El número de teléfono ${cleanPhone} ya está registrado en el sistema. Debe usar un número diferente para el administrador del colegio.`)
        return
      }
    } catch (err) {
      console.warn('Error verificando teléfono:', err)
    } finally {
      saving.value = false
    }
  }
  if (currentStep.value < 5) {
    currentStep.value++
  }
}

const prevStep = () => {
  if (currentStep.value > 1) {
    currentStep.value--
  }
}

const createdSuccessData = ref(null)

const submitWizard = async () => {
  saving.value = true
  try {
    const fullCity = form.value.parish
      ? `${form.value.city} (${form.value.parish})`
      : form.value.city

    const { data, error } = await supabase.functions.invoke('provision-tenant', {
      body: {
        name: form.value.name,
        tradeName: form.value.tradeName || form.value.name,
        code: form.value.code || form.value.name.substring(0, 4).toUpperCase(),
        country: form.value.country,
        province: form.value.province,
        city: fullCity,
        timezone: form.value.timezone,
        adminName: form.value.adminName,
        adminEmail: form.value.adminEmail,
        adminPassword: form.value.adminPassword,
        adminPhone: form.value.adminPhone,
        planId: form.value.planId,
        billingCycle: form.value.billingCycle
      }
    })

    if (error) {
      let msg = error.message || 'Error en provisioning'
      try {
        if (error.context && typeof error.context.json === 'function') {
          const body = await error.context.json()
          if (body?.message) msg = body.message
        }
      } catch {}
      throw new Error(msg)
    }

    if (data?.success) {
      toast.success(data.message || '¡Institución y administrador creados!')
      createdSuccessData.value = {
        schoolName: form.value.name,
        adminName: form.value.adminName,
        email: form.value.adminEmail,
        password: form.value.adminPassword,
        loginUrl: data.loginUrl || 'https://sandybrown-alpaca-347737.hostingersite.com/',
        accountCreated: data.account_created !== false
      }
      currentStep.value = 6
    } else {
      toast.error('Error en provisioning: ' + (data?.message || 'Operación fallida'))
    }
  } catch (err) {
    toast.error('Error creando institución: ' + err.message)
  } finally {
    saving.value = false
  }
}

const getWelcomeMessage = () => {
  if (!createdSuccessData.value) return ''
  return `🏫 *${createdSuccessData.value.schoolName}*\n¡Hola ${createdSuccessData.value.adminName}! Usuario creado exitosamente en el sistema LOGREVA para tu institución.\n\n🌐 *Enlace de acceso:* ${createdSuccessData.value.loginUrl}\n✉️ *Usuario/Correo:* ${createdSuccessData.value.email}\n🔑 *Contraseña:* ${createdSuccessData.value.password || '(Contraseña existente)'}`
}

const copyWelcomeMessage = async () => {
  const msg = getWelcomeMessage()
  if (!msg) return
  try {
    await navigator.clipboard.writeText(msg)
    toast.success('¡Mensaje de bienvenida copiado al portapapeles!')
  } catch {
    toast.error('No se pudo copiar automáticamente.')
  }
}

const whatsappShareUrl = computed(() => {
  const msg = getWelcomeMessage()
  if (!msg) return '#'
  const phone = form.value.adminPhone ? form.value.adminPhone.replace(/\D/g, '') : ''
  const encodedText = encodeURIComponent(msg)
  return phone ? `https://api.whatsapp.com/send?phone=${phone}&text=${encodedText}` : `https://api.whatsapp.com/send?text=${encodedText}`
})

const finishWizard = () => {
  emit('completed')
}

onMounted(() => {
  fetchPlans()
})
</script>

<template>
  <div class="max-w-4xl mx-auto space-y-8 bg-white dark:bg-slate-900/80 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 shadow-sm">
    <div>
      <h2 class="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">Asistente de Registro de Nueva Institución</h2>
      <p class="text-slate-600 dark:text-slate-400 text-sm mt-1">Aprovisionamiento seguro e integral de instituciones educativas.</p>
    </div>

    <!-- Stepper Navigation -->
    <div class="grid grid-cols-5 gap-2 border-b border-slate-200 dark:border-slate-800 pb-6 text-center">
      <div 
        v-for="s in [1,2,3,4,5]" 
        :key="s"
        :class="[
          'flex flex-col items-center gap-1.5 transition-colors',
          currentStep === s ? 'text-indigo-600 dark:text-indigo-400 font-bold' : s < currentStep ? 'text-emerald-600 dark:text-emerald-400' : 'text-slate-400 dark:text-slate-600'
        ]"
      >
        <div :class="[
          'w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all',
          currentStep === s ? 'bg-indigo-600 text-white shadow-sm ring-4 ring-indigo-600/20' :
          s < currentStep ? 'bg-emerald-50 dark:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-500/40' : 'bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400'
        ]">
          <CheckCircle2 v-if="s < currentStep" class="w-4 h-4" />
          <span v-else>{{ s }}</span>
        </div>
        <span class="text-xs hidden sm:block">
          {{ s === 1 ? 'Datos' : s === 2 ? 'Admin' : s === 3 ? 'Plan' : s === 4 ? 'Pago' : 'Confirmación' }}
        </span>
      </div>
    </div>

    <!-- PASO 1: DATOS INSTITUCIONALES -->
    <div v-if="currentStep === 1" class="space-y-4">
      <h3 class="font-bold text-lg text-slate-900 dark:text-white flex items-center gap-2 border-b border-slate-200 dark:border-slate-800/80 pb-2">
        <Building2 class="w-5 h-5 text-indigo-600 dark:text-indigo-400" /> Paso 1: Datos Institucionales
      </h3>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Nombre Oficial *</label>
          <input v-model="form.name" type="text" placeholder="Ej. Unidad Educativa San José" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 placeholder:text-slate-400 dark:placeholder:text-slate-500" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Nombre Comercial</label>
          <input v-model="form.tradeName" type="text" placeholder="Ej. Colegio San José" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 placeholder:text-slate-400 dark:placeholder:text-slate-500" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Código Único Institucional</label>
          <input v-model="form.code" type="text" placeholder="Ej. CSJ-001" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 placeholder:text-slate-400 dark:placeholder:text-slate-500" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">País</label>
          <input v-model="form.country" type="text" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Provincia</label>
          <select 
            v-if="form.country === 'Ecuador'" 
            v-model="form.province" 
            @change="onProvinceChange" 
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer"
          >
            <option v-for="prov in provincesList" :key="prov" :value="prov">{{ prov }}</option>
          </select>
          <input v-else v-model="form.province" type="text" placeholder="Ej. Guayas / Santa Elena" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 placeholder:text-slate-400 dark:placeholder:text-slate-500" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Ciudad / Cantón</label>
          <select 
            v-if="form.country === 'Ecuador'" 
            v-model="form.city" 
            @change="onCityChange" 
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer"
          >
            <option v-for="canton in cantonsList" :key="canton" :value="canton">{{ canton }}</option>
          </select>
          <input v-else v-model="form.city" type="text" placeholder="Ej. Guayaquil / La Libertad" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 placeholder:text-slate-400 dark:placeholder:text-slate-500" />
        </div>
        <div v-if="form.country === 'Ecuador'">
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Parroquia</label>
          <select 
            v-model="form.parish" 
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer"
          >
            <option v-for="parish in parishesList" :key="parish" :value="parish">{{ parish }}</option>
          </select>
        </div>
      </div>
    </div>

    <!-- PASO 2: ADMINISTRADOR -->
    <div v-if="currentStep === 2" class="space-y-4">
      <h3 class="font-bold text-lg text-slate-900 dark:text-white flex items-center gap-2 border-b border-slate-200 dark:border-slate-800/80 pb-2">
        <User class="w-5 h-5 text-indigo-600 dark:text-indigo-400" /> Paso 2: Administrador Inicial (Rector/Directiva)
      </h3>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Nombres Completos *</label>
          <input v-model="form.adminName" type="text" placeholder="Ej. Dr. Carlos Mendoza" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 placeholder:text-slate-400 dark:placeholder:text-slate-500" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Correo Electrónico *</label>
          <input v-model="form.adminEmail" type="email" placeholder="rector@colegiosanjose.edu.ec" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 placeholder:text-slate-400 dark:placeholder:text-slate-500" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Teléfono Móvil *</label>
          <div class="relative flex items-center">
            <span class="absolute left-3 flex items-center text-base leading-none select-none pointer-events-none" role="img" aria-label="Bandera de Ecuador">
              🇪🇨
            </span>
            <input 
              v-model="form.adminPhone" 
              type="tel" 
              placeholder="+593 99 123 4567" 
              class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 pl-10 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 placeholder:text-slate-400 dark:placeholder:text-slate-500" 
            />
          </div>
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Contraseña de acceso *</label>
          <div class="relative">
            <input 
              v-model="form.adminPassword" 
              :type="showAdminPassword ? 'text' : 'password'" 
              minlength="8" 
              autocomplete="new-password" 
              placeholder="Mínimo 8 caracteres" 
              class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 pr-10 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500 placeholder:text-slate-400 dark:placeholder:text-slate-500" 
            />
            <button 
              type="button" 
              @click="showAdminPassword = !showAdminPassword" 
              class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-700 dark:hover:text-white transition p-1 cursor-pointer"
              :title="showAdminPassword ? 'Ocultar contraseña' : 'Ver contraseña'"
            >
              <EyeOff v-if="showAdminPassword" class="w-4 h-4" />
              <Eye v-else class="w-4 h-4" />
            </button>
          </div>
          <p class="mt-1 text-[11px] text-slate-500">La cuenta quedará confirmada y lista para iniciar sesión.</p>
        </div>
      </div>
    </div>

    <!-- PASO 3: PLAN -->
    <div v-if="currentStep === 3" class="space-y-4">
      <h3 class="font-bold text-lg text-slate-900 dark:text-white flex items-center gap-2 border-b border-slate-200 dark:border-slate-800/80 pb-2">
        <CreditCard class="w-5 h-5 text-indigo-600 dark:text-indigo-400" /> Paso 3: Selección de Plan SaaS
      </h3>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div 
          v-for="p in plans" 
          :key="p.id"
          @click="onPlanSelect(p)"
          :class="[
            'p-5 rounded-2xl border cursor-pointer transition-all flex flex-col justify-between space-y-4',
            form.planId === p.id ? 'bg-indigo-50/70 dark:bg-indigo-950/60 border-indigo-500 ring-2 ring-indigo-500/50' : 'bg-slate-50 dark:bg-slate-950 border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700'
          ]"
        >
          <div>
            <h4 class="font-bold text-slate-900 dark:text-white text-base">{{ p.name }}</h4>
            <div class="text-2xl font-extrabold text-indigo-600 dark:text-indigo-400 mt-2">${{ p.monthly_price ?? p.price }} <span class="text-xs text-slate-500 dark:text-slate-400 font-normal">/mes</span></div>
          </div>
          <div class="text-xs text-slate-600 dark:text-slate-400 space-y-1 border-t border-slate-200 dark:border-slate-800/80 pt-3">
            <div>• Hasta {{ p.student_limit ?? p.limits?.max_students ?? 500 }} estudiantes</div>
            <div>• Todas las funciones académicas incluidas</div>
            <div>• 15 días de prueba</div>
          </div>
        </div>
      </div>
    </div>

    <!-- PASO 4: FACTURACIÓN -->
    <div v-if="currentStep === 4" class="space-y-4">
      <h3 class="font-bold text-lg text-slate-900 dark:text-white flex items-center gap-2 border-b border-slate-200 dark:border-slate-800/80 pb-2">
        <Receipt class="w-5 h-5 text-indigo-600 dark:text-indigo-400" /> Paso 4: Condiciones de Facturación
      </h3>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Ciclo de Facturación</label>
          <select v-model="form.billingCycle" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-indigo-500">
            <option value="monthly">Mensual</option>
            <option value="yearly">Anual (Descuento 15%)</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Valor del plan ($ USD)</label>
          <div class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-3 text-sm font-bold text-emerald-600 dark:text-emerald-400">
            ${{ selectedPrice }} / {{ form.billingCycle === 'yearly' ? 'año' : 'mes' }}
          </div>
        </div>
      </div>
    </div>

    <!-- PASO 5: CONFIRMACIÓN -->
    <div v-if="currentStep === 5" class="space-y-4">
      <h3 class="font-bold text-lg text-slate-900 dark:text-white flex items-center gap-2 border-b border-slate-200 dark:border-slate-800/80 pb-2">
        <CheckCircle2 class="w-5 h-5 text-emerald-600 dark:text-emerald-400" /> Paso 5: Resumen y Confirmación
      </h3>

      <div class="bg-slate-50 dark:bg-slate-950 p-5 rounded-2xl border border-slate-200 dark:border-slate-800 space-y-3 text-sm text-slate-700 dark:text-slate-300">
        <div class="flex justify-between border-b border-slate-200 dark:border-slate-800/60 pb-2">
          <span class="text-slate-500 dark:text-slate-400">Institución:</span>
          <strong class="text-slate-900 dark:text-white">{{ form.name }} ({{ form.code }})</strong>
        </div>
        <div class="flex justify-between border-b border-slate-200 dark:border-slate-800/60 pb-2">
          <span class="text-slate-500 dark:text-slate-400">Administrador:</span>
          <strong class="text-slate-900 dark:text-white">{{ form.adminName }} ({{ form.adminEmail }})</strong>
        </div>
        <div class="flex justify-between border-b border-slate-200 dark:border-slate-800/60 pb-2">
          <span class="text-slate-500 dark:text-slate-400">Ubicación:</span>
          <strong class="text-slate-900 dark:text-white">
            <template v-if="form.parish">Parroquia {{ form.parish }}, Cantón {{ form.city }}, {{ form.province }}, {{ form.country }}</template>
            <template v-else>{{ form.city }}, {{ form.province }}, {{ form.country }}</template>
          </strong>
        </div>
        <div class="flex justify-between">
          <span class="text-slate-500 dark:text-slate-400">Valor Plan:</span>
          <strong class="text-emerald-600 dark:text-emerald-400">${{ selectedPrice }} USD / {{ form.billingCycle === 'yearly' ? 'año' : 'mes' }}</strong>
        </div>
      </div>
    </div>

    <!-- PASO 6: CREDENCIALES GENERADAS Y RESUMEN FINAL -->
    <div v-if="currentStep === 6 && createdSuccessData" class="space-y-6 text-center py-4">
      <div class="inline-flex p-4 rounded-full bg-emerald-50 dark:bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-500/30">
        <CheckCircle2 class="w-12 h-12" />
      </div>

      <div>
        <h3 class="text-2xl font-extrabold text-slate-900 dark:text-white">¡Institución y Administrador Creados!</h3>
        <p class="text-slate-600 dark:text-slate-400 text-sm mt-1">La cuenta se encuentra lista para iniciar sesión.</p>
      </div>

      <div class="bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 text-left max-w-lg mx-auto space-y-4 shadow-sm">
        <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-800/80 pb-3">
          <span class="text-xs font-bold uppercase tracking-wider text-indigo-600 dark:text-indigo-400">Credenciales del Contratante</span>
          <span class="text-xs px-2.5 py-0.5 rounded-full bg-emerald-50 dark:bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 font-semibold border border-emerald-200 dark:border-emerald-500/30">Cuenta lista</span>
        </div>

        <div class="space-y-3 text-sm">
          <div>
            <span class="text-xs text-slate-500 dark:text-slate-400 block">Institución</span>
            <strong class="text-slate-900 dark:text-white text-base">{{ createdSuccessData.schoolName }}</strong>
          </div>
          <div>
            <span class="text-xs text-slate-500 dark:text-slate-400 block">Correo / Usuario de Acceso</span>
            <strong class="text-indigo-600 dark:text-indigo-300 font-mono select-all">{{ createdSuccessData.email }}</strong>
          </div>
          <div v-if="createdSuccessData.password">
            <span class="text-xs text-slate-500 dark:text-slate-400 block">Contraseña Temporal</span>
            <strong class="text-emerald-600 dark:text-emerald-300 font-mono select-all">{{ createdSuccessData.password }}</strong>
          </div>
          <div>
            <span class="text-xs text-slate-500 dark:text-slate-400 block">Enlace directo a la plataforma</span>
            <a :href="createdSuccessData.loginUrl" target="_blank" rel="noopener noreferrer" class="text-sky-600 dark:text-sky-400 font-mono underline hover:text-sky-500 dark:hover:text-sky-300 break-all select-all">
              {{ createdSuccessData.loginUrl }}
            </a>
          </div>
        </div>

        <div class="pt-2 border-t border-slate-200 dark:border-slate-800 grid grid-cols-1 sm:grid-cols-2 gap-2">
          <button 
            type="button" 
            @click="copyWelcomeMessage" 
            class="w-full py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center justify-center gap-2 transition-all shadow-sm cursor-pointer"
          >
            📋 Copiar datos de acceso
          </button>
          <a 
            :href="whatsappShareUrl" 
            target="_blank" 
            rel="noopener noreferrer"
            class="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs flex items-center justify-center gap-2 transition-all shadow-sm text-center"
          >
            💬 Enviar por WhatsApp
          </a>
        </div>
      </div>

      <div class="pt-4">
        <button 
          @click="finishWizard" 
          class="px-6 py-2.5 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-white font-bold text-sm transition-all border border-slate-200 dark:border-slate-700 cursor-pointer"
        >
          Finalizar y Volver a Instituciones
        </button>
      </div>
    </div>

    <!-- Botones de Navegación del Wizard -->
    <div v-if="currentStep <= 5" class="flex items-center justify-between border-t border-slate-200 dark:border-slate-800 pt-6">
      <button 
        v-if="currentStep > 1" 
        @click="prevStep" 
        class="px-5 py-2.5 rounded-xl text-sm font-medium bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 transition-colors flex items-center gap-1 border border-slate-200 dark:border-slate-700 cursor-pointer"
      >
        <ChevronLeft class="w-4 h-4" /> Anterior
      </button>
      <div v-else></div>

      <button 
        v-if="currentStep < 5" 
        @click="nextStep" 
        class="px-5 py-2.5 rounded-xl text-sm font-bold bg-indigo-600 hover:bg-indigo-500 text-white transition-colors flex items-center gap-1 shadow-md shadow-indigo-600/20 cursor-pointer"
      >
        Siguiente <ChevronRight class="w-4 h-4" />
      </button>

      <button 
        v-else 
        @click="submitWizard" 
        :disabled="saving"
        class="px-6 py-2.5 rounded-xl text-sm font-extrabold bg-emerald-600 hover:bg-emerald-500 text-white transition-all flex items-center gap-2 shadow-md shadow-emerald-600/20 cursor-pointer disabled:opacity-50"
      >
        <Save class="w-4 h-4" /> Finalizar Aprovisionamiento
      </button>
    </div>
  </div>
</template>
