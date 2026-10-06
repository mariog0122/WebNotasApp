/**
 * Proveedor de Inteligencia Artificial Pedagógica en Modo Demostración
 * Generador determinista de alta fidelidad contextualizado al Currículo de Ecuador.
 */

export class DemoEducationAIProvider {
  constructor() {
    this.name = 'demo'
    this.model = 'demo-pedagogico-ec'
  }

  async testConnection() {
    return {
      success: true,
      status: 'active',
      provider: 'demo',
      model: this.model,
      message: 'Proveedor pedagógico demostrativo activo y listo para operar.',
      timestamp: new Date().toISOString()
    }
  }

  /**
   * Genera una planificación completa de clase
   */
  async generatePlan(input) {
    // Simulación de latencia realista no bloqueante (600ms)
    await new Promise(r => setTimeout(r, 600))

    const {
      topicTitle = 'Contenido Curricular',
      unitTitle = 'Unidad de Aprendizaje',
      subjectName = 'Asignatura',
      gradeYear = 'Grado EGB',
      regime = 'costa_galapagos',
      durationMinutes = 45,
      sessionCount = 2,
      dcdCodes = [],
      dcdDescriptions = [],
      methodologyPrimary = 'ERCA',
      evaluationCriteriaDescriptions = [],
      evaluationIndicators = [],
      learningObjectives = [],
      bloomLevel = 'aplicar',
      duaPrinciples = ['implicacion', 'representacion', 'accion_expresion'],
      adaptedStudents = []
    } = input

    const totalMinutes = durationMinutes * sessionCount
    const expMin = Math.round(totalMinutes * 0.15)
    const refMin = Math.round(totalMinutes * 0.20)
    const conMin = Math.round(totalMinutes * 0.35)
    const aplMin = Math.round(totalMinutes * 0.30)

    const dcdText = dcdDescriptions[0] || 'Desarrollar habilidades cognitivas y prácticas en la materia.'
    const objText = learningObjectives[0] || `Comprender y aplicar los principios de ${topicTitle} en contextos reales del entorno ecuatoriano.`
    const indText = evaluationIndicators[0] || `Aplica los conceptos de ${topicTitle} demostrando rigor y pensamiento crítico.`

    const grade1Students = adaptedStudents.filter(s => String(s.adaptation_grade) === '1').map(s => s.full_name)
    const grade2Students = adaptedStudents.filter(s => String(s.adaptation_grade) === '2').map(s => s.full_name)
    const grade3Students = adaptedStudents.filter(s => String(s.adaptation_grade) === '3').map(s => s.full_name)

    const accommodations = [
      {
        area: 'Acceso a la Información (Visual / Auditivo)',
        grade: '1',
        students: grade1Students,
        strategy: 'Uso de macrotipo, contrastes cromáticos y apoyo gráfico con organizadores conceptuales.'
      },
      {
        area: 'Expresión y Respuesta (Metodología y Tiempos)',
        grade: '2',
        students: grade2Students,
        strategy: 'Permitir entrega oral o digital y otorgar 15 minutos adicionales en la fase de aplicación práctica.'
      },
      {
        area: 'Compromiso, Motivación y DCD Adaptada',
        grade: '3',
        students: grade3Students,
        strategy: 'Alineación de destrezas con objetivos personalizados mediante tareas graduadas y andamiaje individualizado.'
      }
    ]

    return {
      summary: {
        title: `Plan de Clase: ${topicTitle}`,
        topic: topicTitle,
        unit: unitTitle,
        subject: subjectName,
        grade: gradeYear,
        regime: regime === 'costa_galapagos' ? 'Costa – Galápagos' : 'Sierra – Amazonía',
        durationTotal: `${totalMinutes} min (${sessionCount} sesiones de ${durationMinutes} min)`,
        mainObjective: objText,
        dcdSummary: dcdText,
        bloomLevel: bloomLevel.toUpperCase(),
        methodology: methodologyPrimary
      },
      didactic_sequence: {
        methodology: methodologyPrimary,
        total_time_minutes: totalMinutes,
        phases: [
          {
            phase_id: 'experiencia',
            name: '1. Experiencia Concreta (Anticipación)',
            time_minutes: expMin,
            teacher_activity: `Presentar una situación de la vida cotidiana o dilema contextual en Ecuador relacionado con ${topicTitle}. Motivar mediante una pregunta provocadora vinculada a experiencias previas.`,
            student_activity: `Participar en lluvia de ideas activa, compartir experiencias y registrar en sus cuadernos o pizarras individuales la primera hipótesis sobre el tema.`,
            resources: ['Proyector / Pizarra', 'Material concreto o imagen disparadora', 'Guía de preguntas iniciales'],
            evaluation_type: 'Diagnóstica y formativa inicial'
          },
          {
            phase_id: 'reflexion',
            name: '2. Reflexión Crítica (Problematización)',
            time_minutes: refMin,
            teacher_activity: `Guiar el análisis crítico mediante preguntas socráticas: ¿Por qué ocurre esto? ¿Qué sucedería si cambiamos las condiciones? Modelar el razonamiento lógico.`,
            student_activity: `Dialogar en parejas heterogéneas, contrastar opiniones, identificar la necesidad de un método formal y formular interrogantes clave.`,
            resources: ['Ficha de preguntas de reflexión', 'Texto escolar del MinEduc'],
            evaluation_type: 'Formativa de proceso'
          },
          {
            phase_id: 'conceptualizacion',
            name: '3. Conceptualización Abstracta (Construcción)',
            time_minutes: conMin,
            teacher_activity: `Explicar de forma interactiva los conceptos y reglas de ${topicTitle}. Utilizar organizadores gráficos (mapa mental, cuadro sinóptico) y ejemplos progresivos de menor a mayor complejidad.`,
            student_activity: `Construir colaborativamente un organizador gráfico en sus cuadernos, deducir la regla o procedimiento principal y resolver un ejemplo guiado con retroalimentación inmediata.`,
            resources: ['Esquema conceptual en pizarra', 'Ficha resumen con vocabulario clave', 'Herramientas digitales / Calculadora si aplica'],
            evaluation_type: 'Verificación formativa de comprensión'
          },
          {
            phase_id: 'aplicacion',
            name: '4. Aplicación Práctica (Consolidación y Transferencia)',
            time_minutes: aplMin,
            teacher_activity: `Plantear un taller práctico o reto en equipos donde apliquen ${dcdText}. Supervisar los grupos brindando andamiaje pedagógico diferenciado.`,
            student_activity: `Resolver el reto propuesto en equipos, justificar el procedimiento utilizado y presentar un producto breve (ejercicio resuelto, cartel síntesis o ticket de salida).`,
            resources: ['Ficha de trabajo / Taller práctico', 'Rúbrica analítica simplificada', 'Ticket de salida'],
            evaluation_type: 'Formativa y sumativa con rúbrica'
          }
        ]
      },
      evaluation_plan: {
        technique: 'Observación sistemática y análisis del desempeño práctico',
        instrument: 'Rúbrica analítica y lista de cotejo de evidencias',
        criteria: evaluationCriteriaDescriptions[0] || 'Aplica los conceptos y procedimientos de la unidad en la resolución de problemas reales.',
        indicator: indText,
        evidence: 'Ficha de trabajo resuelta, participación en el debate reflexivo y ticket de salida de consolidación.',
        rubric: [
          {
            criterion: 'Comprensión y Rigor Conceptual',
            excellent: 'Identifica y aplica con total precisión todos los conceptos de la destreza.',
            good: 'Aplica los conceptos principales con errores menores de procedimiento.',
            needs_improvement: 'Demuestra confusión parcial en conceptos clave pero logra aproximaciones.',
            insufficient: 'No identifica los conceptos fundamentales de la sesión.'
          },
          {
            criterion: 'Resolución de Problemas y Aplicación',
            excellent: 'Resuelve situaciones complejas justificando cada paso de forma lógica.',
            good: 'Resuelve la mayoría de situaciones siguiendo el procedimiento modelado.',
            needs_improvement: 'Requiere acompañamiento constante para completar los ejercicios.',
            insufficient: 'No logra transferir los conocimientos al ejercicio práctico.'
          },
          {
            criterion: 'Trabajo Colaborativo y Comunicación',
            excellent: 'Participa proactivamente, escucha a sus pares y expresa ideas con claridad.',
            good: 'Colabora adecuadamente en su equipo y cumple su rol asignado.',
            needs_improvement: 'Muestra poca interacción o requiere recordatorios de concentración.',
            insufficient: 'No se integra al trabajo grupal ni participa de las actividades.'
          }
        ],
        feedback_strategy: 'Devolución verbal formativa durante la sesión y retroalimentación escrita focalizada en los tickets de salida.'
      },
      inclusion_dua_plan: {
        principles_applied: duaPrinciples,
        accommodations: accommodations,
        support_for_barriers: {
          slow_pacing: 'Fichas con andamiaje escalonado, menos cantidad de ejercicios y tiempo extendido.',
          fast_pacing: 'Retos de profundización y tutoría entre pares para estudiantes avanzados.',
          low_connectivity: 'Todas las actividades cuentan con variante física imprimible sin requerir internet.'
        }
      },
      resources_plan: {
        suggested_materials: [
          'Guía didáctica para el docente con tiempos y preguntas generadoras',
          'Ficha de taller imprimible para el estudiante',
          'Rúbrica analítica de 3 criterios',
          'Ticket de salida con 2 preguntas de autoevaluación'
        ]
      }
    }
  }

