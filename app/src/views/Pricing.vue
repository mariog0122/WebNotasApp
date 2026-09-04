<script setup>
import { ref, onMounted } from 'vue'
import { COMMERCIAL_PLANS } from '../lib/commercialPlans'
import BrandLogo from '../components/ui/BrandLogo.vue'
import { BRAND_NAME, DEMO_REQUEST_URL } from '../lib/brand'
import { 
  Building2, Check, ShieldCheck, Zap, Headphones, ArrowRight, 
  HelpCircle, CreditCard, Lock, Sparkles, RefreshCw, FileText, 
  PhoneCall, Mail, MessageSquare, ChevronRight, Award, CheckCircle2, X,
  Shield, Users, BarChart3, Bell, CheckCircle, LayoutDashboard, BookOpen,
  GraduationCap, User, Settings, ShieldAlert
} from 'lucide-vue-next'

const isAnnual = ref(true)
const [plan500, plan1000, plan2000] = COMMERCIAL_PLANS
const displayedPrice = (plan) => isAnnual.value ? plan.annualPrice : plan.monthlyPrice
const formatNumber = (value) => new Intl.NumberFormat('es-EC').format(value)

// Structured JSON-LD Schema for SEO
onMounted(() => {
  const schemaScript = document.createElement('script')
  schemaScript.type = 'application/ld+json'
  schemaScript.text = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": BRAND_NAME,
    "operatingSystem": "Web",
    "applicationCategory": "EducationalApplication",
    "offers": {
      "@type": "AggregateOffer",
      "priceCurrency": "USD",
      "lowPrice": String(Math.min(...COMMERCIAL_PLANS.map((plan) => plan.monthlyPrice))),
      "highPrice": String(Math.max(...COMMERCIAL_PLANS.map((plan) => plan.annualPrice))),
      "offerCount": String(COMMERCIAL_PLANS.length)
    }
  })
  document.head.appendChild(schemaScript)
})
</script>

