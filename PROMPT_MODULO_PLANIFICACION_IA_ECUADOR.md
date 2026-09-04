# Prompt maestro — Módulo de Planificación Educativa con IA

## Rol y objetivo

Actúa como arquitecto de software educativo, diseñador UX/UI senior y desarrollador FullStack. Integra en la aplicación existente un nuevo módulo llamado **Planificación IA**. Debe verse y comportarse como una parte nativa del sistema: conserva la arquitectura, componentes, navegación, permisos, sistema visual, tipografías, colores, espaciado, tema claro/oscuro y patrones de código ya existentes.

El objetivo no es crear un chat ni un campo para escribir prompts. Diseña un flujo guiado donde el docente genere una planificación mediante selecciones, botones, tarjetas, chips, listas, interruptores y menús desplegables. La IA ya dispone del contexto pedagógico y curricular de Ecuador; el usuario solo configura variables académicas y didácticas.

En esta primera versión, el módulo puede funcionar en **modo demostración**, pero toda la navegación, selecciones, estados, resultados, acciones y vistas deben ser funcionales. No uses botones sin acción, pantallas vacías ni formularios que parezcan terminados pero no respondan.

---

## 1. Antes de programar

1. Analiza el repositorio completo y documenta brevemente:
   - stack, estructura, rutas y módulos existentes;
   - sistema de autenticación y roles;
   - modelo de institución, docente, curso, asignatura y estudiante;
   - componentes reutilizables;
   - mecanismo actual de persistencia y multitenencia;
   - pruebas, lint, TypeScript y convenciones del proyecto.
2. No reemplaces la arquitectura ni instales dependencias si ya existe una solución equivalente.
3. No cambies módulos no relacionados.
4. Presenta un plan de implementación breve por archivos y continúa sin pedir confirmación, salvo que exista una decisión destructiva o falte un dato realmente bloqueante.
5. Mantén compatibilidad con los datos y permisos actuales.

---

## 2. Ubicación y acceso

- Añade en la navegación principal la opción **Planificación IA**, con un icono coherente, preferentemente `Sparkles`, `BrainCircuit` o el equivalente del sistema actual.
- Crea una ruta protegida siguiendo el patrón del proyecto, por ejemplo `/planificacion-ia`.
- Roles autorizados:
  - **Docente:** crear, editar, duplicar y consultar sus planificaciones; generar recursos y apoyos para sus estudiantes y cursos asignados.
  - **Administrador institucional:** consultar y administrar planificaciones de su institución, configurar IA, límites, plantillas y políticas.
  - **Superadministrador:** administrar proveedores, modelos, cuotas globales y auditoría, sin romper el aislamiento entre instituciones.
- Ningún usuario podrá acceder a datos de otra institución.

---

## 3. Experiencia principal sin escribir prompts

La primera pantalla debe ser una superficie de trabajo, no una página promocional. Incluye:

- título **Planificación con IA**;
- indicador visible `Modo demostración` cuando no exista un proveedor activo;
- botón **Nueva planificación**;
- tarjetas de resumen: borradores, planificaciones listas, recursos creados y estudiantes con seguimiento;
- historial reciente con estado, curso, asignatura, fecha y acciones;
- filtros por periodo, curso, asignatura y estado.

### Asistente guiado

Implementa un flujo de 5 pasos con barra de progreso. Cada paso debe permitir regresar sin perder las selecciones.

#### Paso 1 — Contexto académico

Opciones por clic:

- institución y periodo lectivo, derivados de la sesión cuando existan;
- régimen: Costa–Galápagos o Sierra–Amazonía;
- nivel, subnivel y curso/año;
- paralelo;
- rango de edad sugerido automáticamente y editable mediante selección;
- asignatura;
- unidad curricular;
- tema o bloque curricular, seleccionado desde catálogo;
- número de estudiantes;
- duración: minutos, número de sesiones y fecha estimada.

