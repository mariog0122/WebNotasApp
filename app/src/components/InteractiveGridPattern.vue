
<script setup>
import { ref } from 'vue'

const props = defineProps({
  width: { type: Number, default: 40 },
  height: { type: Number, default: 40 },
  className: { type: String, default: '' },
})

const containerRef = ref(null)
const hoveredSquare = ref(null)

const handleMouseMove = (event) => {
    if (!containerRef.value) return;
    const rect = containerRef.value.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    
    // Calculate which square is hovered
    // We map to the nearest grid cell
    const col = Math.floor(x / props.width);
    const row = Math.floor(y / props.height);
    
    hoveredSquare.value = { col, row };
}

const handleMouseLeave = () => {
    hoveredSquare.value = null;
}
</script>

<template>
  <div 
    ref="containerRef"
    :class="['pointer-events-none', className]"
    class="absolute inset-0 h-full w-full overflow-hidden"
    :style="{
        'mask-image': 'radial-gradient(circle at 50% 50%, black, transparent 90%)',
        'webkit-mask-image': 'radial-gradient(circle at 50% 50%, black, transparent 90%)'
    }"
  >
    <!-- Background Grid (Static) -->
     <svg
      class="absolute inset-0 h-full w-full stroke-gray-300/30 [mask-image:radial-gradient(100%_100%_at_top_right,white,transparent)]"
      aria-hidden="true"
    >
      <defs>
        <pattern
          id="grid-pattern"
          :width="width"
          :height="height"
          x="50%"
          y="-1"
          patternUnits="userSpaceOnUse"
        >
          <path d="M.5 200V.5H200" fill="none" />
        </pattern>
      </defs>
      <!-- We use a simpler approach: SVG Pattern -->
      <!-- Actually, let's use the exact pattern from the requested demo style -->
      <defs>
         <pattern
            id="dotted-grid"
            :width="width"
            :height="height"
            patternUnits="userSpaceOnUse"
            x="0"
            y="0"
         >
            <path :d="`M ${width} 0 L 0 0 0 ${height}`" fill="none" stroke="currentColor" stroke-width="1" />
         </pattern>
      </defs>
      
      <rect width="100%" height="100%" fill="url(#dotted-grid)" />
    </svg>

    <!-- Interactive Layer (Pointer events needed on parent, but mostly pass through) -->
     <div class="absolute inset-0 h-full w-full pointer-events-none" @mousemove="handleMouseMove" @mouseleave="handleMouseLeave">
        <svg
            v-if="hoveredSquare"
            class="absolute inset-0 h-full w-full overflow-visible"
        >
            <rect
                :x="hoveredSquare.col * width"
                :y="hoveredSquare.row * height"
                :width="width"
                :height="height"
                fill="currentColor"
                class="text-slate-300/40 transition-all duration-100 ease-in-out"
            />
             <!-- Surrounding squares for a glow effect -->
             <rect
                v-for="(offset, i) in [[-1,0], [1,0], [0,-1], [0,1]]"
                :key="i"
                :x="(hoveredSquare.col + offset[0]) * width"
                :y="(hoveredSquare.row + offset[1]) * height"
                :width="width"
                :height="height"
                fill="currentColor"
                class="text-slate-200/20 transition-all duration-300 ease-out"
            />
        </svg>
     </div>
  </div>
</template>