<template>
  <div class="min-h-screen bg-[#070913] text-slate-100 font-sans selection:bg-indigo-500 selection:text-white">
    <!-- Navegación comercial LOGREVA -->
    <header class="sticky top-0 z-50 bg-[#070913]/90 backdrop-blur-xl border-b border-slate-800/60 transition-all">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between">
        <router-link to="/login" class="flex items-center gap-3 group" aria-label="Ir al acceso de LOGREVA">
          <BrandLogo variant="horizontal" tone="light" class="text-lg transition-transform group-hover:scale-[1.02]" />
        </router-link>

        <nav class="hidden lg:flex items-center gap-8 text-sm font-medium text-slate-300">
          <a href="#beneficios" class="hover:text-white transition-colors">Beneficios</a>
          <a href="#planes" class="hover:text-white transition-colors">Planes & Precios</a>
          <a href="#implementacion" class="hover:text-white transition-colors">Implementación</a>
          <a href="#seguridad" class="hover:text-white transition-colors">Seguridad</a>
          <a href="#soporte" class="hover:text-white transition-colors">Soporte</a>
          <a href="#faq" class="hover:text-white transition-colors">FAQ</a>
        </nav>

        <div class="flex items-center gap-2 sm:gap-5">
          <router-link to="/login" class="hidden sm:inline text-sm font-semibold text-slate-300 hover:text-white transition-colors">
            Iniciar Sesión
          </router-link>
          <a :href="DEMO_REQUEST_URL" target="_blank" rel="noopener noreferrer" class="bg-cyan-600 hover:bg-cyan-500 text-white px-4 sm:px-6 py-2.5 rounded-full text-xs sm:text-sm font-bold shadow-lg shadow-cyan-700/30 hover:shadow-cyan-500/30 transition-all flex items-center gap-2">
            Solicitar prueba <ArrowRight class="w-4 h-4" />
          </a>
        </div>
      </div>
    </header>

    <!-- SECCIÓN 1: HERO COMERCIAL (Doble Columna con Maqueta SVG/CSS Integrada Fiel a la Imagen 1) -->
    <section class="relative pt-12 pb-16 overflow-hidden border-b border-slate-900/80 bg-gradient-to-b from-[#070913] via-[#0b0e20] to-[#070913]">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 lg:grid-cols-12 gap-10 items-center">
          
          <!-- COLUMNA IZQUIERDA: CONTENIDO PUBLICITARIO -->
          <div class="lg:col-span-5 space-y-6 text-left">
            <div class="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-indigo-950/80 border border-indigo-800/60 text-xs font-semibold text-indigo-300 tracking-wider shadow-sm">
              <Sparkles class="w-3.5 h-3.5 text-indigo-400" />
              PLATAFORMA SaaS MULTIINSTITUCIÓN
            </div>

            <h1 class="text-4xl sm:text-5xl lg:text-[3.1rem] font-black text-white tracking-tight leading-[1.12]">
              La plataforma que centraliza toda la <span class="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 via-sky-400 to-cyan-300">gestión de tu institución educativa.</span>
            </h1>

            <p class="text-slate-300 text-base sm:text-lg leading-relaxed font-normal">
              Administra estudiantes, docentes, cursos, asignaturas, calificaciones, planificaciones didácticas con IA (Normativa MINEDEC), reportes, familias y alertas DECE desde una sola plataforma segura, moderna y fácil de usar.
            </p>

            <div class="pt-2 flex flex-col sm:flex-row items-center gap-4">
              <a :href="DEMO_REQUEST_URL" target="_blank" rel="noopener noreferrer" class="w-full sm:w-auto bg-cyan-600 hover:bg-cyan-500 text-white px-7 py-3.5 rounded-xl font-bold text-base shadow-xl shadow-cyan-700/30 transition-all flex items-center justify-center gap-2.5">
                Solicitar prueba de 15 días <ArrowRight class="w-5 h-5" />
              </a>
              <a href="#planes" class="w-full sm:w-auto bg-slate-900/90 hover:bg-slate-800 border border-slate-700/80 text-slate-200 px-7 py-3.5 rounded-xl font-bold text-base transition-all flex items-center justify-center">
                Ver planes institucionales
              </a>
            </div>

            <div class="flex items-center gap-4 text-xs font-medium text-slate-400 pt-1">
              <span class="flex items-center gap-1.5"><ShieldCheck class="w-4 h-4 text-indigo-400" /> Sin tarjeta de crédito</span>
              <span>•</span>
              <span class="flex items-center gap-1.5"><CheckCircle2 class="w-4 h-4 text-emerald-400" /> Configuración en minutos</span>
            </div>
          </div>

          <!-- COLUMNA DERECHA: MAQUETA DEL PRODUCTO LOGREVA -->
          <div class="lg:col-span-7 relative">
            <!-- Glow morado/azul exterior -->
            <div class="absolute -inset-6 bg-gradient-to-tr from-indigo-600/40 via-purple-600/30 to-blue-500/40 rounded-3xl blur-3xl opacity-80 pointer-events-none"></div>

            <!-- Contenedor Principal de la Ventana -->
            <div class="relative bg-[#060913] border border-slate-800/90 rounded-2xl shadow-[0_25px_60px_-15px_rgba(0,0,0,0.9)] overflow-hidden text-left font-sans">
              
              <!-- Barra Superior MacOS -->
              <div class="bg-[#0b0e1b] px-4 py-2.5 border-b border-slate-800/80 flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <span class="w-3 h-3 rounded-full bg-[#ff5f56] inline-block shadow-inner"></span>
                  <span class="w-3 h-3 rounded-full bg-[#ffbd2e] inline-block shadow-inner"></span>
                  <span class="w-3 h-3 rounded-full bg-[#27c93f] inline-block shadow-inner"></span>
                </div>
              </div>

              <!-- Interior de la aplicación -->
              <div class="flex bg-[#070914] min-h-[430px]">
                
                <!-- Sidebar Lateral Izquierdo -->
                <div class="w-44 bg-[#090c1a] border-r border-slate-800/70 p-3.5 flex flex-col justify-between shrink-0">
                  <div class="space-y-4">
                    <!-- Marca LOGREVA -->
                    <div class="flex items-center gap-2 px-1 py-1">
                      <BrandLogo variant="mark" tone="light" decorative class="h-6 w-6 shrink-0" />
                      <span class="font-black text-white text-xs tracking-[0.16em]">LOGREVA</span>
                    </div>

                    <!-- Items del Menú -->
                    <div class="space-y-1 text-[11px] font-medium">
                      <div class="bg-indigo-600/90 text-white font-bold px-2.5 py-1.5 rounded-lg flex items-center gap-2 shadow-md shadow-indigo-600/30">
                        <LayoutDashboard class="w-3.5 h-3.5" /> Dashboard
                      </div>
                      <div class="px-2.5 py-1.5 text-slate-400 hover:text-slate-200 flex items-center gap-2">
                        <BookOpen class="w-3.5 h-3.5" /> Cursos
                      </div>
                      <div class="px-2.5 py-1.5 text-slate-400 hover:text-slate-200 flex items-center gap-2">
                        <FileText class="w-3.5 h-3.5" /> Asignaturas
                      </div>
                      <div class="px-2.5 py-1.5 text-slate-400 hover:text-slate-200 flex items-center gap-2">
                        <GraduationCap class="w-3.5 h-3.5" /> Estudiantes
                      </div>
                      <div class="px-2.5 py-1.5 text-slate-400 hover:text-slate-200 flex items-center gap-2">
                        <Users class="w-3.5 h-3.5" /> Familias
                      </div>
                      <div class="px-2.5 py-1.5 text-slate-400 hover:text-slate-200 flex items-center gap-2">
                        <CheckCircle2 class="w-3.5 h-3.5" /> Calificaciones
                      </div>
                      <div class="px-2.5 py-1.5 text-slate-400 hover:text-slate-200 flex items-center gap-2">
                        <BarChart3 class="w-3.5 h-3.5" /> Reportes
                      </div>
                      <div class="px-2.5 py-1.5 text-slate-400 hover:text-slate-200 flex items-center gap-2">
                        <Bell class="w-3.5 h-3.5" /> Alertas DECE
                      </div>
                      <div class="px-2.5 py-1.5 text-slate-400 hover:text-slate-200 flex items-center gap-2">
                        <User class="w-3.5 h-3.5" /> Usuarios
                      </div>
                      <div class="px-2.5 py-1.5 text-slate-400 hover:text-slate-200 flex items-center gap-2">
                        <Settings class="w-3.5 h-3.5" /> Configuración
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Area Central Principal -->
                <div class="flex-1 p-4 overflow-hidden flex flex-col justify-between space-y-3">
                  
                  <!-- Header del Dashboard Interno -->
                  <div class="flex items-center justify-between">
                    <div>
                      <h3 class="text-base font-extrabold text-white tracking-tight">Dashboard</h3>
                      <p class="text-[10px] text-slate-400">Resumen general de la institución</p>
                    </div>
                    <div class="flex items-center gap-2 text-[10px]">
                      <div class="bg-[#0f1426] border border-slate-800 px-2.5 py-1 rounded-md text-slate-300 flex items-center gap-1.5">
                        2024 - 2025 <ChevronRight class="w-3 h-3 rotate-90 text-slate-500" />
                      </div>
                      <div class="bg-[#0f1426] border border-slate-800 px-2.5 py-1 rounded-md text-slate-300 flex items-center gap-1.5">
                        Periodo Actual <ChevronRight class="w-3 h-3 rotate-90 text-slate-500" />
                      </div>
                      <!-- Avatar Usuario -->
                      <div class="flex items-center gap-2 ml-1 pl-2 border-l border-slate-800">
                        <div class="w-6 h-6 rounded-full bg-slate-700 border border-slate-600 shrink-0 flex items-center justify-center" aria-hidden="true">
                          <User class="w-3.5 h-3.5 text-slate-300" />
                        </div>
                        <div class="text-[9px] text-left hidden sm:block">
                          <span class="font-bold text-white block leading-tight">Administrador</span>
                          <span class="text-slate-400 block leading-tight text-[8px]">Unidad Educativa San José</span>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Fila 1: 4 Stat Cards con Sparklines SVG -->
                  <div class="grid grid-cols-4 gap-2">
                    <!-- Card 1 -->
                    <div class="bg-[#0b0e1e] border border-slate-800/90 p-2.5 rounded-xl space-y-1 relative overflow-hidden">
                      <div class="flex justify-between items-start">
                        <span class="text-[9px] text-slate-400 font-medium">Estudiantes</span>
                        <span class="text-[8px] text-emerald-400 font-bold bg-emerald-500/10 px-1 py-0.5 rounded">+5.2%</span>
                      </div>
                      <div class="flex items-baseline gap-1">
                        <span class="text-base font-extrabold text-white">1,248</span>
                        <span class="text-[8px] text-slate-500">Activos</span>
                      </div>
                      <!-- Sparkline SVG Azul -->
                      <svg class="w-full h-6 text-sky-400 stroke-current fill-none stroke-[2]" viewBox="0 0 100 30">
                        <path d="M0 22 Q15 28 30 15 T60 22 T90 8 T100 12" />
                      </svg>
                    </div>

                    <!-- Card 2 -->
                    <div class="bg-[#0b0e1e] border border-slate-800/90 p-2.5 rounded-xl space-y-1 relative overflow-hidden">
                      <div class="flex justify-between items-start">
                        <span class="text-[9px] text-slate-400 font-medium">Docentes</span>
                        <span class="text-[8px] text-emerald-400 font-bold bg-emerald-500/10 px-1 py-0.5 rounded">+3.1%</span>
                      </div>
                      <div class="flex items-baseline gap-1">
                        <span class="text-base font-extrabold text-white">86</span>
                        <span class="text-[8px] text-slate-500">Activos</span>
                      </div>
                      <!-- Sparkline SVG Cian -->
                      <svg class="w-full h-6 text-cyan-400 stroke-current fill-none stroke-[2]" viewBox="0 0 100 30">
                        <path d="M0 24 Q20 12 40 20 T70 12 T100 6" />
                      </svg>
                    </div>

                    <!-- Card 3 -->
                    <div class="bg-[#0b0e1e] border border-slate-800/90 p-2.5 rounded-xl space-y-1 relative overflow-hidden">
                      <div class="flex justify-between items-start">
                        <span class="text-[9px] text-slate-400 font-medium">Cursos</span>
                        <span class="text-[8px] text-emerald-400 font-bold bg-emerald-500/10 px-1 py-0.5 rounded">+2.4%</span>
                      </div>
                      <div class="flex items-baseline gap-1">
                        <span class="text-base font-extrabold text-white">48</span>
                        <span class="text-[8px] text-slate-500">Activos</span>
                      </div>
                      <!-- Sparkline SVG Coral/Naranja -->
                      <svg class="w-full h-6 text-coral-400 stroke-[#f97316] fill-none stroke-[2]" viewBox="0 0 100 30">
                        <path d="M0 20 Q25 26 50 12 T75 22 T100 10" />
                      </svg>
                    </div>

                    <!-- Card 4 -->
                    <div class="bg-[#0b0e1e] border border-slate-800/90 p-2.5 rounded-xl space-y-1 relative overflow-hidden">
                      <div class="flex justify-between items-start">
                        <span class="text-[9px] text-slate-400 font-medium">Asistencias Hoy</span>
                        <span class="text-[8px] text-emerald-400 font-bold bg-emerald-500/10 px-1 py-0.5 rounded">+4.7%</span>
                      </div>
                      <div class="flex items-baseline gap-1">
                        <span class="text-base font-extrabold text-white">96%</span>
                        <span class="text-[8px] text-slate-500">Promedio</span>
                      </div>
                      <!-- Sparkline SVG Verde Esmeralda -->
                      <svg class="w-full h-6 text-emerald-400 stroke-current fill-none stroke-[2]" viewBox="0 0 100 30">
                        <path d="M0 26 Q20 16 40 22 T70 10 T100 14" />
                      </svg>
                    </div>
                  </div>

                  <!-- Fila 2: Actividad Reciente & Gráfico Donut de Niveles -->
                  <div class="grid grid-cols-12 gap-2.5">
                    
                    <!-- Actividad Reciente -->
                    <div class="col-span-6 bg-[#0b0e1e] border border-slate-800/90 p-3 rounded-xl space-y-2.5">
                      <h4 class="text-xs font-bold text-white">Actividad Reciente</h4>
                      
                      <div class="space-y-2 text-[10px]">
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-1.5">
                            <div class="w-5 h-5 rounded-md bg-sky-500/10 text-sky-400 flex items-center justify-center shrink-0">
                              <FileText class="w-3 h-3" />
                            </div>
                            <div>
                              <span class="font-bold text-white block leading-tight">Calificaciones publicadas</span>
                              <span class="text-[9px] text-slate-400 block">Matemáticas - 2do BGU</span>
                            </div>
                          </div>
                          <span class="text-[8px] text-slate-500 shrink-0">hace 2 horas</span>
                        </div>

                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-1.5">
                            <div class="w-5 h-5 rounded-md bg-indigo-500/10 text-indigo-400 flex items-center justify-center shrink-0">
                              <User class="w-3 h-3" />
                            </div>
                            <div>
                              <span class="font-bold text-white block leading-tight">Nuevo estudiante registrado</span>
                              <span class="text-[9px] text-slate-400 block">María José Fernández</span>
                            </div>
                          </div>
                          <span class="text-[8px] text-slate-500 shrink-0">hace 5 horas</span>
                        </div>

                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-1.5">
                            <div class="w-5 h-5 rounded-md bg-emerald-500/10 text-emerald-400 flex items-center justify-center shrink-0">
                              <BarChart3 class="w-3 h-3" />
                            </div>
                            <div>
                              <span class="font-bold text-white block leading-tight">Reporte generado</span>
                              <span class="text-[9px] text-slate-400 block">Boletín Mensual - Mayo 2024</span>
                            </div>
                          </div>
                          <span class="text-[8px] text-slate-500 shrink-0">hace 1 día</span>
                        </div>

                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-1.5">
                            <div class="w-5 h-5 rounded-md bg-rose-500/10 text-rose-400 flex items-center justify-center shrink-0">
                              <ShieldAlert class="w-3 h-3" />
                            </div>
                            <div>
                              <span class="font-bold text-white block leading-tight">Alerta DECE creada</span>
                              <span class="text-[9px] text-slate-400 block">Seguimiento emocional - 3ro EGB</span>
                            </div>
                          </div>
                          <span class="text-[8px] text-slate-500 shrink-0">hace 1 día</span>
                        </div>
                      </div>
                    </div>

                    <!-- Distribución por Niveles (Donut Chart SVG Idéntico) -->
                    <div class="col-span-6 bg-[#0b0e1e] border border-slate-800/90 p-3 rounded-xl space-y-2 flex flex-col justify-between">
                      <h4 class="text-xs font-bold text-white">Distribución por Niveles</h4>

                      <div class="flex items-center gap-2.5 my-auto">
                        <!-- SVG Donut Chart exacto con 5 segmentos -->
                        <div class="w-20 h-20 shrink-0 relative">
                          <svg viewBox="0 0 36 36" class="w-full h-full transform -rotate-90">
                            <!-- Segmento 1: Inicial (15%) - Morado -->
                            <circle cx="18" cy="18" r="14" fill="none" stroke="#6366f1" stroke-width="5" stroke-dasharray="13.2 86.8" stroke-dashoffset="0" />
                            <!-- Segmento 2: Básica Elemental (25%) - Azul Real -->
                            <circle cx="18" cy="18" r="14" fill="none" stroke="#2563eb" stroke-width="5" stroke-dasharray="22.0 78.0" stroke-dashoffset="-13.2" />
                            <!-- Segmento 3: Básica Media (25%) - Celeste -->
                            <circle cx="18" cy="18" r="14" fill="none" stroke="#0284c7" stroke-width="5" stroke-dasharray="22.0 78.0" stroke-dashoffset="-35.2" />
                            <!-- Segmento 4: Básica Superior (20%) - Turquesa -->
                            <circle cx="18" cy="18" r="14" fill="none" stroke="#14b8a6" stroke-width="5" stroke-dasharray="17.6 82.4" stroke-dashoffset="-57.2" />
                            <!-- Segmento 5: Bachillerato (15%) - Naranja -->
                            <circle cx="18" cy="18" r="14" fill="none" stroke="#f97316" stroke-width="5" stroke-dasharray="13.2 86.8" stroke-dashoffset="-74.8" />
                          </svg>
                        </div>

                        <!-- Leyenda del Gráfico -->
                        <div class="space-y-1 text-[9px] flex-1">
                          <div class="flex items-center justify-between">
                            <span class="flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-[#6366f1]"></span> Inicial</span>
                            <strong class="text-white font-semibold">15%</strong>
                          </div>
                          <div class="flex items-center justify-between">
                            <span class="flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-[#2563eb]"></span> Básica Elemental</span>
                            <strong class="text-white font-semibold">25%</strong>
                          </div>
                          <div class="flex items-center justify-between">
                            <span class="flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-[#0284c7]"></span> Básica Media</span>
                            <strong class="text-white font-semibold">25%</strong>
                          </div>
                          <div class="flex items-center justify-between">
                            <span class="flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-[#14b8a6]"></span> Básica Superior</span>
                            <strong class="text-white font-semibold">20%</strong>
                          </div>
                          <div class="flex items-center justify-between">
                            <span class="flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-[#f97316]"></span> Bachillerato</span>
                            <strong class="text-white font-semibold">15%</strong>
                          </div>
                        </div>
                      </div>
                    </div>

                  </div>

                </div>
              </div>
            </div>
          </div>

        </div>

        <!-- Barra inferior de características institucionales -->
        <div class="grid grid-cols-1 sm:grid-cols-3 lg:grid-cols-5 gap-4 pt-16 border-t border-slate-800/80 mt-12">
          <div class="flex items-start gap-3 bg-slate-900/40 p-4 rounded-xl border border-slate-800/60">
            <div class="p-2.5 rounded-lg bg-indigo-500/10 text-indigo-400 shrink-0">
              <Shield class="w-5 h-5" />
            </div>
            <div>
              <strong class="text-white text-sm block font-bold">Seguro y Confiable</strong>
              <span class="text-xs text-slate-400 leading-tight block mt-0.5">Protección de datos con altos estándares de seguridad.</span>
            </div>
          </div>

          <div class="flex items-start gap-3 bg-slate-900/40 p-4 rounded-xl border border-slate-800/60">
            <div class="p-2.5 rounded-lg bg-indigo-500/10 text-indigo-400 shrink-0">
              <Users class="w-5 h-5" />
            </div>
            <div>
              <strong class="text-white text-sm block font-bold">Multiinstitución</strong>
              <span class="text-xs text-slate-400 leading-tight block mt-0.5">Gestiona múltiples instituciones desde un solo lugar.</span>
            </div>
          </div>

          <div class="flex items-start gap-3 bg-slate-900/40 p-4 rounded-xl border border-slate-800/60">
            <div class="p-2.5 rounded-lg bg-indigo-500/10 text-indigo-400 shrink-0">
              <BarChart3 class="w-5 h-5" />
            </div>
            <div>
              <strong class="text-white text-sm block font-bold">Reportes Inteligentes</strong>
              <span class="text-xs text-slate-400 leading-tight block mt-0.5">Información clara para tomar mejores decisiones.</span>
            </div>
          </div>

          <div class="flex items-start gap-3 bg-slate-900/40 p-4 rounded-xl border border-slate-800/60">
            <div class="p-2.5 rounded-lg bg-indigo-500/10 text-indigo-400 shrink-0">
              <Bell class="w-5 h-5" />
            </div>
            <div>
              <strong class="text-white text-sm block font-bold">Alertas DECE</strong>
              <span class="text-xs text-slate-400 leading-tight block mt-0.5">Identifica y da seguimiento oportuno a tus estudiantes.</span>
            </div>
          </div>

          <div class="flex items-start gap-3 bg-slate-900/40 p-4 rounded-xl border border-slate-800/60">
            <div class="p-2.5 rounded-lg bg-indigo-500/10 text-indigo-400 shrink-0">
              <Headphones class="w-5 h-5" />
            </div>
            <div>
              <strong class="text-white text-sm block font-bold">Soporte Técnico</strong>
              <span class="text-xs text-slate-400 leading-tight block mt-0.5">Acompañamiento real cuando lo necesitas.</span>
            </div>
          </div>
        </div>

      </div>
    </section>

    <!-- SECCIÓN 2: BENEFICIOS EXCLUSIVOS CON MÓDULOS REALES -->
    <section id="beneficios" class="py-20 border-b border-slate-900 bg-slate-950/50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        <div class="text-center max-w-3xl mx-auto space-y-3">
          <h2 class="text-xs font-mono font-bold uppercase tracking-widest text-indigo-400">Capacidades del Sistema</h2>
          <p class="text-3xl font-extrabold text-white tracking-tight">Diseñado para la eficiencia operativa de tu colegio</p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-3 hover:border-slate-700 transition-all">
            <div class="p-3 bg-indigo-500/10 text-indigo-400 rounded-xl w-fit">
              <Building2 class="w-6 h-6" />
            </div>
            <h3 class="font-bold text-lg text-white">Gestión Centralizada Multiinstitución</h3>
            <p class="text-slate-400 text-sm leading-relaxed">
              Administración unificada de colegios con asignación de rectores, administradores institucionales y docentes.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-3 hover:border-slate-700 transition-all">
            <div class="p-3 bg-sky-500/10 text-sky-400 rounded-xl w-fit">
              <FileText class="w-6 h-6" />
            </div>
            <h3 class="font-bold text-lg text-white">Registro de Calificaciones & Insumos</h3>
            <p class="text-slate-400 text-sm leading-relaxed">
              Formularios optimizados para el ingreso de insumos individuales, grupales, sumativos y escalas cualitativas.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-3 hover:border-slate-700 transition-all">
            <div class="p-3 bg-emerald-500/10 text-emerald-400 rounded-xl w-fit">
              <Award class="w-6 h-6" />
            </div>
            <h3 class="font-bold text-lg text-white">Boletines & Reportes PDF / Excel</h3>
            <p class="text-slate-400 text-sm leading-relaxed">
              Exportación instantánea de cuadros de honor, boletines individuales impresos y sábanas de notas formateadas.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-3 hover:border-slate-700 transition-all">
            <div class="p-3 bg-amber-500/10 text-amber-400 rounded-xl w-fit">
              <ShieldCheck class="w-6 h-6" />
            </div>
            <h3 class="font-bold text-lg text-white">Alertas DECE & Registro de Casos</h3>
            <p class="text-slate-400 text-sm leading-relaxed">
              Clasificación de incidencias académicas o conductuales con dictado por voz e integración con WhatsApp para apoderados.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-3 hover:border-slate-700 transition-all">
            <div class="p-3 bg-rose-500/10 text-rose-400 rounded-xl w-fit">
              <Lock class="w-6 h-6" />
            </div>
            <h3 class="font-bold text-lg text-white">Cierre & Candados por Trimestre</h3>
            <p class="text-slate-400 text-sm leading-relaxed">
              Bloqueo automático o manual de periodos académicos para evitar alteraciones no autorizadas en notas pasadas.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-3 hover:border-slate-700 transition-all">
            <div class="p-3 bg-teal-500/10 text-teal-400 rounded-xl w-fit">
              <Headphones class="w-6 h-6" />
            </div>
            <h3 class="font-bold text-lg text-white">Fichas de Atención a Familias</h3>
            <p class="text-slate-400 text-sm leading-relaxed">
              Directorio de atención presencial para consulta de representantes en secretaría y tutores.
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- SECCIÓN 3: PLANES & PRECIOS APROBADOS -->
    <section id="planes" class="py-20 border-b border-slate-900">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        <div class="text-center max-w-3xl mx-auto space-y-4">
          <h2 class="text-xs font-mono font-bold uppercase tracking-widest text-indigo-400">Precios Transparentes</h2>
          <p class="text-4xl font-extrabold text-white tracking-tight">Planes diseñados para cada tamaño de institución</p>
          
          <!-- TOGGLE MENSUAL / ANUAL -->
          <div class="pt-4 flex flex-wrap items-center justify-center gap-3">
            <span :class="['text-sm font-semibold', !isAnnual ? 'text-white' : 'text-slate-400']">Mensual</span>
            <button 
              type="button"
              role="switch"
              aria-label="Facturación anual"
              :aria-checked="isAnnual"
              @click="isAnnual = !isAnnual"
              class="w-14 h-8 bg-indigo-600 rounded-full p-1 transition-colors relative focus:outline-none"
            >
              <div :class="['w-6 h-6 bg-white rounded-full transition-transform shadow-md', isAnnual ? 'translate-x-6' : 'translate-x-0']"></div>
            </button>
            <span :class="['text-sm font-semibold flex flex-wrap items-center justify-center gap-2', isAnnual ? 'text-white' : 'text-slate-400']">
              Anual 
              <span class="px-2.5 py-0.5 rounded-full text-xs font-extrabold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                2 meses incluidos (Pagas 10 y usas 12)
              </span>
            </span>
          </div>
        </div>

        <!-- PRICING CARDS GRID -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8 items-stretch">
          <!-- PLAN 500 -->
          <div class="bg-slate-900/60 border border-slate-800 rounded-3xl p-8 space-y-6 flex flex-col justify-between hover:border-slate-700 transition-all">
            <div class="space-y-4">
              <h3 class="text-xl font-bold text-white">{{ plan500.name }}</h3>
              <p class="text-xs text-slate-400">Ideal para instituciones medianas en expansión.</p>
              <div class="flex items-baseline gap-1">
                <span class="text-4xl font-extrabold text-white">${{ formatNumber(displayedPrice(plan500)) }}</span>
                <span class="text-xs text-slate-400 font-medium">USD / {{ isAnnual ? 'año' : 'mes' }}</span>
              </div>
              <div class="text-xs font-semibold text-indigo-400">Hasta {{ formatNumber(plan500.maxStudents) }} estudiantes</div>

              <ul class="space-y-3 pt-4 border-t border-slate-800 text-sm text-slate-300">
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-emerald-400" /> Registro de asignaturas y cursos</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-emerald-400" /> Ingreso de calificaciones e insumos</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-emerald-400" /> Generación de sábanas y boletines</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-emerald-400" /> Alertas DECE e incidencias</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-emerald-400" /> Soporte técnico por correo y WhatsApp</li>
              </ul>
            </div>

            <a :href="DEMO_REQUEST_URL" target="_blank" rel="noopener noreferrer" class="w-full bg-slate-800 hover:bg-slate-700 text-white font-bold py-3.5 rounded-xl text-sm transition-all text-center block">
              Solicitar prueba de {{ plan500.trialDays }} días
            </a>
          </div>

          <!-- PLAN 1000 (DESTACADO) -->
          <div class="bg-slate-900 border-2 border-indigo-500 rounded-3xl p-8 space-y-6 flex flex-col justify-between shadow-2xl shadow-indigo-600/20 relative">
            <div class="absolute -top-4 left-1/2 -translate-x-1/2 bg-indigo-600 text-white text-xs font-extrabold px-4 py-1 rounded-full uppercase tracking-wider shadow-md">
              Más elegido por Rectores
            </div>

            <div class="space-y-4 pt-2">
              <h3 class="text-xl font-bold text-white">{{ plan1000.name }}</h3>
              <p class="text-xs text-slate-400">Para unidades educativas de gran capacidad.</p>
              <div class="flex items-baseline gap-1">
                <span class="text-4xl font-extrabold text-white">${{ formatNumber(displayedPrice(plan1000)) }}</span>
                <span class="text-xs text-slate-400 font-medium">USD / {{ isAnnual ? 'año' : 'mes' }}</span>
              </div>
              <div class="text-xs font-semibold text-indigo-400">Hasta {{ formatNumber(plan1000.maxStudents) }} estudiantes</div>

              <ul class="space-y-3 pt-4 border-t border-slate-800 text-sm text-slate-200">
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-indigo-400" /> Todo lo incluido en el Plan 500</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-indigo-400" /> Hasta 1.000 estudiantes activos</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-indigo-400" /> Cierre de periodo por candado</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-indigo-400" /> Atención prioritaria de incidencias</li>
              </ul>
            </div>

            <a :href="DEMO_REQUEST_URL" target="_blank" rel="noopener noreferrer" class="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-extrabold py-3.5 rounded-xl text-sm transition-all shadow-lg shadow-indigo-600/30 text-center block">
              Solicitar prueba de {{ plan1000.trialDays }} días
            </a>
          </div>

          <!-- PLAN 2000 -->
          <div class="bg-slate-900/60 border border-slate-800 rounded-3xl p-8 space-y-6 flex flex-col justify-between hover:border-slate-700 transition-all">
            <div class="space-y-4">
              <h3 class="text-xl font-bold text-white">{{ plan2000.name }}</h3>
              <p class="text-xs text-slate-400">Para complejos educativos e instituciones grandes.</p>
              <div class="flex items-baseline gap-1">
                <span class="text-4xl font-extrabold text-white">${{ formatNumber(displayedPrice(plan2000)) }}</span>
                <span class="text-xs text-slate-400 font-medium">USD / {{ isAnnual ? 'año' : 'mes' }}</span>
              </div>
              <div class="text-xs font-semibold text-indigo-400">Hasta {{ formatNumber(plan2000.maxStudents) }} estudiantes</div>

              <ul class="space-y-3 pt-4 border-t border-slate-800 text-sm text-slate-300">
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-emerald-400" /> Todo lo incluido en el Plan 1000</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-emerald-400" /> Hasta 2.000 estudiantes activos</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-emerald-400" /> Multicursos y múltiples paralelos</li>
                <li class="flex items-center gap-2.5"><Check class="w-4 h-4 text-emerald-400" /> Acompañamiento especializado</li>
              </ul>
            </div>

            <a :href="DEMO_REQUEST_URL" target="_blank" rel="noopener noreferrer" class="w-full bg-slate-800 hover:bg-slate-700 text-white font-bold py-3.5 rounded-xl text-sm transition-all text-center block">
              Solicitar prueba de {{ plan2000.trialDays }} días
            </a>
          </div>
        </div>
      </div>
    </section>

    <!-- SECCIÓN 4: IMPLEMENTACIÓN INICIAL (SEPARADA) -->
    <section id="implementacion" class="py-16 border-b border-slate-900 bg-slate-950/70">
      <div class="max-w-4xl mx-auto px-4 space-y-6 bg-slate-900/80 border border-slate-800 p-8 rounded-3xl shadow-xl">
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-slate-800 pb-6">
          <div>
            <span class="text-xs font-mono font-bold uppercase tracking-wider text-indigo-400">Servicio Único Obligatorio</span>
            <h3 class="text-2xl font-bold text-white mt-1">Implementación Inicial de la Institución</h3>
          </div>
          <div class="text-right">
            <span class="text-3xl font-extrabold text-white">USD 350</span>
            <span class="text-xs text-slate-400 block font-medium">Pago único por puesta en marcha</span>
          </div>
        </div>

        <p class="text-sm text-slate-300 leading-relaxed">
          La implementación inicial corresponde a la puesta en marcha de la institución dentro de la plataforma y comprende:
        </p>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm text-slate-300 pt-2">
          <div class="flex items-center gap-2.5"><CheckCircle2 class="w-4 h-4 text-indigo-400 shrink-0" /> Configuración inicial del entorno del colegio</div>
          <div class="flex items-center gap-2.5"><CheckCircle2 class="w-4 h-4 text-indigo-400 shrink-0" /> Creación de la institución en base de datos</div>
          <div class="flex items-center gap-2.5"><CheckCircle2 class="w-4 h-4 text-indigo-400 shrink-0" /> Configuración del Administrador Principal (Rector)</div>
          <div class="flex items-center gap-2.5"><CheckCircle2 class="w-4 h-4 text-indigo-400 shrink-0" /> Parametrización de quimestres/trimestres</div>
          <div class="flex items-center gap-2.5"><CheckCircle2 class="w-4 h-4 text-indigo-400 shrink-0" /> Orientación inicial para la directiva</div>
          <div class="flex items-center gap-2.5"><CheckCircle2 class="w-4 h-4 text-indigo-400 shrink-0" /> Acompañamiento en la primera carga de datos</div>
        </div>
      </div>
    </section>

    <!-- SECCIÓN PERSONALIZACIONES -->
    <section class="py-12 border-b border-slate-900 bg-slate-950/40">
      <div class="max-w-4xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-6 bg-slate-900/40 border border-slate-800/80 p-6 rounded-2xl">
        <div class="space-y-1">
          <h4 class="font-bold text-white text-lg">¿Necesitas desarrollos o informes a medida?</h4>
          <p class="text-xs text-slate-400">
            Personalizaciones disponibles <strong>desde USD 150</strong>. 
            <span class="text-slate-300">El precio depende del alcance y complejidad técnica del requerimiento.</span>
          </p>
        </div>
        <a href="https://wa.me/593989121871" target="_blank" rel="noopener noreferrer" class="px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs shrink-0 transition-colors flex items-center gap-2">
          <MessageSquare class="w-4 h-4 text-emerald-400" /> Cotizar requerimiento
        </a>
      </div>
    </section>

    <!-- SECCIÓN 5: TABLA COMPARATIVA SIMPLIFICADA & TRANSPARENTE -->
    <section class="py-20 border-b border-slate-900">
      <div class="max-w-5xl mx-auto px-4 space-y-12">
        <div class="text-center space-y-2">
          <h2 class="text-xs font-mono font-bold uppercase tracking-widest text-indigo-400">Comparativa Transparente</h2>
          <p class="text-3xl font-extrabold text-white">Matriz de Capacidad por Plan</p>
        </div>

        <!-- TABLA COMPACTA Y SIN RUIDO VISUAL -->
        <div class="bg-slate-900/60 border border-slate-800 rounded-3xl overflow-hidden shadow-xl">
          <div class="overflow-x-auto">
            <table class="w-full text-left text-sm">
              <thead class="bg-slate-950 text-slate-400 border-b border-slate-800 text-xs uppercase font-semibold">
                <tr>
                  <th class="px-6 py-4">Característica</th>
                  <th class="px-6 py-4 text-center">Plan 500</th>
                  <th class="px-6 py-4 text-center text-indigo-400">Plan 1000</th>
                  <th class="px-6 py-4 text-center">Plan 2000</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-800/60 text-slate-300">
                <tr>
                  <td class="px-6 py-4 font-medium text-white">Precio mensual / anual</td>
                  <td class="text-center font-semibold text-slate-200">${{ formatNumber(displayedPrice(plan500)) }}/{{ isAnnual ? 'año' : 'mes' }}</td>
                  <td class="text-center font-bold text-indigo-400">${{ formatNumber(displayedPrice(plan1000)) }}/{{ isAnnual ? 'año' : 'mes' }}</td>
                  <td class="text-center font-semibold text-slate-200">${{ formatNumber(displayedPrice(plan2000)) }}/{{ isAnnual ? 'año' : 'mes' }}</td>
                </tr>
                <tr>
                  <td class="px-6 py-4 font-medium text-white">Estudiantes incluidos</td>
                  <td class="text-center font-bold text-slate-200">Hasta 500</td>
                  <td class="text-center font-bold text-indigo-400">Hasta 1.000</td>
                  <td class="text-center font-bold text-slate-200">Hasta 2.000</td>
                </tr>
                <tr>
                  <td class="px-6 py-4 font-medium text-white">Funcionalidades académicas</td>
                  <td class="text-center font-medium text-emerald-400">Todas</td>
                  <td class="text-center font-medium text-emerald-400">Todas</td>
                  <td class="text-center font-medium text-emerald-400">Todas</td>
                </tr>
                <tr>
                  <td class="px-6 py-4 font-medium text-white">Soporte técnico</td>
                  <td class="text-center font-medium text-emerald-400">Incluido</td>
                  <td class="text-center font-medium text-emerald-400">Incluido</td>
                  <td class="text-center font-medium text-emerald-400">Incluido</td>
                </tr>
                <tr>
                  <td class="px-6 py-4 font-medium text-white">Actualizaciones de mantenimiento</td>
                  <td class="text-center font-medium text-emerald-400">Incluidas</td>
                  <td class="text-center font-medium text-emerald-400">Incluidas</td>
                  <td class="text-center font-medium text-emerald-400">Incluidas</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- SECCIÓN SEPARADA: TODOS LOS PLANES INCLUYEN -->
        <div class="space-y-6 pt-6">
          <div class="text-center space-y-1">
            <h3 class="text-xl font-bold text-white">Todos los planes incluyen acceso total</h3>
            <p class="text-xs text-slate-400">Sin restricciones artificiales de módulos ni costos ocultos por funcionalidad</p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div class="bg-slate-900/40 border border-slate-800/80 p-4 rounded-2xl flex items-start gap-3">
              <CheckCircle2 class="w-5 h-5 text-indigo-400 shrink-0 mt-0.5" />
              <div>
                <strong class="text-white text-sm block">Cursos, Paralelos y Asignaturas</strong>
                <span class="text-xs text-slate-400">Estructuración completa del año lectivo y materias.</span>
              </div>
            </div>

            <div class="bg-slate-900/40 border border-slate-800/80 p-4 rounded-2xl flex items-start gap-3">
              <CheckCircle2 class="w-5 h-5 text-indigo-400 shrink-0 mt-0.5" />
              <div>
                <strong class="text-white text-sm block">Fichas de Estudiantes & Familias</strong>
                <span class="text-xs text-slate-400">Directorio institucional de apoderados y representantes.</span>
              </div>
            </div>

            <div class="bg-slate-900/40 border border-slate-800/80 p-4 rounded-2xl flex items-start gap-3">
              <CheckCircle2 class="w-5 h-5 text-indigo-400 shrink-0 mt-0.5" />
              <div>
                <strong class="text-white text-sm block">Ingreso de Calificaciones e Insumos</strong>
                <span class="text-xs text-slate-400">Formularios rápidos para notas individuales y grupales.</span>
              </div>
            </div>

            <div class="bg-slate-900/40 border border-slate-800/80 p-4 rounded-2xl flex items-start gap-3">
              <CheckCircle2 class="w-5 h-5 text-indigo-400 shrink-0 mt-0.5" />
              <div>
                <strong class="text-white text-sm block">Boletines PDF & Sábanas Excel</strong>
                <span class="text-xs text-slate-400">Exportación directa para entrega a padres y secretaría.</span>
              </div>
            </div>

            <div class="bg-slate-900/40 border border-slate-800/80 p-4 rounded-2xl flex items-start gap-3">
              <CheckCircle2 class="w-5 h-5 text-indigo-400 shrink-0 mt-0.5" />
              <div>
                <strong class="text-white text-sm block">Alertas DECE & Dictado por Voz</strong>
                <span class="text-xs text-slate-400">Seguimiento de incidencias académicas y conductuales.</span>
              </div>
            </div>

            <div class="bg-slate-900/40 border border-slate-800/80 p-4 rounded-2xl flex items-start gap-3">
              <CheckCircle2 class="w-5 h-5 text-indigo-400 shrink-0 mt-0.5" />
              <div>
                <strong class="text-white text-sm block">Escalas Cualitativas & Candados</strong>
                <span class="text-xs text-slate-400">Calificación A-E y cierre de periodos académicos.</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- SECCIÓN 6: SEGURIDAD (SOLO CAPACIDADES AUDITADAS REALES) -->
    <section id="seguridad" class="py-20 border-b border-slate-900 bg-slate-950/70">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        <div class="text-center max-w-3xl mx-auto space-y-3">
          <h2 class="text-xs font-mono font-bold uppercase tracking-widest text-indigo-400">Infraestructura Verificada</h2>
          <p class="text-3xl font-extrabold text-white">Seguridad diseñada desde la arquitectura</p>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <div class="bg-slate-900/60 border border-slate-800 p-6 rounded-2xl space-y-3">
            <Lock class="w-6 h-6 text-indigo-400" />
            <h3 class="font-bold text-white text-base">Aislamiento Multi-Tenant (RLS)</h3>
            <p class="text-xs text-slate-400 leading-relaxed">
              Políticas de Row Level Security (RLS) en PostgreSQL que impiden técnicamente el acceso o lectura de datos entre distintas instituciones.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800 p-6 rounded-2xl space-y-3">
            <ShieldCheck class="w-6 h-6 text-emerald-400" />
            <h3 class="font-bold text-white text-base">Autenticación con JWT</h3>
            <p class="text-xs text-slate-400 leading-relaxed">
              Control de sesiones mediante JSON Web Tokens firmados y expiración automática de credenciales a través de Supabase Auth.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800 p-6 rounded-2xl space-y-3">
            <Zap class="w-6 h-6 text-sky-400" />
            <h3 class="font-bold text-white text-base">Comunicación Cifrada HTTPS/TLS</h3>
            <p class="text-xs text-slate-400 leading-relaxed">
              Transferencia de datos cifrada de extremo a extremo mediante protocolos TLS 1.3 de alta disponibilidad.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800 p-6 rounded-2xl space-y-3">
            <FileText class="w-6 h-6 text-amber-400" />
            <h3 class="font-bold text-white text-base">Trazabilidad & Logs de Auditoría</h3>
            <p class="text-xs text-slate-400 leading-relaxed">
              Registro inmutable de modificaciones en calificaciones e inicios de sesiones de soporte técnico.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800 p-6 rounded-2xl space-y-3">
            <RefreshCw class="w-6 h-6 text-teal-400" />
            <h3 class="font-bold text-white text-base">Respaldos Automáticos de Datos</h3>
            <p class="text-xs text-slate-400 leading-relaxed">
              Copias de seguridad periódicas de la base de datos PostgreSQL para salvaguardar la información académica.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800 p-6 rounded-2xl space-y-3">
            <Building2 class="w-6 h-6 text-rose-400" />
            <h3 class="font-bold text-white text-base">Protección de Datos Institucionales</h3>
            <p class="text-xs text-slate-400 leading-relaxed">
              Protección de datos personales de docentes y estudiantes conforme a estándares de confidencialidad.
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- SECCIÓN 7: SOPORTE TÉCNICO -->
    <section id="soporte" class="py-20 border-b border-slate-900">
      <div class="max-w-5xl mx-auto px-4 space-y-10">
        <div class="text-center space-y-3">
          <h2 class="text-xs font-mono font-bold uppercase tracking-widest text-indigo-400">Atención Garantizada</h2>
          <p class="text-3xl font-extrabold text-white">Soporte Técnico Institucional</p>
          <p class="text-sm text-slate-400 max-w-2xl mx-auto">Soporte técnico para incidencias relacionadas con el funcionamiento normal de la plataforma.</p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- INCLUIDO -->
          <div class="bg-slate-900/60 border border-emerald-900/50 p-6 rounded-2xl space-y-4">
            <h3 class="font-bold text-emerald-400 text-base flex items-center gap-2">
              <CheckCircle2 class="w-5 h-5" /> Incluido en la Suscripción
            </h3>
            <ul class="space-y-2.5 text-xs text-slate-300">
              <li class="flex items-center gap-2">• Soporte funcional sobre uso de la plataforma</li>
              <li class="flex items-center gap-2">• Asistencia en recuperación de accesos</li>
              <li class="flex items-center gap-2">• Corrección de incidencias o errores de sistema</li>
              <li class="flex items-center gap-2">• Actualizaciones de mantenimiento correctivo</li>
              <li class="flex items-center gap-2">• Consultas básicas de administración para el Rector</li>
            </ul>
          </div>

          <!-- NO INCLUIDO -->
          <div class="bg-slate-900/60 border border-slate-800 p-6 rounded-2xl space-y-4">
            <h3 class="font-bold text-slate-400 text-base flex items-center gap-2">
              <X class="w-5 h-5 text-slate-500" /> Cotizado por Separado
            </h3>
            <ul class="space-y-2.5 text-xs text-slate-400">
              <li class="flex items-center gap-2">• Desarrollo de funciones personalizadas adicionales</li>
              <li class="flex items-center gap-2">• Migraciones masivas complejas de archivos históricos</li>
              <li class="flex items-center gap-2">• Capacitación presencial repetitiva a personal nuevo</li>
              <li class="flex items-center gap-2">• Integraciones especiales con sistemas de terceros</li>
            </ul>
          </div>
        </div>

        <!-- CANALES REALES -->
        <div class="flex flex-col sm:flex-row items-center justify-center gap-6 pt-4 text-sm text-slate-300">
          <a href="https://wa.me/593989121871" target="_blank" rel="noopener noreferrer" class="flex items-center gap-2 bg-slate-900 hover:bg-slate-850 px-5 py-3 rounded-xl border border-slate-800 transition-colors">
            <MessageSquare class="w-4.5 h-4.5 text-emerald-400" /> <span class="font-semibold text-white">WhatsApp Soporte:</span> +593 98 912 1871
          </a>
          <a href="mailto:tecnologia@adyronweb.com" class="flex items-center gap-2 bg-slate-900 hover:bg-slate-850 px-5 py-3 rounded-xl border border-slate-800 transition-colors">
            <Mail class="w-4.5 h-4.5 text-indigo-400" /> <span class="font-semibold text-white">Correo Oficial:</span> tecnologia@adyronweb.com
          </a>
        </div>
      </div>
    </section>

    <!-- SECCIÓN 8: MANTENIMIENTO Y ACTUALIZACIONES -->
    <section class="py-12 border-b border-slate-900 bg-slate-950/40">
      <div class="max-w-4xl mx-auto px-4 text-center space-y-2">
        <h4 class="font-bold text-white text-base">Mantenimiento Evolutivo Incluido</h4>
        <p class="text-xs text-slate-400 leading-relaxed max-w-2xl mx-auto">
          La suscripción incluye mantenimiento evolutivo general y actualizaciones correctivas de la plataforma para asegurar su óptimo funcionamiento.
        </p>
      </div>
    </section>

    <!-- SECCIÓN 9: PROCESO DE CONTRATACIÓN DE 5 PASOS -->
    <section class="py-20 border-b border-slate-900">
      <div class="max-w-6xl mx-auto px-4 space-y-12">
        <div class="text-center space-y-2">
          <h2 class="text-xs font-mono font-bold uppercase tracking-widest text-indigo-400">Puesta en Marcha</h2>
          <p class="text-3xl font-extrabold text-white">Proceso de Contratación en 5 Pasos</p>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-5 gap-4">
          <div class="bg-slate-900/60 border border-slate-800 p-5 rounded-2xl space-y-2 relative">
            <span class="text-xs font-mono font-bold text-indigo-400">01</span>
            <h4 class="font-bold text-white text-sm">Selecciona un Plan</h4>
            <p class="text-xs text-slate-400">Elige el plan según tu número de estudiantes.</p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800 p-5 rounded-2xl space-y-2 relative">
            <span class="text-xs font-mono font-bold text-indigo-400">02</span>
            <h4 class="font-bold text-white text-sm">Registra la Institución</h4>
            <p class="text-xs text-slate-400">Ingresa los datos institucionales y de la directiva.</p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800 p-5 rounded-2xl space-y-2 relative">
            <span class="text-xs font-mono font-bold text-indigo-400">03</span>
            <h4 class="font-bold text-white text-sm">Configuramos la Cuenta</h4>
            <p class="text-xs text-slate-400">Ejecutamos la implementación y alta de la escuela.</p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800 p-5 rounded-2xl space-y-2 relative">
            <span class="text-xs font-mono font-bold text-indigo-400">04</span>
            <h4 class="font-bold text-white text-sm">Inicia la Prueba</h4>
            <p class="text-xs text-slate-400">Prueba la plataforma durante 15 días.</p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800 p-5 rounded-2xl space-y-2 relative">
            <span class="text-xs font-mono font-bold text-indigo-400">05</span>
            <h4 class="font-bold text-white text-sm">Activa la Suscripción</h4>
            <p class="text-xs text-slate-400">Continúa operando mediante transferencia o tarjeta.</p>
          </div>
        </div>
      </div>
    </section>

    <!-- SECCIÓN 10: MÉTODOS DE PAGO Y KUSHKI -->
    <section class="py-16 border-b border-slate-900 bg-slate-950/60">
      <div class="max-w-4xl mx-auto px-4 text-center space-y-6">
        <h3 class="text-xl font-bold text-white">Métodos de Pago Aceptados</h3>

        <div class="flex flex-col sm:flex-row items-center justify-center gap-6 text-sm text-slate-300">
          <div class="flex items-center gap-3 bg-slate-900 border border-slate-800 px-6 py-4 rounded-2xl">
            <Building2 class="w-6 h-6 text-indigo-400" />
            <div class="text-left">
              <strong class="block text-white">Transferencia Bancaria</strong>
              <span class="text-xs text-slate-400">Habilitada para instituciones públicas y privadas</span>
            </div>
          </div>

          <div class="flex items-center gap-3 bg-slate-900 border border-slate-800 px-6 py-4 rounded-2xl">
            <CreditCard class="w-6 h-6 text-sky-400" />
            <div class="text-left">
              <strong class="block text-white">Tarjetas de Crédito / Débito</strong>
              <span class="text-xs text-slate-400">Pago con tarjeta próximamente mediante Kushki</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- SECCIÓN 11: PREGUNTAS FRECUENTES (FAQ REALES) -->
    <section id="faq" class="py-20 border-b border-slate-900">
      <div class="max-w-4xl mx-auto px-4 space-y-10">
        <div class="text-center space-y-2">
          <h2 class="text-xs font-mono font-bold uppercase tracking-widest text-indigo-400">Respuestas Rápidas</h2>
          <p class="text-3xl font-extrabold text-white">Preguntas Frecuentes</p>
        </div>

        <div class="space-y-4">
          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-2">
            <h4 class="font-bold text-white text-base">¿Existe un costo de implementación inicial?</h4>
            <p class="text-sm text-slate-400 leading-relaxed">
              Sí. Corresponde a USD 350 por única vez e incluye el alta institucional en base de datos, la configuración del Rector/Administrador principal y la orientación inicial.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-2">
            <h4 class="font-bold text-white text-base">¿Puedo pagar de manera anual?</h4>
            <p class="text-sm text-slate-400 leading-relaxed">
              Sí. El pago anual equivale a pagar 10 mensualidades y habilita 12 meses de servicio activo (2 meses incluidos).
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-2">
            <h4 class="font-bold text-white text-base">¿Existe período de prueba gratuita?</h4>
            <p class="text-sm text-slate-400 leading-relaxed">
              Sí. Ofrecemos 15 días de prueba para que la directiva y docentes evalúen las funcionalidades de la plataforma.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-2">
            <h4 class="font-bold text-white text-base">¿Qué ocurre si la institución supera el límite de estudiantes?</h4>
            <p class="text-sm text-slate-400 leading-relaxed">
              Se debe solicitar el cambio al siguiente plan superior (ejemplo: de Plan 500 a Plan 1000) ajustando la diferencia correspondiente.
            </p>
          </div>

          <div class="bg-slate-900/60 border border-slate-800/80 p-6 rounded-2xl space-y-2">
            <h4 class="font-bold text-white text-base">¿Qué ocurre si una institución suspende su pago?</h4>
            <p class="text-sm text-slate-400 leading-relaxed">
              No se elimina ninguna información (estudiantes, notas ni documentos se borran). Únicamente se suspende el acceso al sistema hasta regularizar el estado de la suscripción.
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- SECCIÓN 12: CTA FINAL -->
    <section class="py-20 bg-gradient-to-b from-slate-950 via-indigo-950/40 to-slate-950">
      <div class="max-w-4xl mx-auto px-4 text-center space-y-6">
        <h2 class="text-3xl sm:text-4xl font-extrabold text-white tracking-tight">
          Moderniza la gestión de tu institución educativa
        </h2>
        <p class="text-slate-300 text-base max-w-xl mx-auto">
          Comienza hoy tu prueba de 15 días o contáctanos para asesorar a tu directiva.
        </p>

        <div class="pt-2 flex flex-col sm:flex-row items-center justify-center gap-4">
          <a :href="DEMO_REQUEST_URL" target="_blank" rel="noopener noreferrer" class="w-full sm:w-auto bg-indigo-600 hover:bg-indigo-500 text-white px-8 py-4 rounded-2xl font-extrabold text-base shadow-xl shadow-indigo-600/30 transition-all flex items-center justify-center gap-3">
            Solicitar prueba de 15 días <ArrowRight class="w-5 h-5" />
          </a>
          <a href="https://wa.me/593989121871" target="_blank" rel="noopener noreferrer" class="w-full sm:w-auto bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-200 px-8 py-4 rounded-2xl font-bold text-base transition-all flex items-center justify-center gap-2">
            <MessageSquare class="w-5 h-5 text-emerald-400" /> Hablar por WhatsApp (+593 98 912 1871)
          </a>
        </div>
      </div>
    </section>

    <!-- FOOTER PÚBLICO -->
    <footer class="bg-slate-950 border-t border-slate-900 py-12 text-xs text-slate-500">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col md:flex-row items-center justify-between gap-6">
        <div class="flex items-center gap-2">
          <BrandLogo variant="mark" tone="light" decorative class="h-5 w-5" />
          <span class="font-bold text-slate-300 text-sm">LOGREVA</span>
          <span>© 2026 LOGREVA por Adyron S.A.S. Todos los derechos reservados.</span>
        </div>

        <div class="flex flex-wrap items-center gap-6">
          <a href="#planes" class="hover:text-slate-300">Planes</a>
          <a href="#seguridad" class="hover:text-slate-300">Seguridad</a>
          <a href="#soporte" class="hover:text-slate-300">Soporte</a>
          <router-link to="/terminos" class="hover:text-slate-300">Términos de Servicio</router-link>
          <router-link to="/privacidad" class="hover:text-slate-300">Política de Privacidad</router-link>
        </div>
      </div>
    </footer>
  </div>
</template>
