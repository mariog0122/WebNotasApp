import { describe, it, expect } from 'vitest'
import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'
import { DemoEducationAIProvider } from '../src/lib/ai/DemoEducationAIProvider'

describe('Adaptaciones Curriculares y Recuperación Pedagógica con IA', () => {
  it('verifies SQL migration 50 creates curricular adaptation columns and index', () => {
    const migrationPath = resolve(__dirname, '../../migrations/50_student_curricular_adaptations.sql')
    expect(existsSync(migrationPath)).toBe(true)

    const sqlContent = readFileSync(migrationPath, 'utf-8')
    expect(sqlContent).toContain('has_adaptation boolean DEFAULT false')
    expect(sqlContent).toContain("adaptation_grade text DEFAULT '1'")
    expect(sqlContent).toContain("adaptation_details text DEFAULT ''")
    expect(sqlContent).toContain('idx_students_adaptation')
  })

  it('correctly maps adapted students by Grade 1, 2 and 3 in AI Lesson Plan (Inclusión / DUA)', async () => {
    const provider = new DemoEducationAIProvider()
    const adaptedStudentsMock = [
      { id: '1', full_name: 'Estudiante Grado 1 Visual', has_adaptation: true, adaptation_grade: '1' },
      { id: '2', full_name: 'Estudiante Grado 2 Tiempos', has_adaptation: true, adaptation_grade: '2' },
      { id: '3', full_name: 'Estudiante Grado 3 DCD', has_adaptation: true, adaptation_grade: '3' }
    ]

    const plan = await provider.generatePlan({
      topicTitle: 'Ecuaciones de Primer Grado',
      subjectName: 'Matemáticas',
      gradeYear: '9no EGB',
      adaptedStudents: adaptedStudentsMock
    })

    expect(plan.inclusion_dua_plan).toBeDefined()
    expect(plan.inclusion_dua_plan.accommodations).toHaveLength(3)

    // Grado 1
    const g1 = plan.inclusion_dua_plan.accommodations.find(a => a.grade === '1')
    expect(g1).toBeDefined()
    expect(g1.students).toContain('Estudiante Grado 1 Visual')

    // Grado 2
    const g2 = plan.inclusion_dua_plan.accommodations.find(a => a.grade === '2')
    expect(g2).toBeDefined()
    expect(g2.students).toContain('Estudiante Grado 2 Tiempos')

    // Grado 3
    const g3 = plan.inclusion_dua_plan.accommodations.find(a => a.grade === '3')
    expect(g3).toBeDefined()
    expect(g3.students).toContain('Estudiante Grado 3 DCD')
  })

  it('generates customized student recovery and pedagogical support materials', async () => {
    const provider = new DemoEducationAIProvider()
    const supportPlan = await provider.generateStudentSupport({
      topicTitle: 'Ecuaciones Lineales',
      subjectName: 'Matemáticas',
      observedDifficulty: 'Nota inferior a 7/10 en el trimestre',
      evidenceType: 'calificacion',
      intensity: 'moderada'
    })

    expect(supportPlan.diagnostic_summary).toBeDefined()
    expect(supportPlan.pedagogical_goals.length).toBeGreaterThan(0)
    expect(supportPlan.weekly_plan.length).toBeGreaterThan(0)
    expect(supportPlan.family_recommendations.length).toBeGreaterThan(0)
  })
})
