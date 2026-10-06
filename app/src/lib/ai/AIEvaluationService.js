/**
 * Servicio de Evaluación Automatizada de Calidad de IA (AIEvaluationService)
 * Mide el rendimiento y detecta regresiones en modelos generativos evaluando contra el Golden Dataset.
 */

import { GOLDEN_DATASET } from './GoldenDataset'

export class AIEvaluationService {
  /**
   * Evalúa una planificación generada contra los criterios del caso de referencia
   */
  static evaluatePlan(plan, benchmarkCase) {
    if (!plan || typeof plan !== 'object') {
      return {
        passed: false,
        overall_score: 0.0,
        metrics: {
          curriculum_alignment: 0.0,
          pedagogical_quality: 0.0,
          age_alignment: 0.0,
          format_accuracy: 0.0,
          hallucination_rate: 1.0
        }
      }
    }

    let curriculumScore = 0.0
    let pedagogicalScore = 0.0
    let ageScore = 1.0 // Por defecto coherente
    let formatScore = 0.0
    let hallucinationRate = 0.0

    // 1. Alineación Curricular (Objetivos, DCD, Indicadores)
    if (plan.summary?.title) curriculumScore += 0.3
    if (plan.summary?.dcdSummary || plan.summary?.mainObjective || plan.summary?.competencies?.length > 0) curriculumScore += 0.3
    if (plan.evaluation_plan?.rubric?.length >= (benchmarkCase.expectedCriteria?.minRubricCriteria || 3)) {
      curriculumScore += 0.4
    }

    // 2. Calidad Pedagógica (Metodología y Fases)
    if (benchmarkCase.expectedCriteria?.requiredPhases) {
      const phases = plan.didactic_sequence?.phases || []
      const phaseIds = phases.map(p => p.phase_id || '')
      const matched = benchmarkCase.expectedCriteria.requiredPhases.filter(rp => phaseIds.includes(rp))
      pedagogicalScore += (matched.length / benchmarkCase.expectedCriteria.requiredPhases.length) * 0.7
    } else {
      pedagogicalScore += 0.7
    }

    if (plan.inclusion_dua_plan?.accommodations?.length >= (benchmarkCase.expectedCriteria?.minDuaAccommodations || 2)) {
      pedagogicalScore += 0.3
    }

    // 3. Exactitud del Formato (Estructura JSON formal)
    if (plan.summary && plan.didactic_sequence && plan.evaluation_plan && plan.inclusion_dua_plan) {
      formatScore = 1.0
    } else {
      formatScore = 0.5
      hallucinationRate += 0.1
    }

    // 4. Score General Ponderado
    const overallScore = parseFloat((
      curriculumScore * 0.35 +
      pedagogicalScore * 0.35 +
      ageScore * 0.15 +
      formatScore * 0.15 -
      hallucinationRate
    ).toFixed(2))

    const passed = overallScore >= 0.85 && hallucinationRate <= 0.05

    return {
      passed,
      overall_score: Math.max(0.0, Math.min(1.0, overallScore)),
      metrics: {
        curriculum_alignment: parseFloat(curriculumScore.toFixed(2)),
        pedagogical_quality: parseFloat(pedagogicalScore.toFixed(2)),
        age_alignment: parseFloat(ageScore.toFixed(2)),
        format_accuracy: parseFloat(formatScore.toFixed(2)),
        hallucination_rate: parseFloat(hallucinationRate.toFixed(2))
      }
    }
  }

  /**
   * Ejecuta la suite completa de evaluación contra todos los casos del Golden Dataset
   */
  static async runBenchmarkSuite(providerInstance) {
    const results = []
    let totalScore = 0

    for (const benchmark of GOLDEN_DATASET) {
      try {
        const plan = await providerInstance.generatePlan({
          topicTitle: benchmark.topicTitle,
          subjectName: benchmark.subject,
          gradeYear: benchmark.gradeYear,
          level: benchmark.level,
          methodologyPrimary: benchmark.methodology,
          dcdCodes: [benchmark.dcdCode],
          dcdDescriptions: [benchmark.topicTitle]
        })

        const evalResult = AIEvaluationService.evaluatePlan(plan, benchmark)
        results.push({
          caseId: benchmark.id,
          subject: benchmark.subject,
          ...evalResult
        })
        totalScore += evalResult.overall_score
      } catch (err) {
        results.push({
          caseId: benchmark.id,
          subject: benchmark.subject,
          passed: false,
          overall_score: 0.0,
          error: err.message
        })
      }
    }

    const averageScore = results.length > 0 ? parseFloat((totalScore / results.length).toFixed(2)) : 0
    const suitePassed = results.every(r => r.passed) && averageScore >= 0.85

    return {
      suitePassed,
      averageScore,
      totalCases: results.length,
      passedCases: results.filter(r => r.passed).length,
      results,
      evaluatedAt: new Date().toISOString()
    }
  }
}
