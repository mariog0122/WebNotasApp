<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { supabase } from '../lib/supabase'
import { translateError } from '../lib/errorDictionary'
import { toast } from 'vue-sonner'
import BrandLogo from '../components/ui/BrandLogo.vue'
import GalaxyBackground from '../components/ui/GalaxyBackground.vue'
import { DEMO_REQUEST_URL } from '../lib/brand'
import { APP_URL } from '../lib/appUrl'
import { getMfaStatus, isAal2Required, challengeAndVerifyLogin } from '../lib/mfa'
import { Activity, ArrowRight, BookOpenCheck, Brain, Building2, ChartColumn, ClipboardCheck, Eye, EyeOff, GraduationCap, KeyRound, LockKeyhole, Mail, Network, ShieldCheck } from 'lucide-vue-next'

const email = ref('')
const password = ref('')
const loading = ref(false)
const showPassword = ref(false)
const router = useRouter()
const authStore = useAuthStore()

let authStateSubscription = null

const isRecovering = ref(false)
const isUpdatingPassword = ref(false)
const recoverEmail = ref('')
const recoverLoading = ref(false)
const newPassword = ref('')
const updateLoading = ref(false)

const toggleRecover = () => {
    isRecovering.value = true
    recoverEmail.value = email.value
}
const cancelRecover = () => {
    isRecovering.value = false
}

const handleRecoverPassword = async () => {
  if (!recoverEmail.value) return
  recoverLoading.value = true
  try {
    const { error } = await supabase.auth.resetPasswordForEmail(recoverEmail.value, {
      redirectTo: `${APP_URL}/reset-password`,
    })
    if (error) throw error
    toast.success('Correo enviado', { description: 'Revisa tu bandeja de entrada o spam para restablecer tu contraseña.' })
    isRecovering.value = false
  } catch (error) {
    toast.error('Error al enviar correo', { description: translateError(error) })
  } finally {
    recoverLoading.value = false
  }
}

const handleUpdatePassword = async () => {
  if (!newPassword.value || newPassword.value.length < 6) {
    toast.warning('Contraseña muy corta', { description: 'Debe tener al menos 6 caracteres.' })
    return
  }
  updateLoading.value = true
  try {
    const { error } = await supabase.auth.updateUser({ password: newPassword.value })
    if (error) throw error
    toast.success('Contraseña actualizada', { description: 'Tu contraseña ha sido cambiada exitosamente.' })
    isUpdatingPassword.value = false
    await supabase.auth.signOut()
    router.push('/login')
  } catch (error) {
    toast.error('Error al actualizar', { description: translateError(error) })
  } finally {
    updateLoading.value = false
  }
}

const isMfaChallenged = ref(false)
const mfaCode = ref('')
const mfaLoading = ref(false)
const mfaFactorId = ref(null)

const handleLogin = async () => {
  loading.value = true
  try {
    await authStore.signIn(email.value, password.value)

    // Comprobar si la cuenta tiene 2FA activo que requiere verificación
    if (await isAal2Required()) {
      const status = await getMfaStatus()
      mfaFactorId.value = status.verifiedFactors?.[0]?.id || null
      isMfaChallenged.value = true
      return
    }

    router.push('/')
  } catch (error) {
    toast.error('Error de Inicio de Sesión', {
      description: translateError(error)
    })
  } finally {
    loading.value = false
  }
}

const handleVerifyMfa = async () => {
  const code = mfaCode.value.trim().replace(/\s+/g, '')
  if (!code || code.length !== 6) {
    toast.warning('Código incompleto', { description: 'Ingresa los 6 dígitos numéricos de tu autenticador.' })
    return
  }

  mfaLoading.value = true
  try {
    await challengeAndVerifyLogin({ factorId: mfaFactorId.value, code })
    toast.success('Acceso verificado', { description: 'Bienvenido a LOGREVA.' })
    isMfaChallenged.value = false
    router.push('/')
  } catch (error) {
    toast.error('Código 2FA incorrecto o expirado', {
      description: translateError(error) || 'Verifica la hora de tu dispositivo e intenta con un código nuevo.'
    })
  } finally {
    mfaLoading.value = false
  }
}

