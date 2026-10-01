/**
 * LOGREVA — Intelligence Service
 * Capa de comunicación con Supabase para el catálogo de competencias,
 * banco de reactivos diagnósticos, registro de evidencias y brechas de aprendizaje reales.
 */

import { supabase } from '../../../lib/supabase'
import {
  calculateGapPriority,
  generateActionablePedagogicalGroups
} from '../utils/pedagogyEngine'
import { intelligenceFeatureService } from './intelligenceFeatureService'

export const intelligenceService = {
  /**
   * Obtiene la lista de cursos reales de la institución activa
   */
  async getCourses(schoolId) {
    try {
      if (!schoolId) return []
      const { data, error } = await supabase
        .from('courses')
        .select('id, name, level, track, academic_year')
        .eq('school_id', schoolId)
        .order('name')
      if (error) throw error
      return data || []
    } catch (err) {
      console.warn('intelligenceService: error cargando cursos:', err)
      throw err
    }
  },

  /**
   * Obtiene las asignaturas reales de un curso en la institución activa
   */
  async getSubjectsForCourse(courseId, schoolId) {
    try {
      if (!courseId) return []
      let query = supabase
        .from('course_subjects')
        .select(`
          id,
          subject_id,
          subjects (
            id,
            name
          )
        `)
        .eq('course_id', courseId)
      if (schoolId) {
        query = query.eq('school_id', schoolId)
      }
      const { data, error } = await query
      if (error) throw error
      return (data || []).map(cs => ({
        course_subject_id: cs.id,
        subject_id: cs.subject_id,
        name: cs.subjects?.name || 'Asignatura'
      }))
    } catch (err) {
      console.warn('intelligenceService: error cargando asignaturas:', err)
      throw err
    }
  },

  /**
   * Obtiene el catálogo de competencias curriculares reales
   */
  async getCompetencies(subjectArea = null) {
    let query = supabase.from('competencies').select('*').eq('status', 'active')
    if (subjectArea) {
      const keyword = subjectArea.split(' ')[0].trim()
      query = query.ilike('subject_area', `%${keyword}%`)
    }
    const { data, error } = await query
    if (error) throw error
    return data || []
  },

  /**
   * Obtiene reactivos diagnósticos para una materia/nivel
   */
  async getDiagnosticItems(subjectArea = 'Matemática', { schoolId, gradeLevel = 'Media' } = {}) {
    if (!schoolId) throw new Error('No hay una institución activa para iniciar el diagnóstico.')
    if (!subjectArea || !gradeLevel) throw new Error('Faltan la asignatura o el nivel para iniciar el diagnóstico.')

    const { data, error } = await supabase.rpc('get_intelligence_diagnostic_items', {
      p_school_id: schoolId,
      p_subject_area: subjectArea || 'Matemática',
      p_grade_level: gradeLevel || 'Media'
    })
    if (error) throw error

    const items = (Array.isArray(data) ? data : []).map(({ correct_answer: _discardedAnswer, ...safeItem }) => safeItem)
    if (items.length === 0) {
      throw new Error('No hay preguntas diagnósticas disponibles para la asignatura y el nivel seleccionados.')
    }
    return items
  },

  async submitDiagnosticAnswer({ schoolId, studentId, assessmentItemId, answer }) {
    if (!schoolId || !studentId || !assessmentItemId || !answer) {
      throw new Error('Faltan datos para guardar la respuesta diagnóstica.')
    }

    const { data, error } = await supabase.rpc('submit_intelligence_diagnostic_answer', {
      p_school_id: schoolId,
      p_student_id: studentId,
      p_assessment_item_id: assessmentItemId,
      p_answer: answer
    })
    if (error) throw error
    if (!data?.success) throw new Error(data?.message || 'No se pudo guardar la respuesta diagnóstica.')
    return data
  },

  /**
   * Genera el radar de curso y grupos de recuperación para el Teacher Cockpit con ESTUDIANTES REALES
   */
  async getTeacherCockpitData(courseId, schoolId, subjectName = 'Matemática') {
    if (!courseId || !schoolId) {
      return {
        courseId,
        schoolId,
        subjectName,
        totalStudents: 0,
        competenciesCount: 0,
        radarStats: [],
        pedagogicalGroups: [],
        students: [],
        hasRealData: false
      }
    }

    const competencies = await this.getCompetencies(subjectName)

    // Si se especifica un curso real, cargar la nómina auténtica de estudiantes
    if (courseId) {
      try {
        let stQuery = supabase
          .from('students')
          .select('id, full_name, student_cedula, representative_name, school_id')
          .eq('course_id', courseId)
          .order('full_name')

        if (schoolId) {
          stQuery = stQuery.eq('school_id', schoolId)
        }

        const { data: realStudents, error: stError } = await stQuery

        if (stError) throw stError

        if (Array.isArray(realStudents) && realStudents.length > 0) {
          const studentIds = realStudents.map(s => s.id)
          const compIds = competencies.map(c => c.id)

          // 1. Cargar brechas activas registradas en DB
          let gapsQuery = supabase
            .from('learning_gaps')
            .select(`
              student_id, 
              competency_id, 
              cause_competency_id, 
              severity, 
              priority,
              status,
              competencies!competency_id (
                id,
                code,
                name
              )
            `)
            .in('student_id', studentIds)
            .in('status', ['open', 'in_recovery'])

          if (schoolId) gapsQuery = gapsQuery.eq('school_id', schoolId)
          const { data: realGaps, error: gapsError } = await gapsQuery
          if (gapsError) throw gapsError

          // 2. Cargar microintervenciones para las competencias de esta asignatura
          const { data: interventions, error: interventionsError } = await supabase
            .from('interventions')
            .select('*')
            .in('competency_id', compIds)
          if (interventionsError) throw interventionsError

          let masteryRecords = []
          if (compIds.length > 0) {
            const { data, error: masteryError } = await supabase
              .from('mastery_state')
              .select('student_id, competency_id, state')
              .eq('school_id', schoolId)
              .in('student_id', studentIds)
              .in('competency_id', compIds)
            if (masteryError) throw masteryError
            masteryRecords = data || []
          }

          // 3. Estructurar lista de estudiantes reales con sus brechas
          const mappedStudents = realStudents.map(s => {
            const sGaps = (realGaps || [])
              .filter(g => g.student_id === s.id)
              .map(g => ({
                competencyId: g.competency_id,
                competencyName: g.competencies?.name || 'Competencia',
                causeCompetencyId: g.cause_competency_id,
                causeName: null,
                severity: g.severity || 'medium'
              }))

            return {
              id: s.id,
              name: s.full_name,
              cedula: s.student_cedula,
              representative: s.representative_name,
              gaps: sGaps
            }
          })

          // 4. Agrupamiento pedagógico de acción en aula
          const pedagogicalGroups = generateActionablePedagogicalGroups(mappedStudents, interventions || [])

          // 5. Radar de competencias del curso
          const total = mappedStudents.length
          const radarStats = competencies.map((comp, idx) => {
            const affected = mappedStudents.filter(s => 
              (s.gaps || []).some(g => g.competencyId === comp.id || g.causeCompetencyId === comp.id)
            ).length
            const competencyMastery = masteryRecords.filter(record => record.competency_id === comp.id)
            const assessedStudents = new Set(competencyMastery.map(record => record.student_id)).size
            const masteredStudents = new Set(
              competencyMastery
                .filter(record => ['MASTERED', 'COMPETENT'].includes(record.state))
                .map(record => record.student_id)
            ).size
            const masteryRate = total > 0 ? Number((masteredStudents / total).toFixed(2)) : 0

            return {
              competencyId: comp.id,
              code: comp.code,
              name: comp.name,
              subject: comp.subject_area,
              affectedStudents: affected,
              assessedStudents,
              masteredStudents,
              masteryRate,
              priorityScore: calculateGapPriority({
                curricularImpact: idx === 2 ? 1.5 : 1.0,
                severity: affected > 2 ? 'high' : 'medium',
                studentCount: affected,
                totalStudents: total || 1,
                isPrerequisiteOfOther: idx === 0
              })
            }
          })

          return {
            courseId,
            schoolId,
            subjectName,
            totalStudents: total,
            competenciesCount: competencies.length,
            radarStats,
            pedagogicalGroups,
            students: mappedStudents,
            hasRealData: true
          }
        }
      } catch (err) {
        console.warn('intelligenceService: error consultando estudiantes reales:', err)
        throw err
      }
    }

    return {
      courseId,
      schoolId,
      subjectName,
      totalStudents: 0,
      competenciesCount: competencies.length,
      radarStats: [],
      pedagogicalGroups: [],
      students: [],
      hasRealData: false
    }
  },

  /**
   * Sincroniza en tiempo real las brechas de aprendizaje a partir de las calificaciones registradas en el curso
   */
  async syncCourseGapsFromGrades({ schoolId, courseId, courseSubjectId = null }) {
    if (!schoolId || !courseId) {
      throw new Error('Faltan la institución o el curso para sincronizar calificaciones.')
    }
    const { data, error } = await supabase.rpc('sync_course_gaps_from_grades', {
      p_school_id: schoolId,
      p_course_id: courseId,
      p_course_subject_id: courseSubjectId
    })
    if (error) throw error
    if (!data?.success) throw new Error(data?.message || 'No se pudo sincronizar la información de calificaciones.')
    return data
  },

  /**
   * Invoca el RPC assign_pedagogical_intervention para registrar un grupo en recuperación
   */
  async assignPedagogicalIntervention({ schoolId, interventionId, courseId, studentIds, notes }) {
    if (!schoolId || !interventionId || !courseId || !studentIds?.length) {
      throw new Error('Faltan datos para asignar la intervención.')
    }

    const { data, error } = await supabase.rpc('assign_pedagogical_intervention', {
      p_school_id: schoolId,
      p_intervention_id: interventionId,
      p_course_id: courseId,
      p_student_ids: studentIds,
      p_notes: notes || 'Asignado desde Panel Docente'
    })
    if (error) throw error
    if (!data?.success) throw new Error(data?.message || 'No se pudo asignar la intervención.')
    return data
  },

  /**
   * Invoca el RPC complete_intervention_with_reevaluation para verificar el cierre de brecha
   */
  async completeInterventionReevaluation({ schoolId, runId, studentId, competencyId, score, rawResponse }) {
    if (!runId) {
      throw new Error('La intervención debe estar asignada antes de reevaluar.')
    }
    if (!schoolId || !studentId || !competencyId || !Number.isFinite(score) || score < 0 || score > 1) {
      throw new Error('Datos de reevaluación inválidos.')
    }

    const { data, error } = await supabase.rpc('complete_intervention_with_reevaluation', {
      p_school_id: schoolId,
      p_run_id: runId || null,
      p_student_id: studentId,
      p_competency_id: competencyId,
      p_score: score,
      p_raw_response: rawResponse || null
    })
    if (error) throw error
    if (!data?.success) throw new Error(data?.message || 'No se pudo guardar la reevaluación.')
    return data
  },

  /**
   * Invoca el RPC get_school_learning_impact_analytics para el panel directivo con datos reales
   */
  async fetchImpactAnalytics({ schoolId, courseId = null, subjectName = null }) {
    if (!schoolId) throw new Error('No hay una institución activa para consultar los indicadores.')

    const { data, error } = await supabase.rpc('get_school_learning_impact_analytics', {
      p_school_id: schoolId,
      p_course_id: courseId,
      p_subject_name: subjectName
    })
    if (error) throw error
    if (!data || typeof data !== 'object') throw new Error('El servicio de indicadores devolvió una respuesta inválida.')
    return data
  },

  /**
   * Invoca el RPC get_student_longitudinal_passport para el reporte familiar con datos reales
   */
  async fetchStudentLongitudinalPassport({ studentId, schoolId }) {
    if (!studentId || !schoolId) throw new Error('Estudiante e institución son obligatorios para consultar el pasaporte.')

    const { data, error } = await supabase.rpc('get_student_longitudinal_passport', {
      p_student_id: studentId,
      p_school_id: schoolId
    })
    if (error) throw error
    if (!data?.student?.id) throw new Error('El servicio de pasaporte devolvió una respuesta inválida.')
    return data
  },

  /**
   * Valida si el módulo de Inteligencia está habilitado para la institución
   */
  async checkModuleEnabled({ schoolId, client }) {
    return intelligenceFeatureService.checkModuleEnabled({ schoolId, client })
  }
}
