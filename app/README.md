# Sistema de Notas Escolar - WebNotas Docentes

## 🎓 Descripción
Plataforma completa de gestión de calificaciones para docentes, adaptada al sistema educativo ecuatoriano.

---

## 🚀 Mejoras Implementadas (Abril 2026)

### 🔴 Críticas (Seguridad)
- ✅ **Credenciales protegidas**: `.env.local` agregado al `.gitignore` con archivo `.env.example` seguro
- ✅ **RLS completo**: Política de escritura agregada a `system_config`
- ✅ **Control de acceso por roles**: Sistema granular de permisos en `src/lib/permissions.js`

### 🟡 Medias (Arquitectura)
- ✅ **Listener de autenticación**: `onAuthStateChange` reacciona a sesiones expiradas y logout desde otras pestañas
- ✅ **Código reutilizable**: Funciones compartidas de validación y fotos en `src/lib/studentUtils.js`
- ✅ **Índices de rendimiento**: SQL optimizado en `performance_indexes.sql`

### 🟢 Menores (UX y Calidad)
- ✅ **Memory leak fixed**: Animación canvas del Login limpia correctamente event listeners
- ✅ **Título de página**: Actualizado a "WebNotas Docentes - Gestión de Calificaciones"
- ✅ **Vite config genérico**: URL de Supabase ya no está hardcodeada
- ✅ **Formulario de registro**: Se limpia automáticamente y cambia a login tras éxito
- ✅ **Loading state**: Flash de autenticación en router evita parpadeo
- ✅ **Debounce en guardado**: Prevención de doble clic en calificaciones
- ✅ **Tests unitarios**: Cobertura para `gradingLogic.js` y `studentUtils.js`
- ✅ **ErrorBoundary**: Componente para capturar errores sin crashear la app

### 💡 Recomendaciones Adicionales
- ✅ **Paginación server-side**: Ya implementada en Students.vue
- ✅ **Tabla de auditoría**: `audit_log` con triggers automáticos en `audit_log_schema.sql`
- ✅ **Exportación de datos**: Utilidades CSV/Excel en `src/lib/exportUtils.js`
- ✅ **Consultas optimizadas**: `.select()` con columnas específicas en todas las vistas

---

## 📦 Estructura del Proyecto

```
app/
├── src/
│   ├── lib/
│   │   ├── supabase.js           # Cliente Supabase
│   │   ├── gradingLogic.js       # Lógica de cálculo de notas (pura, testeable)
│   │   ├── reporting.js          # Generación de reportes
│   │   ├── pdf.js                # Generación de PDFs
│   │   ├── errorDictionary.js    # Traducción de errores
│   │   ├── studentUtils.js       # ✨ NUEVO: Validación y fotos compartidas
│   │   ├── exportUtils.js        # ✨ NUEVO: Exportación CSV/Excel
│   │   └── permissions.js        # ✨ NUEVO: Control de acceso por roles
│   ├── stores/
│   │   ├── auth.js               # Store de autenticación (con listener)
│   │   └── ui.js                 # ✨ NUEVO: Estado de UI (loading flash)
│   ├── components/
│   │   ├── Navigation.vue        # Barra de navegación
│   │   ├── InteractiveGridPattern.vue  # Fondo animado
│   │   └── ErrorBoundary.vue     # ✨ NUEVO: Captura de errores
│   ├── views/
│   │   ├── Login.vue             # Login/Registro (canvas fix)
│   │   ├── Dashboard.vue         # Panel principal
│   │   ├── Students.vue          # Gestión de estudiantes
│   │   ├── Courses.vue           # Gestión de cursos
│   │   ├── Subjects.vue          # Gestión de asignaturas
│   │   ├── Grades.vue            # Calificaciones (con debounce)
│   │   └── Reports.vue           # Reportes y libretas
│   ├── router/
│   │   └── index.js              # Router con loading state
│   └── App.vue                   # App root con ErrorBoundary
├── tests/
│   ├── gradingLogic.test.js      # ✨ NUEVO: Tests de lógica de notas
│   └── studentUtils.test.js      # ✨ NUEVO: Tests de utilidades
├── db_schema.sql                 # Esquema base de datos
├── advanced_grading_schema.sql   # Esquema de calificaciones avanzadas
├── performance_indexes.sql       # ✨ NUEVO: Índices de rendimiento
├── audit_log_schema.sql          # ✨ NUEVO: Tabla de auditoría con triggers
├── fix_system_config_rls.sql     # ✨ NUEVO: Fix RLS de system_config
├── .env.example                  # ✨ NUEVO: Plantilla segura de variables
└── .gitignore                    # Actualizado con protección de .env
```

---

## 🛠️ Setup

