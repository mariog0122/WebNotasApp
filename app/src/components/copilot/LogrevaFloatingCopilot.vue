<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { useAcademicYearStore } from '../../stores/academicYear'
import { LogrevaCopilotOrchestrator } from '../../lib/ai/agents/LogrevaCopilotOrchestrator'
import LogrevaBotAvatar from './LogrevaBotAvatar.vue'
import { 
  X, 
  Minus, 
  Send, 
  Sparkles, 
  Bell, 
  BookOpen, 
  Users, 
  CalendarCheck, 
  CheckSquare, 
  CalendarRange, 
  AlertTriangle, 
  ChevronRight, 
  MessageSquare,
  Bot,
  GraduationCap,
  ArrowUpRight,
  ExternalLink,
  Volume2
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const academicYearStore = useAcademicYearStore()

// Estados del Copiloto
const isOpen = ref(false)
const isMinimized = ref(false)
const inputQuery = ref('')
const isThinking = ref(false)
const activeRole = ref('Docente')
const chatContainer = ref(null)

// Estado para quitar / llamar al asistente
const isDismissed = ref(false)
if (typeof window !== 'undefined' && window.localStorage) {
  try {
    isDismissed.value = window.localStorage.getItem('logreva_copilot_dismissed') === 'true'
  } catch (e) {}
}

const dismissCopilot = () => {
  isDismissed.value = true
  if (typeof window !== 'undefined' && window.localStorage) {
    try {
      window.localStorage.setItem('logreva_copilot_dismissed', 'true')
    } catch (e) {}
  }
}

const summonCopilot = () => {
  isDismissed.value = false
  if (typeof window !== 'undefined' && window.localStorage) {
    try {
      window.localStorage.removeItem('logreva_copilot_dismissed')
    } catch (e) {}
  }
}

// Atajo global para llamar/abrir el asistente (Alt + A)
const handleGlobalKey = (e) => {
  if (e.altKey && (e.key === 'a' || e.key === 'A')) {
    e.preventDefault()
    if (isDismissed.value) {
      summonCopilot()
    } else {
      toggleOpen()
    }
  }
}

// Historial de interacción
const conversation = ref([
  {
    sender: 'assistant',
    text: '¡Hola! Soy tu asistente de Logreva. Estoy aquí para ayudarte a gestionar asistencias, redactar comunicados, consultar cursos o planificar con IA. ¿En qué te acompaño hoy?',
    agentName: 'Asistente Logreva (Orquestador)',
    timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }
])

// Invalidate pending responses and remove institutional data on context changes.
let contextVersion = 0
watch([
  () => authStore.activeSchoolId,
  () => authStore.user?.id,
  () => authStore.accessContext,
  () => academicYearStore.selectedYearName,
], () => {
  contextVersion++
  conversation.value = []
  inputQuery.value = ''
  isThinking.value = false
}, { flush: 'sync', deep: true })

onMounted(() => {
  if (typeof window !== 'undefined') {
    window.addEventListener('keydown', handleGlobalKey)
  }
})

onUnmounted(() => { 
  contextVersion++ 
  if (typeof window !== 'undefined') {
    window.removeEventListener('keydown', handleGlobalKey)
  }
})

const currentRoleProfile = computed(() => {
  if (activeRole.value === 'Rectorado') {
    return { name: 'Rectorado', desc: 'Visión completa para mejores decisiones' }
  }
  if (activeRole.value === 'Representantes') {
    return { name: 'Representantes', desc: 'Mantente informado siempre' }
  }
  return { name: 'Docente', desc: 'Planifica, consulta y gestiona con facilidad' }
})

// Acciones Rápidas (Globos de diálogo centrales)
const quickPrompts = [
  { text: '¿Qué estudiantes faltaron hoy?', icon: CalendarCheck },
  { text: 'Muéstrame los cursos activos', icon: BookOpen },
  { text: 'Aviso para 2do BGU', icon: Bell },
  { text: 'Recordatorio de tareas pendientes', icon: CheckSquare }
]

// Capacidades Laterales (Tarjetas de la imagen)
const leftCapabilities = [
  {
    id: 'avisos',
    title: 'Avisos',
    desc: 'Comunica información importante al instante',
    icon: Bell,
    badgeColor: 'bg-rose-500 text-white',
    prompt: 'Avisos recientes para padres y estudiantes'
  },
  {
    id: 'cursos',
    title: 'Cursos',
    desc: 'Gestiona y consulta tus cursos activos',
    icon: BookOpen,
    prompt: 'Muéstrame mis cursos y paralelos activos'
  },
  {
    id: 'estudiantes',
    title: 'Estudiantes',
    desc: 'Busca, filtra y conoce el progreso académico',
    icon: Users,
    prompt: 'Buscar y revisar el estado de los estudiantes'
  }
]

const rightCapabilities = [
  {
    id: 'asistencia',
    title: 'Asistencia',
    desc: 'Registra y revisa la asistencia',
    icon: CalendarCheck,
    prompt: '¿Qué estudiantes faltaron hoy?'
  },
  {
    id: 'tareas',
    title: 'Tareas',
    desc: 'Crea, asigna y da seguimiento',
    icon: CheckSquare,
    prompt: 'Recordatorio de tareas y calificaciones pendientes'
  },
  {
    id: 'planificacion',
    title: 'Planificación',
    desc: 'Organiza tu período académico',
    icon: CalendarRange,
    route: '/planificacion-ia',
    prompt: 'Generar planificación curricular con ERCA y DUA'
  },
  {
    id: 'alertas',
    title: 'Alertas',
    desc: 'Detecta situaciones que requieren atención',
    icon: AlertTriangle,
    badgeColor: 'bg-rose-500 text-white',
    route: '/alerts',
    prompt: 'Mostrar alertas académicas y casos del DECE'
  }
]

const toggleOpen = () => {
  isOpen.value = !isOpen.value
  if (isOpen.value) {
    isMinimized.value = false
    scrollToBottom()
  }
}

const toggleMinimize = () => {
  isMinimized.value = !isMinimized.value
}

const selectRole = (role) => {
  activeRole.value = role
  conversation.value.push({
    sender: 'assistant',
    text: `Vista de ${role}. Tus permisos siguen siendo los de tu cuenta institucional.`,
    agentName: 'Asistente Logreva',
    timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  })
  scrollToBottom()
}

const triggerPrompt = async (queryText) => {
  inputQuery.value = queryText
  await handleSubmit()
}

const scrollToBottom = () => {
  nextTick(() => {
    if (chatContainer.value) {
      chatContainer.value.scrollTop = chatContainer.value.scrollHeight
    }
  })
}

const handleSubmit = async () => {
  const query = inputQuery.value.trim()
  if (!query || isThinking.value) return
  const requestVersion = contextVersion
  const orchestrator = new LogrevaCopilotOrchestrator({
    schoolId: authStore.activeSchoolId,
    userId: authStore.user?.id,
    academicYear: academicYearStore.selectedYearName,
    accessContext: authStore.accessContext,
    role: activeRole.value,
  })

  // Agregar mensaje del usuario
  conversation.value.push({
    sender: 'user',
    text: query,
    timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  })
  inputQuery.value = ''
  isThinking.value = true
  scrollToBottom()

  try {
    // Procesar con el orquestador agéntico
    const response = await orchestrator.processQuery(query)
    if (requestVersion !== contextVersion) return

    conversation.value.push({
      sender: 'assistant',
      text: response.message,
      agentName: response.agentName,
      data: response.data,
      type: response.type,
      actionRoute: response.actionRoute,
      actionText: response.actionText,
      suggestions: response.suggestions,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    })
  } catch (err) {
    if (requestVersion !== contextVersion) return
    conversation.value.push({
      sender: 'assistant',
      text: 'Disculpa, ocurrió un inconveniente temporal coordinando con los agentes. Por favor intenta de nuevo.',
      agentName: 'Asistente Logreva',
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    })
  } finally {
    if (requestVersion === contextVersion) {
      isThinking.value = false
      scrollToBottom()
    }
  }
}

const navigateTo = (path) => {
  if (path) {
    router.push(path)
  }
}
</script>

<template>
  <div class="logreva-copilot-root">
    <!-- BOTÓN DISPARADOR FLOTANTE (ESTADO MINIMIZADO / CERRADO) -->
    <Transition name="bounce-subtle">
      <div 
        v-if="!isOpen && !isDismissed"
        class="fixed bottom-6 right-6 z-40 flex items-center gap-3 group select-none"
      >
        <!-- Globo de saludo: solo visible al pasar o acercar el mouse sobre el asistente -->
        <div class="hidden sm:flex items-center gap-2 px-3.5 py-2 bg-slate-900/90 backdrop-blur-xl border border-cyan-400/40 rounded-2xl shadow-xl shadow-cyan-950/40 text-xs font-semibold text-cyan-100 transition-all duration-300 opacity-0 pointer-events-none translate-x-2 group-hover:opacity-100 group-hover:pointer-events-auto group-hover:translate-x-0">
          <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
          <span>¿En qué te ayudo hoy?</span>
        </div>

        <!-- Contenedor del robot con disparador y botón para ocultar -->
        <div class="relative">
          <!-- Botón interactivo con el robot 3D (TAMAÑO Y ESTILO ORIGINALES EXACTOS) -->
          <button
            @click="toggleOpen"
            class="relative w-24 h-24 sm:w-28 sm:h-28 flex items-center justify-center focus:outline-none group cursor-pointer transition-transform duration-300 hover:scale-110 active:scale-95"
            title="Abrir Asistente Logreva"
            aria-label="Abrir Asistente Logreva"
          >
            <!-- Aura y Resplandor de fondo holográfico (sin fondo blanco) -->
            <div class="absolute inset-1.5 rounded-full bg-gradient-to-tr from-cyan-500/20 via-blue-600/20 to-indigo-500/20 backdrop-blur-xl border border-cyan-400/50 shadow-2xl shadow-cyan-500/40 group-hover:shadow-cyan-400/80 group-hover:border-cyan-300/80 transition-all duration-300"></div>
            <div class="absolute inset-0 rounded-full bg-cyan-400/25 blur-xl group-hover:bg-cyan-400/45 transition-all duration-300 animate-pulse"></div>

            <!-- Robot Asistente 3D en WebP transparente, ampliado y nítido -->
            <div class="relative w-full h-full flex items-center justify-center z-10 p-0.5">
              <LogrevaBotAvatar size="100%" :mini="true" />
            </div>

            <!-- Indicador de En Línea -->
            <span class="absolute top-1.5 right-1.5 flex h-4 w-4 z-20">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-4 w-4 bg-emerald-500 border-2 border-slate-950 shadow-md"></span>
            </span>
          </button>

          <!-- Botón sutil para Ocultar/Quitar (aparece al pasar el mouse por el asistente) -->
          <button
            @click.stop="dismissCopilot"
            class="absolute -top-1 -left-1 z-30 w-6 h-6 rounded-full bg-slate-900/90 border border-cyan-400/40 text-slate-400 hover:text-white hover:border-cyan-300 hover:bg-slate-800 flex items-center justify-center shadow-lg transition-all duration-200 opacity-0 group-hover:opacity-100 scale-75 group-hover:scale-100 cursor-pointer"
            title="Ocultar asistente (puedes llamarlo con Alt+A o la pestaña inferior)"
            aria-label="Ocultar asistente"
          >
            <X class="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    </Transition>

    <!-- PESTAÑA DISCRETA PARA LLAMAR AL ASISTENTE CUANDO ESTÁ OCULTO -->
    <Transition name="fade-pill">
      <div 
        v-if="!isOpen && isDismissed"
        class="fixed bottom-3 right-4 z-40 select-none"
      >
        <button
          @click="summonCopilot"
          class="flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-900/85 hover:bg-slate-900 backdrop-blur-md border border-cyan-500/40 hover:border-cyan-400 text-xs font-semibold text-cyan-200 hover:text-white shadow-lg shadow-cyan-950/40 hover:shadow-cyan-500/20 transition-all duration-300 group cursor-pointer"
          title="Llamar al Asistente Logreva (Alt + A)"
          aria-label="Llamar Asistente Logreva"
        >
          <span class="relative flex h-2 w-2">
            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-cyan-400 opacity-75"></span>
            <span class="relative inline-flex rounded-full h-2 w-2 bg-cyan-400"></span>
          </span>
          <Bot class="w-3.5 h-3.5 text-cyan-400 group-hover:scale-110 transition-transform duration-200" />
          <span>Asistente</span>
          <span class="hidden sm:inline-block text-[10px] text-cyan-400/60 font-mono pl-0.5">Alt+A</span>
        </button>
      </div>
    </Transition>

    <!-- VENTANA EXPANDIDA DEL COPILOTO HOLOGRÁFICO -->
    <Transition name="copilot-scale">
      <div 
        v-if="isOpen"
        class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 md:p-6 bg-slate-950/70 backdrop-blur-md"
        @click.self="toggleOpen"
      >
        <!-- CONTENEDOR PRINCIPAL HOLOGRÁFICO -->
        <div 
          class="relative w-full max-w-6xl max-h-[92vh] flex flex-col rounded-3xl border border-cyan-500/30 bg-slate-950/95 text-slate-100 shadow-2xl shadow-cyan-950/80 overflow-hidden font-sans backdrop-blur-2xl"
        >
          <!-- Resplandor ambiental de fondo -->
          <div class="absolute -top-32 left-1/2 -translate-x-1/2 w-96 h-96 bg-cyan-500/15 rounded-full blur-3xl pointer-events-none"></div>
          <div class="absolute -bottom-32 left-1/2 -translate-x-1/2 w-96 h-96 bg-blue-600/15 rounded-full blur-3xl pointer-events-none"></div>

          <!-- TOP BAR / HEADER -->
          <div class="relative z-10 flex items-center justify-between px-6 py-4 border-b border-cyan-500/20 bg-slate-900/40 backdrop-blur-xl">
            <div class="flex items-center gap-3 min-w-0">
              <div class="w-12 h-12 rounded-2xl bg-cyan-500/15 border border-cyan-400/40 flex items-center justify-center p-1 shadow-inner">
                <LogrevaBotAvatar size="100%" :mini="true" />
              </div>
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <h3 class="text-base sm:text-lg font-bold text-white tracking-tight flex items-center gap-1.5">
                    Asistente <span class="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-400">Logreva</span>
                  </h3>
                  <span class="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-cyan-500/15 border border-cyan-400/30 text-cyan-300">
                    Copiloto Global
                  </span>
                </div>
                <p class="text-xs text-slate-400 truncate">Resuelve dudas, avisa y acompaña</p>
              </div>
            </div>

            <!-- Acciones de cabecera -->
            <div class="flex items-center gap-2 shrink-0">
              <div class="hidden sm:flex items-center gap-1.5 px-3 py-1 rounded-xl bg-slate-800/80 border border-slate-700/60 text-xs text-slate-300">
                <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
                <span>Activo: {{ activeRole }}</span>
              </div>

              <button 
                @click="toggleOpen"
                class="w-8 h-8 rounded-xl bg-slate-800/60 hover:bg-rose-500/20 hover:text-rose-400 border border-slate-700/50 hover:border-rose-500/30 text-slate-400 flex items-center justify-center transition-all duration-200"
                title="Cerrar asistente"
              >
                <X class="w-4 h-4" />
              </button>
            </div>
          </div>

          <!-- CUERPO PRINCIPAL (DISEÑO DE 3 COLUMNAS COMO EN LA IMAGEN) -->
          <div class="relative z-10 flex-1 overflow-y-auto custom-copilot-scroll p-4 sm:p-6 grid grid-cols-1 lg:grid-cols-12 gap-5 min-h-0">
            
            <!-- COLUMNA IZQUIERDA: Tarjetas de Capacidades (Avisos, Cursos, Estudiantes) -->
            <div class="lg:col-span-3 flex flex-col gap-3.5 order-2 lg:order-1">
              <div class="text-[11px] font-bold uppercase tracking-wider text-cyan-400/80 px-1">
                Gestión y Consulta
              </div>

              <div 
                v-for="item in leftCapabilities" 
                :key="item.id"
                @click="triggerPrompt(item.prompt)"
                class="group p-3.5 rounded-2xl bg-slate-900/60 hover:bg-slate-800/80 border border-slate-800/80 hover:border-cyan-400/40 shadow-lg hover:shadow-cyan-950/40 transition-all duration-200 cursor-pointer flex items-start justify-between gap-3 backdrop-blur-md"
              >
                <div class="flex items-start gap-3 min-w-0">
                  <div class="p-2 rounded-xl bg-cyan-500/10 text-cyan-400 border border-cyan-500/20 group-hover:scale-105 transition-transform">
                    <component :is="item.icon" class="w-5 h-5" />
                  </div>
                  <div class="min-w-0">
                    <div class="flex items-center gap-2">
                      <span class="text-sm font-bold text-white group-hover:text-cyan-300 transition-colors">
                        {{ item.title }}
                      </span>
                      <span 
                        v-if="item.badge" 
                        class="px-1.5 py-0.2 rounded-full text-[10px] font-extrabold"
                        :class="item.badgeColor"
                      >
                        {{ item.badge }}
                      </span>
                    </div>
                    <p class="text-xs text-slate-400 line-clamp-2 mt-0.5 leading-snug">
                      {{ item.desc }}
                    </p>
                  </div>
                </div>
                <ChevronRight class="w-4 h-4 text-slate-500 group-hover:text-cyan-400 group-hover:translate-x-0.5 transition-all shrink-0 mt-2" />
              </div>
            </div>

            <!-- COLUMNA CENTRAL: Avatar Holográfico del Robot + Globos Interactivos + Flujo de Chat -->
            <div class="lg:col-span-6 flex flex-col items-center justify-between gap-3 order-1 lg:order-2 lg:min-h-0 lg:flex-1">
              
              <!-- ÁREA HOLOGRÁFICA DEL ROBOT (COMO EN LA IMAGEN) -->
              <div class="relative w-full flex flex-col items-center justify-center pt-1 pb-1 shrink-0">
                
                <!-- Globos de diálogo superiores alrededor del robot -->
                <div class="w-full flex flex-wrap items-center justify-center gap-1.5 sm:gap-2 mb-2">
                  <button 
                    v-for="(bubble, idx) in quickPrompts"
                    :key="idx"
                    @click="triggerPrompt(bubble.text)"
                    class="px-3 py-1 rounded-full bg-slate-900/80 hover:bg-cyan-950/80 border border-cyan-400/30 hover:border-cyan-400/60 shadow-md text-[11px] font-semibold text-cyan-200 hover:text-white transition-all duration-200 flex items-center gap-1.5 hover:scale-105 active:scale-95"
                  >
                    <component :is="bubble.icon" class="w-3 h-3 text-cyan-400" />
                    <span>{{ bubble.text }}</span>
                  </button>
                </div>

                <!-- ROBOT 3D ANIMADO FLOTANTE CON PEDESTAL -->
                <div class="relative flex flex-col items-center">
                  <!-- Robot animado con levitación, visiblemente amplio pero adaptativo -->
                  <div 
                    class="relative flex items-center justify-center animate-floating transition-all duration-300"
                    :class="conversation.length > 1 ? 'w-24 h-24 sm:w-28 sm:h-28' : 'w-36 h-36 sm:w-44 sm:h-44 md:w-48 md:h-48'"
                    style="filter: drop-shadow(0 0 25px rgba(0,210,255,0.4))"
                  >
                    <LogrevaBotAvatar size="100%" :thinking="isThinking" />
                  </div>
                  
                  <!-- Base del pedestal de luz holográfico -->
                  <div 
                    class="h-4 rounded-full bg-gradient-to-r from-transparent via-cyan-400/50 to-transparent blur-md -mt-2 transition-all duration-300"
                    :class="conversation.length > 1 ? 'w-24 sm:w-28' : 'w-36 sm:w-48 md:w-56'"
                  ></div>
                </div>
              </div>

              <!-- CHAT INTERACTIVO CON AGENTES (GARANTIZANDO VISIBILIDAD AMPLIA Y NUNCA APLASTADA) -->
              <div 
                ref="chatContainer"
                class="w-full flex-1 min-h-[200px] sm:min-h-[240px] max-h-[260px] sm:max-h-[380px] overflow-y-auto custom-copilot-scroll flex flex-col gap-3 p-3 rounded-2xl bg-slate-900/40 border border-cyan-500/20 backdrop-blur-sm shadow-inner"
              >
                <div 
                  v-for="(msg, i) in conversation" 
                  :key="i"
                  :class="[
                    'flex flex-col max-w-[90%] text-xs leading-relaxed transition-all',
                    msg.sender === 'user' ? 'ml-auto items-end' : 'mr-auto items-start'
                  ]"
                >
                  <!-- Etiqueta del agente emisor -->
                  <span v-if="msg.agentName" class="text-[10px] font-bold text-cyan-400 mb-0.5 flex items-center gap-1">
                    <Bot class="w-3 h-3" /> {{ msg.agentName }}
                  </span>

                  <!-- Burbuja de contenido -->
                  <div 
                    :class="[
                      'p-3 rounded-2xl shadow-md',
                      msg.sender === 'user' 
                        ? 'bg-gradient-to-r from-cyan-600 to-blue-600 text-white rounded-br-none' 
                        : 'bg-slate-900/90 border border-cyan-500/25 text-slate-200 rounded-bl-none'
                    ]"
                  >
                    <p class="whitespace-pre-line">{{ msg.text }}</p>

                    <!-- Datos estructurados si el agente los devuelve -->
                    <div v-if="msg.data && Array.isArray(msg.data)" class="mt-2.5 pt-2 border-t border-slate-700/60 flex flex-col gap-1.5">
                      <div 
                        v-for="(item, idx) in msg.data.slice(0, 4)" 
                        :key="idx"
                        class="p-2 rounded-xl bg-slate-800/80 border border-slate-700/50 flex items-center justify-between text-[11px]"
                      >
                        <span class="font-semibold text-white">{{ item.student || item.name || item.title }}</span>
                        <span class="text-cyan-300 font-mono text-[10px]">{{ item.status || item.parallel || item.deadline }}</span>
                      </div>
                    </div>

                    <!-- Botón de acción directa / salto al módulo -->
                    <button 
                      v-if="msg.actionRoute" 
                      @click="navigateTo(msg.actionRoute); toggleOpen()"
                      class="mt-2.5 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-cyan-500/20 hover:bg-cyan-500/30 text-cyan-300 border border-cyan-400/40 font-bold text-[11px] transition-all"
                    >
                      <span>{{ msg.actionText || 'Ver en el sistema' }}</span>
                      <ArrowUpRight class="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>

                <!-- Indicador de pensamiento del agente -->
                <div v-if="isThinking" class="flex items-center gap-2 text-cyan-300 text-xs py-1 px-3 bg-slate-900/60 rounded-full w-fit border border-cyan-500/20">
                  <span class="w-2 h-2 rounded-full bg-cyan-400 animate-ping"></span>
                  <span>El Asistente Logreva está coordinando la solicitud...</span>
                </div>
              </div>

              <!-- BARRA DE ENTRADA NATURAL -->
              <form 
                @submit.prevent="handleSubmit"
                class="w-full flex items-center gap-2 p-1.5 rounded-2xl bg-slate-900/80 border border-cyan-500/30 shadow-inner focus-within:border-cyan-400 shrink-0"
              >
                <input 
                  v-model="inputQuery"
                  type="text"
                  placeholder="Escribe una instrucción o pregunta a Logreva..."
                  class="flex-1 bg-transparent px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none"
                  :disabled="isThinking"
                />
                <button 
                  type="submit"
                  :disabled="!inputQuery.trim() || isThinking"
                  class="w-9 h-9 rounded-xl bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-white flex items-center justify-center disabled:opacity-40 transition-all shrink-0"
                >
                  <Send class="w-4 h-4" />
                </button>
              </form>

            </div>

            <!-- COLUMNA DERECHA: Tarjetas de Capacidades (Asistencia, Tareas, Planificación, Alertas) -->
            <div class="lg:col-span-3 flex flex-col gap-3.5 order-3">
              <div class="text-[11px] font-bold uppercase tracking-wider text-cyan-400/80 px-1">
                Operaciones del Plantel
              </div>

              <div 
                v-for="item in rightCapabilities" 
                :key="item.id"
                @click="item.route ? (navigateTo(item.route), toggleOpen()) : triggerPrompt(item.prompt)"
                class="group p-3.5 rounded-2xl bg-slate-900/60 hover:bg-slate-800/80 border border-slate-800/80 hover:border-cyan-400/40 shadow-lg hover:shadow-cyan-950/40 transition-all duration-200 cursor-pointer flex items-start justify-between gap-3 backdrop-blur-md"
              >
                <div class="flex items-start gap-3 min-w-0">
                  <div class="p-2 rounded-xl bg-cyan-500/10 text-cyan-400 border border-cyan-500/20 group-hover:scale-105 transition-transform">
                    <component :is="item.icon" class="w-5 h-5" />
                  </div>
                  <div class="min-w-0">
                    <div class="flex items-center gap-2">
                      <span class="text-sm font-bold text-white group-hover:text-cyan-300 transition-colors">
                        {{ item.title }}
                      </span>
                      <span 
                        v-if="item.badge" 
                        class="px-1.5 py-0.2 rounded-full text-[10px] font-extrabold"
                        :class="item.badgeColor"
                      >
                        {{ item.badge }}
                      </span>
                    </div>
                    <p class="text-xs text-slate-400 line-clamp-2 mt-0.5 leading-snug">
                      {{ item.desc }}
                    </p>
                  </div>
                </div>
                <ChevronRight class="w-4 h-4 text-slate-500 group-hover:text-cyan-400 group-hover:translate-x-0.5 transition-all shrink-0 mt-2" />
              </div>
            </div>

          </div>

          <!-- FOOTER / SELECTOR DE ROLES (COMO EN LA BASE DEL PODIO) -->
          <div class="relative z-10 px-6 py-3.5 border-t border-cyan-500/20 bg-slate-900/60 flex flex-wrap items-center justify-between gap-3">
            <div class="text-[11px] text-slate-400 flex items-center gap-2">
              <span class="font-bold text-cyan-400">MÁS QUE UN SOFTWARE, UN ALIADO EN LA EDUCACIÓN</span>
            </div>

            <div class="flex items-center gap-2">
              <button 
                @click="selectRole('Docente')"
                :class="[
                  'px-3 py-1 rounded-xl text-xs font-semibold transition-all',
                  activeRole === 'Docente' 
                    ? 'bg-cyan-500/30 text-cyan-300 border border-cyan-400/50' 
                    : 'bg-slate-800/60 text-slate-400 hover:text-white border border-transparent'
                ]"
              >
                Docente
              </button>
              <button 
                @click="selectRole('Rectorado')"
                :class="[
                  'px-3 py-1 rounded-xl text-xs font-semibold transition-all',
                  activeRole === 'Rectorado' 
                    ? 'bg-cyan-500/30 text-cyan-300 border border-cyan-400/50' 
                    : 'bg-slate-800/60 text-slate-400 hover:text-white border border-transparent'
                ]"
              >
                Rectorado
              </button>
              <button 
                @click="selectRole('Representantes')"
                :class="[
                  'px-3 py-1 rounded-xl text-xs font-semibold transition-all',
                  activeRole === 'Representantes' 
                    ? 'bg-cyan-500/30 text-cyan-300 border border-cyan-400/50' 
                    : 'bg-slate-800/60 text-slate-400 hover:text-white border border-transparent'
                ]"
              >
                Representantes
              </button>
            </div>
          </div>

        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
