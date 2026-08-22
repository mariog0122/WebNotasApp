<script setup>
import { computed } from 'vue'
import { BRAND_DESCRIPTOR } from '../../lib/brand'

const props = defineProps({
  variant: {
    type: String,
    default: 'horizontal',
    validator: (value) => ['horizontal', 'compact', 'mark'].includes(value),
  },
  tone: {
    type: String,
    default: 'dark',
    validator: (value) => ['dark', 'light', 'mono'].includes(value),
  },
  decorative: {
    type: Boolean,
    default: false,
  },
  descriptor: {
    type: String,
    default: BRAND_DESCRIPTOR,
  },
})

const markColor = computed(() => props.tone === 'light' ? '#FFFFFF' : 'currentColor')
const accentColor = computed(() => {
  if (props.tone === 'mono') return 'currentColor'
  return props.tone === 'light' ? '#22D3EE' : '#079AB7'
})
</script>

<template>
  <span
    class="brand-logo"
    :class="[`brand-logo--${variant}`, `brand-logo--${tone}`]"
    :role="decorative ? undefined : 'img'"
    :aria-label="decorative ? undefined : 'Logreva, gestión educativa'"
    :aria-hidden="decorative ? 'true' : undefined"
  >
    <svg class="brand-logo__mark" viewBox="0 0 72 72" fill="none" focusable="false" aria-hidden="true">
      <path
        d="M10 7H21V42C21 49.5 24.5 53 32 53H37V64H30C16.5 64 10 57.5 10 44V7Z"
        :fill="markColor"
      />
      <path
        d="M27 39L37 50L57 18L66 24L38 67L18 45L27 39Z"
        :fill="accentColor"
      />
    </svg>

    <span v-if="variant !== 'mark'" class="brand-logo__type">
      <span class="brand-logo__wordmark" aria-hidden="true">
        <span>LOGRE</span><span class="brand-logo__accent">V</span><span>A</span>
      </span>
      <span v-if="variant === 'horizontal'" class="brand-logo__descriptor">{{ descriptor }}</span>
    </span>
  </span>
</template>

<style scoped>
.brand-logo {
  display: inline-flex;
  align-items: center;
  gap: 0.72em;
  color: #0b1530;
  line-height: 1;
}

.brand-logo--light {
  color: #ffffff;
}

.brand-logo__mark {
  width: 2.65em;
  height: 2.65em;
  flex: 0 0 auto;
}

.brand-logo--compact .brand-logo__mark {
  width: 2.2em;
  height: 2.2em;
}

.brand-logo--mark .brand-logo__mark {
  width: 100%;
  height: 100%;
}

.brand-logo__type {
  display: flex;
  min-width: 0;
  flex-direction: column;
  align-items: flex-start;
}

.brand-logo__wordmark {
  display: inline-flex;
  color: currentColor;
  font-size: 1.16em;
  font-weight: 900;
  letter-spacing: 0.125em;
  white-space: nowrap;
}

.brand-logo__accent {
  color: #079ab7;
}

.brand-logo--light .brand-logo__accent {
  color: #22d3ee;
}

.brand-logo--mono .brand-logo__accent {
  color: currentColor;
}

.brand-logo__descriptor {
  margin-top: 0.52em;
  color: #087c93;
  font-size: 0.43em;
  font-weight: 800;
  letter-spacing: 0.24em;
  white-space: nowrap;
}

.brand-logo--light .brand-logo__descriptor {
  color: #67e8f9;
}
</style>
