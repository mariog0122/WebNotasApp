/**
 * Catálogo Curricular Nacional del Ecuador (Ministerio de Educación - MinEduc)
 * Competencias Comunicacionales, Matemáticas, Digitales y Socioemocionales.
 * 
 * Contiene:
 * - Subniveles y grados con edades sugeridas
 * - Asignaturas por subnivel
 * - Destrezas con Criterio de Desempeño (DCD) con códigos oficiales
 * - Criterios e Indicadores de Evaluación oficiales
 * - Objetivos de Aprendizaje
 * - Taxonomía de Bloom revisada
 * - Metodologías activas (ERCA, ABP, DUA, etc.)
 * - 17 Tipos de recursos didácticos
 * - Categorías de apoyo, adecuación y recuperación pedagógica
 */

export const EDUCATIONAL_REGIMES = [
  { id: 'costa_galapagos', name: 'Costa – Galápagos', description: 'Régimen Lectivo Costa y Región Insular' },
  { id: 'sierra_amazonia', name: 'Sierra – Amazonía', description: 'Régimen Lectivo Sierra y Región Amazónica' }
]

export const EDUCATIONAL_LEVELS = [
  {
    id: 'inicial',
    name: 'Educación Inicial',
    shortName: 'Inicial',
    sublevels: ['Inicial 1 (3-4 años)', 'Inicial 2 (4-5 años)'],
    grades: [
      { id: 'inicial_1', name: 'Inicial 1', ageMin: 3, ageMax: 4 },
      { id: 'inicial_2', name: 'Inicial 2', ageMin: 4, ageMax: 5 }
    ]
  },
  {
    id: 'basica_elemental',
    name: 'Educación General Básica Elemental',
    shortName: 'Básica Elemental',
    sublevels: ['2do, 3ro y 4to Grado EGB'],
    grades: [
      { id: '2do_egb', name: '2do Año EGB', ageMin: 6, ageMax: 7 },
      { id: '3ro_egb', name: '3ro Año EGB', ageMin: 7, ageMax: 8 },
      { id: '4to_egb', name: '4to Año EGB', ageMin: 8, ageMax: 9 }
    ]
  },
  {
    id: 'basica_media',
    name: 'Educación General Básica Media',
    shortName: 'Básica Media',
    sublevels: ['5to, 6to y 7mo Grado EGB'],
    grades: [
      { id: '5to_egb', name: '5to Año EGB', ageMin: 9, ageMax: 10 },
      { id: '6to_egb', name: '6to Año EGB', ageMin: 10, ageMax: 11 },
      { id: '7mo_egb', name: '7mo Año EGB', ageMin: 11, ageMax: 12 }
    ]
  },
  {
    id: 'basica_superior',
    name: 'Educación General Básica Superior',
    shortName: 'Básica Superior',
    sublevels: ['8vo, 9no y 10mo Grado EGB'],
    grades: [
      { id: '8vo_egb', name: '8vo Año EGB', ageMin: 12, ageMax: 13 },
      { id: '9no_egb', name: '9no Año EGB', ageMin: 13, ageMax: 14 },
      { id: '10mo_egb', name: '10mo Año EGB', ageMin: 14, ageMax: 15 }
    ]
  },
  {
    id: 'bachillerato_general',
    name: 'Bachillerato General Unificado (BGU)',
    shortName: 'Bachillerato BGU',
    sublevels: ['1ro, 2do y 3ro Curso BGU'],
    grades: [
      { id: '1ro_bgu', name: '1ro de Bachillerato BGU', ageMin: 15, ageMax: 16 },
      { id: '2do_bgu', name: '2do de Bachillerato BGU', ageMin: 16, ageMax: 17 },
      { id: '3ro_bgu', name: '3ro de Bachillerato BGU', ageMin: 17, ageMax: 18 }
    ]
  },
  {
    id: 'bachillerato_tecnico',
    name: 'Bachillerato Técnico (BT)',
    shortName: 'Bachillerato Técnico',
    sublevels: ['Figura Profesional Técnica'],
    grades: [
      { id: '1ro_bt', name: '1ro de Bachillerato Técnico', ageMin: 15, ageMax: 16 },
      { id: '2do_bt', name: '2do de Bachillerato Técnico', ageMin: 16, ageMax: 17 },
      { id: '3ro_bt', name: '3ro de Bachillerato Técnico', ageMin: 17, ageMax: 18 }
    ]
  }
]

