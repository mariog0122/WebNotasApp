import { describe, it, expect } from 'vitest'
import { GOLDEN_DATASET } from '../src/lib/ai/GoldenDataset'
import { AIEvaluationService } from '../src/lib/ai/AIEvaluationService'
import { DemoEducationAIProvider } from '../src/lib/ai/DemoEducationAIProvider'

describe('Evaluación Automática y Golden Dataset Curricular de Ecuador', () => {
  it('contains validated benchmark cases covering basic and bachillerato levels', () => {
    expect(GOLDEN_DATASET.length).toBeGreaterThanOrEqual(3)

    const mathCase = GOLDEN_DATASET.find(c => c.subject === 'Matemáticas')
    expect(mathCase).toBeDefined()
    expect(mathCase.dcdCode).toBe('M.3.1.28')
    expect(mathCase.expectedCriteria.requiredPhases).toContain('experiencia')
    expect(mathCase.expectedCriteria.requiredPhases).toContain('aplicacion')

    const physicsCase = GOLDEN_DATASET.find(c => c.subject === 'Física')
    expect(physicsCase).toBeDefined()
    expect(physicsCase.level).toBe('bachillerato_general')
  })

  it('runs automated benchmark evaluation suite against DemoEducationAIProvider without regressions', async () => {
    const demo = new DemoEducationAIProvider()
    const suiteResult = await AIEvaluationService.runBenchmarkSuite(demo)

    expect(suiteResult.totalCases).toBe(GOLDEN_DATASET.length)
    expect(suiteResult.passedCases).toBe(GOLDEN_DATASET.length)
    expect(suiteResult.suitePassed).toBe(true)
    expect(suiteResult.averageScore).toBeGreaterThanOrEqual(0.85)

    for (const result of suiteResult.results) {
      expect(result.passed).toBe(true)
      expect(result.metrics.curriculum_alignment).toBeGreaterThanOrEqual(0.8)
      expect(result.metrics.pedagogical_quality).toBeGreaterThanOrEqual(0.8)
      expect(result.metrics.hallucination_rate).toBeLessThanOrEqual(0.05)
    }
  })
})
