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

async function seedQuarter() {
    console.log('Seeding default quarter...')

    const { data: existing } = await supabase.from('quarters').select('*').limit(1)

    if (existing && existing.length > 0) {
        console.log('Quarters already exist. Skipping.')
        return
    }

    const { data, error } = await supabase
        .from('quarters')
        .insert([
            { name: 'Primer Trimestre', is_active: true },
            { name: 'Segundo Trimestre', is_active: false },
            { name: 'Tercer Trimestre', is_active: false }
        ])
        .select()

    if (error) {
        console.error('Error creating quarter:', error.message)
    } else {
        console.log('Created quarters:', data)
    }
}

seedQuarter()