export const MINEDUC_SUBJECTS = {
  basica_elemental: [
    'Lengua y Literatura',
    'Matemáticas',
    'Ciencias Naturales',
    'Estudios Sociales',
    'Educación Cultural y Artística',
    'Educación Física',
    'Inglés'
  ],
  basica_media: [
    'Lengua y Literatura',
    'Matemáticas',
    'Ciencias Naturales',
    'Estudios Sociales',
    'Educación Cultural y Artística',
    'Educación Física',
    'Inglés'
  ],
  basica_superior: [
    'Lengua y Literatura',
    'Matemáticas',
    'Ciencias Naturales',
    'Estudios Sociales',
    'Educación Cultural y Artística',
    'Educación Física',
    'Inglés',
    'Animación a la Lectura'
  ],
  bachillerato_general: [
    'Lengua y Literatura',
    'Matemáticas',
    'Biología',
    'Química',
    'Física',
    'Historia',
    'Filosofía',
    'Educación para la Ciudadanía',
    'Emprendimiento y Gestión',
    'Educación Cultural y Artística',
    'Educación Física',
    'Inglés'
  ],
  bachillerato_tecnico: [
    'Matemáticas',
    'Lengua y Literatura',
    'Física',
    'Química',
    'Historia',
    'Emprendimiento y Gestión',
    'Módulos Formativos Técnicos (FIP)',
    'Formación y Orientación Laboral (FOL)',
    'Inglés Técnico'
  ],
  inicial: [
    'Identidad y Autonomía',
    'Convivencia',
    'Relaciones con el Medio Natural y Cultural',
    'Relaciones Lógico-Matemáticas',
    'Comprensión y Expresión del Lenguaje',
    'Expresión Artística',
    'Expresión Corporal y Motricidad'
  ]
}

export const BLOOM_LEVELS = [
  { id: 'recordar', name: 'Recordar', description: 'Reconocer, listar, describir, identificar información previa' },
  { id: 'comprender', name: 'Comprender', description: 'Interpretar, ejemplificar, clasificar, resumir y explicar' },
  { id: 'aplicar', name: 'Aplicar', description: 'Ejecutar, implementar, usar procedimientos en situaciones concretas' },
  { id: 'analizar', name: 'Analizar', description: 'Diferenciar, organizar, atribuir, contrastar y estructurar ideas' },
  { id: 'evaluar', name: 'Evaluar', description: 'Comprobar, criticar, juzgar y emitir juicios fundamentados' },
  { id: 'crear', name: 'Crear', description: 'Generar, planificar, producir y diseñar soluciones originales' }
]

export const MINEDUC_COMPETENCIES = [
  { id: 'comunicacionales', name: 'Competencias Comunicacionales', icon: 'MessageSquare', color: 'teal' },
  { id: 'matematicas', name: 'Competencias Matemáticas', icon: 'Calculator', color: 'indigo' },
  { id: 'digitales', name: 'Competencias Digitales', icon: 'Laptop', color: 'sky' },
  { id: 'socioemocionales', name: 'Competencias Socioemocionales', icon: 'HeartHandshake', color: 'rose' }
]

