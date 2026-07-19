# WebNotas Docentes 📝

Plataforma de gestión de calificaciones para instituciones educativas y docentes. Permite administrar de manera sencilla cursos, estudiantes y generar reportes individuales y generales en formato PDF.

## 🚀 Características Principales

- **Gestión de Estudiantes:** Registro y administración de estudiantes, asignación rápida a cursos.
- **Gestión de Cursos y Asignaturas:** Organización de los paralelos y materias (tanto cuantitativas como cualitativas).
- **Control de Calificaciones:** Ingreso de notas (por trimestres y supletorios) con guardado automático y manejo de estado offline.
- **Reportes Profesionales en PDF:** Generación de libretas de calificaciones con diseño formal, firmas de autoridades y notas legales predefinidas, listos para imprimir o enviar.
- **Comunicación Integrada:** Opción para contactar y enviar resultados a representantes directamente por WhatsApp.
- **Autenticación Segura:** Sistema de login seguro respaldado por Supabase.
- **Modo PWA (Progressive Web App):** Instalable en teléfonos móviles y computadoras para trabajar más rápido.

## 🛠️ Tecnologías Utilizadas

- **Frontend:** Vue 3 (Composition API), Vite, TailwindCSS
- **Backend / Base de Datos:** Supabase (PostgreSQL, Auth)
- **Generación de PDFs:** html2pdf.js / html2canvas
- **Iconos y Fuentes:** Phosphor Icons, Google Fonts (Inter)

## 📦 Instalación y Configuración Local

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/mariog0122/WebNotasApp.git
   cd WebNotasApp/app
   ```

2. **Instalar dependencias:**
   ```bash
   npm install
   ```

3. **Configurar variables de entorno:**
   Crea un archivo `.env` en la carpeta raíz `app/` y añade tus credenciales de Supabase:
   ```env
   VITE_SUPABASE_URL=tu_supabase_url
   VITE_SUPABASE_ANON_KEY=tu_supabase_anon_key
   ```

4. **Ejecutar el servidor de desarrollo:**
   ```bash
   npm run dev
   ```
   Abre [http://localhost:5174](http://localhost:5174) (o el puerto que te indique la terminal) para ver la aplicación.

## 🏗️ Construcción para Producción

Para compilar la aplicación para producción (generar la carpeta `dist`):
```bash
npm run build
```

## 📝 Licencia

Este proyecto es privado y los derechos pertenecen a su creador original.
