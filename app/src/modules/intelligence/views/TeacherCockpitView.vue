<template>
  <div class="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
    <!-- Header: Teacher Cockpit Title & Quick Context -->
    <div class="bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 rounded-3xl p-6 sm:p-8 text-white shadow-xl relative overflow-hidden">
      <div class="absolute -right-12 -top-12 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none"></div>
      
      <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 relative z-10">
        <div>
          <div class="inline-flex items-center space-x-2 px-3 py-1 rounded-full bg-indigo-500/20 text-indigo-300 text-xs font-semibold uppercase tracking-wider mb-2 border border-indigo-500/30">
            <Sparkles class="w-3.5 h-3.5 text-indigo-400" />
            <span>Inteligencia del Aprendizaje • Decisión en &lt; 5 min</span>
          </div>
          <h1 class="text-2xl sm:text-3xl font-extrabold tracking-tight">Panel Docente</h1>
          <p class="text-slate-300 text-sm mt-1">
            Detectamos brechas causales, organizamos grupos viables y recuperamos el aprendizaje con evidencia verificable.
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-2.5">
          <button
            type="button"
            @click="activeTab = 'students'"
            class="inline-flex items-center space-x-2 px-4 py-2.5 rounded-xl bg-white text-slate-900 hover:bg-slate-100 font-semibold text-sm shadow-md transition"
          >
            <ClipboardCheck class="w-4 h-4 text-indigo-600" />
            <span>Seleccionar estudiante</span>
          </button>

          <button 
            @click="store.openSocraticTutor()"
            class="inline-flex items-center space-x-2 px-4 py-2.5 rounded-xl bg-indigo-600/80 hover:bg-indigo-600 text-white font-semibold text-sm border border-indigo-400/30 shadow-md transition"
          >
            <Bot class="w-4 h-4" />
            <span>Copiloto Socrático</span>
          </button>
        </div>
      </div>

      <!-- Quick Metrics Ribbon -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-6 pt-6 border-t border-slate-800/80">
        <div class="bg-slate-800/50 backdrop-blur rounded-2xl p-3 border border-slate-700/50">
          <span class="text-xs text-slate-400 font-medium">Estudiantes en Nómina</span>
          <p class="text-xl font-bold text-white mt-0.5">{{ store.cockpitData?.totalStudents || 0 }}</p>
        </div>
        <div class="bg-slate-800/50 backdrop-blur rounded-2xl p-3 border border-slate-700/50">
          <span class="text-xs text-slate-400 font-medium">Competencias Clave</span>
          <p class="text-xl font-bold text-indigo-400 mt-0.5">{{ store.cockpitData?.competenciesCount || 0 }}</p>
        </div>
        <div class="bg-slate-800/50 backdrop-blur rounded-2xl p-3 border border-slate-700/50">
          <span class="text-xs text-slate-400 font-medium">Grupos Pedagógicos</span>
          <p class="text-xl font-bold text-amber-400 mt-0.5">{{ store.pedagogicalGroups.length || 0 }}</p>
        </div>
        <div class="bg-slate-800/50 backdrop-blur rounded-2xl p-3 border border-slate-700/50">
          <span class="text-xs text-slate-400 font-medium">Tasa de Dominio Global</span>
          <p class="text-xl font-bold text-emerald-400 mt-0.5">{{ globalMasteryRate }}%</p>
        </div>
      </div>
    </div>

    <!-- Barra de Selección Académica Real -->
    <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-5 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div class="flex flex-wrap items-center gap-4">
        <div>
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-1.5">
            Curso / Paralelo Activo
          </label>
          <select
            v-model="store.selectedCourseId"
            @change="handleCourseChange"
            class="px-3.5 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-800 dark:text-slate-100 focus:ring-2 focus:ring-indigo-500 outline-none min-w-[200px]"
          >
            <option v-if="store.coursesList.length === 0" value="">Cargando cursos...</option>
            <option v-for="c in store.coursesList" :key="c.id" :value="c.id">
              {{ c.name }} {{ c.level ? `(${c.level})` : '' }}
            </option>
          </select>
        </div>

        <div>
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-1.5">
            Asignatura Curricular
          </label>
          <select
            v-model="store.selectedSubjectId"
            @change="handleSubjectChange"
            class="px-3.5 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-800 dark:text-slate-100 focus:ring-2 focus:ring-indigo-500 outline-none min-w-[180px]"
          >
            <option v-if="store.subjectsList.length === 0" value="">Sin asignaturas asignadas</option>
            <option v-for="s in store.subjectsList" :key="s.course_subject_id" :value="s.course_subject_id">
              {{ s.name }}
            </option>
          </select>
        </div>
      </div>

      <div class="flex items-center gap-3">
          <button
            v-if="canUpdateGrades"
            @click="syncOfficialGrades"
          :disabled="isSyncing || !store.selectedCourseId"
          class="inline-flex items-center space-x-2 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white font-bold text-xs shadow-sm transition"
        >
          <RefreshCw :class="['w-3.5 h-3.5', isSyncing ? 'animate-spin' : '']" />
          <span>{{ isSyncing ? 'Sincronizando notas...' : '⚡ Sincronizar desde Calificaciones' }}</span>
        </button>
      </div>
    </div>

    <div v-if="store.loadError" class="rounded-2xl border border-rose-200 dark:border-rose-900 bg-rose-50 dark:bg-rose-950/20 p-4 text-sm text-rose-800 dark:text-rose-200">
      {{ store.loadError }} Revisa tu conexión o tus permisos e inténtalo nuevamente.
    </div>

    <!-- Cockpit Navigation Tabs -->
    <div class="flex items-center space-x-2 border-b border-slate-200 dark:border-slate-800 pb-2 overflow-x-auto">
      <button 
        @click="activeTab = 'radar'"
        :class="[
          'px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition flex items-center space-x-2 shrink-0',
          activeTab === 'radar' 
            ? 'bg-indigo-600 text-white shadow-sm' 
            : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800'
        ]"
      >
        <Compass class="w-4 h-4" />
        <span>Radar del Curso (Brechas)</span>
      </button>

      <button 
        @click="activeTab = 'groups'"
        :class="[
          'px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition flex items-center space-x-2 shrink-0',
          activeTab === 'groups' 
            ? 'bg-indigo-600 text-white shadow-sm' 
            : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800'
        ]"
      >
        <Users class="w-4 h-4" />
        <span>Grupos de Recuperación ({{ store.pedagogicalGroups.length }})</span>
      </button>

      <button 
        @click="activeTab = 'students'"
        :class="[
          'px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition flex items-center space-x-2 shrink-0',
          activeTab === 'students' 
            ? 'bg-indigo-600 text-white shadow-sm' 
            : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800'
        ]"
      >
        <GraduationCap class="w-4 h-4" />
        <span>Ficha de Estudiantes</span>
      </button>
    </div>

    <!-- TAB 1: RADAR DEL CURSO (HEATMAP DE COMPETENCIAS) -->
    <div v-if="activeTab === 'radar'" class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-lg font-bold text-slate-900 dark:text-white">Mapa de Calor por Competencia</h2>
          <p class="text-xs text-slate-500">Priorizadas por impacto curricular y dependencia causal de prerrequisitos.</p>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div 
          v-for="item in store.radarOverview" 
          :key="item.competencyId"
          class="bg-white dark:bg-slate-900 rounded-2xl p-5 border border-slate-200 dark:border-slate-800 shadow-sm hover:shadow-md transition flex flex-col justify-between"
        >
          <div>
            <div class="flex items-center justify-between mb-2">
              <span class="text-xs font-mono font-bold px-2 py-0.5 rounded-md bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                {{ item.code }}
              </span>
              <span 
                :class="[
                  'text-xs font-semibold px-2 py-0.5 rounded-full',
                  item.affectedStudents > 2 
                    ? 'bg-rose-100 text-rose-700 dark:bg-rose-950/40 dark:text-rose-400'
                    : item.affectedStudents > 0 
                      ? 'bg-amber-100 text-amber-700 dark:bg-amber-950/40 dark:text-amber-400'
                      : 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-400'
                ]"
              >
                {{ item.affectedStudents > 0
                  ? `${item.affectedStudents} estudiantes con brecha`
                  : item.assessedStudents > 0
                    ? `${item.masteredStudents}/${store.cockpitData.totalStudents} con dominio registrado`
                    : 'Sin brechas activas registradas' }}
              </span>
            </div>

            <h3 class="font-bold text-slate-900 dark:text-white text-base leading-snug">
              {{ item.name }}
            </h3>
            <p class="text-xs text-slate-500 mt-1">Área: {{ item.subject }}</p>

            <!-- Mastery Progress Bar -->
            <div class="mt-4">
              <div class="flex justify-between text-xs font-medium text-slate-600 dark:text-slate-400 mb-1">
                <span>Nivel de Dominio</span>
                <span>{{ Math.round(item.masteryRate * 100) }}%</span>
              </div>
              <div class="w-full h-2.5 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden">
                <div 
                  class="h-full rounded-full transition-all duration-500"
                  :class="item.masteryRate >= 0.8 ? 'bg-emerald-500' : item.masteryRate >= 0.5 ? 'bg-amber-500' : 'bg-rose-500'"
                  :style="{ width: `${item.masteryRate * 100}%` }"
                ></div>
              </div>
            </div>
          </div>

          <div class="mt-5 pt-3 border-t border-slate-100 dark:border-slate-800/80 flex items-center justify-between text-xs text-slate-500">
            <span class="inline-flex items-center space-x-1">
              <AlertTriangle class="w-3.5 h-3.5 text-amber-500" />
              <span>Prioridad: {{ item.priorityScore }}</span>
            </span>
            <button 
              @click="activeTab = 'groups'"
              class="font-semibold text-indigo-600 hover:text-indigo-700 dark:text-indigo-400 transition"
            >
              Ver intervención &rarr;
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- TAB 2: GRUPOS PEDAGÓGICOS ACCIONABLES (3-5 GRUPOS) -->
    <div v-if="activeTab === 'groups'" class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-lg font-bold text-slate-900 dark:text-white">Grupos de Recuperación Focalizada</h2>
          <p class="text-xs text-slate-500">En lugar de 30 planes individuales, agrupamos causas comunes con intervenciones de 15 minutos.</p>
        </div>
      </div>

      <div class="space-y-4">
        <div 
          v-for="group in store.pedagogicalGroups" 
          :key="group.id"
          class="bg-white dark:bg-slate-900 rounded-2xl p-5 sm:p-6 border border-slate-200 dark:border-slate-800 shadow-sm space-y-4"
        >
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <div class="flex items-start space-x-3">
              <div class="w-10 h-10 rounded-xl bg-indigo-100 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400 flex items-center justify-center font-bold text-base shrink-0">
                #{{ group.groupNumber }}
              </div>
              <div>
                <h3 class="font-bold text-slate-900 dark:text-white text-base sm:text-lg">
                  {{ group.title }}
                </h3>
                <p class="text-xs sm:text-sm text-indigo-600 dark:text-indigo-400 font-medium">
                  {{ group.reason }}
                </p>
              </div>
            </div>

            <div class="flex items-center space-x-2 shrink-0">
              <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                <Clock class="w-3.5 h-3.5 mr-1" />
                {{ group.estimatedTimeMinutes }} min sugeridos
              </span>
            </div>
          </div>

          <!-- Students in this group -->
          <div class="bg-slate-50 dark:bg-slate-800/50 rounded-xl p-3 border border-slate-200/60 dark:border-slate-800">
            <span class="text-xs font-semibold text-slate-500 block mb-2">Estudiantes asignados ({{ group.studentCount }}):</span>
            <div class="flex flex-wrap gap-2">
              <span 
                v-for="std in group.students" 
                :key="std.id"
                class="inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-medium bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-200 border border-slate-200 dark:border-slate-700 shadow-sm"
              >
                {{ std.name }}
              </span>
            </div>
          </div>

          <!-- Suggested Micro-Intervention Card -->
          <div class="bg-gradient-to-r from-indigo-50/70 to-purple-50/70 dark:from-indigo-950/20 dark:to-purple-950/20 p-4 rounded-xl border border-indigo-200/70 dark:border-indigo-900/50 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <span class="text-xs font-bold text-indigo-700 dark:text-indigo-300 uppercase tracking-wider block mb-0.5">
                Microintervención Recomendada
              </span>
              <h4 class="text-sm font-bold text-slate-900 dark:text-white">
                {{ group.suggestedIntervention.title }}
              </h4>
              <p class="text-xs text-slate-600 dark:text-slate-300 mt-1 max-w-2xl">
                {{ group.suggestedIntervention.description }}
              </p>
            </div>

            <div class="flex items-center space-x-2">
              <button
                v-if="group.suggestedIntervention.isPersisted && canUpdateGrades"
                @click="assignIntervention(group)"
                :disabled="isAssigningIntervention"
                class="px-3.5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-xs font-bold shadow transition flex items-center space-x-1.5"
              >
                <CheckCircle2 class="w-4 h-4" />
                <span>{{ isAssigningIntervention ? 'Guardando…' : 'Asignar intervención' }}</span>
              </button>
              <span v-else-if="!group.suggestedIntervention.isPersisted" class="text-xs font-semibold text-amber-700 dark:text-amber-300">
                Sugerencia pendiente de incorporar al catálogo institucional
              </span>
              <span v-else class="text-xs font-semibold text-slate-500 dark:text-slate-400">
                Requiere permiso para actualizar calificaciones
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- TAB 3: ESTUDIANTES & PASAPORTE DE APRENDIZAJE -->
    <div v-if="activeTab === 'students'" class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-lg font-bold text-slate-900 dark:text-white">Ficha Individual y Pasaporte de Aprendizaje</h2>
          <p class="text-xs text-slate-500">Consulta el perfil de dominio cualitativo comprensible para la familia.</p>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div 
          v-for="std in store.cockpitData?.students" 
          :key="std.id"
          class="bg-white dark:bg-slate-900 rounded-2xl p-5 border border-slate-200 dark:border-slate-800 shadow-sm space-y-3"
        >
          <div class="flex items-center justify-between">
            <div class="w-9 h-9 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center font-bold text-sm text-slate-700 dark:text-slate-300">
              {{ std.name.charAt(0) }}
            </div>
            <span 
              :class="[
                'text-xs font-semibold px-2 py-0.5 rounded-full',
                (std.gaps || []).length === 0 
                  ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-400'
                  : 'bg-amber-100 text-amber-700 dark:bg-amber-950/40 dark:text-amber-400'
              ]"
            >
              {{ (std.gaps || []).length === 0 ? 'Sin brechas críticas' : `${std.gaps.length} brecha activa` }}
            </span>
          </div>

          <h3 class="font-bold text-slate-900 dark:text-white text-base">
            {{ std.name }}
          </h3>

          <div class="text-xs text-slate-600 dark:text-slate-400">
            <p v-if="std.gaps && std.gaps.length > 0">
              <strong class="text-slate-800 dark:text-slate-200">Refuerzo requerido:</strong> {{ std.gaps[0].competencyName }}
            </p>
            <p v-else class="text-emerald-600 dark:text-emerald-400">
              Sin brechas activas registradas. Consulta el pasaporte para revisar sus evidencias de dominio.
            </p>
          </div>

          <div class="pt-2 border-t border-slate-100 dark:border-slate-800 flex justify-end">
            <router-link
              v-if="canRunDiagnostics"
              :to="{
                name: 'intelligence-diagnostico',
                query: {
                  studentId: std.id,
                  subject: store.selectedSubject,
                  gradeLevel: selectedCourseLevel
                }
              }"
              class="mr-4 text-xs font-bold text-emerald-600 dark:text-emerald-400 hover:underline"
            >
              Iniciar diagnóstico
            </router-link>
            <router-link 
              :to="`/intelligence/pasaporte/${std.id}`"
              class="text-xs font-bold text-indigo-600 dark:text-indigo-400 hover:underline flex items-center space-x-1"
            >
              <span>Ver Pasaporte &rarr;</span>
            </router-link>
          </div>
        </div>
      </div>
    </div>

    <!-- MODAL: EJECUCIÓN Y REEVALUACIÓN DE MICROINTERVENCIÓN (FASE 2) -->
    <div v-if="selectedGroupForIntervention" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
      <div class="bg-white dark:bg-slate-900 rounded-3xl max-w-2xl w-full p-6 sm:p-8 border border-slate-200 dark:border-slate-800 shadow-2xl space-y-6">
        <div class="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-4">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 rounded-xl bg-indigo-600 text-white flex items-center justify-center font-bold">
              {{ selectedGroupForIntervention.estimatedTimeMinutes }}'
            </div>
            <div>
              <span class="text-xs font-bold text-indigo-600 dark:text-indigo-400 uppercase tracking-wider">Plan de Acción en el Aula</span>
              <h3 class="text-lg font-bold text-slate-900 dark:text-white">{{ selectedGroupForIntervention.title }}</h3>
            </div>
          </div>
          <button @click="selectedGroupForIntervention = null" class="p-2 text-slate-400 hover:text-slate-600 dark:hover:text-white rounded-lg">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Pasos construidos desde la microintervención seleccionada -->
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
          <div
            v-for="step in interventionPlanSteps"
            :key="step.title"
            class="p-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700"
          >
            <span class="font-bold text-indigo-600 dark:text-indigo-400 block mb-1">{{ step.title }}</span>
            <p class="text-slate-600 dark:text-slate-300">{{ step.text }}</p>
          </div>
        </div>

        <!-- Lista de Estudiantes y Verificación en Vivo -->
        <div class="space-y-3">
          <h4 class="text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider">
            Verificación y Reevaluación relámpago:
          </h4>
          <div class="space-y-2 max-h-52 overflow-y-auto pr-1">
            <div 
              v-for="std in selectedGroupForIntervention.students" 
              :key="std.id"
              class="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-3 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700"
            >
              <span class="text-sm font-semibold text-slate-800 dark:text-slate-200">{{ std.name }}</span>
              <div class="flex flex-wrap items-center gap-2">
                <button 
                  v-if="!reevaluationStatus[std.id]"
                  @click="recordReevaluation(std.id, 0.9)"
                  class="px-2.5 py-1 text-xs font-bold rounded-lg bg-emerald-600 text-white hover:bg-emerald-700 transition"
                >
                  ✓ Brecha Superada
                </button>
                <button 
                  v-if="!reevaluationStatus[std.id]"
                  @click="recordReevaluation(std.id, 0.4)"
                  class="px-2.5 py-1 text-xs font-bold rounded-lg bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-300 hover:bg-slate-300 transition"
                >
                  Aún en refuerzo
                </button>
                <span 
                  v-else 
                  :class="[
                    'text-xs font-bold px-2.5 py-1 rounded-lg',
                    reevaluationStatus[std.id].resolved 
                      ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300' 
                      : 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
                  ]"
                >
                  {{ reevaluationStatus[std.id].resolved ? '🎉 Brecha Cerrada' : '🔄 En Refuerzo' }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div class="pt-2 border-t border-slate-100 dark:border-slate-800 flex justify-end">
          <button 
            @click="closeInterventionModal"
            class="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold transition"
          >
            Finalizar Sesión de Recuperación
          </button>
        </div>
      </div>
    </div>

    <!-- Socratic Tutor Drawer Component -->
    <SocraticTutorDrawer />
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useIntelligenceStore } from '../stores/useIntelligenceStore'
import { useAuthStore } from '../../../stores/auth'
import { hasAccessPermission } from '../../../lib/permissions'
import { intelligenceService } from '../services/intelligenceService'
import SocraticTutorDrawer from '../components/tutor/SocraticTutorDrawer.vue'
import { toast } from 'vue-sonner'
import { 
  Sparkles, 
  ClipboardCheck, 
  Bot, 
  Compass, 
  Users, 
  GraduationCap, 
  AlertTriangle, 
  Clock, 
  CheckCircle2,
  RefreshCw,
  X
} from 'lucide-vue-next'