export const PEDAGOGICAL_METHODOLOGIES = [
  {
    id: 'ERCA',
    name: 'Ciclo del Aprendizaje ERCA',
    subtitle: 'Experiencia, Reflexión, Conceptualización y Aplicación',
    description: 'Metodología pedagógica rectora del sistema educativo ecuatoriano orientada al desarrollo competencial.',
    phases: [
      { id: 'experiencia', name: '1. Experiencia Concreta', focus: 'Punto de partida vivencial, saberes previos y contacto real con el tema.' },
      { id: 'reflexion', name: '2. Reflexión Crítica', focus: 'Análisis, cuestionamiento guiado y conexión de ideas mediante preguntas generadoras.' },
      { id: 'conceptualizacion', name: '3. Conceptualización Abstracta', focus: 'Construcción formal de conceptos, definiciones, reglas y principios científicos.' },
      { id: 'aplicacion', name: '4. Aplicación Práctica', focus: 'Transferencia de conocimientos a problemas reales, proyectos o desafíos del contexto.' }
    ]
  },
  {
    id: 'ABP_PROYECTOS',
    name: 'Aprendizaje Basado en Proyectos (ABP)',
    subtitle: 'Resolución de desafíos interdisciplinarios',
    description: 'Los estudiantes investigan y responden a una pregunta o problema complejo para elaborar un producto público.',
    phases: [
      { id: 'desafio', name: '1. Pregunta Impulsora / Desafío', focus: 'Definición del reto y objetivos de impacto comunitario.' },
      { id: 'investigacion', name: '2. Investigación y Diseño', focus: 'Búsqueda de información y trabajo en equipo.' },
      { id: 'desarrollo', name: '3. Elaboración de Prototipo', focus: 'Creación iterativa del producto o propuesta.' },
      { id: 'difusion', name: '4. Presentación y Evaluación', focus: 'Defensa del proyecto y reflexión sobre el aprendizaje.' }
    ]
  },
  {
    id: 'ABP_PROBLEMAS',
    name: 'Aprendizaje Basado en Problemas',
    subtitle: 'Análisis crítico a partir de situaciones reales',
    description: 'Enfoque centrado en el alumno donde el aprendizaje ocurre resolviendo problemas abiertos.',
    phases: [
      { id: 'planteamiento', name: '1. Presentación del Problema', focus: 'Lectura y comprensión del escenario o caso.' },
      { id: 'lluvia_ideas', name: '2. Diagnóstico y Saberes', focus: 'Identificación de lo conocido y lo que se necesita aprender.' },
      { id: 'estudio', name: '3. Estudio Autónomo y Cooperativo', focus: 'Profundización teórica y recolección de datos.' },
      { id: 'resolucion', name: '4. Propuesta de Solución', focus: 'Argumentación y evaluación de alternativas.' }
    ]
  },
  {
    id: 'COOPERATIVO',
    name: 'Aprendizaje Cooperativo',
    subtitle: 'Estructuras de interacción positiva',
    description: 'Organización en pequeños grupos heterogéneos para maximizar el aprendizaje mutuo.',
    phases: [
      { id: 'activacion', name: '1. Activación de Equipos', focus: 'Asignación de roles y meta grupal compartida.' },
      { id: 'interdependencia', name: '2. Interdependencia Positiva', focus: 'Desarrollo de tareas compartidas donde el éxito depende de todos.' },
      { id: 'coevaluacion', name: '3. Síntesis y Coevaluación', focus: 'Retroalimentación entre pares y consolidación.' }
    ]
  },
  {
    id: 'AULA_INVERTIDA',
    name: 'Aula Invertida (Flipped Classroom)',
    subtitle: 'Estudio previo en casa y práctica activa en clase',
    description: 'El contenido teórico se asimila antes de la sesión presencial para dedicar la clase al debate y aplicación.',
    phases: [
      { id: 'previo', name: '1. Fase Previa (Asincrónica)', focus: 'Visualización de recursos y preguntas iniciales.' },
      { id: 'discusion', name: '2. Inicio de Sesión', focus: 'Aclaración de dudas y verificación de conceptos clave.' },
      { id: 'taller', name: '3. Taller Práctico / Reto', focus: 'Aplicación guiada y resolución de ejercicios complejos.' }
    ]
  },
  {
    id: 'DUA_PURO',
    name: 'Diseño Universal para el Aprendizaje (DUA)',
    subtitle: 'Accesibilidad cognitiva y adaptaciones sin barreras',
    description: 'Diseño curricular flexible desde el inicio que reduce barreras de aprendizaje para todos los estudiantes.',
    phases: [
      { id: 'implicacion', name: '1. Múltiples Formas de Implicación', focus: 'Opciones para captar interés, esfuerzo y autorregulación.' },
      { id: 'representacion', name: '2. Múltiples Formas de Representación', focus: 'Opciones de percepción, lenguaje y comprensión.' },
      { id: 'accion', name: '3. Múltiples Formas de Acción y Expresión', focus: 'Opciones de respuesta física y habilidades ejecutivas.' }
    ]
  }
]

