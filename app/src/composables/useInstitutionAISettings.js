/**
 * Composable para la Configuración de Inteligencia Artificial por Institución
 */

import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { toast } from 'vue-sonner'
import { AI_SETTINGS_COLUMNS, invokeEducationAI } from '../lib/ai/RemoteEducationAIProvider'
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
        .select(AI_SETTINGS_COLUMNS)
        .eq('school_id', schoolId)
        .maybeSingle()

      if (error) throw error
      if (data) {
        settings.value = {
          mode: data.mode || 'managed',
          provider: data.provider || 'gemini',
          model_id: data.model_id || 'auto',
          apiKey: '',
          hasExistingKey: !!data.has_api_key,
          monthly_quota_generations: data.monthly_quota_generations ?? 200,
          teacher_daily_limit: data.teacher_daily_limit ?? 15,
          status: data.status || 'active',
          alert_thresholds: data.alert_thresholds || [70, 90, 100]
        }
      }

      // Cargar estadísticas de consumo
      const { count: usageCount, error: usageError } = await supabase
        .from('ai_usage_ledger')
        .select('id', { count: 'exact', head: true })
        .eq('school_id', schoolId)
        .eq('status', 'success')
        .gte('created_at', new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString())

      if (usageError) throw usageError
      const count = usageCount ?? 0
      const quota = settings.value.monthly_quota_generations ?? 200
      usageStats.value = {
        monthly_usage: count,
        monthly_quota: quota,
        usage_percentage: quota > 0 ? Math.min(100, Math.round((count / quota) * 100)) : 100,
        history: []
      }
    } catch (err) {
      toast.error('Error cargando configuración de IA: ' + err.message)
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
      } else {
        testResult.value = await invokeEducationAI({
          action: 'test_connection',
          schoolId: authStore.activeSchoolId || authStore.profile?.school_id,
          settings: { provider: settings.value.provider, model_id: settings.value.model_id },
          apiKey: (customApiKey || settings.value.apiKey || '').trim() || undefined
        })
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
        mode: settings.value.mode,
        provider: settings.value.provider,
        model_id: settings.value.model_id,
        monthly_quota_generations: Number(settings.value.monthly_quota_generations),
        teacher_daily_limit: Number(settings.value.teacher_daily_limit),
        status: settings.value.mode === 'demo' ? 'demo' : 'active',
        alert_thresholds: settings.value.alert_thresholds
      }

      const result = await invokeEducationAI({
        action: 'save_settings', schoolId, settings: payload,
        apiKey: settings.value.apiKey.trim() || undefined
      })

      toast.success('Configuración de Inteligencia Artificial guardada correctamente.')
      settings.value.apiKey = ''
      settings.value.hasExistingKey = !!result.has_api_key
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