const cancelMfa = async () => {
  isMfaChallenged.value = false
  mfaCode.value = ''
  mfaFactorId.value = null
  try {
    await authStore.signOut()
  } catch (err) {
    console.error('Error al cancelar 2FA:', err)
  }
}

onMounted(() => {
  // Detect password recovery link
  const { data } = supabase.auth.onAuthStateChange((event) => {
    if (event === 'PASSWORD_RECOVERY') {
      isUpdatingPassword.value = true
    }
  })
  authStateSubscription = data.subscription

  // Fallback for query param detection
  if (
    window.location.pathname === '/reset-password'
    || window.location.pathname === '/change-password'
    || window.location.hash.includes('type=recovery')
    || window.location.search.includes('type=recovery')
  ) {
    isUpdatingPassword.value = true
  }

  // Si llega con sesión parcial AAL1 que requiere AAL2
  isAal2Required().then((required) => {
    if (required) {
      getMfaStatus().then((status) => {
        mfaFactorId.value = status.verifiedFactors?.[0]?.id || null
        isMfaChallenged.value = true
      }).catch(() => {})
    }
  }).catch(() => {})
})

onUnmounted(() => {
  authStateSubscription?.unsubscribe()
  authStateSubscription = null
})
</script>

<template>
  <main class="login-shell">
    <section
      data-testid="login-brand-panel"
      class="login-brand-panel hidden lg:flex"
      aria-label="Presentación de LOGREVA"
    >
      <GalaxyBackground />

      <div class="brand-content">
        <BrandLogo variant="horizontal" tone="light" class="brand-lockup" />

        <div class="brand-message">
          <div class="brand-tag">
            <span class="brand-tag__bar" aria-hidden="true"></span>
            <p class="brand-tag__text">
              Inteligencia del aprendizaje y gestión
              <span class="brand-tag__year">2026</span>
            </p>
          </div>
          <p class="brand-eyebrow">PLATAFORMA INSTITUCIONAL</p>
          <h1>
            Gestión Académica
            <span>Centralizada</span>
          </h1>
          <p class="brand-promise">Donde cada institución logra su excelencia académica.</p>

          <ul class="brand-benefits" aria-label="Beneficios principales">
            <li><span><BookOpenCheck aria-hidden="true" /></span>Planificación didáctica con IA (Normativa MINEDEC)</li>
            <li><span><Activity aria-hidden="true" /></span>Control académico en tiempo real</li>
            <li><span><ClipboardCheck aria-hidden="true" /></span>Trazabilidad lista para auditoría</li>
            <li><span><ChartColumn aria-hidden="true" /></span>Reportes claros para decidir mejor</li>
            <li class="brand-benefits__advanced"><span><Network aria-hidden="true" /></span>Diagnóstico causal de brechas &amp; Grafo competencial</li>
            <li class="brand-benefits__advanced"><span><GraduationCap aria-hidden="true" /></span>Tutor Socrático con andamiaje y Teacher Cockpit en 15 min</li>
          </ul>

          <!-- Live Pedagogical Intelligence Preview Pill -->
          <div class="mt-5 p-3.5 rounded-2xl bg-slate-900/60 border border-slate-700/60 backdrop-blur-md flex items-center justify-between gap-3 text-xs shadow-lg">
            <div class="flex items-center gap-3">
              <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-indigo-500/20 to-cyan-500/20 border border-cyan-400/30 flex items-center justify-center text-cyan-300 shrink-0">
                <Brain class="w-4 h-4" />
              </div>
              <div>
                <span class="font-bold text-white block">Innovación Educativa Comprobada</span>
                <span class="text-slate-300 text-[11px]">Recuperación de aprendizajes en aula & Pasaporte Familiar</span>
              </div>
            </div>
            <span class="px-2.5 py-1 rounded-full bg-emerald-500/20 text-emerald-300 font-extrabold text-[10px] border border-emerald-500/30 shrink-0">
              ACTIVO
            </span>
          </div>
        </div>

        <div class="secure-card">
          <div class="secure-card__icon"><ShieldCheck aria-hidden="true" /></div>
          <div>
            <p class="secure-card__title">Acceso Seguro</p>
            <p>Autenticación protegida con Supabase Auth y sesiones JWT.</p>
          </div>
          <span class="secure-card__status">PROTEGIDO</span>
        </div>
      </div>
    </section>

    <section class="login-access-panel">
      <div class="access-decoration access-decoration--top" aria-hidden="true"></div>
      <div class="access-decoration access-decoration--bottom" aria-hidden="true"></div>

      <div class="login-access-wrap">
        <div class="mobile-brand lg:hidden">
          <BrandLogo variant="horizontal" class="text-xl" />
        </div>

        <div data-testid="login-card" class="login-card">
          <div class="login-card__accent" aria-hidden="true"></div>
          <div class="login-card__header">
            <div class="login-card__shield">
              <ShieldCheck v-if="isMfaChallenged" aria-hidden="true" />
              <LockKeyhole v-else aria-hidden="true" />
            </div>
            <p class="login-card__eyebrow">Acceso institucional</p>
            <h2>
              {{ isUpdatingPassword ? 'Nueva contraseña' : (isRecovering ? 'Recuperar contraseña' : (isMfaChallenged ? 'Verificación 2FA' : 'Bienvenido a Logreva')) }}
            </h2>
            <p>
              {{ isUpdatingPassword ? 'Crea una contraseña segura para continuar' : (isRecovering ? 'Te enviaremos un enlace seguro de recuperación' : (isMfaChallenged ? 'Ingresa el código de 6 dígitos de tu aplicación autenticadora' : 'Ingresa tus credenciales institucionales')) }}
            </p>
          </div>

          <form v-if="isUpdatingPassword" @submit.prevent="handleUpdatePassword" class="login-form">
            <div>
              <label for="new-password">Nueva contraseña</label>
              <div class="login-control">
                <LockKeyhole aria-hidden="true" />
                <input id="new-password" v-model="newPassword" type="password" autocomplete="new-password" required placeholder="Mínimo 6 caracteres" />
              </div>
            </div>
            <button type="submit" :disabled="updateLoading" class="login-primary-button">
              <span>{{ updateLoading ? 'Actualizando...' : 'Guardar nueva contraseña' }}</span>
              <ArrowRight v-if="!updateLoading" aria-hidden="true" />
            </button>
          </form>

          <form v-else-if="isRecovering" @submit.prevent="handleRecoverPassword" class="login-form">
            <div>
              <label for="recover-email">Correo electrónico</label>
              <div class="login-control">
                <Mail aria-hidden="true" />
                <input id="recover-email" v-model="recoverEmail" type="email" autocomplete="email" required placeholder="correo@institucion.edu.ec" />
              </div>
            </div>
            <button type="submit" :disabled="recoverLoading" class="login-primary-button">
              <span>{{ recoverLoading ? 'Enviando...' : 'Enviar enlace seguro' }}</span>
              <ArrowRight v-if="!recoverLoading" aria-hidden="true" />
            </button>
            <button type="button" @click="cancelRecover" class="login-secondary-action">Volver al inicio de sesión</button>
          </form>

          <form v-else-if="isMfaChallenged" @submit.prevent="handleVerifyMfa" class="login-form" data-testid="mfa-challenge-form">
            <div>
              <label for="mfa-code">Código de Verificación (6 dígitos)</label>
              <div class="login-control">
                <ShieldCheck aria-hidden="true" />
                <input
                  id="mfa-code"
                  v-model="mfaCode"
                  type="text"
                  inputmode="numeric"
                  pattern="[0-9]*"
                  autocomplete="one-time-code"
                  maxlength="6"
                  required
                  placeholder="000000"
                  class="tracking-[0.3em] font-mono text-center text-lg font-bold"
                  autofocus
                />
              </div>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-2 text-center">
                Abre tu aplicación autenticadora (Google Authenticator, Microsoft Authenticator o Authy) e ingresa el código temporal.
              </p>
            </div>
            <button type="submit" :disabled="mfaLoading || mfaCode.trim().length < 6" class="login-primary-button">
              <span>{{ mfaLoading ? 'Verificando...' : 'Verificar y Acceder' }}</span>
              <ArrowRight v-if="!mfaLoading" aria-hidden="true" />
            </button>
            <button type="button" @click="cancelMfa" class="login-secondary-action">
              Cancelar y volver
            </button>
          </form>

          <template v-else>
            <form @submit.prevent="handleLogin" class="login-form">
              <div>
                <label for="login-email">Correo electrónico</label>
                <div class="login-control">
                  <Mail aria-hidden="true" />
                  <input id="login-email" v-model="email" type="email" inputmode="email" autocomplete="email" required placeholder="correo@institucion.edu.ec" />
                </div>
              </div>

              <div>
                <label for="login-password">Contraseña</label>
                <div class="login-control login-control--password">
                  <LockKeyhole aria-hidden="true" />
                  <input id="login-password" v-model="password" :type="showPassword ? 'text' : 'password'" autocomplete="current-password" required placeholder="••••••••" />
                  <button v-if="!showPassword" type="button" aria-label="Mostrar contraseña" @click="showPassword = true" class="password-toggle">
                    <Eye aria-hidden="true" />
                  </button>
                  <button v-else type="button" aria-label="Ocultar contraseña" @click="showPassword = false" class="password-toggle">
                    <EyeOff aria-hidden="true" />
                  </button>
                </div>
              </div>

              <button type="submit" :disabled="loading" class="login-primary-button">
                <span>{{ loading ? 'Ingresando...' : 'Iniciar sesión' }}</span>
                <ArrowRight v-if="!loading" aria-hidden="true" />
              </button>

              <button type="button" @click="toggleRecover" class="forgot-password">¿Olvidaste tu contraseña?</button>
            </form>

            <div class="commercial-actions">
              <p>
                ¿No tienes cuenta?
                <a :href="DEMO_REQUEST_URL" target="_blank" rel="noopener noreferrer">Solicita una demo</a>
              </p>
              <router-link to="/planes" class="plans-link">
                <Building2 aria-hidden="true" />
                <span>Ver Planes, Precios y Seguridad</span>
                <ArrowRight aria-hidden="true" />
              </router-link>
            </div>
          </template>
        </div>

        <footer class="login-footer">
          <p>© 2026 Logreva · Por Adyron S.A.S · <router-link to="/terminos">Términos</router-link> · <router-link to="/privacidad">Privacidad</router-link></p>
          <p>Creado en Ecuador para Latinoamérica 🇪🇨 · Por Adyron S.A.S</p>
        </footer>
      </div>
    </section>
  </main>
