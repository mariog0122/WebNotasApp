<template>
  <div v-if="store.socraticDrawer.isOpen" class="fixed inset-0 z-50 overflow-hidden">
    <!-- Backdrop -->
    <div 
      class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm transition-opacity"
      @click="store.closeSocraticTutor()"
    ></div>

    <div class="fixed inset-y-0 right-0 max-w-full flex pl-10">
      <div class="w-screen max-w-md bg-white dark:bg-slate-900 shadow-2xl flex flex-col border-l border-slate-200 dark:border-slate-800">
        <!-- Drawer Header -->
        <div class="p-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-gradient-to-r from-indigo-50 to-purple-50 dark:from-slate-800/80 dark:to-indigo-950/40">
          <div class="flex items-center space-x-3">
            <div class="w-9 h-9 rounded-xl bg-indigo-600 flex items-center justify-center text-white shadow-md shadow-indigo-600/20">
              <Sparkles class="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <h3 class="font-bold text-slate-800 dark:text-white text-base">Tutor Socrático</h3>
              <p class="text-xs text-indigo-600 dark:text-indigo-400 font-medium">Guía de razonamiento sin respuestas directas</p>
            </div>
          </div>
          <button 
            @click="store.closeSocraticTutor()"
            class="p-2 text-slate-400 hover:text-slate-600 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Problem Context Banner -->
        <div v-if="store.socraticDrawer.currentItemContext" class="p-3 bg-amber-50 dark:bg-amber-950/30 border-b border-amber-200/60 dark:border-amber-900/50 text-xs text-amber-800 dark:text-amber-300 flex items-start space-x-2">
          <Lightbulb class="w-4 h-4 text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
          <div>
            <span class="font-semibold">Ejercicio en análisis:</span>
            <p class="mt-0.5 line-clamp-2">{{ store.socraticDrawer.currentItemContext.stem }}</p>
          </div>
        </div>

        <!-- Chat Conversation Area -->
        <div class="flex-1 p-4 overflow-y-auto space-y-3 bg-slate-50/50 dark:bg-slate-900/50" ref="chatContainer">
          <div 
            v-for="msg in store.socraticDrawer.messages" 
            :key="msg.id"
            :class="['flex', msg.sender === 'user' ? 'justify-end' : 'justify-start']"
          >
            <div 
              :class="[
                'max-w-[85%] rounded-2xl px-4 py-2.5 text-sm shadow-sm transition-all',
                msg.sender === 'user'
                  ? 'bg-indigo-600 text-white rounded-br-none'
                  : 'bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 border border-slate-200/80 dark:border-slate-700/80 rounded-bl-none'
              ]"
            >
              <div v-if="msg.isLoading" class="flex items-center space-x-2 text-indigo-600 dark:text-indigo-400 py-1">
                <span class="inline-block w-2 h-2 rounded-full bg-indigo-500 animate-bounce"></span>
                <span class="inline-block w-2 h-2 rounded-full bg-indigo-500 animate-bounce [animation-delay:0.2s]"></span>
                <span class="inline-block w-2 h-2 rounded-full bg-indigo-500 animate-bounce [animation-delay:0.4s]"></span>
                <span class="text-xs font-medium ml-1">Analizando tu razonamiento...</span>
              </div>
              <div v-else>
                <p class="whitespace-pre-line">{{ msg.text }}</p>
                <div v-if="msg.isAntiCheatApplied" class="mt-2 flex items-center text-[10px] text-amber-700 dark:text-amber-300 font-semibold bg-amber-100 dark:bg-amber-950/60 px-2 py-0.5 rounded-md w-fit">
                  <span class="mr-1">🛡️</span> Andamiaje Socrático Activo
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Socratic Quick Nudges -->
        <div class="p-2 border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex flex-wrap gap-1.5">
          <button 
            @click="sendQuickNudge('¿Me puedes dar una pista para empezar?')"
            class="text-xs px-2.5 py-1 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-indigo-50 hover:text-indigo-600 dark:hover:bg-indigo-950/50 dark:hover:text-indigo-300 border border-slate-200 dark:border-slate-700 transition"
          >
            💡 Dame una pista
          </button>
          <button 
            @click="sendQuickNudge('¿Qué operación básica necesito repasar para esto?')"
            class="text-xs px-2.5 py-1 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-indigo-50 hover:text-indigo-600 dark:hover:bg-indigo-950/50 dark:hover:text-indigo-300 border border-slate-200 dark:border-slate-700 transition"
          >
            🔍 Prerrequisito
          </button>
          <button 
            @click="sendQuickNudge('¿Cómo puedo verificar si mi respuesta tiene sentido?')"
            class="text-xs px-2.5 py-1 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-indigo-50 hover:text-indigo-600 dark:hover:bg-indigo-950/50 dark:hover:text-indigo-300 border border-slate-200 dark:border-slate-700 transition"
          >
            ✅ ¿Cómo verificar?
          </button>
        </div>

        <!-- Message Input -->
        <div class="p-3 border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
          <form @submit.prevent="handleSend" class="flex items-center space-x-2">
            <input 
              v-model="userInput" 
              type="text" 
              placeholder="Explica tu duda o tu intento..."
              class="flex-1 px-3.5 py-2 text-sm rounded-xl border border-slate-300 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <button 
              type="submit" 
              :disabled="!userInput.trim()"
              class="p-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl shadow disabled:opacity-50 transition"
            >
              <Send class="w-4 h-4" />
            </button>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useIntelligenceStore } from '../../stores/useIntelligenceStore'
import { Sparkles, X, Lightbulb, Send } from 'lucide-vue-next'

const store = useIntelligenceStore()
const userInput = ref('')

function handleSend() {
  if (!userInput.value.trim()) return
  store.sendSocraticMessage(userInput.value)
  userInput.value = ''
}

function sendQuickNudge(text) {
  store.sendSocraticMessage(text)
}
</script>
