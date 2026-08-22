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
import { ArrowRight, Building2, Check, Eye, EyeOff, LockKeyhole, Mail, ShieldCheck } from 'lucide-vue-next'

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
          <p class="brand-eyebrow">PLATAFORMA INSTITUCIONAL</p>
          <h1>
            Gestión Académica
            <span>Centralizada</span>
          </h1>
          <p class="brand-promise">Donde cada institución logra su excelencia académica.</p>

          <ul class="brand-benefits" aria-label="Beneficios principales">
            <li><span><Check aria-hidden="true" /></span>Control académico en tiempo real</li>
            <li><span><Check aria-hidden="true" /></span>Trazabilidad lista para auditoría</li>
            <li><span><Check aria-hidden="true" /></span>Reportes claros para decidir mejor</li>
          </ul>
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
            <div class="login-card__shield"><LockKeyhole aria-hidden="true" /></div>
            <h2>
              {{ isUpdatingPassword ? 'Nueva contraseña' : (isRecovering ? 'Recuperar contraseña' : 'Bienvenido a Logreva') }}
            </h2>
            <p>
              {{ isUpdatingPassword ? 'Crea una contraseña segura para continuar' : (isRecovering ? 'Te enviaremos un enlace seguro de recuperación' : 'Ingresa tus credenciales institucionales') }}
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
  width: 1.55rem;
  height: 1.55rem;
  place-items: center;
  border: 1px solid rgba(34, 211, 238, 0.34);
  border-radius: 999px;
  color: #22d3ee;
  background: rgba(8, 145, 178, 0.12);
}

.brand-benefits svg {
  width: 0.9rem;
  height: 0.9rem;
  stroke-width: 3;
}

.secure-card {
  display: flex;
  position: absolute;
  right: clamp(2.5rem, 5vw, 5.5rem);
  bottom: clamp(2.4rem, 5vh, 4.5rem);
  left: clamp(2.5rem, 5vw, 5.5rem);
  max-width: 590px;
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
    radial-gradient(circle at 12% 10%, rgba(34, 211, 238, 0.08), transparent 28%),
    linear-gradient(145deg, #f8fafc 0%, #ffffff 45%, #f1f5f9 100%);
}

.access-decoration {
  position: absolute;
  border: 1px solid rgba(7, 154, 183, 0.13);
  border-radius: 999px;
  pointer-events: none;
}

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
  padding: clamp(1.5rem, 5vw, 2.65rem);
  border: 1px solid rgba(203, 213, 225, 0.72);
  border-radius: 1.6rem;
  background: rgba(255, 255, 255, 0.92);
  box-shadow: 0 34px 90px -42px rgba(15, 23, 42, 0.48), 0 12px 30px -20px rgba(15, 23, 42, 0.2), inset 0 1px white;
  backdrop-filter: blur(18px);
}

.login-card__accent {
  position: absolute;
  top: 0;
  right: 16%;
  left: 16%;
  height: 2px;
  background: linear-gradient(90deg, transparent, #079ab7, transparent);
  box-shadow: 0 0 22px rgba(7, 154, 183, 0.55);
}

.login-card__header { margin-bottom: 2rem; text-align: center; }

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

.login-primary-button {
  display: flex;
  min-height: 3.35rem;
  margin-top: 0.15rem;
  padding: 0 1.2rem;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  border-radius: 0.82rem;
  color: white;
  background: linear-gradient(100deg, #087c78 0%, #079ab7 56%, #06b6d4 100%);
  box-shadow: 0 16px 30px -18px rgba(7, 154, 183, 0.95), inset 0 1px rgba(255, 255, 255, 0.22);
  font-size: 0.9rem;
  font-weight: 850;
  transition: transform 160ms ease, box-shadow 160ms ease, filter 160ms ease;
}

.login-primary-button:hover:not(:disabled) { transform: translateY(-1px); filter: saturate(1.08); box-shadow: 0 20px 34px -18px rgba(7, 154, 183, 1); }
.login-primary-button:disabled { cursor: wait; opacity: 0.62; }
.login-primary-button svg { width: 1.05rem; height: 1.05rem; }

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
  .brand-content { padding-top: 5.5rem; padding-bottom: 8rem; }
  .brand-message h1 { font-size: clamp(2.8rem, 4vw, 4.2rem); }
  .brand-promise { margin-top: 1.1rem; }
  .brand-benefits { margin-top: 1.25rem; gap: 0.55rem; }
  .secure-card { bottom: 1.5rem; }
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
}
</style>