</template>

<style scoped>
.login-shell {
  display: flex;
  min-height: 100vh;
  min-height: 100svh;
  overflow: hidden;
  background: #f8fafc;
}

.login-brand-panel {
  position: relative;
  width: 52%;
  min-height: 100vh;
  align-items: stretch;
  overflow: hidden;
  background: #020817;
}

.brand-content {
  position: relative;
  z-index: 1;
  display: flex;
  width: 100%;
  max-width: 760px;
  min-height: 100%;
  margin: 0 auto;
  padding: clamp(2.5rem, 5vw, 5.5rem);
  flex-direction: column;
  justify-content: center;
  color: white;
}

.brand-lockup {
  position: absolute;
  top: clamp(2.5rem, 5vh, 4.5rem);
  left: clamp(2.5rem, 5vw, 5.5rem);
  font-size: clamp(1.25rem, 1.55vw, 1.7rem);
}

.brand-message {
  max-width: 590px;
  padding-top: 3rem;
}

.brand-tag {
  display: inline-flex;
  align-items: stretch;
  gap: 0.9rem;
  margin-bottom: 2rem;
  padding: 0.85rem 1.35rem 0.85rem 1.1rem;
  border: 1px solid rgba(148, 163, 184, 0.16);
  border-radius: 0.9rem;
  background: rgba(15, 23, 42, 0.5);
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(12px);
}

