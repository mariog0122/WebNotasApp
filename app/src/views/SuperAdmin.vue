<script setup>
import { ref } from 'vue'
import { LayoutDashboard, Building2, UserPlus, Users, ShieldCheck, Activity, Sparkles } from 'lucide-vue-next'

import OverviewTab from './superadmin/OverviewTab.vue'
import TenantsTab from './superadmin/TenantsTab.vue'
import WizardTab from './superadmin/WizardTab.vue'
import UsersTab from '../modules/superadmin/users/UsersTab.vue'
import AuditTab from './superadmin/AuditTab.vue'
import HealthTab from './superadmin/HealthTab.vue'
import AIImprovementCenterTab from './superadmin/AIImprovementCenterTab.vue'

const activeTab = ref('overview')
</script>

<template>
  <div class="p-4 md:p-8 max-w-7xl mx-auto space-y-6">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-slate-200 dark:border-slate-800/80 pb-5">
      <div>
        <h1 class="text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight flex items-center gap-3">
          Centro de Comando SaaS
          <span class="text-xs font-mono font-semibold uppercase tracking-widest px-2.5 py-1 rounded-md bg-indigo-50 dark:bg-indigo-500/10 text-indigo-700 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-500/20">
            Consola Multi-Institución
          </span>
        </h1>
        <p class="text-slate-600 dark:text-slate-400 text-sm mt-1">Gestión integral de instituciones, suscripciones, seguridad, límites y auditoría.</p>
      </div>

      <div class="flex items-center gap-2">
        <button 
          @click="activeTab = 'wizard'"
          class="px-4 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center gap-2 transition-all shadow-md shadow-indigo-600/20 cursor-pointer"
        >
          <UserPlus class="w-4 h-4" /> Alta de Institución
        </button>
      </div>
    </div>

    <!-- Navigation Tabs -->
    <div class="flex overflow-x-auto space-x-2 border-b border-slate-200 dark:border-slate-800 pb-2 custom-scrollbar-main">
      <button 
        @click="activeTab = 'overview'" 
        :class="['px-4 py-2.5 font-bold text-sm rounded-xl flex items-center gap-2 transition-all whitespace-nowrap cursor-pointer', activeTab === 'overview' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-800/50 dark:hover:text-white']"
      >
        <LayoutDashboard class="w-4 h-4" />
        Vista General
      </button>

      <button 
        @click="activeTab = 'tenants'" 
        :class="['px-4 py-2.5 font-bold text-sm rounded-xl flex items-center gap-2 transition-all whitespace-nowrap cursor-pointer', activeTab === 'tenants' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-800/50 dark:hover:text-white']"
      >
        <Building2 class="w-4 h-4" />
        Instituciones
      </button>

      <button 
        @click="activeTab = 'wizard'" 
        :class="['px-4 py-2.5 font-bold text-sm rounded-xl flex items-center gap-2 transition-all whitespace-nowrap cursor-pointer', activeTab === 'wizard' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-800/50 dark:hover:text-white']"
      >
        <UserPlus class="w-4 h-4" />
        Asistente de Registro
      </button>

      <button
        @click="activeTab = 'users'"
        :class="['px-4 py-2.5 font-bold text-sm rounded-xl flex items-center gap-2 transition-all whitespace-nowrap cursor-pointer', activeTab === 'users' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-800/50 dark:hover:text-white']"
      >
        <Users class="w-4 h-4" />
        Usuarios
      </button>

      <button 
        @click="activeTab = 'audit'" 
        :class="['px-4 py-2.5 font-bold text-sm rounded-xl flex items-center gap-2 transition-all whitespace-nowrap cursor-pointer', activeTab === 'audit' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-800/50 dark:hover:text-white']"
      >
        <ShieldCheck class="w-4 h-4" />
        Auditoría y Registros
      </button>

      <button 
        @click="activeTab = 'health'" 
        :class="['px-4 py-2.5 font-bold text-sm rounded-xl flex items-center gap-2 transition-all whitespace-nowrap cursor-pointer', activeTab === 'health' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-800/50 dark:hover:text-white']"
      >
        <Activity class="w-4 h-4" />
        Monitoreo del Sistema
      </button>

      <button 
        @click="activeTab = 'ai-improvement'" 
        :class="['px-4 py-2.5 font-bold text-sm rounded-xl flex items-center gap-2 transition-all whitespace-nowrap cursor-pointer', activeTab === 'ai-improvement' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-800/50 dark:hover:text-white']"
      >
        <Sparkles class="w-4 h-4" />
        AI Improvement Center
      </button>
    </div>

    <!-- Tab View Components -->
    <div class="pt-2">
      <OverviewTab v-if="activeTab === 'overview'" />
      <TenantsTab v-else-if="activeTab === 'tenants'" />
      <WizardTab v-else-if="activeTab === 'wizard'" @completed="activeTab = 'tenants'" />
      <UsersTab v-else-if="activeTab === 'users'" />
      <AuditTab v-else-if="activeTab === 'audit'" />
      <HealthTab v-else-if="activeTab === 'health'" />
      <AIImprovementCenterTab v-else-if="activeTab === 'ai-improvement'" />
    </div>
  </div>
</template>
