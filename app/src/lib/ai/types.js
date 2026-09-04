/**
 * Constantes y Definiciones de Tipos para el Motor de IA Educativo
 */

export const AI_PROVIDERS = Object.freeze({
  DEMO: 'demo',
  GEMINI: 'gemini',
  OPENAI: 'openai'
})

export const AI_MODELS = Object.freeze({
  // Google Gemini (Vigentes)
  AUTO: 'auto',
  GEMINI_37_FLASH: 'gemini-3.7-flash',
  GEMINI_25_FLASH: 'gemini-2.5-flash',
  GEMINI_25_FLASH_LITE: 'gemini-2.5-flash-lite',
  GEMINI_25_PRO: 'gemini-2.5-pro',
  // OpenAI
  GPT_56_LUNA: 'gpt-5.6-luna',
  GPT_4O_MINI: 'gpt-4o-mini',
  GPT_4O: 'gpt-4o',
  // Demo
  DEMO_DEFAULT: 'demo-pedagogico-ec'
})

export const AI_TEACHER_QUALITY = Object.freeze({
  AUTOMATICA: 'automatica',
  ECONOMICA: 'economica',
  ALTA_CALIDAD: 'alta_calidad'
})

export const AI_TASK_TYPES = Object.freeze({
  PLAN_GENERATION: 'plan_generation',
  SECTION_REGENERATION: 'section_regeneration',
  RESOURCE_GENERATION: 'resource_generation',
  STUDENT_SUPPORT_GENERATION: 'student_support_generation'
})

export const AI_STATUSES = Object.freeze({
  ACTIVE: 'active',
  DEMO: 'demo',
  SUSPENDED: 'suspended',
  LIMIT_REACHED: 'limit_reached'
})

export const AI_FEEDBACK_CATEGORIES = Object.freeze({
  PEDAGOGICAL: 'pedagogical',
  CURRICULUM: 'curriculum',
  DIFFICULTY: 'difficulty',
  FORMAT: 'format',
  METHODOLOGY: 'methodology',
  INSTITUTIONAL_PREFERENCE: 'institutional_preference',
  FACTUAL_ERROR: 'factual_error',
  STYLE: 'style',
  RESOURCE_QUALITY: 'resource_quality',
  OTHER: 'other'
})

export const AI_FEEDBACK_STATUSES = Object.freeze({
  RECEIVED: 'received',
  SANITIZED: 'sanitized',
  CLASSIFIED: 'classified',
  QUARANTINED: 'quarantined',
  APPROVED: 'approved',
  REJECTED: 'rejected',
  PROMOTED: 'promoted',
  ARCHIVED: 'archived'
})

export const AI_KNOWLEDGE_SCOPES = Object.freeze({
  USER: 'user',
  INSTITUTION: 'institution',
  GLOBAL: 'global'
})

export const AI_KNOWLEDGE_TYPES = Object.freeze({
  FEW_SHOT_SAMPLE: 'few_shot_sample',
  INSTITUTIONAL_GUIDELINE: 'institutional_guideline',
  PEDAGOGICAL_CAUTION: 'pedagogical_caution',
  TEACHER_PREFERENCE: 'teacher_preference'
})

export const AI_EVALUATION_METRICS = Object.freeze({
  CURRICULUM_ALIGNMENT: 'curriculum_alignment',
  PEDAGOGICAL_QUALITY: 'pedagogical_quality',
  AGE_ALIGNMENT: 'age_alignment',
  COMPETENCY_ALIGNMENT: 'competency_alignment',
  FORMAT_ACCURACY: 'format_accuracy',
  HALLUCINATION_RATE: 'hallucination_rate',
  OVERALL_SCORE: 'overall_score'
})