const store = useIntelligenceStore()
const authStore = useAuthStore()
const activeTab = ref('radar')
const selectedGroupForIntervention = ref(null)
const reevaluationStatus = reactive({})
const isSyncing = ref(false)
const isAssigningIntervention = ref(false)

const selectedCourseLevel = computed(() => (
  store.coursesList.find(course => course.id === store.selectedCourseId)?.level || ''
))
const canUpdateGrades = computed(() => hasAccessPermission(authStore.accessContext, 'grades.update'))
const canRunDiagnostics = computed(() => (
  canUpdateGrades.value && hasAccessPermission(authStore.accessContext, 'students.read')
))

const interventionPlanSteps = computed(() => {
  const intervention = selectedGroupForIntervention.value?.suggestedIntervention
  const payload = intervention?.resource_payload || {}
  if (!intervention) return []

  return [
    {
      title: '1. Propósito',
      text: `Explica el objetivo de refuerzo: ${selectedGroupForIntervention.value.competencyName}.`
    },
    {
      title: '2. Actividad guiada',
      text: payload.activity || intervention.description
    },
    {
      title: '3. Verificación',
      text: payload.checkpoint || 'Solicita una explicación breve y registra la reevaluación individual.'
    }
  ]
})

const globalMasteryRate = computed(() => {
  const radar = store.radarOverview
  if (!radar || radar.length === 0) return 0
  const sum = radar.reduce((acc, curr) => acc + (curr.masteryRate || 0), 0)
  return Math.round((sum / radar.length) * 100)
})

