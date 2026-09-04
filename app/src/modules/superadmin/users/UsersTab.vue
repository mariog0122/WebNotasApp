<script setup>
import { computed, onMounted, ref } from 'vue'
import { supabase } from '../../../lib/supabase'
import { toast } from 'vue-sonner'
import { Eye, EyeOff, LoaderCircle, Plus, Search, Trash2, UserRound, X } from 'lucide-vue-next'

const loading = ref(true)
const saving = ref(false)
const users = ref([])
const schools = ref([])
const search = ref('')
const showCreate = ref(false)
const showPassword = ref(false)
const deleteTarget = ref(null)

const roleOptions = [
  { value: 'school_admin', label: 'Administrador institucional' },
  { value: 'rector', label: 'Rector / Director' },
  { value: 'vicerrector', label: 'Vicerrector' },
  { value: 'secretary', label: 'Secretaría' },
  { value: 'inspector', label: 'Inspector' },
  { value: 'counselor', label: 'Consejería / DECE' },
  { value: 'teacher', label: 'Docente' },
]

const form = ref({
  firstName: '',
  lastName: '',
  email: '',
  phone: '',
  password: '',
  schoolId: '',
  role: 'school_admin',
})

const filteredUsers = computed(() => {
  const term = search.value.trim().toLowerCase()
  if (!term) return users.value
  return users.value.filter((user) =>
    [user.full_name, user.email, user.schoolName, user.tenantRole]
      .some((value) => value?.toLowerCase().includes(term)),
  )
})

const roleLabel = (role) => roleOptions.find((option) => option.value === role)?.label || role || 'Sin rol'

const loadUsers = async () => {
  loading.value = true
  try {
    const [
      { data: profileRows, error: profilesError },
      { data: membershipRows },
      { data: schoolRows, error: schoolsError },
    ] = await Promise.all([
      supabase
        .from('profiles')
        .select('id, full_name, email, role, school_id, is_active, schools!school_id(name)')
        .order('full_name'),
      supabase
        .from('tenant_memberships')
        .select('user_id, tenant_roles(name)'),
      supabase
        .from('schools')
        .select('id, name, status, is_active')
        .eq('is_active', true)
        .order('name'),
    ])

    if (profilesError) throw profilesError
    if (schoolsError) throw schoolsError

    const membershipRoleMap = new Map()
    if (membershipRows) {
      for (const m of membershipRows) {
        if (m.user_id && m.tenant_roles?.name) {
          membershipRoleMap.set(m.user_id, m.tenant_roles.name)
        }
      }
    }

    users.value = (profileRows || []).map((profile) => ({
      ...profile,
      schoolName: profile.schools?.name || 'Plataforma',
      tenantRole: membershipRoleMap.get(profile.id) || profile.role,
    }))
    schools.value = (schoolRows || []).filter((school) => !['suspended', 'cancelled'].includes(school.status))
    if (!form.value.schoolId && schools.value.length) form.value.schoolId = schools.value[0].id
  } catch (error) {
    toast.error('No se pudieron cargar los usuarios', { description: error.message })
  } finally {
    loading.value = false
  }
}

const resetForm = () => {
  form.value = {
    firstName: '', lastName: '', email: '', phone: '', password: '',
    schoolId: schools.value[0]?.id || '', role: 'school_admin',
  }
}

const createUser = async () => {
  // Validación estricta de teléfono para administradores de colegio
  if (['school_admin', 'rector'].includes(form.value.role)) {
    const cleanPhone = (form.value.phone || '').trim()
    const digitsOnly = cleanPhone.replace(/\D/g, '')
    if (!cleanPhone || cleanPhone === '+593' || digitsOnly.length < 8) {
      toast.error('El número de teléfono es obligatorio para el Administrador del colegio.')
      return
    }

    // Verificar si el teléfono ya está en uso en Supabase
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
    } catch (e) {
      console.warn('Error verificando teléfono:', e)
    }
  }

  saving.value = true
  try {
    const { data, error } = await supabase.functions.invoke('manage-tenant-user', {
      body: { action: 'create', ...form.value },
    })
    if (error) {
      let msg = 'No fue posible crear el usuario.'
      try {
        const body = await error.context?.json()
        if (body?.message) msg = body.message
      } catch {}
      throw new Error(msg)
    }
    if (!data?.success) throw new Error(data?.message || 'No fue posible crear el usuario.')

    toast.success(data.message)
    showCreate.value = false
    resetForm()
    await loadUsers()
  } catch (error) {
    toast.error('No se pudo crear el usuario', { description: error.message })
  } finally {
    saving.value = false
  }
}