No pidas al docente redactar el tema si existe un catálogo curricular. Añade búsqueda dentro de listas extensas, pero no un campo de prompt.

#### Paso 2 — Propósito curricular

Permite seleccionar desde un catálogo versionado:

- competencia que se quiere desarrollar;
- destreza con criterio de desempeño;
- criterio de evaluación;
- indicador de evaluación;
- objetivo de aprendizaje;
- eje o inserción curricular aplicable;
- nivel cognitivo de Bloom revisada;
- tipo de evidencia de aprendizaje.

Las opciones deben filtrarse según nivel, curso, asignatura y unidad seleccionados. No inventes códigos curriculares. Si el catálogo todavía no existe, usa datos demostrativos claramente identificados y crea la interfaz/repositorio que luego recibirá el catálogo oficial versionado.

#### Paso 3 — Diseño metodológico

Permite seleccionar una metodología principal y hasta dos complementarias:

- ERCA;
- aprendizaje basado en proyectos;
- aprendizaje basado en problemas;
- aprendizaje cooperativo;
- aula invertida;
- indagación;
- gamificación;
- estudio de casos;
- aprendizaje por estaciones;
- Diseño Universal para el Aprendizaje (DUA).

Incluye selecciones para:

- modalidad: presencial, virtual o híbrida;
- organización: individual, parejas, equipos o grupo completo;
- recursos disponibles: pizarra, proyector, internet, laboratorio, dispositivos, material reciclado, texto escolar;
- contexto: urbano, rural, conectividad limitada u otro valor institucional preconfigurado;
- enfoque de evaluación: diagnóstica, formativa y/o sumativa.

#### Paso 4 — Inclusión y diferenciación

Configura por selección:

- DUA: múltiples formas de implicación, representación y acción/expresión;
- ritmo: refuerzo, estándar o profundización;
- barreras de aprendizaje presentes en el grupo;
- necesidad de adecuaciones de acceso o curriculares;
- estrategias de apoyo;
- extensión para estudiantes avanzados;
- recursos de baja conectividad.

No solicites diagnósticos médicos ni envíes información clínica a la IA. Utiliza categorías pedagógicas mínimas y datos anonimizados.

#### Paso 5 — Revisión y generación

Muestra un resumen completo, editable por sección, antes de generar. Incluye:

- estimación de tiempo;
- formato de salida;
- idioma;
- extensión: breve, estándar o detallada;
- interruptores para incluir DUA, evaluación, instrumentos, recursos y adecuaciones;
- botón principal **Generar planificación**;
- botón secundario **Guardar como borrador**.

No muestres el prompt interno, parámetros técnicos, tokens ni razonamiento del modelo.

---

## 4. Resultado de la planificación

Tras generar, abre una vista de trabajo con autosave y estas pestañas:

1. **Resumen:** datos académicos, objetivo, competencia y duración.
2. **Secuencia didáctica:** inicio, desarrollo y cierre, o fases de la metodología seleccionada; actividades del docente y del estudiante; tiempos y recursos.
3. **Evaluación:** técnica, instrumento, criterios, evidencias, indicadores y retroalimentación.
4. **Inclusión y DUA:** barreras, apoyos, alternativas de participación y adecuaciones.
5. **Recursos:** materiales generados y pendientes.
6. **Seguimiento:** estudiantes, alertas pedagógicas y acciones de apoyo.

Acciones disponibles:

- editar contenido por bloques;
- regenerar solo una sección, nunca toda la planificación por defecto;
- restaurar la versión anterior;
- guardar;
- duplicar;
- marcar como lista;
- enviar a revisión institucional si ese flujo existe;
- exportar o imprimir usando las capacidades actuales del sistema;
- crear recursos desde la misma planificación.

Muestra siempre el estado: borrador, generando, lista, en revisión, aprobada o archivada. Toda generación debe requerir revisión humana antes de publicarse, asignarse o convertirse en documento oficial.

