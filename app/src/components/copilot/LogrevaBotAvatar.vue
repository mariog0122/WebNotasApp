<script setup>
/**
 * LogrevaBotAvatar — Usa la imagen real del robot Logreva (3D render)
 * con efectos CSS de profundidad, glow, flotación y brillo profesional.
 *
 * Props:
 *  - size: CSS size string (default '100%')
 *  - thinking: boolean — cuando está procesando, efecto de pulso rápido
 *  - mini: boolean — para versión pequeña (botón flotante y header)
 */
defineProps({
  size: { type: String, default: '100%' },
  thinking: { type: Boolean, default: false },
  mini: { type: Boolean, default: false }
})
</script>

<template>
  <div
    class="logreva-avatar-wrap"
    :class="{ 'is-thinking': thinking, 'is-mini': mini }"
    :style="{ width: size, height: size }"
  >
    <!-- Glow ambiental cyan detrás del robot -->
    <div class="ambient-glow"></div>

    <!-- Imagen real del robot 3D en WebP optimizado -->
    <img
      src="/assistant/logreva-bot-3d.webp"
      alt="Asistente Logreva"
      class="bot-img"
      draggable="false"
    />

    <!-- Reflejo de piso (solo en versión grande) -->
    <div v-if="!mini" class="floor-reflection">
      <img
        src="/assistant/logreva-bot-3d.webp"
        alt=""
        class="reflection-img"
        draggable="false"
      />
    </div>
  </div>
</template>

<style scoped>
.logreva-avatar-wrap {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  /* Contenedor sin fondo */
}

/* ═══════════════════════════════════════════
   IMAGEN DEL ROBOT — Efecto 3D premium
   ═══════════════════════════════════════════ */
.bot-img {
  position: relative;
  z-index: 2;
  width: 100%;
  height: 100%;
  object-fit: contain;
  /* Sombra 3D de profundidad */
  filter:
    drop-shadow(0 10px 24px rgba(6, 182, 212, 0.35))
    drop-shadow(0 2px 8px rgba(0, 0, 0, 0.2));
  /* Levitación suave */
  animation: float 4s ease-in-out infinite;
  transition: transform 0.3s ease, filter 0.3s ease;
}

.logreva-avatar-wrap:hover .bot-img {
  transform: scale(1.04) translateY(-2px);
  filter:
    drop-shadow(0 12px 28px rgba(6, 182, 212, 0.45))
    drop-shadow(0 4px 10px rgba(0, 0, 0, 0.2));
}

/* ═══════════════════════════════════════════
   GLOW AMBIENTAL — Halo cyan detrás del robot
   ═══════════════════════════════════════════ */
.ambient-glow {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 70%;
  height: 70%;
  border-radius: 50%;
  background: radial-gradient(
    circle,
    rgba(34, 211, 238, 0.18) 0%,
    rgba(34, 211, 238, 0.08) 40%,
    transparent 70%
  );
  z-index: 1;
  animation: glow-breathe 3s ease-in-out infinite;
  pointer-events: none;
}

/* ═══════════════════════════════════════════
   REFLEJO DE PISO — Perspectiva 3D
   ═══════════════════════════════════════════ */
.floor-reflection {
  position: absolute;
  bottom: -20%;
  left: 50%;
  transform: translateX(-50%) scaleY(-0.25) scaleX(0.85);
  width: 80%;
  height: 50%;
  z-index: 0;
  pointer-events: none;
  opacity: 0.12;
  filter: blur(3px);
  mask-image: linear-gradient(to top, rgba(0,0,0,0.5) 0%, transparent 80%);
  -webkit-mask-image: linear-gradient(to top, rgba(0,0,0,0.5) 0%, transparent 80%);
}

.reflection-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

/* ═══════════════════════════════════════════
   ANIMACIÓN DE LEVITACIÓN
   ═══════════════════════════════════════════ */
@keyframes float {
  0%, 100% {
    transform: translateY(0px);
  }
  50% {
    transform: translateY(-6px);
  }
}

/* ═══════════════════════════════════════════
   GLOW RESPIRACIÓN
   ═══════════════════════════════════════════ */
@keyframes glow-breathe {
  0%, 100% {
    opacity: 0.7;
    transform: translate(-50%, -50%) scale(1);
  }
  50% {
    opacity: 1;
    transform: translate(-50%, -50%) scale(1.08);
  }
}

/* ═══════════════════════════════════════════
   MODO MINI — Más compacto, sin reflejo
   ═══════════════════════════════════════════ */
.is-mini .bot-img {
  width: 100%;
  height: 100%;
  animation: float 5s ease-in-out infinite;
  filter:
    drop-shadow(0 3px 8px rgba(6, 182, 212, 0.25))
    drop-shadow(0 1px 3px rgba(0, 0, 0, 0.1));
}

.is-mini .ambient-glow {
  width: 80%;
  height: 80%;
  background: radial-gradient(
    circle,
    rgba(34, 211, 238, 0.12) 0%,
    transparent 60%
  );
}

/* ═══════════════════════════════════════════
   MODO THINKING — Pulso rápido
   ═══════════════════════════════════════════ */
.is-thinking .bot-img {
  animation: think-pulse 1.5s ease-in-out infinite;
}

.is-thinking .ambient-glow {
  animation: think-glow 1s ease-in-out infinite alternate;
  background: radial-gradient(
    circle,
    rgba(167, 139, 250, 0.2) 0%,
    rgba(34, 211, 238, 0.1) 40%,
    transparent 70%
  );
}

@keyframes think-pulse {
  0%, 100% {
    transform: translateY(0px) scale(1);
    filter:
      drop-shadow(0 8px 20px rgba(6, 182, 212, 0.3))
      drop-shadow(0 2px 6px rgba(0, 0, 0, 0.15));
  }
  50% {
    transform: translateY(-4px) scale(1.02);
    filter:
      drop-shadow(0 12px 28px rgba(139, 92, 246, 0.35))
      drop-shadow(0 4px 10px rgba(0, 0, 0, 0.18));
  }
}

@keyframes think-glow {
  from {
    opacity: 0.5;
    transform: translate(-50%, -50%) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translate(-50%, -50%) scale(1.1);
  }
}
</style>
