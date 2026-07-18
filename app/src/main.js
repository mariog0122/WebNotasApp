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
    console.log('[PWA] WebNotas lista para trabajar sin conexión.')
  },
})

import { VueQueryPlugin, QueryClient } from '@tanstack/vue-query'
import { persistQueryClient } from '@tanstack/query-persist-client-core'
import { createAsyncStoragePersister } from '@tanstack/query-async-storage-persister'
import { get, set, del } from 'idb-keyval'

const idbValidKey = {
  getItem: async (key) => await get(key),
  setItem: async (key, value) => await set(key, value),
  removeItem: async (key) => await del(key),
}

const persister = createAsyncStoragePersister({
  storage: idbValidKey,
})

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

app.use(createPinia())
app.use(router)
app.use(VueVirtualScroller)
app.use(VueQueryPlugin, { 
  queryClient,
  clientPersister: (queryClient) => {
    return persistQueryClient({
      queryClient,
      persister,
      maxAge: 1000 * 60 * 60 * 24 * 7, // 1 week cache
    })
  }
})

app.mount('#app')
