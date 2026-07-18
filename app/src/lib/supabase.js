import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.replace(/\/$/, '')
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error(
    '[WebNotas] Faltan VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY. Copia app/.env.example a app/.env.local y configura tu proyecto Supabase.'
  )
}

/** Cliente oficial; misma superficie que usan las vistas (`from`, `auth`, `storage`). */
const supabase = createClient(supabaseUrl ?? '', supabaseAnonKey ?? '', {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: window.localStorage,
    storageKey: 'webnotas-auth-token',
    flowType: 'pkce',
    lock: async (name, acquireTimeout, fn) => {
      // Dummy lock bypasses navigator.locks to prevent the 5000ms deadlocks in local Chromium
      return await fn();
    }
  },
})

export { supabase }
