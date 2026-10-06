/**
 * tenantService.js
 * Capa de servicios desacoplada para gestión de instituciones, límites y módulos activados.
 */
import { supabase } from '../lib/supabase'

export const tenantService = {
  /**
   * Obtiene los módulos activados de una institución
   */
  async fetchFeatures(schoolId) {
    if (!schoolId) throw new Error('ID de institución requerido.')

    const feats = {}
    const { data, error } = await supabase
      .from('tenant_features')
      .select('*')
      .eq('school_id', schoolId)

    if (!error && data && data.length > 0) {
      data.forEach(f => { feats[f.feature_key] = f.enabled })
      return feats
    }

    if (error) {
      throw error
    }

    return feats
  },

  /**
   * Guarda los módulos de una institución consolidando en tenant_features
   */
  async saveFeatures(schoolId, featuresMap) {
    if (!schoolId) throw new Error('ID de institución requerido.')

    const updates = Object.keys(featuresMap).map(key => ({
      school_id: schoolId,
      feature_key: key,
      enabled: Boolean(featuresMap[key])
    }))

    const { error } = await supabase.from('tenant_features').upsert(updates)
    if (error) throw error

    return true
  },

  /**
   * Obtiene los límites comerciales y técnicos de una institución
   */
  async fetchLimits(schoolId) {
    if (!schoolId) throw new Error('ID de institución requerido.')

    const { data: lim, error } = await supabase
      .from('tenant_limits')
      .select('*')
      .eq('school_id', schoolId)
      .maybeSingle()

    if (!error && lim) return lim

    if (error) {
      throw error
    }

    return null
  },

  /**
   * Guarda los límites de una institución consolidando en tenant_limits
   */
  async saveLimits(schoolId, limitsData) {
    if (!schoolId) throw new Error('ID de institución requerido.')

    const { error } = await supabase.from('tenant_limits').upsert({
      school_id: schoolId,
      ...limitsData,
      updated_at: new Date().toISOString()
    })

    if (error) throw error

    return true
  }
}
