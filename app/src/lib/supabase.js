import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.replace(/\/$/, '')
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error(
    '[Logreva] Faltan VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY. Copia app/.env.example a app/.env.local y configura tu proyecto Supabase.'
  )
}

/** Cliente oficial; misma superficie que usan las vistas (`from`, `auth`, `storage`). */
const supabase = createClient(supabaseUrl ?? '', supabaseAnonKey ?? '', {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: typeof window !== 'undefined' ? window.localStorage : undefined,
    storageKey: 'webnotas-auth-token',
    flowType: 'pkce',
    lock: typeof window !== 'undefined' && window.navigator?.locks && !import.meta.env.DEV
      ? undefined // En producción, aprovecha navigator.locks para evitar colisiones entre pestañas
      : async (name, acquireTimeout, fn) => {
          // En desarrollo, evita deadlocks de 5000ms producidos por HMR en Chromium local
          return await fn();
        },
  },
})

export { supabase }