export const DUA_OPTIONS = [
  {
    principle: 'implicacion',
    title: 'Múltiples formas de implicación (El "Por qué" del aprendizaje)',
    options: [
      'Elección autónoma del formato de trabajo (individual, parejas o equipos)',
      'Actividades ancladas en la realidad local y comunitaria de Ecuador',
      'Desafíos graduados con metas escalonadas de logro',
      'Rúbricas transparentes de autoevaluación y metas personales',
      'Estrategias lúdicas y gamificadas para mantener el interés'
    ]
  },
  {
    principle: 'representacion',
    title: 'Múltiples formas de representación (El "Qué" del aprendizaje)',
    options: [
      'Apoyo visual: organizadores gráficos, esquemas e infografías',
      'Material concreto manipulable (ábacos, regletas, modelos tridimensionales)',
      'Glosario ilustrado de vocabulario técnico y conceptos clave',
      'Subtitulado, audiolectura o textos digitales adaptables',
      'Ejemplos contextualizados y analogías cotidianas'
    ]
  },
  {
    principle: 'accion_expresion',
    title: 'Múltiples formas de acción y expresión (El "Cómo" del aprendizaje)',
    options: [
      'Variedad de productos: exposición oral, podcast, infografía o informe escrito',
      'Plantillas y guías paso a paso para estructurar las respuestas',
      'Tiempo flexible para elaboración y entrega de actividades',
      'Uso de herramientas tecnológicas (calculadoras, procesadores de texto)',
      'Evaluación mediante desempeño práctico en lugar de prueba memorística'
    ]
  }
]

export const RESOURCE_TYPES = [
  { id: 'guia_docente', name: 'Guía Didáctica para el Docente', icon: 'BookOpen', category: 'Planificación', desc: 'Guía con instrucciones paso a paso, tiempos y variantes didácticas.' },
  { id: 'ficha_trabajo', name: 'Ficha de Trabajo / Taller en Clase', icon: 'FileText', category: 'Actividades', desc: 'Hoja de actividades imprimible para los estudiantes.' },
  { id: 'actividad_inicio', name: 'Actividad de Inicio / Provocación', icon: 'Sparkles', category: 'Actividades', desc: 'Dinámica breve para activar saberes previos y motivación.' },
  { id: 'actividad_colaborativa', name: 'Actividad de Trabajo Cooperativo', icon: 'Users', category: 'Actividades', desc: 'Dinámica en equipos con roles definidos e interdependencia.' },
  { id: 'ejercicio_practico', name: 'Guía de Ejercicios Prácticos', icon: 'Edit3', category: 'Actividades', desc: 'Set de ejercicios con diferentes niveles de complejidad.' },
  { id: 'cuestionario', name: 'Cuestionario de Comprensión', icon: 'HelpCircle', category: 'Evaluación', desc: 'Preguntas de opción múltiple, verdadero/falso y desarrollo.' },
  { id: 'banco_preguntas', name: 'Banco de Preguntas por Niveles Bloom', icon: 'Layers', category: 'Evaluación', desc: 'Preguntas clasificadas desde nivel recordar hasta crear.' },
  { id: 'rubrica', name: 'Rúbrica Analítica de Evaluación', icon: 'CheckSquare', category: 'Evaluación', desc: 'Criterios, descriptores y niveles de desempeño cuantitativos.' },
  { id: 'lista_cotejo', name: 'Lista de Cotejo / Checklist', icon: 'ListChecks', category: 'Evaluación', desc: 'Verificación rápida de criterios de cumplimiento.' },
  { id: 'evaluacion_diagnostica', name: 'Evaluación Diagnóstica Inicial', icon: 'ClipboardCheck', category: 'Evaluación', desc: 'Instrumento para detectar prerrequisitos y vacíos de aprendizaje.' },
  { id: 'evaluacion_formativa', name: 'Evaluación Formativa de Proceso', icon: 'BarChart2', category: 'Evaluación', desc: 'Ticket de salida y evaluación formativa rápida.' },
  { id: 'evaluacion_sumativa', name: 'Prueba Sumativa Estructurada', icon: 'Award', category: 'Evaluación', desc: 'Evaluación de unidad conforme a las normas MinEduc.' },
  { id: 'material_refuerzo', name: 'Guía de Refuerzo Pedagógico', icon: 'TrendingUp', category: 'Apoyo', desc: 'Material con explicaciones simplificadas para estudiantes con dificultad.' },
  { id: 'material_profundizacion', name: 'Reto de Profundización / Extensión', icon: 'Compass', category: 'Apoyo', desc: 'Desafíos avanzados para estudiantes con alto ritmo de aprendizaje.' },
  { id: 'tarjetas_estudio', name: 'Tarjetas de Repaso (Flashcards)', icon: 'Copy', category: 'Recursos', desc: 'Fichas con conceptos clave y preguntas rápidas.' },
  { id: 'presentacion_clase', name: 'Guion para Presentación de Clase', icon: 'Monitor', category: 'Recursos', desc: 'Estructura de diapositivas con puntos clave y preguntas.' },
  { id: 'tarea_casa', name: 'Tarea de Aplicación en Casa', icon: 'Home', category: 'Actividades', desc: 'Actividad contextualizada y realista para el hogar.' },
  { id: 'actividad_sin_internet', name: 'Actividad Desconectada (Offline)', icon: 'WifiOff', category: 'Inclusión', desc: 'Actividad con material reciclable y sin necesidad de internet.' },
  { id: 'comunicacion_familia', name: 'Informe Breve para la Familia', icon: 'Send', category: 'Familia', desc: 'Mensaje pedagógico claro para representantes vía WhatsApp.' }
]

