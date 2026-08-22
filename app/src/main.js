import { createApp } from 'vue'
import { createPinia } from 'pinia'
import './style.css'
import App from './App.vue'
import router from './router'
import VueVirtualScroller from 'vue-virtual-scroller'
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css'
import 'vue-sonner/style.css'

import { registerSW } from 'virtual:pwa-register'

const updateSW = registerSW({
  onNeedRefresh() {
    console.log('[PWA] Nueva versión disponible. Actualice para ver los cambios.')
  },
  onOfflineReady() {
    console.log('[PWA] LOGREVA está lista para trabajar sin conexión.')
  },
})

import { VueQueryPlugin, QueryClient } from '@tanstack/vue-query'
import { del } from 'idb-keyval'
import { supabase } from './lib/supabase'
import { installErrorTelemetry } from './lib/telemetry'

// Retira datos académicos que versiones anteriores persistían durante siete días.
if ('caches' in globalThis) {
  void globalThis.caches.delete('supabase-api-cache')
}
void del('REACT_QUERY_OFFLINE_CACHE')

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      refetchOnWindowFocus: false,
      gcTime: 1000 * 60 * 60 * 24 * 7, // Keep garbage collected data for 7 days
    },
  },
})

const app = createApp(App)

installErrorTelemetry(app, supabase, {
  release: import.meta.env.VITE_APP_RELEASE || 'unknown',
})

app.use(createPinia())
app.use(router)
app.use(VueVirtualScroller)
app.use(VueQueryPlugin, { queryClient })

app.mount('#app')
