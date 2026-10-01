# Nombres de módulos del menú Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Mejorar los nombres visibles de los módulos nuevos del menú lateral, manteniendo intactas las rutas, permisos, iconos y lógica funcional.

El ZIP final se generará únicamente después de completar todas las etapas de auditoría, las pruebas autenticadas con dos instituciones y el ensayo de restauración aislada. Cualquier ZIP existente corresponde a una etapa intermedia y no debe subirse todavía.

**Architecture:** El cambio se limita a la configuración `navLinks` de `Sidebar.vue`. Los identificadores técnicos (`path`, `iconType`, permisos y nombres de componentes) no se modifican. Se añadirá cobertura estática para comprobar que las etiquetas comerciales esperadas existen y que las rutas actuales permanecen sin cambios.

**Tech Stack:** Vue 3, Vitest, Vite, Playwright.

---

### Task 1: Congelar el contrato visual del menú

**Files:**
- Modify: `app/tests/sidebar.test.js` (crear si no existe)
- Inspect: `app/src/components/Sidebar.vue:43-69`

- [x] **Step 1: Confirmar el archivo de pruebas existente y sus convenciones**

Run: `rg -n "Sidebar|navLinks|Asistencia|Planificación|Alertas" app/tests app/src/components/Sidebar.vue`

Expected: localizar la suite existente; si no existe una prueba específica, crear `app/tests/sidebar.test.js` con el mismo estilo de importación usado por las suites Vitest.

- [x] **Step 2: Escribir pruebas que fijen etiquetas y rutas**

La prueba debe leer `Sidebar.vue` como texto y verificar estas etiquetas: `Asistencia Escolar`, `Reportes Académicos`, `Planificación Curricular IA`, `Bienestar Estudiantil`, `Panel Docente`, `Indicadores Institucionales` y `Administración Global`. También debe verificar que permanecen `/attendance`, `/reports`, `/planificacion-ia`, `/alerts`, `/intelligence/cockpit` y `/intelligence/impacto`.

- [x] **Step 3: Ejecutar sólo la suite nueva**

Run: `npm test -- --run tests/sidebar.test.js`

Expected: FAIL antes de modificar las etiquetas, demostrando que la prueba protege el cambio solicitado.

### Task 2: Aplicar los nombres visibles del menú

**Files:**
- Modify: `app/src/components/Sidebar.vue:53-68`

- [x] **Step 1: Cambiar únicamente las etiquetas visibles**

Usar este mapeo, sin cambiar permisos, rutas ni `iconType`:

```js
Asistencia -> Asistencia Escolar
Reportes -> Reportes Académicos
Teacher Cockpit -> Panel Docente
Impact Analytics -> Indicadores Institucionales
Planificación IA -> Planificación Curricular IA
Alertas DECE -> Bienestar Estudiantil
Súper Admin -> Administración Global
```

Mantener `Familias`, `Calificaciones`, `Informes Docentes` y `Mi Perfil`.

- [x] **Step 2: Ejecutar la suite del menú**

Run: `npm test -- --run tests/sidebar.test.js`

Expected: PASS.

### Task 3: Validar regresión funcional y móvil

**Files:**
- Inspect: `app/src/components/Sidebar.vue`
- Inspect: `app/e2e/`

- [x] **Step 1: Ejecutar todas las pruebas Vitest**

Run: `npm test -- --run`

Expected: todas las suites y pruebas existentes pasan, incluyendo la nueva suite del menú.

- [x] **Step 2: Ejecutar build y presupuesto**

Run: `npm run build` y `npm run check:bundle`

Expected: compilación exitosa y presupuesto aprobado.

- [x] **Step 3: Ejecutar Playwright en los anchos ya definidos**

Run: `npm run test:e2e`

Expected: ningún desbordamiento horizontal ni regresión del menú móvil en 320–1920 px.

### Task 4: Documentar y reservar el empaquetado final

**Files:**
- Modify: `docs/CONTINUIDAD_ANTIGRAVITY_AUDITORIA_2026-09-10.md`
- Modify: `SOFTWARE_QUALITY_AUDIT.md` sólo si cambian las cifras de verificación
- Create: ZIP de entrega Hostinger desde `app/dist`

- [x] **Step 1: Registrar el mapeo visual y la evidencia de pruebas**
- [ ] **Step 2: Generar el ZIP final sólo después de cerrar todas las etapas pendientes de auditoría**
- [ ] **Step 3: Verificar que la entrega final tenga `index.html`, manifiesto en raíz y hash SHA-256**