export const STUDENT_SUPPORT_CATEGORIES = [
  { id: 'refuerzo', name: 'Plan de Refuerzo Personalizado', desc: 'Acompañamiento pedagógico focalizado en destrezas no consolidadas.' },
  { id: 'recuperacion', name: 'Recuperación Pedagógica', desc: 'Estrategia formal tras evaluación con calificación inferior a 7/10.' },
  { id: 'adecuacion', name: 'Adecuación Curricular / Acceso', desc: 'Ajustes no significativos (Grado 1 y 2) para barreras de aprendizaje.' },
  { id: 'diferenciada', name: 'Actividad Diferenciada en Aula', desc: 'Variante de la tarea regular con apoyos visuales o tiempo extendido.' },
  { id: 'material_apoyo', name: 'Material de Apoyo Específico', desc: 'Fichas y recursos complementarios de estudio guiado.' },
  { id: 'profundizacion', name: 'Proyecto de Profundización', desc: 'Retos de alta complejidad para estudiantes con altas capacidades.' },
  { id: 'retroalimentacion', name: 'Retroalimentación Individual Escrita', desc: 'Devolución formativa detallada sobre fortalezas y mejoras.' },
  { id: 'comunicacion_familia', name: 'Notificación y Pautas para el Hogar', desc: 'Recomendaciones concretas para que la familia apoye en casa.' }
]

/**
 * Catálogo Pedagógico Curricular Oficial de Ecuador
 * Incluye Destrezas con Criterio de Desempeño (DCD), Criterios e Indicadores.
 */
