<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { supabase } from '../lib/supabase'
import { translateError } from '../lib/errorDictionary'
import { toast } from 'vue-sonner'

const email = ref('')
const password = ref('')
const loading = ref(false)
const router = useRouter()
const authStore = useAuthStore()

const canvasRef = ref(null)
let animationId = null

const isRegistering = ref(false)
const regEmail = ref('')
const regPassword = ref('')
const regLoading = ref(false)

const toggleMode = () => {
    isRegistering.value = !isRegistering.value
    email.value = ''
    password.value = ''
    regEmail.value = ''
    regPassword.value = ''
}

const handleLogin = async () => {
  loading.value = true
  try {
    await authStore.signIn(email.value, password.value)
    router.push('/')
  } catch (error) {
    toast.error('Error de Inicio de Sesión', {
      description: translateError(error)
    })
  } finally {
    loading.value = false
  }
}

const handleRegister = async () => {
    regLoading.value = true

    const domain = '@docentes.educacion.edu.ec'
    if (!regEmail.value.endsWith(domain)) {
        toast.warning('Error de Seguridad', {
          description: `Solo se permiten correos institucionales terminados en ${domain}`
        })
        regLoading.value = false
        return
    }

    if (!regPassword.value || regPassword.value.length < 6) {
        toast.warning('Contraseña muy corta', {
          description: 'La contraseña debe tener al menos 6 caracteres.'
        })
        regLoading.value = false
        return
    }

    try {
        const { error } = await supabase.auth.signUp({
            email: regEmail.value,
            password: regPassword.value,
        })
        
        if (error) throw error

        toast.success('Registro Exitoso', {
          description: 'Revisa tu correo electrónico para confirmar tu cuenta.'
        })
        
        regEmail.value = ''
        regPassword.value = ''
        setTimeout(() => {
            isRegistering.value = false
        }, 1500)
    } catch (error) {
        toast.error('Error de Registro', {
          description: translateError(error)
        })
    } finally {
        regLoading.value = false
    }
}

const initCanvas = () => {
  const canvas = canvasRef.value
  if (!canvas) return
  
  const ctx = canvas.getContext('2d')
  let width = canvas.width = canvas.parentElement.clientWidth
  let height = canvas.height = canvas.parentElement.clientHeight
  
  const stars = []
  const starCount = 300
  const speed = 2

  class Star {
    constructor() {
      this.x = Math.random() * width - width / 2
      this.y = Math.random() * height - height / 2
      this.z = Math.random() * width
      this.pz = this.z
    }

    update() {
      this.z = this.z - speed
      if (this.z < 1) {
        this.z = width
        this.x = Math.random() * width - width / 2
        this.y = Math.random() * height - height / 2
        this.pz = this.z
      }
    }

    draw() {
      const sx = (this.x / this.z) * width + width / 2
      const sy = (this.y / this.z) * width + height / 2
      const r = (1 - this.z / width) * 2.5
      const px = (this.x / this.pz) * width + width / 2
      const py = (this.y / this.pz) * width + height / 2
      this.pz = this.z

      if (sx > 0 && sx < width && sy > 0 && sy < height) {
        ctx.fillStyle = `rgba(255, 255, 255, ${1 - this.z / width})`
        ctx.beginPath()
        ctx.arc(sx, sy, r, 0, Math.PI * 2)
        ctx.fill()

        ctx.strokeStyle = `rgba(255, 255, 255, ${(1 - this.z / width) * 0.5})`
        ctx.lineWidth = r
        ctx.beginPath()
        ctx.moveTo(px, py)
        ctx.lineTo(sx, sy)
        ctx.stroke()
      }
    }
  }

  for (let i = 0; i < starCount; i++) {
    stars.push(new Star())
  }

  const animate = () => {
    ctx.fillStyle = 'rgba(15, 23, 42, 0.4)'
    ctx.fillRect(0, 0, width, height)
    stars.forEach(star => {
      star.update()
      star.draw()
    })
    animationId = requestAnimationFrame(animate)
  }

  animate()

  const handleResize = () => {
    width = canvas.width = canvas.parentElement.clientWidth
    height = canvas.height = canvas.parentElement.clientHeight
  }
  
  window.addEventListener('resize', handleResize)
  canvas._resizeHandler = handleResize
}

onMounted(() => {
  initCanvas()
})

onUnmounted(() => {
  cancelAnimationFrame(animationId)
  const canvas = canvasRef.value
  if (canvas?._resizeHandler) {
    window.removeEventListener('resize', canvas._resizeHandler)
    delete canvas._resizeHandler
  }
})
</script>