  /**
   * Regenera únicamente una sección individual
   */
  async regenerateSection(input, sectionKey) {
    await new Promise(r => setTimeout(r, 400))
    const fullPlan = await this.generatePlan(input)
    return fullPlan[sectionKey] || fullPlan
  }

  /**
   * Genera uno de los 17 tipos de recursos didácticos
   */
  async generateResource(input) {
    await new Promise(r => setTimeout(r, 500))
    const {
      resourceType = 'ficha_trabajo',
      topicTitle = 'Tema de Clase',
      subjectName = 'Asignatura',
      gradeYear = 'Grado EGB',
      learningObjectives = [],
      dcdDescriptions = [],
      difficultyLevel = 'medio'
    } = input

    const dcd = dcdDescriptions[0] || 'Desarrollar destrezas prácticas y conceptuales del área.'

    switch (resourceType) {
      case 'ficha_trabajo':
        return {
          type: 'ficha_trabajo',
          title: `Taller de Aplicación: ${topicTitle}`,
          instructions: 'Lee con atención cada una de las actividades y resuelve de forma individual o en parejas.',
          sections: [
            {
              title: 'Actividad 1: Activación y Reconocimiento',
              prompt: `A partir de lo aprendido en clase sobre ${topicTitle}, completa el siguiente cuadro sinóptico con tus propias palabras.`
            },
            {
              title: 'Actividad 2: Aplicación Práctica Guiada',
              prompt: `Resuelve los siguientes ejercicios de nivel ${difficultyLevel} aplicando la destreza (${dcd}).`
            },
            {
              title: 'Actividad 3: Desafío de Pensamiento Crítico',
              prompt: `Imagina una situación en tu ciudad o comunidad escolar donde sea indispensable aplicar ${topicTitle}. Explica qué solución propondrías.`
            }
          ],
          exit_ticket: {
            question: '¿Qué fue lo que más fácil comprendiste hoy y en qué punto necesitas más práctica?'
          }
        }

      case 'rubrica':
        return {
          type: 'rubrica',
          title: `Rúbrica Analítica de Evaluación: ${topicTitle}`,
          descriptors: [
            {
              aspect: 'Comprensión y Rigor',
              levels: {
                muy_superior: '10 - 9: Domina y explica con total precisión conceptual.',
                superior: '8.9 - 7: Comprende los aspectos clave con mínimas imprecisiones.',
                medio: '6.9 - 5: Presenta vacíos conceptuales que limitan la aplicación.',
                bajo: 'Menor a 5: No demuestra comprensión básica de la destreza.'
              }
            },
            {
              aspect: 'Procedimiento y Resolución',
              levels: {
                muy_superior: '10 - 9: Aplica procedimientos óptimos y justifica cada respuesta.',
                superior: '8.9 - 7: Sigue el procedimiento adecuado con pocos errores.',
                medio: '6.9 - 5: Procedimiento desordenado o incompleto.',
                bajo: 'Menor a 5: Procedimiento incorrecto o sin resolver.'
              }
            }
          ]
        }

      case 'cuestionario':
        return {
          type: 'cuestionario',
          title: `Cuestionario de Comprensión: ${topicTitle}`,
          questions: [
            {
              num: 1,
              type: 'opcion_multiple',
              question: `¿Cuál es el concepto central que define a ${topicTitle}?`,
              options: ['Opción A: Definición formal correcta', 'Opción B: Distractor común', 'Opción C: Concepto opuesto', 'Opción D: Información irrelevante'],
              correct_answer: 'Opción A'
            },
            {
              num: 2,
              type: 'verdadero_falso',
              question: `En el contexto de ${subjectName}, el procedimiento de ${topicTitle} depende del análisis de variables.`,
              correct_answer: 'Verdadero'
            },
            {
              num: 3,
              type: 'desarrollo',
              question: `Explica un ejemplo de la vida cotidiana donde sea fundamental aplicar este conocimiento.`
            }
          ]
        }

      case 'comunicacion_familia':
        return {
          type: 'comunicacion_familia',
          title: `Notificación Pedagógica para Representantes`,
          channels: ['WhatsApp', 'Mensajería Institucional'],
          message: `Estimada familia: En ${gradeYear} estamos abordando en ${subjectName} el tema "${topicTitle}". Les invitamos a dialogar en casa con su representado sobre cómo aplica estos aprendizajes en la vida diaria. Agradecemos su permanente apoyo.`
        }

      default:
        return {
          type: resourceType,
          title: `Recurso Didáctico: ${topicTitle}`,
          content_summary: `Material adaptado para ${gradeYear} en la asignatura de ${subjectName}.`,
          sections: [
            { title: 'Propósito', content: `Fortalecer la destreza ${dcd}` },
            { title: 'Contenido y Actividades', content: `Guía estructurada de nivel ${difficultyLevel} para el aula de clases.` }
          ]
        }
    }
  }

