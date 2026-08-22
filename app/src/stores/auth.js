import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { normalizeStoragePath, resolvePrivateImageUrl } from '../lib/storageUtils'
import { createAuthorizationContext } from '../lib/permissions'

const createProfileAccessError = () => {
    const error = new Error('Tu cuenta no tiene un perfil institucional activo. Contacta al administrador de tu institución.')
    error.code = 'PROFILE_NOT_PROVISIONED'
    return error
}

const createAuthorizationAccessError = () => {
    const error = new Error('Tu cuenta no tiene un rol activo en LOGREVA. Contacta al administrador de tu institución.')
    error.code = 'AUTHORIZATION_NOT_PROVISIONED'
    return error
}

export const useAuthStore = defineStore('auth', () => {
    const user = ref(null)
    const profile = ref(null)
    const accessContext = ref(createAuthorizationContext(null))
    const activeSchoolId = computed(() => accessContext.value.activeSchoolId || profile.value?.school_id || null)
    const isInitialized = ref(false)
    const loading = ref(false)

    let sessionPromise = null
    let profilePromise = null
    let accessContextPromise = null

    const schoolStorageKey = () => user.value?.id
        ? `logreva-active-school:${user.value.id}`
        : null

    const readStoredSchoolId = () => {
        const key = schoolStorageKey()
        if (!key || typeof globalThis.localStorage === 'undefined') return null
        return globalThis.localStorage.getItem(key)
    }

    function setActiveSchoolId(schoolId) {
        if (!schoolId) return false

        const nextContext = createAuthorizationContext({
            ...accessContext.value.raw,
            active_school_id: schoolId,
        })
        if (nextContext.activeSchoolId !== schoolId) return false

        accessContext.value = nextContext
        const key = schoolStorageKey()
        if (key && typeof globalThis.localStorage !== 'undefined') {
            globalThis.localStorage.setItem(key, schoolId)
        }
        return true
    }

    async function fetchAccessContext() {
        if (!user.value) throw createAuthorizationAccessError()
        if (accessContextPromise) return accessContextPromise

        accessContextPromise = (async () => {
            let data = null
            let rpcError = null

            try {
                const res = await supabase.rpc('get_my_access_context')
                data = res.data
                rpcError = res.error
            } catch (err) {
                rpcError = err
            }

            // Fallback de contingencia: si el RPC falla por permisos o desincronización en DB
            if (rpcError) {
                console.warn('supabase.rpc("get_my_access_context") no disponible, usando fallback de perfil:', rpcError)
                if (profile.value?.role === 'superadmin') {
                    data = {
                        user_id: user.value.id,
                        is_platform_admin: true,
                        is_platform_owner: true,
                        platform_roles: ['platform_owner', 'platform_admin'],
                        default_school_id: profile.value.school_id || null,
                        memberships: [],
                    }
                    rpcError = null
                } else if (profile.value?.role) {
                    data = {
                        user_id: user.value.id,
                        is_platform_admin: false,
                        is_platform_owner: false,
                        platform_roles: [],
                        default_school_id: profile.value.school_id || null,
                        memberships: profile.value.school_id ? [{
                            school_id: profile.value.school_id,
                            role: profile.value.role,
                            permissions: [],
                        }] : [],
                    }
                    rpcError = null
                }
            }

            if (rpcError) throw rpcError

            const context = createAuthorizationContext({
                ...(data || {}),
                active_school_id: readStoredSchoolId() || data?.default_school_id || null,
            })
            if (!context.isPlatformAdmin && context.memberships.length === 0) {
                throw createAuthorizationAccessError()
            }

            accessContext.value = context
            return context
        })()

        try {
            return await accessContextPromise
        } finally {
            accessContextPromise = null
        }
    }

    async function fetchProfile() {
        if (!user.value) throw createProfileAccessError()
        if (profilePromise) return profilePromise

        profilePromise = (async () => {
            const { data, error } = await supabase
                .from('profiles')
                .select('id, email, role, full_name, school_id, created_at, photo_url')
                .eq('id', user.value.id)
                .maybeSingle()

            if (error) {
                profile.value = null
                throw error
            }
            if (!data) {
                profile.value = null
                throw createProfileAccessError()
            }

            const photoPath = normalizeStoragePath(data.photo_url, 'profile-photos')
            profile.value = {
                ...data,
                photo_storage_path: photoPath,
                photo_url: await resolvePrivateImageUrl(supabase, 'profile-photos', photoPath).catch(() => ''),
            }
            return data
        })()

        try {
            return await profilePromise
        } finally {
            profilePromise = null
        }
    }

    /** Sincroniza la identidad autorizada con la sesión persistida de Supabase. */
    async function ensureSession() {
        if (user.value && profile.value && accessContext.value.userId === user.value.id) {
            loading.value = false
            return
        }
        if (sessionPromise) return sessionPromise

        sessionPromise = (async () => {
            loading.value = true
            try {
                const { data, error } = await supabase.auth.getSession()
                if (error) throw error

                if (!data?.session) {
                    user.value = null
                    profile.value = null
                    accessContext.value = createAuthorizationContext(null)
                    return
                }

                user.value = data.session.user
                await fetchProfile()
                await fetchAccessContext()
            } catch (error) {
                user.value = null
                profile.value = null
                accessContext.value = createAuthorizationContext(null)
                if (
                    error?.code === 'PROFILE_NOT_PROVISIONED'
                    || error?.code === 'AUTHORIZATION_NOT_PROVISIONED'
                    || error?.message?.includes('Refresh Token')
                ) {
                    try {
                        await supabase.auth.signOut()
                    } catch {
                        // La limpieza local de estado ya impide el acceso a rutas privadas.
                    }
                }
                throw error
            } finally {
                loading.value = false
                isInitialized.value = true
            }
        })()

        try {
            return await sessionPromise
        } finally {
            sessionPromise = null
        }
    }

    async function signIn(email, password) {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password })
        if (error) throw error

        user.value = data.user
        try {
            await fetchProfile()
            await fetchAccessContext()
        } catch (profileError) {
            await supabase.auth.signOut()
            user.value = null
            profile.value = null
            accessContext.value = createAuthorizationContext(null)
            throw profileError
        }
    }

    async function signOut() {
        await supabase.auth.signOut()
        user.value = null
        profile.value = null
        accessContext.value = createAuthorizationContext(null)
    }

    async function initialize() {
        await ensureSession()
        isInitialized.value = true
    }

    function resetAuth() {
        user.value = null
        profile.value = null
        accessContext.value = createAuthorizationContext(null)
        isInitialized.value = false
    }

    const { data: authListener } = supabase.auth.onAuthStateChange((event, session) => {
        if (event === 'SIGNED_OUT' || event === 'USER_DELETED') {
            user.value = null
            profile.value = null
            accessContext.value = createAuthorizationContext(null)
            isInitialized.value = false
            if (typeof globalThis.window !== 'undefined' && globalThis.window.location.pathname !== '/login') {
                globalThis.window.location.href = '/login'
            }
        } else if ((event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') && session) {
            user.value = session.user
        }
    })

    return {
        user,
        profile,
        accessContext,
        activeSchoolId,
        setActiveSchoolId,
        signIn,
        signOut,
        initialize,
        ensureSession,
        resetAuth,
        authListener,
    }
})