export const ECUADOR_CURRICULAR_DATABASE = [
  // ==========================================
  // MATEMÁTICAS - BÁSICA ELEMENTAL (3ro EGB)
  // ==========================================
  {
    id: 'mat_3egb_u1',
    level: 'basica_elemental',
    grade_year: '3ro_egb',
    subject_name: 'Matemáticas',
    unit_title: 'Unidad 1: Números y Operaciones en mi Entorno',
    topic_title: 'Lectura, escritura y valor posicional de números hasta 999',
    dcd_code: 'M.2.1.12',
    dcd_description: 'Representar, escribir y leer los números naturales del 0 al 999 en forma concreta, gráfica y simbólica.',
    evaluation_criteria_code: 'CE.M.2.2',
    evaluation_criteria_description: 'Aplica estrategias de conteo, el concepto de número, expresiones matemáticas sencillas y propiedades de la suma y la multiplicación en la resolución de problemas cotidianos.',
    evaluation_indicator_code: 'I.M.2.2.1',
    evaluation_indicator_description: 'Completa secuencias numéricas ascendentes o descendentes con números naturales de hasta tres cifras, utilizando material concreto, simbologías y estrategias de conteo.',
    learning_objective_code: 'O.M.2.1',
    learning_objective_description: 'Explicar y construir patrones de figuras y numéricos relacionándolos con la suma y la resta para desarrollar el pensamiento lógico.',
    bloom_level: 'aplicar',
    competencies: ['matematicas', 'comunicacionales']
  },
  {
    id: 'mat_3egb_u2',
    level: 'basica_elemental',
    grade_year: '3ro_egb',
    subject_name: 'Matemáticas',
    unit_title: 'Unidad 2: Estrategias de Cálculo y Resolución de Problemas',
    topic_title: 'Suma y resta con reagrupación en situaciones de compra y venta',
    dcd_code: 'M.2.1.21',
    dcd_description: 'Realizar adiciones y sustracciones con los números hasta 999, con material concreto, mentalmente, gráficamente y de manera numérica.',
    evaluation_criteria_code: 'CE.M.2.2',
    evaluation_criteria_description: 'Aplica estrategias de cálculo mental y algoritmos de suma y resta en la resolución de situaciones problemáticas contextualizadas.',
    evaluation_indicator_code: 'I.M.2.2.3',
    evaluation_indicator_description: 'Aplica de manera razonada la adición y sustracción con reagrupación con números naturales de hasta tres cifras en situaciones de la vida cotidiana.',
    learning_objective_code: 'O.M.2.2',
    learning_objective_description: 'Utilizar objetos del entorno para formar conjuntos y establecer relaciones de equivalencia numérica.',
    bloom_level: 'aplicar',
    competencies: ['matematicas', 'socioemocionales']
  },

  // ==========================================
  // LENGUA Y LITERATURA - BÁSICA ELEMENTAL (3ro EGB)
  // ==========================================
  {
    id: 'leng_3egb_u1',
    level: 'basica_elemental',
    grade_year: '3ro_egb',
    subject_name: 'Lengua y Literatura',
    unit_title: 'Unidad 1: Palabras que nos conectan',
    topic_title: 'Comprensión de textos narrativos (fábulas y cuentos tradicionales ecuatorianos)',
    dcd_code: 'LL.2.3.5',
    dcd_description: 'Desarrollar estrategias cognitivas como lectura de paratextos, establecimiento del propósito de lectura, relectura y parafraseo para autorregular la comprensión.',
    evaluation_criteria_code: 'CE.LL.2.5',
    evaluation_criteria_description: 'Comprende contenidos explícitos e implícitos de un texto basándose en inferencias espacio-temporales y valorativas.',
    evaluation_indicator_code: 'I.LL.2.5.1',
    evaluation_indicator_description: 'Construye los significados de un texto a partir del establecimiento de relaciones de semejanza, diferencia, causa-efecto y cotejo con el contexto.',
    learning_objective_code: 'O.LL.2.5',
    learning_objective_description: 'Leer de manera autónoma textos literarios y no literarios para recrearse y satisfacer necesidades de aprendizaje.',
    bloom_level: 'comprender',
    competencies: ['comunicacionales', 'socioemocionales']
  },

  // ==========================================
  // MATEMÁTICAS - BÁSICA MEDIA (6to EGB)
  // ==========================================
  {
    id: 'mat_6egb_u1',
    level: 'basica_media',
    grade_year: '6to_egb',
    subject_name: 'Matemáticas',
    unit_title: 'Unidad 1: Números Decimales y Fracciones en la Vida Real',
    topic_title: 'Operaciones combinadas con números decimales y redondeo comercial',
    dcd_code: 'M.3.1.28',
    dcd_description: 'Calcular, aplicando algoritmos y la tecnología, sumas, restas, multiplicaciones y divisiones con números decimales.',
    evaluation_criteria_code: 'CE.M.3.5',
    evaluation_criteria_description: 'Plantea problemas numéricos en los que intervienen números naturales, decimales o fraccionarios, asociados a situaciones del entorno.',
    evaluation_indicator_code: 'I.M.3.5.1',
    evaluation_indicator_description: 'Aplica las propiedades de las operaciones y estrategias de cálculo mental o escrito para resolver problemas con números decimales.',
    learning_objective_code: 'O.M.3.1',
    learning_objective_description: 'Utilizar el sistema de coordenadas cartesianas y la generación de sucesiones con sumas, restas, multiplicaciones y divisiones.',
    bloom_level: 'analizar',
    competencies: ['matematicas', 'digitales']
  },
  {
    id: 'mat_6egb_u2',
    level: 'basica_media',
    grade_year: '6to_egb',
    subject_name: 'Matemáticas',
    unit_title: 'Unidad 2: Geometría y Medida en el Espacio',
    topic_title: 'Cálculo de perímetro y área de polígonos regulares e irregulares',
    dcd_code: 'M.3.2.8',
    dcd_description: 'Clasificar polígonos regulares e irregulares según sus lados y ángulos, y calcular el perímetro y área en la resolución de problemas.',
    evaluation_criteria_code: 'CE.M.3.7',
    evaluation_criteria_description: 'Explica las características y propiedades de figuras planas y cuerpos geométricos al resolver situaciones de la vida diaria.',
    evaluation_indicator_code: 'I.M.3.7.1',
    evaluation_indicator_description: 'Construye polígonos con regla y compás y calcula su perímetro y área aplicando fórmulas directas.',
    learning_objective_code: 'O.M.3.3',
    learning_objective_description: 'Resolver problemas cotidianos que requieran del cálculo de perímetros y áreas de polígonos.',
    bloom_level: 'aplicar',
    competencies: ['matematicas', 'comunicacionales']
  },

  // ==========================================
  // CIENCIAS NATURALES - BÁSICA MEDIA (6to EGB)
  // ==========================================
  {
    id: 'cn_6egb_u1',
    level: 'basica_media',
    grade_year: '6to_egb',
    subject_name: 'Ciencias Naturales',
    unit_title: 'Unidad 1: Ecosistemas del Ecuador y Biodiversidad',
    topic_title: 'Cadenas tróficas, niveles tróficos y equilibrio en las cuatro regiones naturales de Ecuador',
    dcd_code: 'CN.3.1.9',
    dcd_description: 'Indagar, con uso de las TIC y otros recursos, las características de los ecosistemas y sus clases, interpretar las interrelaciones de los seres vivos en los ecosistemas y clasificarlos en productores, consumidores y descomponedores.',
    evaluation_criteria_code: 'CE.CN.3.3',
    evaluation_criteria_description: 'Analiza, desde la indagación y observación, la dinámica de los ecosistemas en función de sus características y diversidad biológica.',
    evaluation_indicator_code: 'I.CN.3.3.1',
    evaluation_indicator_description: 'Examina la dinámica de los ecosistemas en función de sus características, diversidad de flora y fauna, y adaptaciones a las regiones naturales de Ecuador.',
    learning_objective_code: 'O.CN.3.1',
    learning_objective_description: 'Observar y describir animales y plantas y agruparlos de acuerdo a sus características para comprender la biodiversidad del país.',
    bloom_level: 'analizar',
    competencies: ['socioemocionales', 'digitales']
  },

  // ==========================================
  // CIENCIAS SOCIALES - BÁSICA SUPERIOR (9no EGB)
  // ==========================================
  {
    id: 'cs_9egb_u1',
    level: 'basica_superior',
    grade_year: '9no_egb',
    subject_name: 'Estudios Sociales',
    unit_title: 'Unidad 1: La Construcción del Estado Ecuatoriano',
    topic_title: 'Diversidad étnica, pueblos y nacionalidades indígenas, afroecuatorianos y montubios',
    dcd_code: 'CS.4.2.28',
    dcd_description: 'Demostrar la vigencia de la interculturalidad en el Ecuador a través del análisis de las manifestaciones culturales y la convivencia armónica de los pueblos.',
    evaluation_criteria_code: 'CE.CS.4.10',
    evaluation_criteria_description: 'Examina la relación entre la democracia y la interculturalidad reconociendo la diversidad humana y cultural del Ecuador.',
    evaluation_indicator_code: 'I.CS.4.10.1',
    evaluation_indicator_description: 'Explica la interculturalidad desde el análisis de las diferentes manifestaciones culturales del Ecuador y promueve el diálogo de saberes.',
    learning_objective_code: 'O.CS.4.5',
    learning_objective_description: 'Determinar los orígenes históricos de la diversidad cultural de la comunidad y del país.',
    bloom_level: 'evaluar',
    competencies: ['socioemocionales', 'comunicacionales']
  },

  // ==========================================
  // LENGUA Y LITERATURA - BÁSICA SUPERIOR (10mo EGB)
  // ==========================================
  {
    id: 'leng_10egb_u1',
    level: 'basica_superior',
    grade_year: '10mo_egb',
    subject_name: 'Lengua y Literatura',
    unit_title: 'Unidad 1: Comunicación Crítica y Ensayo Argumentativo',
    topic_title: 'Estructura, tesis y argumentos en textos de opinión sobre dilemas éticos y medioambiente',
    dcd_code: 'LL.4.4.1',
    dcd_description: 'Escribir textos periodísticos y académicos con manejo de su estructura básica, y sustentar las ideas con razones y ejemplos organizados de manera jerárquica.',
    evaluation_criteria_code: 'CE.LL.4.7',
    evaluation_criteria_description: 'Produce diferentes tipos de textos periodísticos y académicos utilizando elementos de la lengua con coherencia y cohesión.',
    evaluation_indicator_code: 'I.LL.4.7.1',
    evaluation_indicator_description: 'Estructura diferentes tipos de textos académicos (ensayos breves, informes, reseñas) organizando ideas con esquemas lógicos y citas bibliográficas.',
    learning_objective_code: 'O.LL.4.4',
    learning_objective_description: 'Escribir textos persuasivos y académicos para responder a necesidades comunicativas con autonomía y rigor.',
    bloom_level: 'crear',
    competencies: ['comunicacionales', 'digitales']
  },

  // ==========================================
  // MATEMÁTICAS - BACHILLERATO (1ro BGU)
  // ==========================================
  {
    id: 'mat_1bgu_u1',
    level: 'bachillerato_general',
    grade_year: '1ro_bgu',
    subject_name: 'Matemáticas',
    unit_title: 'Unidad 1: Funciones Reales y Modelización Matemática',
    topic_title: 'Función lineal y cuadrática: gráficas, dominio, recorrido y aplicaciones a la física y economía',
    dcd_code: 'M.5.1.20',
    dcd_description: 'Graficar y analizar el dominio, el recorrido, la monotonía, ceros, extremos y paridad de las diferentes funciones reales utilizando las TIC.',
    evaluation_criteria_code: 'CE.M.5.3',
    evaluation_criteria_description: 'Opera y emplea funciones reales lineales, cuadráticas, polinomiales y racionales para modelar situaciones de la vida real.',
    evaluation_indicator_code: 'I.M.5.3.1',
    evaluation_indicator_description: 'Grafica funciones reales y analiza su comportamiento reconociendo sus aplicaciones en modelos científicos y financieros.',
    learning_objective_code: 'O.M.5.1',
    learning_objective_description: 'Proponer soluciones creativas a situaciones concretas de la realidad nacional mediante la aplicación de las matemáticas.',
    bloom_level: 'analizar',
    competencies: ['matematicas', 'digitales']
  },

  // ==========================================
  // HISTORIA - BACHILLERATO (2do BGU)
  // ==========================================
  {
    id: 'hist_2bgu_u1',
    level: 'bachillerato_general',
    grade_year: '2do_bgu',
    subject_name: 'Historia',
    unit_title: 'Unidad 1: Culturas Ancestrales y el Encuentro de Dos Mundos',
    topic_title: 'El Tahuantinsuyo: organización social, reciprocidad andina y tecnología agrícola',
    dcd_code: 'CS.H.5.3.1',
    dcd_description: 'Identificar y valorar las producciones intelectuales más significativas de las culturas aborígenes de América Latina previa a la conquista.',
    evaluation_criteria_code: 'CE.CS.H.5.11',
    evaluation_criteria_description: 'Explica y valora las contribuciones éticas, sociales y tecnológicas de las civilizaciones precolombinas.',
    evaluation_indicator_code: 'I.CS.H.5.11.1',
    evaluation_indicator_description: 'Analiza las producciones intelectuales y materiales de los incas, mayas y aztecas, destacando sus aportes a la humanidad.',
    learning_objective_code: 'O.CS.H.5.3',
    learning_objective_description: 'Analizar los procesos históricos de América Latina desde una perspectiva crítica y descolonizadora.',
    bloom_level: 'evaluar',
    competencies: ['comunicacionales', 'socioemocionales']
  }
]

