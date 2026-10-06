import { sanitizeEducationAIInput } from './privacy.js'
import { isValidEducationAIOutput } from './output-contracts.js'

// Runtime-neutral handler: exercised with synthetic Auth, database and provider adapters.
export function createEducationAIHandler({ createClient, env, providers }) {
  const isEncryptedKey = key => typeof key === 'string' && key.startsWith('-----BEGIN PGP MESSAGE-----')
  const cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }
  const reply = (body, status = 200) => new Response(JSON.stringify(body), {
    status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  })
  const tasks = {
    generatePlan: 'plan_generation', regenerateSection: 'section_regeneration',
    generateResource: 'resource_generation', generateStudentSupport: 'student_support_generation',
    generateAnnualPlan: 'annual_plan_generation', generateUnitPlan: 'unit_plan_generation',
  }
  const providerModels = {
    openai: new Set(['auto', 'gpt-5-nano', 'gpt-5-mini', 'gpt-5']),
    gemini: new Set(['auto', 'gemini-3.7-flash', 'gemini-2.5-flash', 'gemini-2.5-flash-lite', 'gemini-2.5-pro']),
    demo: new Set(['auto', 'demo-pedagogico-ec']),
  }
  const modelFor = (settings, quality) => {
    const openai = settings.provider === 'openai'
    if (quality === 'economica') return openai ? 'gpt-5-nano' : 'gemini-2.5-flash-lite'
    if (quality === 'alta_calidad') return openai ? 'gpt-5' : 'gemini-3.7-flash'
    return settings.model_id && settings.model_id !== 'auto' && providerModels[settings.provider]?.has(settings.model_id)
      ? settings.model_id : (openai ? 'gpt-5-mini' : 'gemini-2.5-flash')
  }
  return async (request) => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
    if (request.method !== 'POST') return reply({ error: 'Método no permitido.' }, 405)
    const authorization = request.headers.get('Authorization') || ''
    if (!/^Bearer\s+\S+$/i.test(authorization)) return reply({ error: 'Sesión no válida.' }, 401)
    let admin, reservationId, requestSchoolId, actorId, actionName
    try {
      const raw = await request.text()
      if (new TextEncoder().encode(raw).byteLength > 100_000) return reply({ error: 'La solicitud es demasiado grande.' }, 413)
      let body
      try { body = JSON.parse(raw) } catch { return reply({ error: 'Solicitud no válida.' }, 400) }
      if (!body || typeof body !== 'object' || !/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(body.schoolId || '')) {
        return reply({ error: 'Institución no válida.' }, 400)
      }
      const { action, schoolId } = body
      requestSchoolId = schoolId
      actionName = action
      if (!Object.hasOwn(tasks, action) && !['save_settings', 'test_connection'].includes(action)) return reply({ error: 'Operación no válida.' }, 400)
      const url = env('SUPABASE_URL'), anon = env('SUPABASE_ANON_KEY'), secret = env('SUPABASE_SERVICE_ROLE_KEY')
      if (!url || !anon || !secret) return reply({ error: 'El servicio de IA no está configurado.' }, 503)
      const caller = createClient(url, anon, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } })
      const { data: identity, error: authError } = await caller.auth.getUser(authorization.replace(/^Bearer\s+/i, ''))
      if (authError || !identity?.user) return reply({ error: 'Sesión no válida.' }, 401)
      actorId = identity.user.id
      const { data: context, error: contextError } = await caller.rpc('get_my_access_context')
      if (contextError || context?.user_id !== identity.user.id) return reply({ error: 'Acceso no autorizado.' }, 403)
      const platform = context.is_platform_admin === true
      const membership = context.memberships?.find(item => item.school_id === schoolId)
      if (!platform && (!membership || context.default_school_id !== schoolId)) return reply({ error: 'Institución no autorizada.' }, 403)
      const canConfigure = platform || membership?.permissions?.includes('settings.manage')
      if (['save_settings', 'test_connection'].includes(action) && !canConfigure) return reply({ error: 'Solo un administrador puede configurar la IA.' }, 403)
      if (Object.hasOwn(tasks, action) && !platform && !membership?.permissions?.includes('grades.read')) return reply({ error: 'No tienes permiso para generar documentos.' }, 403)

      admin = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } })
      const { data: settings, error: settingsError } = await admin.from('institution_ai_settings').select('*').eq('school_id', schoolId).maybeSingle()
      if (settingsError) throw settingsError
      if (action === 'save_settings') {
        const input = body.settings || {}
        if (!['managed', 'byok', 'demo'].includes(input.mode) || !['gemini', 'openai', 'demo'].includes(input.provider)
          || typeof input.model_id !== 'string' || !/^[\w.:-]{1,100}$/.test(input.model_id)
          || !providerModels[input.provider]?.has(input.model_id)
          || !Number.isSafeInteger(input.monthly_quota_generations) || input.monthly_quota_generations < 0
          || !Number.isSafeInteger(input.teacher_daily_limit) || input.teacher_daily_limit < 0
          || !Array.isArray(input.alert_thresholds) || input.alert_thresholds.length > 10
          || input.alert_thresholds.some(n => !Number.isFinite(n) || n < 0 || n > 100)
          || (body.apiKey !== undefined && (typeof body.apiKey !== 'string' || body.apiKey.length > 1024))) {
          return reply({ error: 'Revisa los valores de configuración de IA.' }, 400)
        }
        let key = body.apiKey?.trim() || settings?.encrypted_api_key || null
        if (key && (body.apiKey?.trim() || !isEncryptedKey(key))) {
          const { data: encrypted, error: encryptionError } = await admin.rpc('encrypt_ai_api_key', {
            p_key: key,
          })
          if (encryptionError || !isEncryptedKey(encrypted)) throw new Error('Credential encryption failed')
          key = encrypted
        }
        const { error } = await admin.from('institution_ai_settings').upsert({
          school_id: schoolId, mode: input.mode, provider: input.provider, model_id: input.model_id,
          monthly_quota_generations: input.monthly_quota_generations, teacher_daily_limit: input.teacher_daily_limit,
          alert_thresholds: input.alert_thresholds, status: input.mode === 'demo' ? 'demo' : 'active',
          encrypted_api_key: key, updated_at: new Date().toISOString(),
        }, { onConflict: 'school_id' })
        if (error) throw error
        return reply({ success: true, has_api_key: !!key })
      }
      const config = action === 'test_connection' ? { ...settings, ...body.settings } : settings
      if (!config || !Object.hasOwn(providers, config.provider)) return reply({ error: 'Configura un proveedor de IA válido.' }, 400)
      if (body.apiKey !== undefined && (typeof body.apiKey !== 'string' || body.apiKey.length > 1024)) return reply({ error: 'Clave no válida.' }, 400)
      let key = (action === 'test_connection' ? body.apiKey?.trim() : null) || settings?.encrypted_api_key
      if (!key) return reply({ error: 'La institución aún no ha configurado una clave de IA.' }, 409)
      if (isEncryptedKey(key)) {
        const { data: decrypted, error: decryptionError } = await admin.rpc('decrypt_ai_api_key', {
          p_armored_cipher: key,
        })
        if (decryptionError || typeof decrypted !== 'string' || !decrypted.trim()) throw new Error('Credential decryption failed')
        key = decrypted
      }
      const model = modelFor(config, action === 'test_connection' ? 'automatica' : body.quality)
      if (!/^[\w.:-]{1,100}$/.test(model)) return reply({ error: 'Modelo no válido.' }, 400)
      const provider = new providers[config.provider](key, model)
      if (action === 'test_connection') {
        const result = await provider.testConnection()
        // Provider errors may echo request credentials; never return them to the browser.
        return reply({ success: result.success === true, message: result.success ? 'Conexión verificada.' : 'No se pudo verificar el proveedor. Revisa la clave y el modelo.' })
      }
      if (!body.input || typeof body.input !== 'object' || Array.isArray(body.input)) return reply({ error: 'Datos de generación no válidos.' }, 400)
      if (action === 'regenerateSection' && (typeof body.sectionKey !== 'string' || !/^[a-z_]{1,80}$/.test(body.sectionKey))) return reply({ error: 'Sección no válida.' }, 400)
      const safeInput = sanitizeEducationAIInput(body.input)
      if (!safeInput.ok) return reply({ error: safeInput.error }, 400)
      const { data: reservation, error: quotaError } = await admin.rpc('reserve_education_ai_usage', {
        p_school_id: schoolId, p_user_id: identity.user.id, p_task_type: tasks[action], p_provider: config.provider, p_model_id: model,
      })
      if (quotaError) return reply({ error: 'La generación no está disponible o se alcanzó el límite de la institución.' }, 429)
      if (!reservation) throw new Error('Usage reservation was not confirmed')
      reservationId = reservation
      const started = Date.now()
      const result = await provider[action](safeInput.value, body.sectionKey)
      if (!isValidEducationAIOutput(action, result)) throw new Error('Invalid provider output')
      const { error: ledgerError } = await admin.from('ai_usage_ledger').update({ status: 'success', duration_ms: Date.now() - started }).eq('id', reservationId)
      if (ledgerError) throw ledgerError
      return reply({ ...result, _meta: { provider: config.provider, model, isDemo: false, durationMs: Date.now() - started, generatedAt: new Date().toISOString() } })
    } catch {
      if (admin && reservationId) {
        // No prompts, keys or personal data in logs or error responses.
        await admin.from('ai_usage_ledger').update({ status: 'error' }).eq('id', reservationId).then(() => {}, () => {})
      }
      if (admin) {
        try {
          await admin.rpc('record_edge_function_error', {
            p_function_name: 'education-ai', p_error_message: 'GENERATION_FAILED', p_status_code: 502,
            p_school_id: requestSchoolId || null, p_user_id: actorId || null,
            p_metadata: { action: actionName || 'unknown' },
          })
        } catch {
          // The user-facing error must not depend on telemetry availability.
        }
      }
      return reply({ error: 'No se pudo completar la operación de IA. Inténtalo nuevamente.' }, 502)
    }
  }
}
