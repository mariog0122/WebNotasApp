<script setup>
defineProps({
  rows: {
    type: Number,
    default: 5
  },
  columns: {
    type: Number,
    default: 4
  }
})
</script>

<template>
  <div class="w-full bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden shadow-sm">
    <!-- Header Skeleton -->
    <div class="flex items-center gap-4 p-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50">
      <div 
        v-for="col in columns" 
        :key="'header-'+col" 
        class="h-4 bg-slate-200 dark:bg-slate-700 rounded-md animate-pulse"
        :style="{ width: `${100/columns}%` }"
      ></div>
    </div>
    
    <!-- Rows Skeleton -->
    <div class="flex flex-col">
      <div 
        v-for="row in rows" 
        :key="'row-'+row"
        class="flex items-center gap-4 p-4 border-b border-slate-100 dark:border-slate-800/60 last:border-0"
      >
        <div 
          v-for="col in columns" 
          :key="'cell-'+row+'-'+col" 
          class="h-10 bg-slate-100 dark:bg-slate-700/50 rounded-lg animate-pulse"
          :style="{ width: `${100/columns}%`, animationDelay: `${(row * 100) + (col * 50)}ms` }"
        ></div>
      </div>
    </div>
  </div>
</template>
