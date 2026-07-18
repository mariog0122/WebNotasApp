# Módulo de calificaciones (WebNotas)

## Ubicación en código

| Pieza | Ruta |
|--------|------|
| Vista principal | `app/src/views/Grades.vue` |
| Estado y API (lógica de pantalla) | `app/src/composables/useGradesPage.js` |
| Fórmulas y pruebas unitarias | `app/src/lib/gradingLogic.js`, `app/tests/gradingLogic.test.js` |

## Flujo de uso

1. **Curso** y **periodo** (trimestre o quimestre) definen el contexto.
2. Cada **asignatura** del curso se abre para mostrar el acta.
3. Para cursos **Inicial / Preparatoria / Elemental** se usa calificación **cualitativa** (MINEDUC). En el resto, **numérica** (0–10).
4. **Guardar** persiste en Supabase (`grades` o `qualitative_grades`).
5. **Proyecto interdisciplinario** opcional: `project_settings`, `project_subject_grades` (ver SQL en `app/project_global_schema.sql`).

## Fórmula 70 / 30 (numérica)

Implementada en `gradingLogic.js` → `calculateStudentAverages`:

- Se promedian insumos por categoría: **INDIVIDUAL**, **GRUPAL**, **REFUERZO** (parte formativa).
- **Promedio formativo** = media de esas medias de categoría (solo las que tengan datos).
- **Peso formativo** = `promedioFormativo × 0.70`.
- **Sumativa**: media de columnas **SUMATIVA**; la fila cuyo nombre contiene “proyecto” puede tomar el valor del **proyecto global** si la materia está marcada en ajustes de proyecto.
- **Peso sumativo** = `promedioSumativo × 0.30`.
- **Total** = suma de ambos pesos cuando existen ambos datos.

## Tablas Supabase relevantes

| Tabla | Uso |
|--------|-----|
| `courses`, `quarters`, `subjects`, `course_subjects` | Catálogo y relación curso–materia |
| `students` | Listado por curso en el acta |
| `grade_definitions` | Columnas del acta por `course_subject_id` + `quarter_id` |
| `grades` | Notas numéricas (`student_id`, `grade_definition_id`, `score`) |
| `qualitative_grades` | Notas cualitativas por estudiante / materia / periodo |
| `project_settings`, `project_subject_grades` | Proyecto interdisciplinario |
| `system_config` | Nombre institución, logo, tutor, rector, `academic_periods` |

Migración completa de referencia: `migrations/insforge_webnotas_full.sql`.

## Pruebas

- Unitarias: `npm run test` (Vitest, incluye `gradingLogic`).
- E2E (navegador): `npm run test:e2e` en `app` (requiere `npx playwright install` la primera vez).

## Extensión modular

- Nuevas pantallas del dominio académico pueden añadir rutas en `app/src/router/index.js` y enlaces en `Navigation.vue`.
- El símbolo `gradesPageInjectionKey` en `useGradesPage.js` está pensado para **subcomponentes** (por ejemplo bajo `app/src/components/grades/`) que quieran inyectar el mismo estado sin prop drilling cuando partas la plantilla en varios `.vue`.
