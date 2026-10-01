<script setup>
</script>

<template>
  <div class="app-card-soft p-5 mb-8">
    <h2 class="text-lg font-semibold text-teal-900 dark:text-teal-200 mb-4 flex items-center gap-2">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-teal-600 dark:text-teal-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      Guía de Flujo de Trabajo
    </h2>
    <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
      <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
        <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 1</div>
        <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Configuración</h3>
        <p class="text-xs text-slate-500 dark:text-slate-400">Configure los datos de la institución (Nombre, Logo, Autoridades) en este mismo panel.</p>
      </div>
      <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
        <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 2</div>
        <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Catálogos</h3>
        <p class="text-xs text-slate-500 dark:text-slate-400">Vaya a <strong>Asignaturas</strong> y <strong>Cursos</strong> para definir las materias y paralelos disponibles.</p>
      </div>
      <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
        <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 3</div>
        <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Matriculación</h3>
        <p class="text-xs text-slate-500 dark:text-slate-400">Vaya a <strong>Estudiantes</strong> para registrar a los alumnos y asignarlos a sus cursos.</p>
      </div>
      <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
        <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 4</div>
        <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Calificaciones</h3>
        <p class="text-xs text-slate-500 dark:text-slate-400">En <strong>Docentes / Notas</strong>, seleccione el curso y asignatura para ingresar los insumos y notas.</p>
      </div>
      <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
        <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 5</div>
        <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Reportes</h3>
        <p class="text-xs text-slate-500 dark:text-slate-400">El sistema calcula promedios automáticamente. Genere actas y libretas desde la sección de Notas.</p>
      </div>
    </div>
  </div>
</template>
