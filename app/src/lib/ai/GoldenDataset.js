/**
 * Golden Dataset Curricular del Ecuador
 * Colección inmutable de casos de prueba pedagógicos de referencia para detectar regresiones
 * en la generación de planes de clase, recursos y adaptaciones DUA.
 */

export const GOLDEN_DATASET = Object.freeze([
  {
    id: 'golden-mat-6egb-001',
    subject: 'Matemáticas',
    level: 'basica_media',
    gradeYear: '6to_egb',
    topicTitle: 'Operaciones combinadas con números decimales',
    dcdCode: 'M.3.1.28',
    methodology: 'ERCA',
    expectedCriteria: {
      requiredPhases: ['experiencia', 'reflexion', 'conceptualizacion', 'aplicacion'],
      minRubricCriteria: 3,
      minDuaAccommodations: 2,
      minLearningObjectives: 1,
      expectedBloomLevel: 'aplicar'
    }
  },
  {
    id: 'golden-fis-1bgu-002',
    subject: 'Física',
    level: 'bachillerato_general',
    gradeYear: '1ro_bgu',
    topicTitle: 'Movimiento Rectilíneo Uniforme (MRU)',
    dcdCode: 'CN.F.5.1.1',
    methodology: 'ABP_PROYECTOS',
    expectedCriteria: {
      minRubricCriteria: 3,
      minDuaAccommodations: 2,
      minLearningObjectives: 1,
      expectedBloomLevel: 'analizar'
    }
  },
  {
    id: 'golden-len-8egb-003',
    subject: 'Lengua y Literatura',
    level: 'basica_superior',
    gradeYear: '8vo_egb',
    topicTitle: 'Estructura del texto de divulgación científica',
    dcdCode: 'LL.4.3.1',
    methodology: 'ERCA',
    expectedCriteria: {
      requiredPhases: ['experiencia', 'reflexion', 'conceptualizacion', 'aplicacion'],
      minRubricCriteria: 3,
      minDuaAccommodations: 2,
      minLearningObjectives: 1,
      expectedBloomLevel: 'comprender'
    }
  }
])
