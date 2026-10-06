<script setup>
import { onMounted, onUnmounted, ref } from 'vue'

const canvasRef = ref(null)

let context = null
let frameId = 0
let resizeObserver = null
let reduceMotionQuery = null
let width = 0
let height = 0
let pixelRatio = 1
let stars = []
let ambientMeteors = []
let featuredMeteor = null
let nextFeaturedMeteorAt = 0
let pageVisible = true
let parallaxX = 0
let parallaxY = 0
let targetParallaxX = 0
let targetParallaxY = 0

const randomBetween = (min, max) => min + Math.random() * (max - min)

const makeStar = (index) => {
  const layer = index % 3
  return {
    x: Math.random(),
    y: Math.random(),
    radius: randomBetween(0.45, 1.35) + layer * 0.18,
    alpha: randomBetween(0.28, 0.86),
    phase: randomBetween(0, Math.PI * 2),
    twinkleSpeed: randomBetween(0.00045, 0.00125),
    layer,
    tint: Math.random() > 0.82 ? (Math.random() > 0.5 ? '34,211,238' : '125,211,252') : '255,255,255',
  }
}

const makeAmbientMeteor = (index) => ({
  x: randomBetween(0.08, 0.92),
  y: randomBetween(-0.15, 0.82),
  length: randomBetween(44, 92),
  speed: randomBetween(0.006, 0.012),
  alpha: randomBetween(0.12, 0.25),
  delay: index * 2400 + randomBetween(0, 1800),
})

const resetScene = () => {
  stars = Array.from({ length: 64 }, (_, index) => makeStar(index))
  ambientMeteors = Array.from({ length: 3 }, (_, index) => makeAmbientMeteor(index))
  featuredMeteor = null
  nextFeaturedMeteorAt = performance.now() + randomBetween(4000, 8000)
}

const sizeCanvas = () => {
  const canvas = canvasRef.value
  if (!canvas) return

  const bounds = canvas.getBoundingClientRect()
  width = Math.max(1, bounds.width)
  height = Math.max(1, bounds.height)
  pixelRatio = Math.min(window.devicePixelRatio || 1, 1.5)
  canvas.width = Math.round(width * pixelRatio)
  canvas.height = Math.round(height * pixelRatio)
  context = canvas.getContext('2d', { alpha: true })
  context?.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0)

  drawScene(performance.now(), true)
}

const drawGlow = (x, y, radius, color) => {
  const gradient = context.createRadialGradient(x, y, 0, x, y, radius)
  gradient.addColorStop(0, color)
  gradient.addColorStop(1, 'rgba(0,0,0,0)')
  context.fillStyle = gradient
  context.fillRect(x - radius, y - radius, radius * 2, radius * 2)
}

const drawEnergyCurves = (time) => {
  const pulse = 0.72 + Math.sin(time * 0.00045) * 0.18
  const curves = [
    { y: 0.9, color: `rgba(34,211,238,${0.42 * pulse})`, width: 1.5 },
    { y: 0.84, color: `rgba(14,165,233,${0.26 * pulse})`, width: 1 },
    { y: 0.96, color: `rgba(59,130,246,${0.2 * pulse})`, width: 0.8 },
  ]

  curves.forEach((curve, index) => {
    context.beginPath()
    context.moveTo(-40, height * curve.y + parallaxY * 0.35)
    context.bezierCurveTo(
      width * 0.24,
      height * (0.68 + index * 0.045),
      width * 0.72,
      height * (1.04 - index * 0.025),
      width + 70,
      height * (0.37 + index * 0.055),
    )
    context.strokeStyle = curve.color
    context.lineWidth = curve.width
    context.shadowColor = curve.color
    context.shadowBlur = 10 + index * 3
    context.stroke()
  })

  context.shadowBlur = 0
}

const drawStars = (time, staticScene) => {
  stars.forEach((star) => {
    const depth = (star.layer + 1) / 3
    const twinkle = staticScene ? 0.82 : 0.68 + Math.sin(time * star.twinkleSpeed + star.phase) * 0.32
    const x = star.x * width + parallaxX * depth
    const y = star.y * height + parallaxY * depth
    const alpha = star.alpha * twinkle

    context.beginPath()
    context.arc(x, y, star.radius, 0, Math.PI * 2)
    context.fillStyle = `rgba(${star.tint},${alpha})`
    context.fill()

    if (star.radius > 1.25 && alpha > 0.58) {
      context.strokeStyle = `rgba(${star.tint},${alpha * 0.38})`
      context.lineWidth = 0.6
      context.beginPath()
      context.moveTo(x - 4, y)
      context.lineTo(x + 4, y)
      context.moveTo(x, y - 4)
      context.lineTo(x, y + 4)
      context.stroke()
    }
  })
}

const drawAmbientMeteors = (time, staticScene) => {
  if (staticScene) return

  ambientMeteors.forEach((meteor) => {
    const cycle = ((time - meteor.delay) * meteor.speed) % (height + 320)
    if (cycle < 0) return
    const x = meteor.x * width + cycle * 0.24
    const y = meteor.y * height + cycle
    const tailX = x - meteor.length * 0.48
    const tailY = y - meteor.length
    const gradient = context.createLinearGradient(tailX, tailY, x, y)
    gradient.addColorStop(0, 'rgba(56,189,248,0)')
    gradient.addColorStop(1, `rgba(186,230,253,${meteor.alpha})`)
    context.strokeStyle = gradient
    context.lineWidth = 1
    context.beginPath()
    context.moveTo(tailX, tailY)
    context.lineTo(x, y)
    context.stroke()
  })
}

