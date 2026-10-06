import { supabase } from '../supabase'

export const AI_SETTINGS_COLUMNS = 'school_id,mode,provider,model_id,has_api_key,monthly_quota_generations,teacher_daily_limit,is_active,status,alert_thresholds'

export async function invokeEducationAI(body) {
  const { data, error } = await supabase.functions.invoke('education-ai', { body })
  if (error) {
    const details = await error.context?.json?.().catch(() => null)
    throw new Error(details?.error || 'No se pudo completar la operación de IA. Inténtalo nuevamente.')
  }
  if (!data || data.error) throw new Error(data?.error || 'Respuesta de IA vacía.')
  return data
}

export class RemoteEducationAIProvider {
  constructor(schoolId, quality = 'automatica') {
    this.schoolId = schoolId
    this.quality = quality
  }

  call(action, input, sectionKey) {
    return invokeEducationAI({ schoolId: this.schoolId, action, quality: this.quality, input, sectionKey })
  }

  generatePlan(input) { return this.call('generatePlan', input) }
  regenerateSection(input, sectionKey) { return this.call('regenerateSection', input, sectionKey) }
  generateResource(input) { return this.call('generateResource', input) }
  generateStudentSupport(input) { return this.call('generateStudentSupport', input) }
  testConnection() { return this.call('test_connection') }
}
