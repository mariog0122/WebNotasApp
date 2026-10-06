# Planificación Curricular Oficial (PCA y Microcurricular)

Módulo: **Planificación IA → botón "PCA y Microcurricular"**.

## Fuentes oficiales cargadas
| Archivo de datos | Fuente | Extractor |
|---|---|---|
| `alfabetizacion_postalfabetizacion_2025.json` | PDF oficial Alfabetización y Postalfabetización (2025) | `extract_alfabetizacion.py` |
| `primera_infancia_0_3.json` | PDF oficial Primera Infancia (0-3 años) | `extract_primera_infancia.py` |
| `inicial.json` | PDF oficial Currículo Priorizado de Inicial | `extract_inicial.py` |
| `preparatoria.json`, `elemental.json`, `media.json` | PDF oficiales Currículo Priorizado | `extract_priorizado_egb.py` |
| `superior.json`, `bachillerato.json` | JSON entregados por la institución (**sin PDF todavía**) | `normalize_priorizados.py` |
| `adaptaciones_jovenes_adultos.json` | JSON entregado por la institución (**sin PDF todavía**) | `normalize_priorizados.py` |

Todos los extractores copian códigos y textos literalmente, leen los íconos de competencias e inserciones de cada
destreza y asignan cada destreza e indicador a su criterio por la geometría de la tabla. Las erratas del propio PDF
oficial (p. ej. `L.3.3.1`, `EC.ECA.2.6`, `I.E.ECA.3.5.1`, códigos al final del indicador) se corrigen y quedan
registradas en `avisos`, visibles en la app con "Ver correcciones aplicadas".
Inicial y Primera Infancia no tienen códigos oficiales de destreza: se planifican por ámbito, objetivo y edad.
EGB Superior, Bachillerato y Adaptaciones (jóvenes y adultos) provienen de JSON con criterios fusionados (la app
los señala) y, en EGB Superior, sin las destrezas de Inglés (asignatura bloqueada): conviene reemplazarlos
extrayendo sus PDF con `extract_priorizado_egb.py`.

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