---

## 5. Creación de recursos desde la planificación

El botón **Crear recursos** abre un panel con opciones visuales, selección múltiple y nivel de dificultad:

- guía docente;
- ficha de trabajo;
- actividad de inicio;
- actividad colaborativa;
- ejercicio práctico;
- cuestionario;
- banco de preguntas;
- rúbrica;
- lista de cotejo;
- evaluación diagnóstica, formativa o sumativa;
- material de refuerzo;
- material de profundización;
- tarjetas de estudio;
- presentación de clase;
- tarea para casa;
- actividad sin internet;
- comunicación breve para familias.

El recurso debe heredar automáticamente curso, edad, asignatura, objetivo, destreza, metodología, tiempo y criterios de evaluación. El docente no vuelve a introducir información ni escribe un prompt.

Permite:

- previsualizar;
- editar;
- regenerar una sección;
- guardar;
- asociar a la planificación;
- asignar al curso o a estudiantes seleccionados;
- imprimir o exportar si el proyecto ya cuenta con esa capacidad.

---

## 6. Seguimiento individual por estudiante

En la pestaña **Seguimiento**, muestra la lista del curso con avatar o iniciales, estado de progreso y un icono de acción individual junto a cada estudiante. Ese icono abre un menú o panel lateral con:

- **Plan de refuerzo personalizado**;
- **Recuperación pedagógica**;
- **Adecuación o adaptación**;
- **Actividad diferenciada**;
- **Material de apoyo**;
- **Profundización**;
- **Retroalimentación individual**;
- **Registro de seguimiento**;
- **Comunicación para la familia**.

Flujo de recuperación y apoyo:

1. seleccionar dificultad observada desde categorías pedagógicas;
2. seleccionar evidencia disponible: calificación, rúbrica, tarea, observación o inasistencia;
3. elegir intensidad y duración del apoyo;
4. generar una propuesta;
5. revisar y aprobar;
6. asignar fecha y evidencia esperada;
7. registrar resultado: pendiente, en progreso, logrado o requiere nueva intervención.

La IA no debe diagnosticar, etiquetar ni tomar decisiones automáticas sobre promoción, sanciones o necesidades educativas. Solo propone apoyos revisables por el docente.

Incluye una vista grupal con:

- estudiantes sin dificultad;
- estudiantes que requieren refuerzo;
- recuperaciones pendientes;
- adecuaciones activas;
- progresos recientes.

No envíes nombres, documentos de identidad, diagnósticos ni información sensible al proveedor de IA. Usa un identificador temporal y agrega la identidad únicamente en la capa de aplicación después de recibir el resultado.

---

## 7. Configuración profesional de IA por institución

No implementes la clave de Gemini como un campo común visible dentro del módulo docente. Crea una sección protegida para **Administrador institucional → Configuración → Inteligencia artificial**.

### Modelo recomendado

Implementa una arquitectura híbrida:

1. **IA administrada por la plataforma — opción predeterminada:** la aplicación controla el proveedor, modelo, seguridad, plantillas, cuotas y facturación por institución.
2. **Clave propia de la institución (BYOK) — opción avanzada:** el administrador puede conectar su propia API de Gemini si el plan comercial lo permite.
3. **Modo demostración:** usa respuestas simuladas deterministas cuando no exista proveedor configurado.

Ventajas obligatorias del modelo administrado: experiencia más simple, seguridad uniforme, soporte centralizado, control de costos, cambio de modelo sin modificar el frontend y posibilidad de ofrecer paquetes de consumo.

### Pantalla de configuración

Incluye:

- estado: demostración, activo, suspendido o límite alcanzado;
- modo: administrado por la plataforma o clave institucional;
- proveedor y modelo seleccionables solo por usuarios autorizados;
- campo de clave enmascarado con acción conectar/reemplazar, sin volver a mostrar el secreto;
- botón **Probar conexión**;
- presupuesto mensual o cuota de generaciones;
- límites por docente, día y mes;
- porcentaje consumido y fecha de reinicio;
- modelos habilitados por tipo de tarea;
- política de retención;
- registro de uso sin contenido sensible;
- alertas al 70 %, 90 % y 100 % del límite.

