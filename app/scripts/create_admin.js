
import { createClient } from '@supabase/supabase-js'
import { loadEnv } from './load_env.js'

const env = loadEnv(['.env.admin', '.env.local'])
const supabaseUrl = env.SUPABASE_URL || env.VITE_SUPABASE_URL
const supabaseServiceKey = env.SUPABASE_SERVICE_KEY
const adminEmail = env.ADMIN_EMAIL
const adminPassword = env.ADMIN_PASSWORD

if (!supabaseUrl || !supabaseServiceKey || !adminEmail || !adminPassword) {
    console.error('Missing env vars. Required: SUPABASE_URL, SUPABASE_SERVICE_KEY, ADMIN_EMAIL, ADMIN_PASSWORD')
    process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseServiceKey)

async function createAdmin() {
    console.log(`Creating user ${adminEmail}...`)

    const { data: user, error: createUserError } = await supabase.auth.admin.createUser({
        email: adminEmail,
        password: adminPassword,
        email_confirm: true,
        user_metadata: { full_name: 'Administrador General' }
    })

    if (createUserError) {
        console.error('Error creating user:', createUserError.message)
        return
    }

    console.log('User created:', user.user.id)

    // Now create the profile in public.profiles
    // Note: The trigger should handle this if set up, but let's be sure or update it
    // Our schema usually has a trigger or we insert manually.
    // Let's try to insert/update the profile to ensure role is 'admin'

    const { error: profileError } = await supabase
        .from('profiles')
        .upsert({
            id: user.user.id,
            email: adminEmail,
            role: 'admin',
            full_name: 'Administrador General'
        })

    if (profileError) {
        console.error('Error creating profile:', profileError.message)
    } else {
        console.log('Profile created/updated successfully with ADMIN role.')
    }
}

createAdmin()
