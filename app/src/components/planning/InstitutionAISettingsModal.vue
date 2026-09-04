<script setup>
import { onMounted } from 'vue'
import { 
  X, 
  Settings, 
  KeyRound, 
  ShieldCheck, 
  Activity, 
  CheckCircle2, 
  AlertTriangle, 
  Zap, 
  RefreshCw, 
  Save,
  Loader2,
  Lock
} from 'lucide-vue-next'
import { useInstitutionAISettings } from '../../composables/useInstitutionAISettings'

const props = defineProps({
  onClose: {
    type: Function,
    required: true
  }
})

const {
  loading,
  saving,
  testing,
  testResult,
  settings,
  usageStats,
  fetchSettings,
  testConnection,
  saveSettings
} = useInstitutionAISettings()

const onProviderChange = () => {
  if (settings.value.provider === 'openai') {
    settings.value.model_id = 'gpt-5.6-luna'
  } else if (settings.value.provider === 'gemini') {
    settings.value.model_id = 'gemini-2.5-flash'
  } else {
    settings.value.model_id = 'demo-pedagogico-ec'
  }
}

onMounted(() => {
  fetchSettings()
})
</script>

<template>
  <div class="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-3 sm:p-5 overflow-y-auto">
    <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl shadow-2xl w-full max-w-3xl max-h-[92vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
      
      <!-- Header -->
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-900/80">
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-2xl bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-500/20">
            <Settings class="w-6 h-6" />
          </div>
          <div>
            <h2 class="text-base font-bold text-slate-900 dark:text-white">Configuración Institucional de Inteligencia Artificial</h2>
            <p class="text-xs text-slate-500 dark:text-slate-400">Control de proveedores, modelos de Gemini, cuotas de consumo y seguridad</p>
          </div>
        </div>

        <button
          @click="onClose"
          type="button"
          class="p-2 rounded-xl text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <!-- Settings Body -->
      <div class="p-6 overflow-y-auto flex-1 custom-scrollbar space-y-6">
        
        <!-- Estado de Consumo y Cuota Mensual -->
        <div class="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-950/50 space-y-3">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <Activity class="w-4 h-4 text-indigo-500" />
              <span class="text-xs font-bold text-slate-900 dark:text-white">Consumo Mensual de Generaciones</span>
            </div>
            <span class="text-xs font-mono font-bold text-slate-700 dark:text-slate-300">
              {{ usageStats.monthly_usage }} / {{ usageStats.monthly_quota }} ({{ usageStats.usage_percentage }}%)
            </span>
          </div>

          <!-- Progress bar with alert markers at 70%, 90%, 100% -->
          <div class="w-full bg-slate-200 dark:bg-slate-800 h-2.5 rounded-full overflow-hidden relative">
            <div
              :class="[
                'h-full transition-all duration-500 rounded-full',
                usageStats.usage_percentage >= 90 ? 'bg-rose-500' : usageStats.usage_percentage >= 70 ? 'bg-amber-500' : 'bg-teal-500'
              ]"
              :style="{ width: `${usageStats.usage_percentage}%` }"
            ></div>
          </div>
          <div class="flex justify-between text-[10px] text-slate-400 font-mono">
            <span>0%</span>
            <span class="text-amber-500">70% Alerta</span>
            <span class="text-rose-500">90% Límite</span>
            <span>100%</span>
          </div>
        </div>

        <!-- Modo de Operación -->
        <div>
          <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-2">Modo de Operación de IA</label>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <button
              v-for="m in [
                { id: 'managed', title: 'Administrado por Plataforma', desc: 'Control centralizado, óptimo y seguro.', tag: 'Predeterminado' },
                { id: 'byok', title: 'Clave Propia (BYOK)', desc: 'Conecta tu propia API Key de Google Gemini.', tag: 'Avanzado' },
                { id: 'demo', title: 'Modo Demostración', desc: 'Respuestas pedagógicas simuladas deterministas.', tag: 'Sin costo' }
              ]"
              :key="m.id"
              @click="settings.mode = m.id"
              type="button"
              :class="[
                'p-3.5 rounded-2xl border text-left transition-all text-xs flex flex-col justify-between',
                settings.mode === m.id
                  ? 'border-indigo-500 bg-indigo-50/60 dark:bg-indigo-500/10 text-slate-900 dark:text-white ring-2 ring-indigo-500'
                  : 'border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/40 text-slate-700 dark:text-slate-300'
              ]"
            >
              <div>
                <div class="flex items-center justify-between">
                  <strong class="font-bold">{{ m.title }}</strong>
                  <span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-slate-200 dark:bg-slate-800 text-slate-600 dark:text-slate-400">{{ m.tag }}</span>
                </div>
                <p class="text-[11px] text-slate-400 mt-1 leading-tight">{{ m.desc }}</p>
              </div>
            </button>
          </div>
        </div>

        <!-- Configuración de Proveedor y Modelo -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Proveedor de IA</label>
            <select
              v-model="settings.provider"
              @change="onProviderChange"
              class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
            >
              <option value="gemini">Google Gemini (Recomendado)</option>
              <option value="openai">OpenAI (ChatGPT / Luna)</option>
              <option value="demo">Motor Pedagógico Demo (Ecuador)</option>
            </select>
          </div>

          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Modelo de Generación</label>
            <select
              v-model="settings.model_id"
              class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
            >
              <!-- Modelos Gemini -->
              <template v-if="settings.provider === 'gemini'">
                <option value="auto">Automático — recomendado</option>
                <option value="gemini-3.7-flash">Alta calidad — Gemini 3.7 Flash</option>
                <option value="gemini-2.5-flash">Equilibrado — Gemini 2.5 Flash</option>
                <option value="gemini-2.5-flash-lite">Económico — Gemini 2.5 Flash-Lite</option>
                <option value="gemini-2.5-pro">Revisión avanzada — Gemini 2.5 Pro</option>
              </template>

              <!-- Modelos OpenAI -->
              <template v-else-if="settings.provider === 'openai'">
                <option value="auto">Automático — recomendado</option>
                <option value="gpt-5.6-luna">Económico — gpt-5.6-luna</option>
                <option value="gpt-4o-mini">Equilibrado — gpt-4o-mini</option>
                <option value="gpt-4o">Alta calidad — gpt-4o</option>
              </template>

              <!-- Modelo Demo -->
              <template v-else>
                <option value="demo-pedagogico-ec">Motor Demo Educativo Ecuador (Simulado)</option>
              </template>
            </select>
          </div>
        </div>

        <!-- Campo de Clave API (BYOK) -->
        <div v-if="settings.mode === 'byok'" class="space-y-3 p-4 rounded-2xl border border-indigo-500/20 bg-indigo-50/20 dark:bg-indigo-950/20">
          <div class="flex items-center justify-between">
            <label class="text-xs font-bold text-slate-900 dark:text-white flex items-center gap-1.5">
              <KeyRound class="w-4 h-4 text-indigo-500" />
              {{ settings.provider === 'openai' ? 'Clave de OpenAI API (BYOK)' : 'Clave de Google Gemini API (BYOK)' }}
            </label>
            <span v-if="settings.hasExistingKey" class="text-[10px] text-emerald-600 dark:text-emerald-400 font-bold flex items-center gap-1">
              <Lock class="w-3 h-3" /> Clave configurada y encriptada
            </span>
          </div>

          <div class="flex gap-2">
            <input
              v-model="settings.apiKey"
              type="password"
              :placeholder="settings.provider === 'openai' ? 'Ingresa tu clave sk-... de OpenAI' : 'Ingresa tu clave AIzaSy... de Google Gemini'"
              class="flex-1 bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3.5 py-2 text-xs text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
            />
            <button
              @click="testConnection(settings.apiKey)"
              :disabled="testing || (!settings.apiKey && !settings.hasExistingKey)"
              type="button"
              class="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-white text-xs font-semibold transition-colors disabled:opacity-50"
            >
              <Loader2 v-if="testing" class="w-3.5 h-3.5 animate-spin" />
              <Zap v-else class="w-3.5 h-3.5 text-amber-400" />
              Probar Conexión
            </button>
          </div>
        </div>

        <!-- Límites y Cuotas -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Cuota Mensual Institucional</label>
            <input
              v-model.number="settings.monthly_quota_generations"
              type="number"
              min="10"
              max="5000"
              class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white"
            />
          </div>

          <div>
            <label class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Límite Diario por Docente</label>
            <input
              v-model.number="settings.teacher_daily_limit"
              type="number"
              min="1"
              max="100"
              class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white"
            />
          </div>
        </div>

        <!-- Seguridad y Políticas -->
        <div class="p-3.5 rounded-2xl bg-slate-100 dark:bg-slate-800/60 text-xs text-slate-600 dark:text-slate-300 space-y-1">
          <div class="flex items-center gap-2 font-bold text-slate-800 dark:text-slate-100">
            <ShieldCheck class="w-4 h-4 text-teal-500" />
            Políticas de Seguridad y Privacidad
          </div>
          <p class="text-[11px] leading-relaxed">
            Las credenciales se cifran en reposo. Nunca se exponen en cliente ni se transmiten nombres o expedientes de estudiantes en los payloads de IA.
          </p>
        </div>

      </div>

      <!-- Footer -->
      <div class="px-6 py-4 border-t border-slate-200 dark:border-slate-800 flex items-center justify-end gap-3 bg-slate-50 dark:bg-slate-900/80">
        <button
          @click="onClose"
          type="button"
          class="px-4 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          Cerrar
        </button>

        <button
          @click="saveSettings"
          :disabled="saving"
          type="button"
          class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-lg shadow-indigo-600/20 transition-all cursor-pointer disabled:opacity-50"
        >
          <Loader2 v-if="saving" class="w-4 h-4 animate-spin" />
          <Save v-else class="w-4 h-4" />
          <span>{{ saving ? 'Guardando...' : 'Guardar Configuración' }}</span>
        </button>
      </div>

    </div>
  </div>
</template>