const drawFeaturedMeteor = (time, staticScene) => {
  if (staticScene) return

  if (!featuredMeteor && time >= nextFeaturedMeteorAt) {
    featuredMeteor = {
      startedAt: time,
      duration: randomBetween(1100, 1450),
      startX: randomBetween(width * 0.58, width * 0.92),
      startY: randomBetween(-30, height * 0.22),
      travel: randomBetween(240, 360),
    }
  }

  if (!featuredMeteor) return
  const progress = (time - featuredMeteor.startedAt) / featuredMeteor.duration
  if (progress >= 1) {
    featuredMeteor = null
    nextFeaturedMeteorAt = time + randomBetween(4000, 8000)
    return
  }

  const eased = 1 - Math.pow(1 - progress, 3)
  const x = featuredMeteor.startX - featuredMeteor.travel * eased
  const y = featuredMeteor.startY + featuredMeteor.travel * 0.58 * eased
  const opacity = Math.sin(Math.PI * progress) * 0.95
  const tailLength = 128 + 76 * (1 - progress)
  const tailX = x + tailLength
  const tailY = y - tailLength * 0.58
  const gradient = context.createLinearGradient(tailX, tailY, x, y)
  gradient.addColorStop(0, 'rgba(34,211,238,0)')
  gradient.addColorStop(0.72, `rgba(56,189,248,${opacity * 0.45})`)
  gradient.addColorStop(1, `rgba(255,255,255,${opacity})`)

  context.strokeStyle = gradient
  context.lineWidth = 2
  context.shadowColor = '#22d3ee'
  context.shadowBlur = 14
  context.beginPath()
  context.moveTo(tailX, tailY)
  context.lineTo(x, y)
  context.stroke()
  context.shadowBlur = 0
}

function drawScene(time, staticScene = false) {
  if (!context || !width || !height) return

  if (!staticScene) {
    parallaxX += (targetParallaxX - parallaxX) * 0.045
    parallaxY += (targetParallaxY - parallaxY) * 0.045
  }

  context.clearRect(0, 0, width, height)
  drawGlow(width * 0.94, height * 0.7, Math.max(width, height) * 0.5, 'rgba(8,145,178,0.13)')
  drawGlow(width * 0.52, height * 0.18, Math.max(width, height) * 0.34, 'rgba(37,99,235,0.09)')
  drawStars(time, staticScene)
  drawAmbientMeteors(time, staticScene)
  drawEnergyCurves(time)
  drawFeaturedMeteor(time, staticScene)
}

const animate = (time) => {
  drawScene(time)
  frameId = requestAnimationFrame(animate)
}

const stopAnimation = () => {
  if (frameId) cancelAnimationFrame(frameId)
  frameId = 0
}

const startAnimation = () => {
  stopAnimation()
  if (!pageVisible || reduceMotionQuery?.matches) {
    drawScene(performance.now(), true)
    return
  }
  frameId = requestAnimationFrame(animate)
}

const handleVisibilityChange = () => {
  pageVisible = !document.hidden
  startAnimation()
}

const handlePointerMove = (event) => {
  if (reduceMotionQuery?.matches || !width || !height) return
  targetParallaxX = Math.max(-8, Math.min(8, (event.clientX / window.innerWidth - 0.5) * 16))
  targetParallaxY = Math.max(-8, Math.min(8, (event.clientY / window.innerHeight - 0.5) * 16))
}

const handleMotionPreferenceChange = () => {
  targetParallaxX = 0
  targetParallaxY = 0
  parallaxX = 0
  parallaxY = 0
  startAnimation()
}

onMounted(() => {
  resetScene()
  reduceMotionQuery = window.matchMedia('(prefers-reduced-motion: reduce)')
  reduceMotionQuery.addEventListener?.('change', handleMotionPreferenceChange)
  document.addEventListener('visibilitychange', handleVisibilityChange)
  window.addEventListener('pointermove', handlePointerMove, { passive: true })

  resizeObserver = new ResizeObserver(sizeCanvas)
  if (canvasRef.value) resizeObserver.observe(canvasRef.value)
  sizeCanvas()
  startAnimation()
})

onUnmounted(() => {
  stopAnimation()
  if (resizeObserver) resizeObserver.disconnect()
  reduceMotionQuery?.removeEventListener?.('change', handleMotionPreferenceChange)
  document.removeEventListener('visibilitychange', handleVisibilityChange)
  window.removeEventListener('pointermove', handlePointerMove)
  context = null
  stars = []
  ambientMeteors = []
  featuredMeteor = null
})
</script>

<template>
  <div class="galaxy-background" aria-hidden="true">
    <canvas ref="canvasRef" class="galaxy-background__canvas"></canvas>
  </div>
</template>

<style scoped>
.galaxy-background {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
  background:
    radial-gradient(circle at 88% 72%, rgba(8, 145, 178, 0.2), transparent 38%),
    radial-gradient(circle at 58% 10%, rgba(37, 99, 235, 0.16), transparent 34%),
    linear-gradient(142deg, #020617 0%, #07132d 48%, #020817 100%);
}

.galaxy-background::before {
  position: absolute;
  inset: 0;
  content: '';
  background: linear-gradient(90deg, rgba(2, 6, 23, 0.64) 0%, rgba(2, 6, 23, 0.3) 58%, transparent 100%);
}

.galaxy-background::after {
  position: absolute;
  inset: 0;
  content: '';
  background-image: linear-gradient(rgba(255, 255, 255, 0.018) 1px, transparent 1px);
  background-size: 100% 4px;
  opacity: 0.2;
}

.galaxy-background__canvas {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

@media (prefers-reduced-motion: reduce) {
  .galaxy-background__canvas {
    opacity: 0.9;
  }
}
</style>
