<script setup>
import { ArrowLeft, LayoutDashboard, ShieldX } from 'lucide-vue-next'
import BrandLogo from '../components/ui/BrandLogo.vue'
</script>

<template>
  <main class="min-h-screen bg-slate-950 px-5 py-10 text-slate-100 sm:px-8">
    <div class="mx-auto flex min-h-[calc(100vh-5rem)] max-w-xl items-center justify-center">
      <section class="w-full overflow-hidden rounded-[2rem] border border-white/10 bg-white/[0.06] p-6 shadow-2xl shadow-cyan-950/30 backdrop-blur-xl sm:p-10">
        <BrandLogo variant="horizontal" tone="light" class="h-9 w-auto" />

        <div class="mt-10 flex h-16 w-16 items-center justify-center rounded-2xl border border-amber-300/20 bg-amber-300/10 text-amber-300">
          <ShieldX class="h-8 w-8" aria-hidden="true" />
        </div>

        <p class="mt-8 text-xs font-bold uppercase tracking-[0.24em] text-cyan-300">Código 403</p>
        <h1 class="mt-3 text-3xl font-black tracking-tight text-white sm:text-4xl">Acceso no autorizado</h1>
        <p class="mt-4 max-w-md text-base leading-7 text-slate-300">
          Tu sesión está activa, pero tu rol institucional no tiene permiso para abrir esta sección.
        </p>
        <p class="mt-3 text-sm leading-6 text-slate-400">
          Si necesitas este acceso, solicítalo al administrador de tu institución. LOGREVA mantiene tus datos protegidos por permisos y políticas RLS.
        </p>

        <div class="mt-9 grid gap-3 sm:grid-cols-2">
          <router-link
            to="/"
            class="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-cyan-500 px-5 py-3 font-bold text-slate-950 transition hover:bg-cyan-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan-300"
          >
            <LayoutDashboard class="h-5 w-5" aria-hidden="true" />
            Ir al panel
          </router-link>
          <button
            type="button"
            class="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl border border-white/15 px-5 py-3 font-semibold text-white transition hover:bg-white/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
            @click="$router.back()"
          >
            <ArrowLeft class="h-5 w-5" aria-hidden="true" />
            Volver
          </button>
        </div>
      </section>
    </div>
  </main>
</template>
