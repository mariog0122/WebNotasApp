# FEEDBACK PIPELINE: Ciclo Completo de Aprendizaje Continuo y Curaduría Humana

**Fecha:** 2026-09-03  
**Proyecto:** LOGREVA (WebNotasApp)  

---

## 1. Las Tres Vías de Entrada de Retroalimentación

1. **Vía Rápida (Micro-Feedback 👍 / 👎)**:
   - Un solo clic desde el visor de documentos o las tarjetas de recursos.
   - Envío instantáneo con telemetría no bloqueante.
2. **Vía Estructurada (Modal con Categorías y Sugerencias)**:
   - Activada al pulsar `👎 Necesita mejora` o `✏️ Sugerir corrección`.
   - Selección de categorías predefinidas pedagógicas (Error conceptual, Metodología, Dificultad, etc.).
   - Campo de texto opcional con detector de privacidad en vivo.
3. **Vía Implícita (Diff Tracking en Edición Manual)**:
   - Cuando un docente edita manualmente el texto generado por la IA en cualquiera de las fases ERCA o rúbricas y pulsa "Guardar Planificación", el composable `useAIPlanning.js` computa un diff estructurado (`original` vs `edited`).
   - Este diff representa **Ground Truth Humano**, y tiene el mayor peso de confianza (`confidence_score + 0.25`).

---

## 2. Compuerta de Cuarentena (Knowledge Quarantine)

```text
[Feedback / Diff Docente]
           |
           v
   [AIPrivacySanitizer] ---> ¿Detecta PII? --> Redacta a [ESTUDIANTE_REDACTADO]
           |             ---> ¿Inyección?  --> Bloquea y marca 'rejected'
           v
   [FeedbackClassificationService]
           |
           v
   ¿Score >= 0.70 AND (Rating >= 4 OR Diff)?
          / \
         /   \
     SI /     \ NO
       /       \
      v         v
[Quarantine]  [Feedback Log Estándar]
(ai_knowledge_quarantine)  (Solo telemetría interna)
      |
      v
[Revisión Humana en AI Improvement Center]
   - Aprobar como Guía Institucional (Level 2)
   - Aprobar como Patrón Global (Level 3 - SuperAdmin)
   - Rechazar o Editar
```

---

## 3. Prevención de Bucles de Sesgo (Echo Chambers)

Para evitar que la IA se limite a repetir errores populares de los docentes:
* **Frecuencia ≠ Verdad**: Un patrón repetido 10 veces no se promueve automáticamente si contradice los criterios del Golden Dataset.
* **Evaluación Pre-Promoción**: Antes de activar un nuevo conocimiento masivo, se corre la suite `AIEvaluationService.runBenchmarkSuite()` para verificar que la alineación curricular se mantenga >= 0.90.
