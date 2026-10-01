# TESTING: Estrategia de Pruebas, Casos de Seguridad y No Regresión

**Fecha:** 2026-09-03  
**Proyecto:** LOGREVA (WebNotasApp)  

---

## 1. Cobertura de la Suite de Pruebas

La suite de pruebas automatizadas garantiza que cada componente del pipeline de feedback, sanitización, RAG y evaluación funcione de acuerdo con las especificaciones.

| Archivo de Prueba | Casos Cubiertos | Estado |
|---|---|---|
| `app/tests/aiFeedbackSecurity.test.js` | 1. Validación matemática de Cédula Ecuatoriana (Módulo 10, códigos de provincia 01-24, 30).<br>2. Redacción de PII (cédulas, emails, teléfonos ecuatorianos).<br>3. Redacción de diagnósticos DECE y nombres de estudiantes conocidos.<br>4. Detección y bloqueo de ataques de Prompt Injection y Jailbreaks (`[CONTENIDO_BLOQUEADO_POR_SEGURIDAD]`).<br>5. Clasificación taxonómica de feedback con cálculo de confianza.<br>6. Verificación de sintaxis SQL y RLS de la migración 51 y su rollback. | **PASÓ (6/6)** |
| `app/tests/aiContextBuilderAndRAG.test.js` | 1. Registro versionado de prompts con inmutabilidad y rollback.<br>2. Ensamblado de contexto delimitado RAG respetando el presupuesto de tokens (máx. 1,600 caracteres).<br>3. Orquestación end-to-end con `EducationAIGateway` preservando metadatos y envío de feedback. | **PASÓ (3/3)** |
| `app/tests/aiEvaluationGoldenDataset.test.js` | 1. Validación de cobertura curricular del Golden Dataset de Ecuador.<br>2. Ejecución de la suite de benchmark automatizada contra `DemoEducationAIProvider`, verificando que el score curricular promedio supere el 85% sin alucinaciones. | **PASÓ (2/2)** |
| `app/tests/aiPlanning.test.js` | 10 pruebas preexistentes del módulo de planificación curricular demostrando **cero regresiones**. | **PASÓ (10/10)** |

---

## 2. Comandos para Ejecutar las Pruebas

Para ejecutar la suite completa de IA:
```bash
cd app
npx vitest run tests/aiFeedbackSecurity.test.js tests/aiContextBuilderAndRAG.test.js tests/aiEvaluationGoldenDataset.test.js tests/aiPlanning.test.js
```

Para ejecutar la verificación de compilación de producción:
```bash
cd app
npm run build
```
