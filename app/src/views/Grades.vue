<script setup>
import { provide } from 'vue'
import GradesInstitutionHero from '../components/grades/GradesInstitutionHero.vue'
import GradesFiltersPanel from '../components/grades/GradesFiltersPanel.vue'
import GradesTermSummaryCard from '../components/grades/GradesTermSummaryCard.vue'
import GradesSubjectsSection from '../components/grades/GradesSubjectsSection.vue'
import GradesColumnRenameModal from '../components/grades/GradesColumnRenameModal.vue'
import GradesProjectModal from '../components/grades/GradesProjectModal.vue'
import { useGradesPage, gradesPageInjectionKey } from '../composables/useGradesPage'

const gp = useGradesPage()
provide(gradesPageInjectionKey, gp)
</script>

<template>
  <div class="app-shell">
    <main class="app-container">
      <GradesInstitutionHero />
      <GradesFiltersPanel />
      <GradesTermSummaryCard />
      <GradesSubjectsSection />
    </main>

    <GradesColumnRenameModal />
    <GradesProjectModal />
  </div>
</template>

<style scoped>
@media print {
  :deep(nav) {
    display: none !important;
  }
}
</style>

<style>
@media print {
  body,
  html {
    background: white !important;
  }
}
</style>
