# Planificación Curricular Oficial (PCA y Microcurricular)

Módulo: **Planificación IA → botón "PCA y Microcurricular"**.

## Fuentes oficiales cargadas
| Archivo de datos | Documento MinEduc | Contenido |
|---|---|---|
| `app/src/data/curriculos/alfabetizacion_postalfabetizacion_2025.json` | Currículo integrado de Alfabetización y Postalfabetización priorizado (2025) | Alfabetización: 12 objetivos, 30 criterios, 120 destrezas, 63 indicadores. Postalfabetización: 12 / 33 / 124 / 75. Inserción Cívica (CAI.JA): 16 destrezas. Inserciones curriculares por destreza (íconos del PDF). |
| `app/src/data/curriculos/primera_infancia_0_3.json` | Currículo Nacional de Atención y Educación de la Primera Infancia (0-3 años) | 5 ámbitos, 18 objetivos de aprendizaje, destrezas por rango de edad. **El documento oficial no tiene códigos de destreza**: no se inventan. |

Los textos y códigos se extraen literalmente con `app/scripts/curriculum/extract_*.py` (requiere `pip install pdfplumber`).
Para agregar otro currículo: crear su extractor, guardar el JSON en `src/data/curriculos/` y registrarlo en `src/lib/curriculum/officialCurricula.js`.

## Plantillas Word
`app/public/plantillas/pca.docx` y `micro.docx` son las plantillas institucionales convertidas con
`app/scripts/curriculum/convert_templates.py` (bucles `{% for %}` → docxtemplater, años y trimestre como campos).
Para cambiar el diseño: editar la plantilla original en Word y volver a ejecutar el conversor.

## Qué hace la IA y qué no
- Códigos, destrezas, criterios e indicadores se copian del currículo oficial; la IA nunca los escribe.
- La IA (Gemini u OpenAI, vía la función `education-ai`) redacta títulos de unidad, temas de clase por código,
  orientaciones ERCA/DUA, recursos, actividades evaluativas, proyecto integrador y adaptaciones NEE.
- Toda respuesta se filtra por código: lo que la IA devuelva para un código inexistente o de otra unidad se descarta.
- Sin IA (modo demostración o error) el documento se arma igual con textos base editables.

## Despliegue
Las tareas nuevas `generateAnnualPlan` y `generateUnitPlan` viven en `supabase/functions/education-ai`.
Tras subir la app, desplegar la función: `supabase functions deploy education-ai`.
