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
    let identityVersion = 0

    const clearIdentity = () => {
        identityVersion += 1
        user.value = null
        profile.value = null
        accessContext.value = createAuthorizationContext(null)
        sessionPromise = null
        profilePromise = null
        accessContextPromise = null
    }

    const assertCurrentIdentity = (version, userId) => {
        if (version !== identityVersion || user.value?.id !== userId) {
            const error = new Error('La sesión cambió. Inténtalo nuevamente.')
            error.code = 'AUTH_SESSION_CHANGED'
            throw error
        }
    }

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
        const version = identityVersion
        const userId = user.value.id

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

            assertCurrentIdentity(version, userId)
            if (rpcError) throw rpcError

            const context = createAuthorizationContext({
                ...(data || {}),
                active_school_id: readStoredSchoolId() || data?.default_school_id || null,
            })
            if (context.userId !== userId) throw createAuthorizationAccessError()
            if (!context.isPlatformAdmin && context.memberships.length === 0) {
                throw createAuthorizationAccessError()
            }

            accessContext.value = context
            return context
        })()

        try {
            return await accessContextPromise
        } finally {
            if (version === identityVersion) accessContextPromise = null
        }
    }

    async function fetchProfile() {
        if (!user.value) throw createProfileAccessError()
        if (profilePromise) return profilePromise
        const version = identityVersion
        const userId = user.value.id

        profilePromise = (async () => {
            const { data, error } = await supabase
                .from('profiles')
                .select('id, email, role, full_name, school_id, created_at, photo_url')
                .eq('id', userId)
                .maybeSingle()

            assertCurrentIdentity(version, userId)
            if (error) {
                profile.value = null
                throw error
            }
            if (!data || data.id !== userId) {
                profile.value = null
                throw createProfileAccessError()
            }

            const photoPath = normalizeStoragePath(data.photo_url, 'profile-photos')
            const photoUrl = await resolvePrivateImageUrl(supabase, 'profile-photos', photoPath).catch(() => '')
            assertCurrentIdentity(version, userId)
            profile.value = {
                ...data,
                photo_storage_path: photoPath,
                photo_url: photoUrl,
            }
            return data
        })()

        try {
            return await profilePromise
        } finally {
            if (version === identityVersion) profilePromise = null
        }
    }

    /** Sincroniza la identidad autorizada con la sesión persistida de Supabase. */
    async function ensureSession() {
        if (user.value && profile.value && accessContext.value.userId === user.value.id) {
            loading.value = false
            return
        }
        if (sessionPromise) return sessionPromise
        const version = identityVersion

        sessionPromise = (async () => {
            loading.value = true
            try {
                const { data, error } = await supabase.auth.getSession()
                if (version !== identityVersion) return
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
                if (version !== identityVersion) throw error
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
                if (version === identityVersion) {
                    loading.value = false
                    isInitialized.value = true
                }
            }
        })()

        try {
            return await sessionPromise
        } finally {
            if (version === identityVersion) sessionPromise = null
        }
    }

    async function signIn(email, password) {
        clearIdentity()
        const version = identityVersion
        const { data, error } = await supabase.auth.signInWithPassword({ email, password })
        if (error) throw error
        if (version !== identityVersion) return
        user.value = data.user
        try {
            await fetchProfile()
            await fetchAccessContext()
        } catch (profileError) {
            if (version !== identityVersion) throw profileError
            await supabase.auth.signOut()
            if (version === identityVersion) clearIdentity()
            throw profileError
        }
    }

    async function signOut() {
        const { error } = await supabase.auth.signOut()
        if (error) throw error
        clearIdentity()
    }

    async function initialize() {
        await ensureSession()
        isInitialized.value = true
    }

    function resetAuth() {
        clearIdentity()
        isInitialized.value = false
    }

    const { data: authListener } = supabase.auth.onAuthStateChange((event, session) => {
        if (event === 'SIGNED_OUT' || event === 'USER_DELETED') {
            clearIdentity()
            isInitialized.value = false
            if (typeof globalThis.window !== 'undefined' && globalThis.window.location.pathname !== '/login') {
                globalThis.window.location.href = '/login'
            }
        } else if ((event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') && session) {
            if (user.value && user.value.id !== session.user.id) clearIdentity()
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
