import { ref } from 'vue'
import { defineStore } from 'pinia'

export const useUIStore = defineStore('ui', () => {
    const isAuthLoading = ref(false)
    const showAuthFlash = ref(false)
    /** Evita que un setTimeout antiguo active el overlay cuando la navegación ya terminó. */
    let authFlashTimer = null

    function setAuthLoading(loading) {
        if (authFlashTimer != null) {
            clearTimeout(authFlashTimer)
            authFlashTimer = null
        }
        isAuthLoading.value = loading
        if (loading) {
            // Mostrar flash después de 300ms para evitar parpadeo en cargas rápidas
            authFlashTimer = setTimeout(() => {
                authFlashTimer = null
                if (isAuthLoading.value) {
                    showAuthFlash.value = true
                }
            }, 300)
        } else {
            showAuthFlash.value = false
            isAuthLoading.value = false
        }
    }

    return { isAuthLoading, showAuthFlash, setAuthLoading }
})