/* Animación de levitación suave del robot */
@keyframes floating {
  0%, 100% {
    transform: translateY(0px);
  }
  50% {
    transform: translateY(-8px);
  }
}

.animate-floating {
  animation: floating 4s ease-in-out infinite;
}

/* Transiciones de apertura */
.copilot-scale-enter-active,
.copilot-scale-leave-active {
  transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

.copilot-scale-enter-from,
.copilot-scale-leave-to {
  opacity: 0;
  transform: scale(0.92);
}

.bounce-subtle-enter-active {
  animation: bounce-in 0.4s;
}
.bounce-subtle-leave-active {
  animation: bounce-in 0.25s reverse;
}

@keyframes bounce-in {
  0% {
    transform: scale(0.6);
    opacity: 0;
  }
  50% {
    transform: scale(1.05);
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}

/* Transición para la pestaña de llamada del asistente */
.fade-pill-enter-active,
.fade-pill-leave-active {
  transition: all 0.25s ease-out;
}
.fade-pill-enter-from,
.fade-pill-leave-to {
  opacity: 0;
  transform: translateY(8px);
}

/* Scrollbars personalizados para estética glassmorphism */
.custom-copilot-scroll::-webkit-scrollbar {
  width: 5px;
}
.custom-copilot-scroll::-webkit-scrollbar-track {
  background: rgba(15, 23, 42, 0.4);
}
.custom-copilot-scroll::-webkit-scrollbar-thumb {
  background: rgba(6, 182, 212, 0.3);
  border-radius: 9999px;
}
.custom-copilot-scroll::-webkit-scrollbar-thumb:hover {
  background: rgba(6, 182, 212, 0.6);
}
</style>
