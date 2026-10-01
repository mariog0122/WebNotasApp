/**
 * Consulta mínima del estado del módulo de inteligencia.
 * Se mantiene separada del servicio pedagógico para no cargarlo en el paquete principal.
 */
import { supabase } from '../../../lib/supabase'

export const intelligenceFeatureService = {
  async checkModuleEnabled({ schoolId, client = supabase }) {
    try {
      if (!schoolId) return false
      const { data, error } = await client.rpc('is_intelligence_module_enabled', {
        p_school_id: schoolId,
      })
      if (error) throw error
      return data === true
    } catch {
      return false
    }
  },
}
