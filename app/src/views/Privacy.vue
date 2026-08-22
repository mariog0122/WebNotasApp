<template>
  <div class="min-h-screen bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 font-sans py-12 px-4 sm:px-6 transition-colors">
    <div class="max-w-4xl mx-auto space-y-8 bg-white dark:bg-slate-900/80 border border-slate-200 dark:border-slate-800 p-8 sm:p-12 rounded-3xl shadow-xl shadow-slate-900/5">
      <div class="border-b border-slate-200 dark:border-slate-800 pb-6">
        <router-link to="/planes" class="text-indigo-600 dark:text-indigo-400 text-xs font-bold uppercase tracking-wider mb-3 inline-flex items-center gap-1 hover:underline">
          ← Volver a Precios & Planes
        </router-link>
        <h1 class="text-3xl sm:text-4xl font-extrabold text-slate-900 dark:text-white tracking-tight">
          Política de Privacidad y Protección de Datos
        </h1>
        <p class="text-slate-500 dark:text-slate-400 text-sm mt-2 font-medium">
          LOGREVA por Adyron S.A.S · Última actualización: 8 de Agosto de 2026
        </p>
      </div>

      <div class="space-y-6 text-slate-700 dark:text-slate-300 text-sm leading-relaxed">
        <section class="p-5 rounded-2xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200 dark:border-slate-800 space-y-2">
          <h2 class="font-bold text-slate-900 dark:text-white text-base flex items-center gap-2">
            <span class="w-6 h-6 rounded-lg bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 flex items-center justify-center text-xs font-extrabold">1</span>
            Tratamiento de Información Institucional
          </h2>
          <p class="text-slate-600 dark:text-slate-300">
            LOGREVA recopila información institucional de docentes, calificaciones y estudiantes exclusivamente para prestar el servicio de gestión académica de la institución contratante.
          </p>
        </section>

        <section class="p-5 rounded-2xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200 dark:border-slate-800 space-y-2">
          <h2 class="font-bold text-slate-900 dark:text-white text-base flex items-center gap-2">
            <span class="w-6 h-6 rounded-lg bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 flex items-center justify-center text-xs font-extrabold">2</span>
            Controles de Acceso y Separación de Datos
          </h2>
          <p class="text-slate-600 dark:text-slate-300">
            LOGREVA aplica autenticación, permisos por rol y políticas de Row Level Security (RLS) para limitar el acceso a la institución correspondiente. Estos controles se revisan periódicamente y los incidentes o solicitudes de acceso se gestionan conforme a los contratos y procedimientos de seguridad vigentes.
          </p>
        </section>

        <section class="p-5 rounded-2xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200 dark:border-slate-800 space-y-2">
          <h2 class="font-bold text-slate-900 dark:text-white text-base flex items-center gap-2">
            <span class="w-6 h-6 rounded-lg bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 flex items-center justify-center text-xs font-extrabold">3</span>
            Confidencialidad y Seguridad
          </h2>
          <p class="text-slate-600 dark:text-slate-300">
            Toda la transmisión de información se realiza mediante canales cifrados TLS/HTTPS. Las contraseñas de los usuarios no son almacenadas en texto plano y se gestionan a través del proveedor de autenticación Supabase Auth.
          </p>
        </section>
      </div>

      <div class="pt-6 border-t border-slate-200 dark:border-slate-800 text-center text-xs text-slate-500 dark:text-slate-400">
        © 2026 LOGREVA por Adyron S.A.S. Todos los derechos reservados.
      </div>
    </div>
  </div>
</template>