/**
 * Función de consulta para filtrar el catálogo curricular
 */
export const getCurriculumItems = ({ level, gradeYear, subjectName, query = '' }) => {
  return ECUADOR_CURRICULAR_DATABASE.filter(item => {
    const matchLevel = !level || item.level === level
    const matchGrade = !gradeYear || item.grade_year === gradeYear
    const matchSubject = !subjectName || item.subject_name.toLowerCase() === subjectName.toLowerCase()
    
    let matchQuery = true
    if (query && query.trim()) {
      const q = query.toLowerCase().trim()
      matchQuery = (
        item.dcd_code.toLowerCase().includes(q) ||
        item.dcd_description.toLowerCase().includes(q) ||
        item.topic_title.toLowerCase().includes(q) ||
        item.unit_title.toLowerCase().includes(q)
      )
    }

    return matchLevel && matchGrade && matchSubject && matchQuery
  })
}

/**
 * Genera edades recomendadas para un grado específico
 */
export const getSuggestedAgeForGrade = (gradeId) => {
  for (const lvl of EDUCATIONAL_LEVELS) {
    const grade = lvl.grades.find(g => g.id === gradeId || g.name === gradeId)
    if (grade) {
      return { min: grade.ageMin, max: grade.ageMax, label: `${grade.ageMin} - ${grade.ageMax} años` }
    }
  }
  return { min: 8, max: 9, label: '8 - 9 años' }
}