### 1. Prerequisitos
- Node.js 18+
- Cuenta en [Supabase](https://supabase.com/)

### 2. Configuración de Supabase
1. Crea un proyecto en Supabase
2. Ve a **SQL Editor** y ejecuta en orden:
   - `db_schema.sql` (tablas base y políticas)
   - `advanced_grading_schema.sql` (calificaciones dinámicas)
   - `performance_indexes.sql` (índices de rendimiento) ✨
   - `audit_log_schema.sql` (auditoría de cambios) ✨
   - `fix_system_config_rls.sql` (fix de permisos) ✨
3. Ve a **Project Settings > API**
4. Copia `Project URL` y `anon` key

### 3. Variables de Entorno
```bash
# Copiar plantilla
cp .env.example .env.local

# Editar con tus credenciales
VITE_SUPABASE_URL=tu_url_aqui
VITE_SUPABASE_ANON_KEY=tu_clave_aqui
```

⚠️ **NUNCA commitees `.env.local` al repositorio**

### 4. Instalar y Ejecutar
```bash
npm install
npm run dev
```

Abre http://localhost:5173

---

## 🧪 Tests

```bash
# Ejecutar tests unitarios
npm test

# Tests en modo watch (desarrollo)
npx vitest
```

Cobertura actual:
- ✅ `gradingLogic.js` - Cálculo de promedios
- ✅ `studentUtils.js` - Validación y utilidades

---

## 📊 Características Principales

### Sistema de Calificaciones Ecuatoriano
- **Trimestral o Quimestral**: Configurable según régimen (Sierra/Amazonía o Costa/Galápagos)
- **Cálculo automático**: 
  - 70% Formativo (Individual + Grupal + Refuerzo)
  - 30% Sumativo
- **Niveles cualitativos**: Inicial, Preparatoria, Elemental (A+ a E-)
- **Proyecto Interdisciplinario**: Nota global por materia seleccionadas

### Gestión Completa
- **Estudiantes**: CRUD con fotos, cédula ecuatoriana validada, representante legal
- **Cursos**: Configuración por nivel y paralelo
- **Asignaturas**: Asignación dinámica por curso
- **Importación Excel**: Carga masiva de estudiantes

### Reportes
- **Libretas por trimestre**: Con promedio y observación automática
- **PDF exportable**: Descarga de fichas y libretas
- **Exportación datos**: Backup CSV/Excel ✨

### Seguridad
- **Supabase Auth**: Autenticación segura
- **Row Level Security**: Políticas por tabla
- **Auditoría**: Log de cambios en calificaciones ✨
- **Validación cédula**: Algoritmo oficial ecuatoriano

---

## 🔐 Control de Acceso por Roles

| Acción | Admin | Docente |
|--------|-------|---------|
| Ver estudiantes/cursos | ✅ | ✅ |
| Crear/editar estudiantes | ✅ | ✅ |
| Eliminar estudiantes | ✅ | ❌ |
| Editar calificaciones | ✅ | ✅ |
| Eliminar calificaciones | ✅ | ❌ |
| Configuración institución | ✅ | ❌ |
| Ver auditoría | ✅ | ❌ |
| Exportar datos | ✅ | ✅ |

---

## 📈 Optimizaciones de Rendimiento

- **Índices de base de datos**: Consultas frecuentes optimizadas
- **Paginación server-side**: No carga todos los registros en cliente
- **Select específico**: Solo se traen columnas necesarias
- **Debounce en guardado**: Previene operaciones duplicadas
- **PWA**: Cacheo de assets para funcionamiento offline

---

## 🐛 Troubleshooting

### Error de build con Tailwind
```bash
rm -rf node_modules
npm install
```

### Error "Could not find the table"
Ejecuta los schemas SQL que faltan en Supabase SQL Editor

### Credenciales expuestas
Si commiteaste `.env.local` por error:
1. Rota las claves en Supabase Dashboard
2. Agrega `.env.local` al `.gitignore`
3. Ejecuta `git rm --cached .env.local`

---

## 📝 Notas de Versión

### Versión 2.0.0 (Abril 2026)
- ✅ 18 mejoras implementadas
- ✅ Seguridad reforzada
- ✅ Tests unitarios
- ✅ Auditoría de cambios
- ✅ Exportación de datos
- ✅ Optimización de rendimiento
- ✅ Control de acceso granular
- ✅ Manejo de errores robusto

---

## 🤝 Contribuir

1. Nunca commitees archivos `.env`
2. Usa las funciones de `studentUtils.js` para validación
3. Agrega tests para nueva lógica de negocio
4. Sigue el patrón de consultas con columnas específicas

---

## 📄 Licencia
Uso interno institucional
