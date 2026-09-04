<script setup>
import { Sparkles, ShieldAlert, CreditCard, Lock, CheckCircle2, ArrowRight } from 'lucide-vue-next'

const props = defineProps({
  reason: {
    type: String,
    default: 'inactive' // 'inactive' | 'limit_reached'
  },
  monthlyQuota: {
    type: Number,
    default: 200
  },
  monthlyUsage: {
    type: Number,
    default: 0
  }
})

const emit = defineEmits(['open-settings'])
</script>

<template>
  <div class="rounded-3xl border border-indigo-500/20 bg-gradient-to-br from-slate-900 via-indigo-950/40 to-slate-900 p-8 text-white shadow-2xl relative overflow-hidden">
    <!-- Decorative background glow -->
    <div class="absolute -right-20 -top-20 w-80 h-80 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none"></div>
    <div class="absolute -left-20 -bottom-20 w-80 h-80 bg-teal-500/10 rounded-full blur-3xl pointer-events-none"></div>

    <div class="relative z-10 max-w-3xl mx-auto text-center space-y-6">
      <div class="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full text-xs font-bold bg-indigo-500/20 text-indigo-300 border border-indigo-500/30">
        <Sparkles class="w-4 h-4 text-indigo-400" />
        Módulo Premium: Planificación Educativa con IA (Ecuador)
      </div>

      <h2 class="text-3xl font-extrabold text-white tracking-tight">
        {{ reason === 'limit_reached' ? 'Límite Mensual de Generaciones Alcanzado' : 'Módulo de Planificación IA no Activo' }}
      </h2>

      <p class="text-slate-300 text-sm md:text-base leading-relaxed">
        {{ reason === 'limit_reached'
          ? `Tu institución ha consumido ${monthlyUsage} de ${monthlyQuota} generaciones este mes. Puedes solicitar una ampliación de cuota o conectar una clave propia de Gemini.`
          : 'Este módulo requiere que el Superadministrador de la plataforma active la suscripción tras el registro y verificación del pago correspondiente.'
        }}
      </p>

      <!-- Feature Highlights -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 pt-4 text-left">
        <div class="p-4 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-sm">
          <CheckCircle2 class="w-5 h-5 text-teal-400 mb-2" />
          <h4 class="text-xs font-bold text-white">Currículo Nacional Ecuador</h4>
          <p class="text-[11px] text-slate-400 mt-1">DCDs oficiales, criterios de evaluación, indicadores y taxonomía de Bloom.</p>
        </div>
        <div class="p-4 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-sm">
          <CheckCircle2 class="w-5 h-5 text-indigo-400 mb-2" />
          <h4 class="text-xs font-bold text-white">Metodología ERCA & DUA</h4>
          <p class="text-[11px] text-slate-400 mt-1">Secuencia en 4 fases, adaptaciones de acceso y 17 tipos de recursos de aula.</p>
        </div>
        <div class="p-4 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-sm">
          <CheckCircle2 class="w-5 h-5 text-cyan-400 mb-2" />
          <h4 class="text-xs font-bold text-white">Seguimiento Estudiantil</h4>
          <p class="text-[11px] text-slate-400 mt-1">Recuperación pedagógica y planes de refuerzo 100% anonimizados.</p>
        </div>
      </div>

      <div class="pt-4 flex flex-wrap items-center justify-center gap-3">
        <button
          @click="emit('open-settings')"
          type="button"
          class="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white text-xs font-bold shadow-lg shadow-indigo-900/30 transition-all cursor-pointer"
        >
          <CreditCard class="w-4 h-4" />
          Ver Estado de Suscripción / Configurar IA
          <ArrowRight class="w-4 h-4" />
        </button>
      </div>
    </div>
  </div>
</template>
