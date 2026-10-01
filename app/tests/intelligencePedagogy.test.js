import { describe, it, expect, vi } from 'vitest'
import {
  calculateMasteryState,
  calculateGapPriority,
  generateActionablePedagogicalGroups,
  evaluateSocraticInteraction,
  MASTERY_STATES
} from '../src/modules/intelligence/utils/pedagogyEngine'
import { intelligenceService } from '../src/modules/intelligence/services/intelligenceService'

describe('LOGREVA — Pedagogy & Intelligence Engine', () => {
  describe('calculateMasteryState()', () => {
    it('returns NOT_EVIDENCED when no evidence exists', () => {
      const result = calculateMasteryState([])
      expect(result.state).toBe(MASTERY_STATES.NOT_EVIDENCED)
      expect(result.score).toBe(0)
      expect(result.confidence).toBe(0)
    })

    it('identifies MASTERED when student demonstrates high consistency over time', () => {
      const evidences = [
        { score: 0.9, confidence: 0.8, weight: 1.0 },
        { score: 0.95, confidence: 0.9, weight: 1.0 },
        { score: 1.0, confidence: 0.95, weight: 1.2 }
      ]
      const result = calculateMasteryState(evidences)
      expect(result.state).toBe(MASTERY_STATES.MASTERED)
      expect(result.score).toBeGreaterThanOrEqual(0.85)
      expect(result.confidence).toBeGreaterThanOrEqual(0.7)
      expect(result.color).toBe('emerald')
    })

    it('identifies COMPETENT when student demonstrates acceptable proficiency', () => {
      const evidences = [
        { score: 0.75, confidence: 0.7, weight: 1.0 },
        { score: 0.72, confidence: 0.8, weight: 1.0 }
      ]
      const result = calculateMasteryState(evidences)
      expect(result.state).toBe(MASTERY_STATES.COMPETENT)
      expect(result.score).toBeGreaterThanOrEqual(0.70)
      expect(result.color).toBe('blue')
    })

    it('identifies DEVELOPING (refuerzo) when score is below 0.50', () => {
      const evidences = [
        { score: 0.3, confidence: 0.8, weight: 1.0 },
        { score: 0.4, confidence: 0.85, weight: 1.0 }
      ]
      const result = calculateMasteryState(evidences)
      expect(result.state).toBe(MASTERY_STATES.DEVELOPING)
      expect(result.score).toBeLessThan(0.50)
      expect(result.label).toBe('Requiere refuerzo')
      expect(result.color).toBe('rose')
    })
  })

  describe('calculateGapPriority()', () => {
    it('ranks prerequisite dependencies with higher priority score', () => {
      const regularGap = calculateGapPriority({
        curricularImpact: 1.0,
        severity: 'medium',
        studentCount: 3,
        totalStudents: 30,
        isPrerequisiteOfOther: false
      })

      const prerequisiteGap = calculateGapPriority({
        curricularImpact: 1.0,
        severity: 'medium',
        studentCount: 3,
        totalStudents: 30,
        isPrerequisiteOfOther: true
      })

      expect(prerequisiteGap).toBeGreaterThan(regularGap)
    })

    it('increases priority as frequency and severity increase', () => {
      const lowPrio = calculateGapPriority({ severity: 'low', studentCount: 1, totalStudents: 30 })
      const criticalPrio = calculateGapPriority({ severity: 'critical', studentCount: 10, totalStudents: 30 })
      expect(criticalPrio).toBeGreaterThan(lowPrio * 2)
    })
  })

  describe('generateActionablePedagogicalGroups()', () => {
    it('clusters students into at most 3 to 5 actionable groups', () => {
      const mockStudents = [
        { id: '1', name: 'Estudiante 1', gaps: [{ competencyId: 'comp-1', competencyName: 'Fracciones', causeCompetencyId: 'comp-0', causeName: 'División básica', severity: 'high' }] },
        { id: '2', name: 'Estudiante 2', gaps: [{ competencyId: 'comp-1', competencyName: 'Fracciones', causeCompetencyId: 'comp-0', causeName: 'División básica', severity: 'critical' }] },
        { id: '3', name: 'Estudiante 3', gaps: [{ competencyId: 'comp-2', competencyName: 'Inferencia', severity: 'medium' }] }
      ]

      const groups = generateActionablePedagogicalGroups(mockStudents)
      expect(groups.length).toBeGreaterThan(0)
      expect(groups.length).toBeLessThanOrEqual(5)

      // El grupo principal debe ser el de División básica porque afecta a 2 estudiantes
      const rootGroup = groups[0]
      expect(rootGroup.competencyName).toBe('División básica')
      expect(rootGroup.studentCount).toBe(2)
      expect(rootGroup.estimatedTimeMinutes).toBe(15)
      expect(rootGroup.suggestedIntervention.id).toBeNull()
      expect(rootGroup.suggestedIntervention.isPersisted).toBe(false)
    })
  })

  describe('evaluateSocraticInteraction()', () => {
    it('blocks direct solution demands and yields a pedagogical hint', () => {
      const itemContext = {
        stem: '¿Cuánto es 1/2 + 1/4?',
        hints: ['Observa que los denominadores son diferentes.', 'Convierte a cuartos.']
      }

      const result = evaluateSocraticInteraction('Dime la respuesta por favor', itemContext, 0)
      expect(result.allowDirectAnswer).toBe(false)
      expect(result.reply).toContain('Pista:')
      expect(result.reply).toContain('Observa que los denominadores son diferentes.')
      expect(result.nextHintLevel).toBe(1)
    })

    it('provides progressive second hint on subsequent request', () => {
      const itemContext = {
        hints: ['Pista 1', 'Pista 2']
      }
      const result = evaluateSocraticInteraction('resuélvelo tú', itemContext, 1)
      expect(result.reply).toContain('Pista 2')
    })
  })

  describe('intelligenceService', () => {
    it('requires an institutional context before loading diagnostic items', async () => {
      await expect(intelligenceService.getDiagnosticItems('Matemática')).rejects.toThrow(
        'No hay una institución activa para iniciar el diagnóstico.'
      )
    })

    it('returns an empty Teacher Cockpit when no real course is selected', async () => {
      const cockpit = await intelligenceService.getTeacherCockpitData(null, 'school-123')
      expect(cockpit.radarStats).toBeDefined()
      expect(cockpit.pedagogicalGroups).toBeDefined()
      expect(cockpit.students).toBeDefined()
      expect(cockpit.totalStudents).toBe(0)
      expect(cockpit.students).toEqual([])
    })

    it('rejects an incomplete recovery-group assignment before contacting the backend', async () => {
      await expect(intelligenceService.assignPedagogicalIntervention({
        schoolId: null,
        interventionId: null,
        courseId: null,
        studentIds: [],
      })).rejects.toThrow('Faltan datos para asignar la intervención.')
    })

    it('rejects an invalid reevaluation score before contacting the backend', async () => {
      await expect(intelligenceService.completeInterventionReevaluation({
        schoolId: 'school-1',
        runId: 'run-1',
        studentId: 'std-1',
        competencyId: 'comp-1',
        score: 1.5
      })).rejects.toThrow('Datos de reevaluación inválidos.')
    })
  })
})