.brand-tag__bar {
  width: 3px;
  flex: 0 0 auto;
  border-radius: 999px;
  background: linear-gradient(180deg, #22d3ee, #3b82f6);
}

.brand-tag__text {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  color: #cbd5e1;
  font-size: 0.82rem;
  font-weight: 600;
  letter-spacing: 0.01em;
  line-height: 1.5;
}

.brand-tag__year {
  padding-left: 0.75rem;
  border-left: 1px solid rgba(148, 163, 184, 0.28);
  color: #67e8f9;
  font-variant-numeric: tabular-nums;
  font-weight: 700;
}

.brand-eyebrow {
  margin-bottom: 1.15rem;
  color: #67e8f9;
  font-size: 0.7rem;
  font-weight: 800;
  letter-spacing: 0.24em;
}

.brand-message h1 {
  margin: 0;
  font-size: clamp(3rem, 4.6vw, 5.35rem);
  font-weight: 900;
  letter-spacing: -0.052em;
  line-height: 0.98;
  text-wrap: balance;
}

.brand-message h1 span {
  display: block;
  margin-top: 0.14em;
  color: #22d3ee;
  background: linear-gradient(95deg, #22d3ee 5%, #38bdf8 58%, #60a5fa 100%);
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.brand-promise {
  max-width: 500px;
  margin-top: 1.65rem;
  color: #cbd5e1;
  font-size: clamp(1rem, 1.3vw, 1.25rem);
  line-height: 1.7;
}

.brand-benefits {
  display: grid;
  margin-top: 2rem;
  gap: 0.8rem;
  color: #e2e8f0;
  font-size: 0.92rem;
  font-weight: 650;
}

.brand-benefits li {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.brand-benefits li > span {
  display: grid;
  width: 1.9rem;
  height: 1.9rem;
  flex: 0 0 auto;
  place-items: center;
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 0.55rem;
  color: #67e8f9;
  background: rgba(15, 23, 42, 0.55);
}

.brand-benefits svg {
  width: 1.05rem;
  height: 1.05rem;
  stroke-width: 1.7;
}

.brand-benefits__advanced { color: #c7d2fe; }
.brand-benefits__advanced > span { color: #a5b4fc; }

.secure-card {
  display: flex;
  position: relative;
  width: 100%;
  max-width: 590px;
  margin-top: 1.25rem;
  padding: 1.1rem 1.2rem;
  align-items: center;
  gap: 1rem;
  border: 1px solid rgba(125, 211, 252, 0.2);
  border-radius: 1.15rem;
  background: linear-gradient(120deg, rgba(15, 23, 42, 0.62), rgba(8, 47, 73, 0.35));
  box-shadow: 0 22px 70px rgba(2, 6, 23, 0.35), inset 0 1px rgba(255, 255, 255, 0.06);
  backdrop-filter: blur(18px);
}

.secure-card__icon {
  display: grid;
  width: 3rem;
  height: 3rem;
  flex: 0 0 auto;
  place-items: center;
  border: 1px solid rgba(34, 211, 238, 0.3);
  border-radius: 0.85rem;
  color: #22d3ee;
  background: rgba(6, 182, 212, 0.1);
}

.secure-card__icon svg { width: 1.45rem; }
.secure-card__title { margin-bottom: 0.25rem; color: white; font-weight: 800; }
.secure-card p:last-child { color: #94a3b8; font-size: 0.76rem; line-height: 1.5; }

.secure-card__status {
  margin-left: auto;
  padding: 0.35rem 0.55rem;
  border: 1px solid rgba(34, 211, 238, 0.22);
  border-radius: 999px;
  color: #67e8f9;
  font-size: 0.54rem;
  font-weight: 900;
  letter-spacing: 0.14em;
}

.login-access-panel {
  position: relative;
  display: flex;
  width: 100%;
  min-height: 100vh;
  min-height: 100svh;
  padding: 1.25rem;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  background:
    radial-gradient(70rem 34rem at 100% -8%, rgba(7, 154, 183, 0.13), transparent 62%),
    radial-gradient(52rem 30rem at -8% 108%, rgba(30, 64, 175, 0.08), transparent 58%),
    linear-gradient(160deg, #f5f8fb 0%, #ecf2f7 52%, #e4edf4 100%);
}

/* Trama técnica muy tenue que se desvanece hacia los bordes */
.login-access-panel::before {
  content: '';
  position: absolute;
  inset: 0;
  pointer-events: none;
  background-image:
    linear-gradient(rgba(15, 23, 42, 0.045) 1px, transparent 1px),
    linear-gradient(90deg, rgba(15, 23, 42, 0.045) 1px, transparent 1px);
  background-size: 44px 44px;
  -webkit-mask-image: radial-gradient(ellipse at center, #000 20%, transparent 72%);
  mask-image: radial-gradient(ellipse at center, #000 20%, transparent 72%);
}

.dark .login-access-panel {
  background:
    radial-gradient(70rem 34rem at 100% -8%, rgba(6, 182, 212, 0.14), transparent 62%),
    radial-gradient(52rem 30rem at -8% 108%, rgba(59, 130, 246, 0.1), transparent 58%),
    linear-gradient(160deg, #0a1426 0%, #0b1730 52%, #0d1b36 100%);
}

.dark .login-access-panel::before {
  background-image:
    linear-gradient(rgba(148, 163, 184, 0.06) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148, 163, 184, 0.06) 1px, transparent 1px);
}

.access-decoration { display: none; }

.access-decoration--top { width: 15rem; height: 15rem; top: -8rem; right: -7rem; box-shadow: 0 0 0 28px rgba(7, 154, 183, 0.025); }
.access-decoration--bottom { width: 10rem; height: 10rem; bottom: -6rem; left: -5rem; box-shadow: 0 0 0 22px rgba(7, 154, 183, 0.02); }

.login-access-wrap {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 31rem;
}

.mobile-brand { margin-bottom: 1.75rem; text-align: center; }

.login-card {
  position: relative;
  overflow: hidden;
  padding: clamp(1.75rem, 5vw, 3rem);
  border: 1px solid rgba(203, 213, 225, 0.8);
  border-radius: 1.6rem;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 34px 90px -42px rgba(15, 23, 42, 0.48), 0 12px 30px -20px rgba(15, 23, 42, 0.2), inset 0 1px white;
  backdrop-filter: blur(18px);
}

@property --beam-angle {
  syntax: '<angle>';
  initial-value: 0deg;
  inherits: false;
}

/* Rayo de luz que recorre el borde de la tarjeta */
.login-card::before {
  content: '';
  position: absolute;
  inset: 0;
  z-index: 2;
  padding: 1.5px;
  border-radius: inherit;
  pointer-events: none;
  background: conic-gradient(
    from var(--beam-angle),
    transparent 0deg,
    transparent 250deg,
    rgba(34, 211, 238, 0.12) 290deg,
    #22d3ee 335deg,
    #7dd3fc 352deg,
    transparent 360deg
  );
  -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
  mask: linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0);
  opacity: 0;
  transition: opacity 280ms ease;
}

.login-card:hover::before,
.login-card:focus-within::before {
  opacity: 1;
  animation: login-beam 9s linear infinite;
}

@keyframes login-beam {
  to { --beam-angle: 360deg; }
}

.login-card__header p.login-card__eyebrow {
  margin: 0 0 0.75rem;
  color: #07839c;
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0.2em;
  text-transform: uppercase;
}

.dark .login-card__header p.login-card__eyebrow { color: #67e8f9; }

.login-card__accent {
  position: absolute;
  top: 0;
  right: 16%;
  left: 16%;
  height: 2px;
  background: linear-gradient(90deg, transparent, #079ab7, transparent);
  box-shadow: 0 0 22px rgba(7, 154, 183, 0.55);
}

.login-card__header { margin-bottom: 2.1rem; text-align: center; }

.login-card__shield {
  display: grid;
  width: 3.6rem;
  height: 3.6rem;
  margin: 0 auto 1rem;
  place-items: center;
  border: 1px solid rgba(7, 154, 183, 0.16);
  border-radius: 1.1rem;
  color: #07839c;
  background: linear-gradient(145deg, #ecfeff, #e6f8f7);
  box-shadow: 0 12px 24px -16px rgba(7, 154, 183, 0.7), inset 0 1px white;
}

.login-card__shield svg { width: 1.65rem; height: 1.65rem; stroke-width: 1.8; }
.login-card__header h2 { color: #0b1530; font-size: clamp(1.55rem, 4vw, 2rem); font-weight: 900; letter-spacing: -0.035em; }
.login-card__header p { margin-top: 0.5rem; color: #64748b; font-size: 0.9rem; }

.login-form { display: grid; gap: 1.15rem; }
.login-form label { display: block; margin-bottom: 0.5rem; color: #1e293b; font-size: 0.8rem; font-weight: 800; }

.login-control {
  display: flex;
  min-height: 3.2rem;
  padding: 0 0.95rem;
  align-items: center;
  gap: 0.75rem;
  border: 1px solid #dbe3ed;
  border-radius: 0.8rem;
  background: #fbfdff;
  box-shadow: inset 0 1px 2px rgba(15, 23, 42, 0.025);
  transition: border-color 160ms ease, box-shadow 160ms ease, background 160ms ease;
}

.login-control:focus-within { border-color: rgba(7, 154, 183, 0.72); background: white; box-shadow: 0 0 0 4px rgba(7, 154, 183, 0.1); }
.login-control > svg { width: 1.1rem; height: 1.1rem; flex: 0 0 auto; color: #64748b; stroke-width: 1.8; }
.login-control input { width: 100%; min-width: 0; border: 0; outline: 0; color: #0f172a; background: transparent; font-size: 0.9rem; }
.login-control input::placeholder { color: #94a3b8; }
.login-control--password { padding-right: 0.55rem; }

.password-toggle {
  display: grid;
  width: 2.25rem;
  height: 2.25rem;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 0.6rem;
  color: #64748b;
  transition: color 150ms ease, background 150ms ease;
}

.password-toggle:hover { color: #087c93; background: #ecfeff; }
.password-toggle svg { width: 1.05rem; height: 1.05rem; }

/* Botón principal: círculo que se expande + flechas que se deslizan (colores LOGREVA) */
.login-primary-button {
  --flow-ease: cubic-bezier(0.19, 1, 0.22, 1);
  --flow-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
  position: relative;
  isolation: isolate;
  display: flex;
  min-height: 3.35rem;
  margin-top: 0.15rem;
  padding: 0 2.9rem;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  border-radius: 999px;
  color: white;
  background: linear-gradient(100deg, #087c78 0%, #079ab7 56%, #06b6d4 100%);
  box-shadow: 0 16px 30px -18px rgba(7, 154, 183, 0.95), inset 0 1px rgba(255, 255, 255, 0.22);
  font-size: 0.9rem;
  font-weight: 850;
  cursor: pointer;
  transition: border-radius 600ms var(--flow-ease), box-shadow 300ms ease, transform 200ms ease;
}

.login-primary-button > span {
  position: relative;
  z-index: 1;
  transform: translateX(-0.45rem);
  transition: transform 800ms ease-out;
}

/* Círculo azul marino de marca que crece desde el centro */
.login-primary-button::before {
  content: '';
  position: absolute;
  z-index: -1;
  top: 50%;
  left: 50%;
  width: 1rem;
  height: 1rem;
  border-radius: 50%;
  background: #0b1f3a;
  opacity: 0;
  transform: translate(-50%, -50%);
  transition: width 800ms var(--flow-ease), height 800ms var(--flow-ease), opacity 800ms var(--flow-ease);
}

/* Flecha izquierda: entra al pasar el cursor */
.login-primary-button::after {
  content: '';
  position: absolute;
  z-index: 2;
  top: 50%;
  left: -25%;
  width: 1.05rem;
  height: 1.05rem;
  margin-top: -0.525rem;
  background: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2367e8f9' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M5 12h14'/%3E%3Cpath d='m12 5 7 7-7 7'/%3E%3C/svg%3E") center / contain no-repeat;
  transition: left 800ms var(--flow-spring);
}

/* Flecha derecha: sale al pasar el cursor */
.login-primary-button svg {
  position: absolute;
  z-index: 2;
  top: 50%;
  right: 1.15rem;
  width: 1.05rem;
  height: 1.05rem;
  margin-top: -0.525rem;
  transition: right 800ms var(--flow-spring), color 400ms ease;
}

.login-primary-button:hover:not(:disabled),
.login-primary-button:focus-visible:not(:disabled) {
  border-radius: 0.82rem;
  box-shadow: 0 20px 34px -18px rgba(11, 31, 58, 0.85);
}

.login-primary-button:hover:not(:disabled) > span,
.login-primary-button:focus-visible:not(:disabled) > span { transform: translateX(0.9rem); }

.login-primary-button:hover:not(:disabled)::before,
.login-primary-button:focus-visible:not(:disabled)::before {
  width: 40rem;
  height: 40rem;
  opacity: 1;
}

.login-primary-button:hover:not(:disabled)::after,
.login-primary-button:focus-visible:not(:disabled)::after { left: 1.15rem; }

.login-primary-button:hover:not(:disabled) svg,
.login-primary-button:focus-visible:not(:disabled) svg { right: -25%; }

.login-primary-button:active:not(:disabled) { transform: scale(0.97); }
.login-primary-button:focus-visible { outline: 2px solid #67e8f9; outline-offset: 3px; }
.login-primary-button:disabled { cursor: wait; opacity: 0.62; }

/* Sin flecha (estado de carga): el texto queda centrado */
.login-primary-button:disabled > span { transform: none; }

.forgot-password, .login-secondary-action { justify-self: center; color: #087c93; font-size: 0.78rem; font-weight: 750; }
.forgot-password:hover, .login-secondary-action:hover { color: #075f72; text-decoration: underline; text-underline-offset: 3px; }

.commercial-actions { margin-top: 1.45rem; padding-top: 1.35rem; border-top: 1px solid #edf1f5; text-align: center; }
.commercial-actions > p { color: #64748b; font-size: 0.78rem; }
.commercial-actions > p a { margin-left: 0.25rem; color: #087c93; font-weight: 850; }
.commercial-actions > p a:hover { color: #075f72; }

.plans-link {
  display: flex;
  margin-top: 1.15rem;
  padding: 0.9rem 1rem;
  align-items: center;
  gap: 0.65rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.8rem;
  color: #334155;
  background: #f8fafc;
  font-size: 0.76rem;
  font-weight: 800;
  transition: border-color 150ms ease, color 150ms ease, background 150ms ease;
}

.plans-link:hover { border-color: rgba(7, 154, 183, 0.28); color: #087c93; background: #f0fdff; }
.plans-link svg { width: 1rem; height: 1rem; color: #087c93; }
.plans-link span { flex: 1; text-align: left; }

.login-footer { margin-top: 1.25rem; color: #64748b; text-align: center; font-size: 0.68rem; line-height: 1.75; }
.login-footer a:hover { color: #087c93; }

.dark .login-card {
  background: rgba(15, 23, 42, 0.88);
  border-color: rgba(51, 65, 85, 0.7);
  box-shadow: 0 34px 90px -42px rgba(0, 0, 0, 0.8), inset 0 1px rgba(255, 255, 255, 0.05);
}

.dark .login-card__header h2 {
  color: #f8fafc;
}

.dark .login-card__header p {
  color: #94a3b8;
}

.dark .login-form label {
  color: #e2e8f0;
}

.dark .login-control {
  background: rgba(2, 6, 23, 0.6);
  border-color: #334155;
}

.dark .login-control:focus-within {
  background: rgba(2, 6, 23, 0.9);
  border-color: #06b6d4;
}

.dark .login-control input {
  color: #f8fafc;
}

.dark .plans-link {
  background: rgba(15, 23, 42, 0.6);
  border-color: #334155;
  color: #cbd5e1;
}

.dark .plans-link:hover {
  background: rgba(15, 23, 42, 0.9);
  color: #38bdf8;
  border-color: #0284c7;
}

.dark .commercial-actions {
  border-top-color: #1e293b;
}

@media (min-width: 1024px) {
  .login-access-panel { width: 48%; padding: 2rem; }
}

@media (max-height: 820px) and (min-width: 1024px) {
  .brand-content { padding-top: 5.5rem; padding-bottom: 2.5rem; }
  .brand-message h1 { font-size: clamp(2.8rem, 4vw, 4.2rem); }
  .brand-promise { margin-top: 1.1rem; }
  .brand-benefits { margin-top: 1.25rem; gap: 0.55rem; }
  .secure-card { margin-top: 0.9rem; }
  .login-card { padding-top: 1.6rem; padding-bottom: 1.6rem; }
  .login-card__header { margin-bottom: 1.25rem; }
  .login-card__shield { width: 3rem; height: 3rem; margin-bottom: 0.75rem; }
}

@media (max-width: 639px) {
  .login-access-panel { align-items: flex-start; padding: 1.1rem 0.9rem 1.5rem; overflow-y: auto; }
  .login-access-wrap { margin: auto 0; }
  .login-card { border-radius: 1.35rem; }
  .login-footer { margin-top: 1rem; }
}

@media (prefers-reduced-motion: reduce) {
  .login-primary-button, .login-control, .plans-link, .password-toggle { transition: none; }
  .login-primary-button::before, .login-primary-button::after, .login-primary-button svg, .login-primary-button > span { transition: none; }
  .login-card:hover::before, .login-card:focus-within::before { animation: none; --beam-angle: 300deg; }
}
</style>