### Seguridad obligatoria

- Nunca guardes la clave en frontend, `localStorage`, código fuente, repositorio, logs ni tablas en texto plano.
- Toda llamada a Gemini debe salir desde backend o función segura.
- Cifra las credenciales en reposo mediante el mecanismo seguro disponible en la infraestructura.
- Usa variables de entorno o un gestor de secretos para la clave administrada por la plataforma.
- Aplica aislamiento por institución, permisos de mínimo privilegio, auditoría y rotación de claves.
- No registres prompts completos, respuestas con datos estudiantiles ni secretos.
- Redacta o anonimiza datos antes de llamar al proveedor.

---

## 8. Capa de IA desacoplada

No llames directamente a Gemini desde componentes React. Implementa una abstracción de proveedor:

```ts
interface EducationAIProvider {
  generatePlan(input: PlanningInput): Promise<PlanningResult>;
  generateResource(input: ResourceInput): Promise<ResourceResult>;
  generateStudentSupport(input: StudentSupportInput): Promise<StudentSupportResult>;
  testConnection(): Promise<ProviderHealth>;
}
```

Crea, como mínimo:

- `DemoEducationAIProvider`, con datos demostrativos coherentes y deterministas;
- `GeminiEducationAIProvider`, preparado para activarse cuando exista una credencial válida;
- `EducationAIGateway`, que elija proveedor, aplique límites, anonimización, validación, reintentos controlados y auditoría.

Requisitos:

- entradas y salidas tipadas;
- validación estricta con el sistema de esquemas ya usado en el proyecto;
- respuestas estructuradas en JSON, no texto libre sin validar;
- plantillas internas versionadas y no editables por docentes;
- temperatura baja para consistencia;
- timeout, cancelación, reintentos con backoff y circuit breaker;
- idempotencia para evitar cobros dobles;
- caché de resultados equivalentes cuando sea seguro;
- generación por secciones;
- registro de proveedor, modelo, versión de plantilla, duración, estado y consumo estimado;
- mensajes de error comprensibles y opción de reintentar;
- ningún fallback silencioso que presente datos simulados como generados por IA real.

El identificador concreto del modelo debe ser configurable en servidor. No lo fijes en componentes visuales.

---

## 9. Modelo de datos sugerido

Adapta los nombres al esquema existente; no dupliques tablas equivalentes. Si el proyecto usa Supabase/PostgreSQL, crea migraciones y políticas RLS para:

- `curriculum_catalog_versions`;
- `curriculum_items`;
- `lesson_plans`;
- `lesson_plan_versions`;
- `lesson_plan_resources`;
- `student_support_plans`;
- `student_support_events`;
- `institution_ai_settings`;
- `institution_ai_quotas`;
- `ai_generation_jobs`;
- `ai_usage_ledger`;
- `ai_prompt_template_versions`;
- `ai_audit_events`.

Campos comunes necesarios:

- `id`;
- `institution_id`;
- `created_by`;
- `created_at` y `updated_at`;
- estado;
- versión;
- referencias a curso, asignatura, planificación y estudiante cuando corresponda;
- metadatos de generación sin información sensible;
- `deleted_at` si el proyecto usa borrado lógico.

Reglas:

- RLS por institución y rol;
- historial inmutable de versiones aprobadas;
- separación entre contenido académico y métricas de consumo;
- claves cifradas o referencia a secreto, nunca texto plano;
- índices para institución, docente, curso, estado y fechas;
- restricciones y claves foráneas explícitas.

---

## 10. Estados y comportamiento del prototipo

Aunque Gemini todavía no esté conectado, implementa:

