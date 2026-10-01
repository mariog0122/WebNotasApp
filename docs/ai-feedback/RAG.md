# RAG: Retrieval Augmented Generation y Memoria Institucional Delimitada

**Fecha:** 2026-09-03  
**Proyecto:** LOGREVA (WebNotasApp)  

---

## 1. Principio Fundamental: Enriquecimiento Delimitado vs. Mutación del Modelo

El sistema NO aplica *Fine-Tuning* ni reentrenamiento continuo directo de pesos por tres motivos de seguridad y estabilidad:
1. **Riesgo de Olvido Catastrófico y Alucinaciones**: El reentrenamiento no supervisado degrada la rigurosidad pedagógica.
2. **Costos Prohibitivos y Latencia**: Un SaaS multi-tenant con cientos de colegios no puede costear checkpoints dedicados por cada institución.
3. **Imposibilidad de Rollback Inmediato**: Un sesgo indeseado en los pesos requiere días de reentrenamiento.

En su lugar, LOGREVA implementa **RAG Delimitado en Tiempo de Generación (In-Context Few-Shot Learning)** con conocimiento previamente curado y validado.

```text
                                  +------------------------------+
                                  |  MINEDUC Currículo Oficial   |
                                  +------------------------------+
                                                 |
+------------------------------+                 v                 +------------------------------+
|   Solicitud del Docente      | ---> [ AIContextBuilder.js ] <--- |   Preferencias Docente (L1)  |
|  (Tema, Nivel, DCD, ERCA)    |                 ^                 +------------------------------+
+------------------------------+                 |
                                                 |
                                  +------------------------------+
                                  |   Memoria Institucional (L2) |
                                  |   (Top-2 Guías + Top-1 Few)  |
                                  +------------------------------+
                                                 |
                                                 v
                                  +------------------------------+
                                  |     Contexto Ensamblado      |
                                  |     (Límite <= 1600 chars)   |
                                  +------------------------------+
                                                 |
                                                 v
                                  +------------------------------+
                                  |      LLM (Gemini/OpenAI)     |
                                  +------------------------------+
                                                 |
                                                 v
                                  +------------------------------+
                                  |  Planificación Enriquecida   |
                                  +------------------------------+
```

---

## 2. Presupuesto y Límites Estrictos de Tokens

* **Presupuesto máximo de contexto RAG**: 1,600 caracteres (~400 tokens).
* **Estrategia de Selección Top-K**:
  - Máximo 2 lineamientos institucionales (`institutional_guideline`).
  - Máximo 1 ejemplo dorado (`few_shot_sample`) con `confidence_score >= 0.90`.
* **Aislamiento de Prompts**:
  El System Prompt es inmutable. El conocimiento institucional se inyecta siempre dentro de la plantilla `rag-institutional-template` demarcado claramente como directrices de apoyo:
  ```text
  [PAUTAS DE CALIDAD INSTITUCIONAL APRENDIDAS - USAR COMO REFERENCIA]
  - [Lineamiento]: En esta institución se priorizan actividades de indagación en grupos de 3 a 4 estudiantes.
  - [Ejemplo Modelo]: {"fase": "aplicacion", "actividad": "Elaboración de informe de campo"}
  ```
