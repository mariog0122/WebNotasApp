/** Operaciones seguras del catálogo académico usadas por la interfaz. */
import { supabase } from '../lib/supabase'

const requireSchool = (schoolId) => {
  if (!schoolId) throw new Error('No hay una institución activa seleccionada.')
}

const confirmSubject = (data, { schoolId, subjectId = null, name, action }) => {
  if (
    !data?.success
    || data.action !== action
    || !data.subject?.id
    || data.subject.school_id !== schoolId
    || data.subject.name !== name
    || (subjectId && data.subject.id !== subjectId)
  ) throw new Error('El servidor no confirmó el guardado de la asignatura.')
  return data.subject
}

export const academicService = {
  async createSubject({ name, school_id }) {
    const cleanName = String(name || '').trim()
    if (!cleanName) throw new Error('El nombre de la asignatura no puede estar vacío.')
    requireSchool(school_id)
    const { data, error } = await supabase.rpc('save_subject_record', {
      p_school_id: school_id,
      p_subject_id: null,
      p_name: cleanName,
    })
    if (error) throw error
    return confirmSubject(data, { schoolId: school_id, name: cleanName, action: 'created' })
  },

  async updateSubject(id, { name, school_id }) {
    if (!id) throw new Error('ID de asignatura inválido.')
    const cleanName = String(name || '').trim()
    if (!cleanName) throw new Error('El nombre de la asignatura no puede estar vacío.')
    requireSchool(school_id)
    const { data, error } = await supabase.rpc('save_subject_record', {
      p_school_id: school_id,
      p_subject_id: id,
      p_name: cleanName,
    })
    if (error) throw error
    return confirmSubject(data, { schoolId: school_id, subjectId: id, name: cleanName, action: 'updated' })
  },

  async deleteSubject(id, school_id) {
    if (!id) throw new Error('ID de asignatura inválido.')
    requireSchool(school_id)
    const { data, error } = await supabase.rpc('delete_subject_record', {
      p_school_id: school_id,
      p_subject_id: id,
    })
    if (error) throw error
    if (!data?.success || data.subject_id !== id || data.school_id !== school_id || Number(data.deleted_count) !== 1) {
      throw new Error('El servidor no confirmó la eliminación de la asignatura.')
    }
    return true
  },

  async importSubjectsBatch(subjectsToInsert, school_id) {
    if (!Array.isArray(subjectsToInsert) || subjectsToInsert.length === 0) {
      throw new Error('No hay asignaturas válidas para importar.')
    }
    requireSchool(school_id)
    const names = subjectsToInsert.map(subject => String(subject?.name || '').trim())
    if (names.some(name => !name)) throw new Error('El lote contiene una asignatura sin nombre.')
    const { data, error } = await supabase.rpc('import_subjects_batch', {
      p_school_id: school_id,
      p_names: names,
    })
    if (error) throw error
    if (!data?.success || data.school_id !== school_id || Number(data.inserted_count) !== names.length) {
      throw new Error('El servidor no confirmó la importación completa de asignaturas.')
    }
    return data
  },
}