const deleteUser = async () => {
  if (!deleteTarget.value) return
  saving.value = true
  try {
    const { data, error } = await supabase.functions.invoke('manage-tenant-user', {
      body: { action: 'delete', userId: deleteTarget.value.id },
    })
    if (error) {
      let msg = 'No fue posible eliminar el usuario.'
      try {
        const body = await error.context?.json()
        if (body?.message) msg = body.message
      } catch {}
      throw new Error(msg)
    }
    if (!data?.success) throw new Error(data?.message || 'No fue posible eliminar el usuario.')

    toast.success(data.message)
    deleteTarget.value = null
    await loadUsers()
  } catch (error) {
    toast.error('No se pudo eliminar el usuario', { description: error.message })
  } finally {
    saving.value = false
  }
}

onMounted(loadUsers)
</script>

<template>
  <section class="space-y-5" aria-labelledby="users-title">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <p class="text-xs font-bold uppercase tracking-[0.2em] text-cyan-600 dark:text-cyan-400">Identidades institucionales</p>
        <h2 id="users-title" class="mt-1 text-2xl font-extrabold text-slate-900 dark:text-white">Usuarios</h2>
        <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">Cuentas de acceso, institución y rol asignado.</p>
      </div>
      <button
        type="button"
        class="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-bold text-white shadow-md shadow-indigo-600/20 transition hover:bg-indigo-500 cursor-pointer"
        @click="showCreate = true"
      >
        <Plus class="h-4 w-4" aria-hidden="true" /> Nuevo usuario
      </button>
    </div>

    <div class="relative">
      <Search class="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400 dark:text-slate-500" aria-hidden="true" />
      <input
        v-model="search"
        type="search"
        class="min-h-12 w-full rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-950/80 pl-11 pr-4 text-sm text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-slate-500 outline-none transition focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20"
        placeholder="Buscar por nombre, correo, institución o rol"
        aria-label="Buscar usuarios"
      />
    </div>

    <div class="overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/80 shadow-sm">
      <div v-if="loading" class="grid min-h-52 place-items-center text-slate-500">
        <LoaderCircle class="h-7 w-7 animate-spin" aria-label="Cargando usuarios" />
      </div>
      <div v-else-if="!filteredUsers.length" class="grid min-h-52 place-items-center px-6 text-center text-sm text-slate-500">
        No hay usuarios que coincidan con la búsqueda.
      </div>
      <div v-else class="overflow-x-auto">
        <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-800 text-left">
          <thead class="bg-slate-50 dark:bg-slate-950/90 text-xs uppercase tracking-wider text-slate-600 dark:text-slate-400">
            <tr>
              <th class="px-5 py-4">Usuario</th>
              <th class="px-5 py-4">Institución</th>
              <th class="px-5 py-4">Rol</th>
              <th class="px-5 py-4">Estado</th>
              <th class="px-5 py-4 text-right">Acciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-200 dark:divide-slate-800/80">
            <tr v-for="user in filteredUsers" :key="user.id" class="transition hover:bg-slate-50 dark:hover:bg-slate-800/35">
              <td class="px-5 py-4">
                <div class="flex items-center gap-3">
                  <span class="grid h-9 w-9 place-items-center rounded-xl border border-cyan-200 dark:border-cyan-900/70 bg-cyan-50 dark:bg-cyan-950/40 text-cyan-700 dark:text-cyan-300"><UserRound class="h-4 w-4" /></span>
                  <div><p class="font-semibold text-slate-900 dark:text-white">{{ user.full_name || 'Sin nombre' }}</p><p class="text-xs text-slate-500 dark:text-slate-400">{{ user.email }}</p></div>
                </div>
              </td>
              <td class="px-5 py-4 text-sm text-slate-700 dark:text-slate-300">{{ user.schoolName }}</td>
              <td class="px-5 py-4 text-sm text-slate-700 dark:text-slate-300">{{ roleLabel(user.tenantRole) }}</td>
              <td class="px-5 py-4"><span :class="user.is_active ? 'text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-950/50 border-emerald-200 dark:border-emerald-900' : 'text-rose-700 dark:text-rose-300 bg-rose-50 dark:bg-rose-950/50 border-rose-200 dark:border-rose-900'" class="rounded-full border px-2.5 py-1 text-xs font-bold">{{ user.is_active ? 'Activo' : 'Inactivo' }}</span></td>
              <td class="px-5 py-4 text-right">
                <button
                  type="button"
                  :disabled="user.role === 'superadmin'"
                  class="inline-grid h-10 w-10 place-items-center rounded-xl border border-rose-200 dark:border-rose-900/70 bg-rose-50 dark:bg-rose-950/40 text-rose-600 dark:text-rose-300 transition hover:bg-rose-100 dark:hover:bg-rose-900 disabled:cursor-not-allowed disabled:opacity-30 cursor-pointer"
                  :aria-label="`Eliminar a ${user.full_name}`"
                  title="Eliminar usuario"
                  @click="deleteTarget = user"
                ><Trash2 class="h-4 w-4" /></button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div v-if="showCreate" class="fixed inset-0 z-50 grid place-items-center overflow-y-auto bg-slate-950/80 p-4 backdrop-blur-sm" role="dialog" aria-modal="true" aria-labelledby="create-user-title">
      <form class="my-auto w-full max-w-xl space-y-5 rounded-2xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 p-5 shadow-2xl sm:p-7" @submit.prevent="createUser">
        <div class="flex items-start justify-between gap-4"><div><h3 id="create-user-title" class="text-xl font-extrabold text-slate-900 dark:text-white">Crear usuario</h3><p class="mt-1 text-sm text-slate-600 dark:text-slate-400">La cuenta queda confirmada y lista para iniciar sesión.</p></div><button type="button" class="rounded-lg p-2 text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-white cursor-pointer" aria-label="Cerrar" @click="showCreate = false"><X class="h-5 w-5" /></button></div>
        <div class="grid gap-4 sm:grid-cols-2">
          <label class="grid gap-1.5 text-xs font-bold text-slate-700 dark:text-slate-300">Nombre<input v-model="form.firstName" required minlength="2" autocomplete="given-name" class="min-h-11 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-950 px-3 text-sm text-slate-900 dark:text-white outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20" /></label>
          <label class="grid gap-1.5 text-xs font-bold text-slate-700 dark:text-slate-300">Apellido<input v-model="form.lastName" required minlength="2" autocomplete="family-name" class="min-h-11 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-950 px-3 text-sm text-slate-900 dark:text-white outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20" /></label>
          <label class="grid gap-1.5 text-xs font-bold text-slate-700 dark:text-slate-300 sm:col-span-2">Correo electrónico<input v-model="form.email" required type="email" autocomplete="email" class="min-h-11 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-950 px-3 text-sm text-slate-900 dark:text-white outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20" /></label>
          <label class="grid gap-1.5 text-xs font-bold text-slate-700 dark:text-slate-300 sm:col-span-2">
            <span>Teléfono Móvil <span v-if="['school_admin', 'rector'].includes(form.role)" class="text-rose-500">*</span></span>
            <input v-model="form.phone" :required="['school_admin', 'rector'].includes(form.role)" type="tel" placeholder="+593 99 123 4567" class="min-h-11 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-950 px-3 text-sm text-slate-900 dark:text-white outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20" />
            <span v-if="['school_admin', 'rector'].includes(form.role)" class="text-[11px] font-normal text-slate-500">Obligatorio y único para administradores institucionales.</span>
          </label>
          <div class="grid gap-1.5 text-xs font-bold text-slate-700 dark:text-slate-300 sm:col-span-2">
            <span>Contraseña temporal</span>
            <div class="relative">
              <input v-model="form.password" required :type="showPassword ? 'text' : 'password'" minlength="8" autocomplete="new-password" class="min-h-11 w-full rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-950 px-3 pr-10 text-sm text-slate-900 dark:text-white outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20" />
              <button 
                type="button" 
                @click="showPassword = !showPassword" 
                class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-700 dark:hover:text-white transition p-1 cursor-pointer"
                :title="showPassword ? 'Ocultar contraseña' : 'Ver contraseña'"
              >
                <EyeOff v-if="showPassword" class="h-4 w-4" />
                <Eye v-else class="h-4 w-4" />
              </button>
            </div>
            <span class="font-normal text-slate-500">Mínimo 8 caracteres. No se enviará correo de confirmación.</span>
          </div>
          <label class="grid gap-1.5 text-xs font-bold text-slate-700 dark:text-slate-300">Institución<select v-model="form.schoolId" required class="min-h-11 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-950 px-3 text-sm text-slate-900 dark:text-white outline-none focus:border-indigo-500"><option v-for="school in schools" :key="school.id" :value="school.id">{{ school.name }}</option></select></label>
          <label class="grid gap-1.5 text-xs font-bold text-slate-700 dark:text-slate-300">Rol<select v-model="form.role" required class="min-h-11 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-950 px-3 text-sm text-slate-900 dark:text-white outline-none focus:border-indigo-500"><option v-for="role in roleOptions" :key="role.value" :value="role.value">{{ role.label }}</option></select></label>
        </div>
        <div class="flex flex-col-reverse gap-3 border-t border-slate-200 dark:border-slate-800 pt-4 sm:flex-row sm:justify-end"><button type="button" class="min-h-11 rounded-xl px-4 text-sm font-bold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer" @click="showCreate = false">Cancelar</button><button type="submit" :disabled="saving" class="min-h-11 rounded-xl bg-indigo-600 px-5 text-sm font-bold text-white hover:bg-indigo-500 disabled:opacity-50 cursor-pointer shadow-md shadow-indigo-600/20">{{ saving ? 'Creando…' : 'Crear y habilitar' }}</button></div>
      </form>
    </div>

    <div v-if="deleteTarget" class="fixed inset-0 z-50 grid place-items-center bg-slate-950/80 p-4 backdrop-blur-sm" role="dialog" aria-modal="true" aria-labelledby="delete-user-title">
      <div class="w-full max-w-md space-y-5 rounded-2xl border border-rose-200 dark:border-rose-900/70 bg-white dark:bg-slate-900 p-6 shadow-2xl">
        <div><p class="text-xs font-bold uppercase tracking-widest text-rose-600 dark:text-rose-400">Acción irreversible</p><h3 id="delete-user-title" class="mt-1 text-xl font-extrabold text-slate-900 dark:text-white">Confirmar eliminación</h3></div>
        <p class="text-sm leading-6 text-slate-600 dark:text-slate-300">Se eliminará <strong class="text-slate-900 dark:text-white">{{ deleteTarget.full_name }}</strong> de Supabase Auth, su perfil y sus membresías institucionales.</p>
        <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end"><button type="button" class="min-h-11 rounded-xl px-4 text-sm font-bold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer" @click="deleteTarget = null">Cancelar</button><button type="button" :disabled="saving" class="min-h-11 rounded-xl bg-rose-600 px-5 text-sm font-bold text-white hover:bg-rose-500 disabled:opacity-50 cursor-pointer shadow-md shadow-rose-600/20" @click="deleteUser">{{ saving ? 'Eliminando…' : 'Eliminar usuario' }}</button></div>
      </div>
    </div>
  </section>
</template>