- flujo completo de configuración por clic;
- validación de cada paso;
- resumen previo;
- estado de carga realista y cancelable;
- resultado demostrativo coherente con las selecciones;
- edición por bloques;
- creación simulada de recursos;
- seguimiento individual;
- guardado local o en la persistencia actual, según las capacidades existentes;
- estado vacío, error, límite alcanzado y sin conexión;
- indicador visible y permanente de **Contenido demostrativo** cuando corresponda.

No uses `alert()` del navegador. Utiliza diálogos, paneles, toasts, skeletons, estados vacíos y confirmaciones coherentes con la UI existente.

---

## 11. UX/UI y responsive

- Diseño profesional para docentes y autoridades; evita estética infantil o apariencia de chatbot genérico.
- Prioriza claridad, densidad moderada y acciones visibles.
- En escritorio, usa navegación lateral o el patrón existente y panel de resultado amplio.
- En tablet, conserva el progreso y agrupa controles sin desbordes.
- En móvil, convierte el asistente en pasos verticales, usa acciones inferiores fijas cuando sea necesario y evita tablas horizontales imposibles de usar.
- Tamaño táctil mínimo accesible, foco visible, navegación por teclado, etiquetas y estados `aria`.
- No dependas únicamente del color para comunicar estados.
- Confirma acciones sensibles y evita perder selecciones o contenido no guardado.
- Mantén tiempos, fechas, idioma y terminología compatibles con Ecuador.

---

## 12. Criterios de aceptación

La implementación se considera terminada solo si:

1. El módulo aparece en la navegación y respeta roles.
2. El docente puede completar los 5 pasos sin escribir un prompt.
3. Las opciones se filtran según curso, edad, asignatura y currículo.
4. El resumen permite corregir selecciones antes de generar.
5. El modo demostración genera una planificación coherente y claramente etiquetada.
6. Se pueden editar y regenerar secciones individuales.
7. **Crear recursos** hereda automáticamente el contexto de la planificación.
8. Cada estudiante tiene acceso a refuerzo, recuperación, adecuación, actividad diferenciada y seguimiento.
9. La propuesta individual requiere aprobación docente.
10. La configuración de Gemini solo es accesible para roles autorizados.
11. Ninguna clave o dato sensible queda en cliente, logs o repositorio.
12. Existen cuotas y métricas por institución y docente.
13. Los datos están aislados por institución.
14. La interfaz funciona en escritorio, tablet y móvil sin desbordes.
15. No existen botones decorativos sin funcionalidad.
16. TypeScript, lint, build y pruebas del alcance quedan en verde.

---

## 13. Pruebas mínimas

Añade pruebas siguiendo el stack actual para:

- permisos por rol e institución;
- validación y persistencia de los 5 pasos;
- filtrado curricular dependiente;
- generación demostrativa determinista;
- cambio entre modo demostración y proveedor real;
- bloqueo por cuota agotada;
- regeneración de una sola sección;
- herencia de contexto al crear recursos;
- anonimización del estudiante antes de invocar IA;
- creación y actualización de un plan de recuperación;
- errores de proveedor, timeout y reintento;
- ausencia de secretos en payloads del cliente y logs;
- responsive básico de los flujos críticos.

---

## 14. Entrega

Al terminar, entrega:

1. resumen de lo implementado;
2. lista de archivos creados y modificados;
3. migraciones y políticas aplicadas;
4. variables de entorno requeridas, solo por nombre y sin valores secretos;
5. instrucciones para activar Gemini;
6. pruebas ejecutadas y resultados reales;
7. limitaciones pendientes;
8. evidencia de que no hay claves ni datos sensibles expuestos;
9. recomendaciones de siguiente etapa separadas de la implementación actual.

No afirmes que algo funciona si no fue implementado o probado. Si una integración real no puede activarse todavía, deja el adaptador, la configuración y el contrato preparados, mantén el modo demostración visible y documenta exactamente qué falta.