onMounted(async () => {
  const sId = authStore.activeSchoolId
  await store.loadInstitutionCourses(sId)
  await store.loadCockpit(store.selectedCourseId, sId, store.selectedSubject)
})

async function handleCourseChange() {
  const sId = authStore.activeSchoolId
  await store.loadCourseSubjects(store.selectedCourseId, sId)
  await store.loadCockpit(store.selectedCourseId, sId, store.selectedSubject)
}

async function handleSubjectChange() {
  const selected = store.subjectsList.find(s => s.course_subject_id === store.selectedSubjectId)
  if (selected) {
    store.selectedSubject = selected.name
  }
  const sId = authStore.activeSchoolId
  await store.loadCockpit(store.selectedCourseId, sId, store.selectedSubject)
}

async function syncOfficialGrades() {
  if (!store.selectedCourseId) return
  isSyncing.value = true
  try {
    const sId = authStore.activeSchoolId
    const res = await store.syncFromGrades(sId, store.selectedCourseId, store.selectedSubjectId)
    if (res?.success) {
      toast.success('Calificaciones oficiales sincronizadas', {
        description: `Se evaluaron ${res.total_students} estudiantes y se identificaron ${res.gaps_created} brechas activas.`
      })
    } else {
      toast.info('Sincronización completada', {
        description: 'No se encontraron notas pendientes de procesar para esta materia.'
      })
    }
  } catch (err) {
    console.error('Error sincronizando notas:', err)
    toast.error('Error al sincronizar calificaciones')
  } finally {
    isSyncing.value = false
  }
}

