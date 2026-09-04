/**
 * Composable para la Configuración de Inteligencia Artificial por Institución
 */

import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { toast } from 'vue-sonner'
import { GeminiEducationAIProvider } from '../lib/ai/GeminiEducationAIProvider'
import { OpenAIEducationAIProvider } from '../lib/ai/OpenAIEducationAIProvider'
import { DemoEducationAIProvider } from '../lib/ai/DemoEducationAIProvider'

export function useInstitutionAISettings() {
  const authStore = useAuthStore()
  const loading = ref(false)
  const saving = ref(false)
  const testing = ref(false)
  const testResult = ref(null)

  const settings = ref({
    mode: 'managed', // managed | byok | demo
    provider: 'gemini',
    model_id: 'auto',
    apiKey: '',
    hasExistingKey: false,
    monthly_quota_generations: 200,
    teacher_daily_limit: 15,
    status: 'active',
    alert_thresholds: [70, 90, 100]
  })

  const usageStats = ref({
    monthly_usage: 0,
    monthly_quota: 200,
    usage_percentage: 0,
    history: []
  })

  const fetchSettings = async () => {
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!schoolId) return

    loading.value = true
    try {
      const { data, error } = await supabase
        .from('institution_ai_settings')
        .select('*')
        .eq('school_id', schoolId)
        .maybeSingle()

      if (data) {
        settings.value = {
          mode: data.mode || 'managed',
          provider: data.provider || 'gemini',
          model_id: data.model_id || 'auto',
          apiKey: '',
          hasExistingKey: !!data.encrypted_api_key,
          monthly_quota_generations: data.monthly_quota_generations || 200,
          teacher_daily_limit: data.teacher_daily_limit || 15,
          status: data.status || 'active',
          alert_thresholds: data.alert_thresholds || [70, 90, 100]
        }
      }

      // Cargar estadísticas de consumo
      const { data: usageCount } = await supabase
        .from('ai_usage_ledger')
        .select('id', { count: 'exact', head: true })
        .eq('school_id', schoolId)
        .gte('created_at', new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString())

      const count = usageCount || 0
      const quota = settings.value.monthly_quota_generations || 200
      usageStats.value = {
        monthly_usage: count,
        monthly_quota: quota,
        usage_percentage: Math.min(100, Math.round((count / quota) * 100))
      }
    } catch (err) {
      console.warn('Error cargando configuración de IA:', err)
    } finally {
      loading.value = false
    }
  }

  const testConnection = async (customApiKey = null) => {
    testing.value = true
    testResult.value = null

    try {
      if (settings.value.mode === 'demo') {
        const demo = new DemoEducationAIProvider()
        testResult.value = await demo.testConnection()
      } else if (settings.value.provider === 'openai') {
        const keyToTest = customApiKey || settings.value.apiKey
        const model = settings.value.model_id === 'auto' ? 'gpt-5.6-luna' : (settings.value.model_id || 'gpt-5.6-luna')
        const openai = new OpenAIEducationAIProvider(keyToTest, model)
        testResult.value = await openai.testConnection()
      } else {
        const keyToTest = customApiKey || settings.value.apiKey
        const model = settings.value.model_id === 'auto' ? 'gemini-2.5-flash' : (settings.value.model_id || 'gemini-2.5-flash')
        const gemini = new GeminiEducationAIProvider(keyToTest, model)
        testResult.value = await gemini.testConnection()
      }

      if (testResult.value.success) {
        toast.success(testResult.value.message || 'Conexión verificada con éxito')
      } else {
        toast.error(testResult.value.message || 'Error al verificar proveedor')
      }
    } catch (err) {
      testResult.value = { success: false, message: err.message }
      toast.error('Error: ' + err.message)
    } finally {
      testing.value = false
    }
  }

  const saveSettings = async () => {
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!schoolId) {
      toast.error('No hay institución activa seleccionada.')
      return
    }

    saving.value = true
    try {
      const payload = {
        school_id: schoolId,
        mode: settings.value.mode,
        provider: settings.value.provider,
        model_id: settings.value.model_id,
        monthly_quota_generations: Number(settings.value.monthly_quota_generations),
        teacher_daily_limit: Number(settings.value.teacher_daily_limit),
        status: settings.value.mode === 'demo' ? 'demo' : 'active',
        alert_thresholds: settings.value.alert_thresholds,
        updated_at: new Date().toISOString()
      }

      if (settings.value.apiKey && settings.value.apiKey.trim()) {
        payload.encrypted_api_key = settings.value.apiKey.trim()
      }

      const { error } = await supabase
        .from('institution_ai_settings')
        .upsert(payload, { onConflict: 'school_id' })

      if (error) throw error

      toast.success('Configuración de Inteligencia Artificial guardada correctamente.')
      settings.value.apiKey = ''
      settings.value.hasExistingKey = true
    } catch (err) {
      toast.error('Error al guardar configuración: ' + err.message)
    } finally {
      saving.value = false
    }
  }

  return {
    loading,
    saving,
    testing,
    testResult,
    settings,
    usageStats,
    fetchSettings,
    testConnection,
    saveSettings
  }
}
