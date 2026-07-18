import { ref, watch, onMounted } from 'vue'

const theme = ref('light')

export function useTheme() {
  const toggleTheme = () => {
    theme.value = theme.value === 'light' ? 'dark' : 'light'
  }

  const initTheme = () => {
    // Revisar localStorage o preferencia del sistema
    const savedTheme = localStorage.getItem('app-theme')
    if (savedTheme) {
      theme.value = savedTheme
    } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      theme.value = 'dark'
    } else {
      theme.value = 'light' // Default a claro si no hay preferencia
    }
    applyTheme()
  }

  const applyTheme = () => {
    const html = document.documentElement
    if (theme.value === 'dark') {
      html.classList.add('dark')
    } else {
      html.classList.remove('dark')
    }
    localStorage.setItem('app-theme', theme.value)
  }

  // Sincronizar cambios automáticos si cambia la preferencia de sistema
  onMounted(() => {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
      if (!localStorage.getItem('app-theme')) {
        theme.value = e.matches ? 'dark' : 'light'
      }
    })
  })

  watch(theme, () => {
    applyTheme()
  })

  return { theme, toggleTheme, initTheme }
}
