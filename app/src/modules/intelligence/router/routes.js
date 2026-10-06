/**
 * LOGREVA — Intelligence Module Routes
 */

export const intelligenceRoutes = [
  {
    path: '/intelligence/cockpit',
    name: 'intelligence-cockpit',
    component: () => import('../views/TeacherCockpitView.vue'),
    meta: { 
      title: 'Panel Docente',
      requiresAuth: true,
      permission: 'grades.read',
      intelligenceFeature: true
    }
  },
  {
    path: '/intelligence/diagnostico',
    name: 'intelligence-diagnostico',
    component: () => import('../views/DiagnosticSessionView.vue'),
    meta: { 
      title: 'Diagnóstico',
      requiresAuth: true,
      permissionsAll: ['students.read', 'grades.update'],
      intelligenceFeature: true
    }
  },
  {
    path: '/intelligence/pasaporte/:studentId',
    name: 'intelligence-pasaporte',
    component: () => import('../views/LearningPassportView.vue'),
    meta: { 
      title: 'Pasaporte de Aprendizaje',
      requiresAuth: true,
      permission: 'students.read',
      intelligenceFeature: true
    }
  },
  {
    path: '/intelligence/impacto',
    name: 'intelligence-impacto',
    component: () => import('../views/ImpactAnalyticsView.vue'),
    meta: { 
      title: 'Impacto Educativo',
      requiresAuth: true,
      permission: 'reports.read',
      intelligenceFeature: true
    }
  }
]
