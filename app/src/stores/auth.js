import { ref } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'

export const useAuthStore = defineStore('auth', () => {
    const user = ref(null)
    const profile = ref(null)
    const isInitialized = ref(false)
    const loading = ref(false)

    let sessionPromise = null

    /**
     * Sincroniza usuario y perfil con la sesión de Supabase (localStorage + refresh).
     * Debe llamarse en el guard de rutas para detectar logout o sesión nueva.
     */
    async function ensureSession() {
        if (user.value && profile.value) {
            loading.value = false
            return
        }

        if (sessionPromise) {
            return sessionPromise
        }

        sessionPromise = (async () => {
            try {
                loading.value = true
                console.log('[WebNotas Debug] ensureSession: llamando a supabase.auth.getSession()')
                const { data, error } = await supabase.auth.getSession()
                console.log('[WebNotas Debug] ensureSession: getSession terminada', { hasSession: !!data?.session, error })
                
                if (error) {
                   if (error.message && error.message.includes('Refresh Token')) {
                       try {
                           await supabase.auth.signOut()
                       } catch (signOutErr) {
                           console.warn('signOut error inside getSession error handler:', signOutErr)
                       }
                       user.value = null
                       profile.value = null
                       if (typeof window !== 'undefined' && window.localStorage) {
                           window.localStorage.removeItem('webnotas-auth-token')
                       }
                   }
                   throw error
                }

                if (data?.session) {
                    user.value = data.session.user
                    console.log('[WebNotas Debug] ensureSession: sesion activa encontrada, llamando a fetchProfile()')
                    await fetchProfile()
                    console.log('[WebNotas Debug] ensureSession: fetchProfile() terminado')
                } else {
                    user.value = null
                    profile.value = null
                }
            } catch (err) {
                console.error('[WebNotas Debug] ensureSession exception:', err)
                // Si es un timeout o error crítico, limpiamos user.value para que el guard de rutas fuerce login
                user.value = null
                profile.value = null
                throw err
            } finally {
                loading.value = false
                isInitialized.value = true
            }
        })()

        try {
            await sessionPromise
        } finally {
            sessionPromise = null
        }
    }

    let profilePromise = null

    async function fetchProfile() {
        if (!user.value) return
        if (profilePromise) {
            return profilePromise
        }

        profilePromise = (async () => {
            console.log('[WebNotas Debug] fetchProfile: consultando tabla profiles para id:', user.value.id)
            const { data, error } = await supabase
                .from('profiles')
                .select('id, email, role, full_name, created_at')
                .eq('id', user.value.id)
                .maybeSingle()
            console.log('[WebNotas Debug] fetchProfile: profiles query completado', { hasProfile: !!data, error })
            if (error) {
                console.error('fetchProfile', error)
                profile.value = null
                return
            }
            if (!data) {
                const email = user.value.email ?? ''
                const row = {
                    id: user.value.id,
                    email,
                    role: 'teacher',
                    full_name: email.includes('@') ? email.split('@')[0] : 'Docente',
                }
                const { error: insertErr } = await supabase.from('profiles').insert([row])
                if (insertErr) {
                    console.error('bootstrap profile', insertErr)
                    profile.value = null
                    return
                }
                const { data: created, error: readErr } = await supabase
                    .from('profiles')
                    .select('id, email, role, full_name, created_at')
                    .eq('id', user.value.id)
                    .maybeSingle()
                if (readErr) {
                    console.error('fetchProfile after insert', readErr)
                    profile.value = null
                    return
                }
                profile.value = created
                return
            }
            profile.value = data
        })()

        try {
            await profilePromise
        } finally {
            profilePromise = null
        }
    }

    async function signIn(email, password) {
        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password,
        })
        if (error) throw error
        user.value = data.user
        await fetchProfile()
    }

    async function signOut() {
        await supabase.auth.signOut()
        user.value = null
        profile.value = null
    }

    /** Primera carga o re-sync explícito; mismo comportamiento estable que ensureSession. */
    async function initialize() {
        await ensureSession()
        isInitialized.value = true
    }

    function resetAuth() {
        user.value = null
        profile.value = null
        isInitialized.value = false
    }

    const { data: authListener } = supabase.auth.onAuthStateChange(async (event, session) => {
        console.log('[WebNotas Debug] onAuthStateChange:', event)
        if (event === 'SIGNED_OUT' || event === 'USER_DELETED') {
            user.value = null
            profile.value = null
            isInitialized.value = false
            if (typeof globalThis.window !== 'undefined' && globalThis.window.location.pathname !== '/login') {
                globalThis.window.location.href = '/login'
            }
        } else if (event === 'SIGNED_IN' && session) {
            user.value = session.user
            // DO NOT await fetchProfile() here — it would deadlock because
            // Supabase's internal initializePromise hasn't resolved yet and
            // any supabase.from() call waits for it. The router guard's
            // ensureSession() will fetch the profile after initialization.
            isInitialized.value = true
        } else if (event === 'TOKEN_REFRESHED' && session) {
            user.value = session.user
            isInitialized.value = true
        }
    })

    return {
        user,
        profile,
        signIn,
        signOut,
        initialize,
        ensureSession,
        resetAuth,
        authListener,
    }
})
