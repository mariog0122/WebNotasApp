
import { createClient } from '@supabase/supabase-js'
import { loadEnv } from './load_env.js'

const env = loadEnv(['.env.admin', '.env.local'])
const supabaseUrl = env.SUPABASE_URL || env.VITE_SUPABASE_URL
const supabaseServiceKey = env.SUPABASE_SERVICE_KEY

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('Missing env vars. Required: SUPABASE_URL, SUPABASE_SERVICE_KEY')
    process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseServiceKey)

async function fixQuarters() {
    console.log('Fixing Quarters...')

    const quarters = [
        { name: 'Primer Trimestre', is_active: true },
        { name: 'Segundo Trimestre', is_active: false },
        { name: 'Tercer Trimestre', is_active: false }
    ]

    for (const q of quarters) {
        // Check if exists
        const { data } = await supabase.from('quarters').select('id').eq('name', q.name).maybeSingle()

        if (!data) {
            console.log(`Inserting ${q.name}...`)
            const { error } = await supabase.from('quarters').insert(q)
            if (error) console.error(`Error inserting ${q.name}:`, error.message)
        } else {
            console.log(`${q.name} already exists.`)
        }
    }
    console.log('Done.')
}

fixQuarters()