  /**
   * Genera un plan individualizado de recuperación y apoyo pedagógico
   */
  async generateStudentSupport(input) {
    await new Promise(r => setTimeout(r, 450))
    const {
      observedDifficulty = 'Dificultad en comprensión y aplicación de la destreza',
      evidenceType = 'calificacion',
      intensity = 'moderada',
      durationWeeks = 2,
      topicTitle = 'Contenido Académico',
      subjectName = 'Materia'
    } = input

    return {
      diagnostic_summary: `Se observa dificultad en ${observedDifficulty}, respaldada por evidencia de tipo ${evidenceType}. Se diseña intervención de intensidad ${intensity} con duración de ${durationWeeks} semanas.`,
      pedagogical_goals: [
        `Revisar y nivelar los prerrequisitos conceptuales de ${topicTitle}.`,
        `Desarrollar ejercicios con andamiaje paso a paso y refuerzo visual.`,
        `Consolidar la destreza alcanzando un puntaje mínimo de 7/10 en la evaluación de recuperación.`
      ],
      weekly_plan: [
        {
          week: 1,
          objective: 'Nivelación de prerrequisitos y aclaración de dudas',
          activities: [
            'Tutoría pedagógica de 20 minutos con material concreto o esquemas visuales.',
            'Resolución de 3 ejercicios tipo con modelado docente explícito.',
            'Ficha de refuerzo para el hogar con acompañamiento de la familia.'
          ],
          evidence: 'Ficha de trabajo 1 revisada.'
        },
        {
          week: 2,
          objective: 'Aplicación autónoma y evaluación de recuperación',
          activities: [
            'Taller práctico autónomo con apoyo de un estudiante tutor.',
            'Evaluación formativa de verificación de logros.',
            'Registro de calificación de recuperación pedagógica en el sistema.'
          ],
          evidence: 'Prueba de recuperación pedagógica aprobada.'
        }
      ],
      family_recommendations: [
        'Establecer un horario diario de 20 minutos para repasar las fichas enviadas.',
        'Verificar que el estudiante realice los ejercicios sin distractores (celular, TV).',
        'Mantener comunicación fluida con el docente de la asignatura.'
      ]
    }
  }
}