async function assignIntervention(group) {
  if (!group?.suggestedIntervention?.isPersisted) return

  isAssigningIntervention.value = true
  try {
    const result = await intelligenceService.assignPedagogicalIntervention({
      schoolId: authStore.activeSchoolId,
      interventionId: group.suggestedIntervention.id,
      courseId: store.selectedCourseId,
      studentIds: group.students.map(student => student.id),
      notes: `Asignación desde Panel Docente: ${group.title}`
    })
    const assignedRuns = Array.isArray(result.assigned_runs) ? result.assigned_runs : []
    if (assignedRuns.length !== group.students.length) {
      throw new Error('El servidor no confirmó todas las ejecuciones de la intervención.')
    }

    for (const studentId of Object.keys(reevaluationStatus)) delete reevaluationStatus[studentId]
    selectedGroupForIntervention.value = {
      ...group,
      runIdsByStudent: Object.fromEntries(
        assignedRuns.map(run => [run.student_id, run.run_id])
      )
    }
    toast.success('Intervención asignada', {
      description: `Se registró para ${assignedRuns.length} estudiante${assignedRuns.length === 1 ? '' : 's'}.`
    })
  } catch (err) {
    console.error('Error asignando intervención:', err)
    toast.error('No se asignó la intervención', {
      description: err?.message || 'Revisa tu conexión o tus permisos e inténtalo nuevamente.'
    })
  } finally {
    isAssigningIntervention.value = false
  }
}

async function recordReevaluation(studentId, score) {
  try {
    const compId = selectedGroupForIntervention.value?.competencyId
    const runId = selectedGroupForIntervention.value?.runIdsByStudent?.[studentId]
    const result = await intelligenceService.completeInterventionReevaluation({
      schoolId: authStore.activeSchoolId,
      runId,
      studentId,
      competencyId: compId,
      score,
      rawResponse: `Reevaluación relámpago en aula: ${score >= 0.7 ? 'Acierto en reactivo' : 'Requiere más refuerzo'}`
    })

    reevaluationStatus[studentId] = {
      resolved: result.resolved,
      score: result.score
    }
  } catch (err) {
    console.error('Error guardando reevaluación:', err)
    toast.error('No se guardó la reevaluación', {
      description: 'Revisa tu conexión o tus permisos e inténtalo nuevamente.'
    })
  }
}

function closeInterventionModal() {
  selectedGroupForIntervention.value = null
  store.loadCockpit(store.selectedCourseId, authStore.activeSchoolId, store.selectedSubject)
}
</script>