<template>
  <div class="min-h-screen flex bg-slate-50 relative overflow-hidden">
    <div class="hidden lg:flex lg:w-1/2 relative bg-slate-900 items-center justify-center overflow-hidden">
      <div class="absolute inset-0 z-0">
        <img src="https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?q=80&w=2069&auto=format&fit=crop" 
             alt="Docente" 
             class="w-full h-full object-cover opacity-60 mix-blend-overlay" />
        <div class="absolute inset-0 bg-gradient-to-br from-indigo-900/95 via-slate-900/90 to-slate-900/95 mix-blend-multiply"></div>
      </div>

      <canvas ref="canvasRef" class="absolute inset-0 w-full h-full z-0 opacity-40"></canvas>

      <div class="relative z-10 p-12 text-white max-w-lg pointer-events-none select-none">
        <div class="mb-8">
           <div class="h-16 w-16 bg-white/10 backdrop-blur-md rounded-2xl flex items-center justify-center mb-6 shadow-2xl border border-white/20">
             <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-cyan-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
               <path d="M12 14l9-5-9-5-9 5 9 5z" />
               <path d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z" />
               <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5zm0 0l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14zm-4 6v-7.5l4-2.222" />
             </svg>
           </div>
           
           <h1 class="text-5xl font-extrabold mb-6 leading-tight tracking-tight drop-shadow-lg">
             Gestiona el <br>
             <span class="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-400 filter drop-shadow-lg">Futuro Educativo</span>
           </h1>
           <p class="text-slate-300 text-lg leading-relaxed font-light drop-shadow-md">
             Control total de calificaciones y reportes en una plataforma diseñada para la excelencia académica. Optimiza tu tiempo y enfócate en lo que importa: enseñar.
           </p>
        </div>

        <div class="mt-12">
          <div class="bg-slate-900/40 backdrop-blur-xl border border-white/10 p-5 rounded-2xl shadow-2xl relative overflow-hidden group hover:border-cyan-500/30 transition-all duration-300">
            <div class="absolute inset-0 pointer-events-none z-0">
              <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -skew-x-12 translate-x-[-150%] animate-laser-scan w-1/2 h-full"></div>
            </div>
            <div class="absolute -inset-1 bg-gradient-to-r from-cyan-500 to-blue-500 rounded-2xl blur opacity-5 group-hover:opacity-20 transition duration-1000 group-hover:duration-200"></div>
            <div class="relative flex items-start gap-4 z-10">
              <div class="h-12 w-12 rounded-xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center flex-shrink-0 border border-white/5">
                <svg class="h-6 w-6 text-cyan-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                </svg>
              </div>
              <div>
                <h3 class="font-bold text-white mb-1">Acceso Seguro</h3>
                <p class="text-sm text-slate-400">Autenticación protegida por Supabase y sesiones persistentes.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="w-full lg:w-1/2 flex items-center justify-center p-6 sm:p-10 relative z-10">
      <div class="w-full max-w-md">
        <div class="text-center mb-8 lg:hidden">
          <div class="mx-auto h-16 w-16 bg-indigo-600 rounded-2xl flex items-center justify-center mb-4 shadow-lg shadow-indigo-500/30">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path d="M12 14l9-5-9-5-9 5 9 5z" />
              <path d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z" />
            </svg>
          </div>
          <h1 class="text-3xl font-bold text-slate-900">Sistema de Notas</h1>
          <p class="text-slate-500 mt-2">Plataforma académica</p>
        </div>

        <div class="bg-white rounded-2xl shadow-xl border border-slate-200 p-8">
          <div class="mb-6">
            <h2 class="text-2xl font-bold text-slate-900">{{ isRegistering ? 'Registro Docente' : 'Bienvenido' }}</h2>
            <p class="text-slate-500 mt-1">
              {{ isRegistering ? 'Crea tu cuenta con correo institucional' : 'Ingresa tus credenciales para continuar' }}
            </p>
          </div>

          <form v-if="!isRegistering" @submit.prevent="handleLogin" class="space-y-5">
            <div>
              <label class="block text-sm font-semibold text-slate-700 mb-1">Correo electrónico</label>
              <input v-model="email" type="email" required class="app-input" placeholder="correo@institucion.edu.ec" />
            </div>

            <div>
              <label class="block text-sm font-semibold text-slate-700 mb-1">Contraseña</label>
              <input v-model="password" type="password" required class="app-input" placeholder="••••••••" />
            </div>

            <button type="submit" :disabled="loading" class="w-full app-btn app-btn-primary py-3 disabled:opacity-60">
              {{ loading ? 'Ingresando...' : 'Iniciar Sesión' }}
            </button>
          </form>

          <form v-else @submit.prevent="handleRegister" class="space-y-5">
            <div>
              <label class="block text-sm font-semibold text-slate-700 mb-1">Correo institucional</label>
              <input v-model="regEmail" type="email" required class="app-input" placeholder="usuario@docentes.educacion.edu.ec" />
            </div>

            <div>
              <label class="block text-sm font-semibold text-slate-700 mb-1">Contraseña</label>
              <input v-model="regPassword" type="password" required class="app-input" placeholder="Mínimo 6 caracteres" />
            </div>

            <button type="submit" :disabled="regLoading" class="w-full app-btn app-btn-primary py-3 disabled:opacity-60">
              {{ regLoading ? 'Registrando...' : 'Crear Cuenta' }}
            </button>
          </form>

          <div class="mt-6 text-center">
            <button @click="toggleMode" class="text-sm font-semibold text-indigo-600 hover:text-indigo-700">
              {{ isRegistering ? 'Ya tengo una cuenta' : 'Crear cuenta docente' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
@keyframes laser-scan {
  0% {
    transform: translateX(-150%) skewX(-12deg);
  }
  100% {
    transform: translateX(350%) skewX(-12deg);
  }
}

.animate-laser-scan {
  animation: laser-scan 3s ease-in-out infinite;
}
</style>
