<template>
  <div class="h-full flex flex-col space-y-6">
    <!-- Academic Year Banner -->
    <AcademicYearBanner module-name="Alertas DECE" class="no-print" />

    <!-- Header & Stats -->
    <div class="flex flex-col gap-4 no-print">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">Alertas Estudiantiles / DECE</h1>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Gestión de disciplina, asistencia, actas oficiales y firma electrónica</p>
        </div>
        <button 
          @click="openNewAlertModal" 
          class="inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-2.5 sm:py-2 text-sm font-medium text-white hover:bg-indigo-700 shadow-sm transition-colors ring-1 ring-indigo-500/50 gap-2 w-full sm:w-auto"
        >
          <Plus class="w-4 h-4" />
          Nueva Alerta
        </button>
      </div>

      <!-- Stats row -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        <div class="rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 p-3 sm:p-4 shadow-sm">
          <div class="flex items-center gap-3">
            <div class="rounded-lg bg-slate-100 dark:bg-slate-800 p-2 text-slate-600 dark:text-slate-400">
              <ClipboardList class="w-5 h-5" />
            </div>
            <div>
              <p class="text-sm font-medium text-slate-600 dark:text-slate-400">Total Alertas</p>
              <p class="text-2xl font-bold text-slate-900 dark:text-white">{{ stats.total }}</p>
            </div>
          </div>
        </div>
        <div class="rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 p-3 sm:p-4 shadow-sm">
          <div class="flex items-center gap-3">
            <div class="rounded-lg bg-emerald-100 dark:bg-emerald-500/20 p-2 text-emerald-600 dark:text-emerald-400">
              <CheckCircle class="w-5 h-5" />
            </div>
            <div>
              <p class="text-sm font-medium text-slate-600 dark:text-slate-400">Leves</p>
              <p class="text-2xl font-bold text-slate-900 dark:text-white">{{ stats.leve }}</p>
            </div>
          </div>
        </div>
        <div class="rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 p-3 sm:p-4 shadow-sm">
          <div class="flex items-center gap-3">
            <div class="rounded-lg bg-amber-100 dark:bg-amber-500/20 p-2 text-amber-600 dark:text-amber-400">
              <AlertTriangle class="w-5 h-5" />
            </div>
            <div>
              <p class="text-sm font-medium text-slate-600 dark:text-slate-400">Graves</p>
              <p class="text-2xl font-bold text-slate-900 dark:text-white">{{ stats.grave }}</p>
            </div>
          </div>
        </div>
        <div class="rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 p-3 sm:p-4 shadow-sm">
          <div class="flex items-center gap-3">
            <div class="rounded-lg bg-rose-100 dark:bg-rose-500/20 p-2 text-rose-600 dark:text-rose-400">
              <ShieldAlert class="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <p class="text-sm font-medium text-slate-600 dark:text-slate-400">Muy Graves</p>
              <p class="text-2xl font-bold text-slate-900 dark:text-white">{{ stats.muyGrave }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Filters & Table -->
    <div class="flex-1 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 flex flex-col min-h-0 overflow-hidden shadow-sm no-print">
      <!-- Filters -->
      <div class="p-4 border-b border-slate-200 dark:border-slate-800 flex flex-col sm:flex-row gap-4 items-center bg-slate-50 dark:bg-slate-900/80">
        <div class="relative w-full sm:w-64">
          <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400 dark:text-slate-500" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar estudiante..."
            class="w-full pl-9 pr-4 py-2 bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 placeholder-slate-400 dark:placeholder-slate-600 transition-shadow"
          />
        </div>

        <select
          v-model="selectedCourse"
          class="w-full sm:w-48 bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-2 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow appearance-none"
        >
          <option value="">Todos los Cursos</option>
          <option v-for="course in courses" :key="course.id" :value="course.id">
            {{ course.name }}
          </option>
        </select>

        <select
          v-model="selectedQuarter"
          class="w-full sm:w-48 bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-2 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow appearance-none"
        >
          <option value="">Todos los Períodos</option>
          <option v-for="quarter in quarters" :key="quarter.id" :value="quarter.id">
            {{ quarter.name }}
          </option>
        </select>
        
        <select
          v-model="selectedStatus"
          class="w-full sm:w-48 bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-2 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow appearance-none"
        >
          <option value="">Todos los Estados</option>
          <option v-for="(val, key) in ALERT_STATUSES" :key="key" :value="key">
            {{ val.label }}
          </option>
        </select>
      </div>

      <!-- Table Content -->
      <div class="flex-1 overflow-auto custom-scrollbar relative">
        <div v-if="loading" class="absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/50 z-10 backdrop-blur-sm">
          <Loader2 class="w-8 h-8 text-indigo-500 animate-spin" />
        </div>

        <table class="w-full text-left border-collapse min-w-[850px]">
          <thead class="bg-slate-100/90 dark:bg-slate-900/90 sticky top-0 z-10 shadow-sm backdrop-blur-md">
            <tr>
              <th class="px-5 py-3 text-xs font-medium text-slate-600 dark:text-slate-400 uppercase tracking-wider border-b border-slate-200 dark:border-slate-800">Estudiante</th>
              <th class="px-5 py-3 text-xs font-medium text-slate-600 dark:text-slate-400 uppercase tracking-wider border-b border-slate-200 dark:border-slate-800">Tipo de Alerta</th>
              <th class="px-5 py-3 text-xs font-medium text-slate-600 dark:text-slate-400 uppercase tracking-wider border-b border-slate-200 dark:border-slate-800">Gravedad</th>
              <th class="px-5 py-3 text-xs font-medium text-slate-600 dark:text-slate-400 uppercase tracking-wider border-b border-slate-200 dark:border-slate-800">Estado / Firma</th>
              <th class="px-5 py-3 text-xs font-medium text-slate-600 dark:text-slate-400 uppercase tracking-wider border-b border-slate-200 dark:border-slate-800">Fecha</th>
              <th class="px-5 py-3 text-xs font-medium text-slate-600 dark:text-slate-400 uppercase tracking-wider border-b border-slate-200 dark:border-slate-800 text-right">Acciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-200 dark:divide-slate-800">
            <tr v-if="filteredAlerts.length === 0" class="hover:bg-transparent">
              <td colspan="6" class="px-6 py-12 text-center text-slate-500">
                <ShieldAlert class="w-12 h-12 mx-auto mb-3 opacity-30" />
                <p class="font-medium">No se encontraron alertas</p>
              </td>
            </tr>
            <tr 
              v-for="alert in filteredAlerts" 
              :key="alert.id"
              class="hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors group"
            >
              <td class="px-5 py-4">
                <div class="flex items-center gap-3">
                  <div class="w-8 h-8 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center overflow-hidden shrink-0">
                    <img v-if="alert.students?.student_photo_url" :src="alert.students.student_photo_url" :alt="`Foto de ${alert.students?.full_name || 'estudiante'}`" class="w-full h-full object-cover" />
                    <User v-else class="w-4 h-4 text-slate-400 dark:text-slate-500" />
                  </div>
                  <div>
                    <div class="text-sm font-medium text-slate-900 dark:text-slate-200 group-hover:text-indigo-600 dark:group-hover:text-white transition-colors">
                      {{ alert.students?.full_name || 'Desconocido' }}
                    </div>
                    <div class="text-xs text-slate-500">
                      {{ alert.courses?.name || 'Sin curso' }}
                    </div>
                  </div>
                </div>
              </td>
              <td class="px-5 py-4">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium gap-1.5" :class="ALERT_TYPES[alert.alert_type]?.color || 'bg-slate-500/20 text-slate-600 dark:text-slate-400'">
                  {{ ALERT_TYPES[alert.alert_type]?.label || alert.alert_type }}
                </span>
              </td>
              <td class="px-5 py-4">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border" :class="ALERT_SEVERITIES[alert.severity]?.color || 'bg-slate-500/20 text-slate-600 dark:text-slate-400 border-slate-500'">
                  {{ ALERT_SEVERITIES[alert.severity]?.label || alert.severity }}
                </span>
              </td>
              <td class="px-5 py-4">
                <div class="flex flex-col gap-1">
                  <div class="flex items-center gap-1.5">
                    <div class="w-2 h-2 rounded-full" :class="ALERT_STATUSES[alert.status]?.color?.replace('/20', '') || 'bg-slate-500'"></div>
                    <span class="text-xs font-medium text-slate-700 dark:text-slate-300">{{ ALERT_STATUSES[alert.status]?.label || alert.status }}</span>
                  </div>
                  <span v-if="alert.is_digitally_signed" class="inline-flex items-center gap-1 text-[10px] font-bold text-teal-600 dark:text-teal-400">
                    <ShieldCheck class="w-3 h-3" /> Firmada .p12
                  </span>
                </div>
              </td>
              <td class="px-5 py-4 text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap">
                {{ formatDate(alert.date_occurred) }}
              </td>
              <td class="px-5 py-4 text-right">
                <div class="flex items-center justify-end gap-1 sm:gap-1.5">
                  <!-- Print / View Physical Acta -->
                  <button 
                    @click="openPrintModal(alert)"
                    class="p-2 text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/40 rounded-lg transition-colors"
                    title="Imprimir Acta DECE (Físico)"
                  >
                    <Printer class="w-4 h-4" />
                  </button>

                  <!-- Digital Sign -->
                  <button 
                    @click="openSignModal(alert)"
                    class="p-2 text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-950/40 rounded-lg transition-colors"
                    :title="alert.is_digitally_signed ? 'Refirmar con Firma Electrónica' : 'Firmar con Firma Electrónica (.p12)'"
                  >
                    <ShieldCheck class="w-4 h-4" :class="alert.is_digitally_signed ? 'text-teal-600 dark:text-teal-400' : ''" />
                  </button>

                  <!-- Details -->
                  <button 
                    @click="openDetailsModal(alert)"
                    class="p-2 text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-400/10 rounded-lg transition-colors"
                    title="Ver Detalles"
                  >
                    <Eye class="w-4 h-4" />
                  </button>

                  <!-- WhatsApp -->
                  <a 
                    v-if="alert.students?.representative_phone"
                    :href="getWhatsAppLink(alert)"
                    target="_blank"
                    rel="noopener noreferrer"
                    @click="markAsConvocado(alert)"
                    class="p-2 text-slate-400 hover:text-[#25D366] hover:bg-[#25D366]/10 rounded-lg transition-colors"
                    title="Convocar por WhatsApp"
                  >
                    <MessageCircle class="w-4 h-4" />
                  </a>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      
      <!-- Pagination -->
      <div class="p-4 border-t border-slate-200 dark:border-slate-800 flex justify-between items-center bg-slate-50 dark:bg-slate-900/80">
        <span class="text-sm text-slate-500">Mostrando {{ filteredAlerts.length }} alertas</span>
      </div>
    </div>

    <!-- Modals -->
    <!-- New Alert Modal -->
    <div v-if="showNewModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showNewModal = false"></div>
      <div class="relative bg-white dark:bg-slate-900 sm:border border-slate-200 dark:border-slate-800 rounded-t-2xl sm:rounded-2xl w-full max-w-2xl overflow-hidden shadow-2xl flex flex-col max-h-[90dvh] sm:max-h-[90vh]">
        <div class="p-4 sm:p-6 border-b border-slate-200 dark:border-slate-800 flex justify-between items-center bg-slate-50 dark:bg-slate-900/50">
          <h2 class="text-lg sm:text-xl font-bold text-slate-900 dark:text-white">Registrar Nueva Alerta</h2>
          <button @click="showNewModal = false" class="text-slate-400 hover:text-slate-600 dark:hover:text-white transition-colors">
            <X class="w-5 h-5" />
          </button>
        </div>
        
        <div class="p-4 sm:p-6 overflow-y-auto custom-scrollbar flex-1 space-y-4 sm:space-y-6">
          <div v-if="newAlertError" class="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-sm">
            {{ newAlertError }}
          </div>
          
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Course Selection -->
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Curso</label>
              <select
                v-model="newAlert.course_id"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-2.5 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow appearance-none"
                @change="fetchStudentsForNewAlert"
              >
                <option value="" disabled>Seleccione un curso</option>
                <option v-for="course in courses" :key="course.id" :value="course.id">
                  {{ course.name }}
                </option>
              </select>
            </div>
            
            <!-- Student Selection -->
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Estudiante</label>
              <select
                v-model="newAlert.student_id"
                :disabled="!newAlert.course_id || loadingStudents"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-2.5 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow appearance-none disabled:opacity-50"
              >
                <option value="" disabled>{{ loadingStudents ? 'Cargando...' : 'Seleccione un estudiante' }}</option>
                <option v-for="student in currentCourseStudents" :key="student.id" :value="student.id">
                  {{ student.full_name }}
                </option>
              </select>
            </div>
            
            <!-- Alert Type -->
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Tipo de Alerta</label>
              <select
                v-model="newAlert.alert_type"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-2.5 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow appearance-none"
              >
                <option value="" disabled>Seleccione el tipo</option>
                <option v-for="(val, key) in ALERT_TYPES" :key="key" :value="key">
                  {{ val.label }}
                </option>
              </select>
            </div>
            
            <!-- Severity -->
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Gravedad (Art. 330)</label>
              <div class="flex gap-2">
                <button 
                  v-for="(val, key) in ALERT_SEVERITIES" 
                  :key="key"
                  type="button"
                  @click="newAlert.severity = key"
                  class="flex-1 py-2 text-xs font-medium rounded-lg border transition-colors flex items-center justify-center"
                  :class="newAlert.severity === key 
                    ? val.color 
                    : 'bg-slate-100 dark:bg-slate-900 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-800'"
                >
                  {{ val.label }}
                </button>
              </div>
            </div>
            
            <!-- Date Occurred -->
            <div class="space-y-2 md:col-span-2">
              <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Fecha y Hora del Incidente</label>
              <input
                v-model="newAlert.date_occurred"
                type="datetime-local"
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-2.5 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow"
              />
            </div>
            
            <!-- Description -->
            <div class="space-y-2 md:col-span-2">
              <div class="flex items-center justify-between">
                <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Descripción Detallada</label>
                <button 
                  type="button" 
                  @click="startDictation('description')" 
                  class="text-xs flex items-center gap-1.5 px-2.5 py-1 rounded-md transition-colors"
                  :class="isListening 
                    ? 'bg-rose-500/20 text-rose-600 dark:text-rose-400 border border-rose-500/30 shadow-[0_0_10px_rgba(244,63,94,0.2)]' 
                    : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 border border-slate-200 dark:border-slate-700 hover:text-slate-900 dark:hover:text-white hover:bg-slate-200 dark:hover:bg-slate-700'"
                >
                  <Mic class="w-3.5 h-3.5" :class="isListening ? 'animate-pulse' : ''" />
                  {{ isListening ? 'Escuchando...' : 'Dictar' }}
                </button>
              </div>
              <textarea
                v-model="newAlert.description"
                rows="4"
                placeholder="Describa objetivamente los hechos sucedidos..."
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-3 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow resize-none"
              ></textarea>
            </div>
          </div>
        </div>
        
        <div class="p-4 sm:p-6 border-t border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/50 flex flex-col-reverse sm:flex-row justify-end gap-3 pb-8 sm:pb-6">
          <button 
            @click="showNewModal = false"
            class="px-5 py-2.5 text-sm font-medium text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white transition-colors"
          >
            Cancelar
          </button>
          <button 
            @click="saveNewAlert"
            :disabled="savingAlert || !isNewAlertValid"
            class="inline-flex items-center justify-center rounded-xl bg-indigo-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-indigo-700 shadow-sm transition-colors ring-1 ring-indigo-500/50 disabled:opacity-50 disabled:cursor-not-allowed gap-2"
          >
            <Loader2 v-if="savingAlert" class="w-4 h-4 animate-spin" />
            <Save v-else class="w-4 h-4" />
            Guardar Alerta
          </button>
        </div>
      </div>
    </div>

    <!-- Details/Resolution Modal -->
    <div v-if="showDetailsModal && selectedAlert" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showDetailsModal = false"></div>
      <div class="relative bg-white dark:bg-slate-900 sm:border border-slate-200 dark:border-slate-800 rounded-t-2xl sm:rounded-2xl w-full max-w-3xl overflow-hidden shadow-2xl flex flex-col max-h-[90dvh] sm:max-h-[90vh]">
        <div class="p-4 sm:p-6 border-b border-slate-200 dark:border-slate-800 flex justify-between items-center bg-slate-50 dark:bg-slate-900/50">
          <div class="flex items-center gap-2 sm:gap-3 flex-wrap">
            <h2 class="text-lg sm:text-xl font-bold text-slate-900 dark:text-white">Detalle de Alerta</h2>
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border" :class="ALERT_SEVERITIES[selectedAlert.severity]?.color">
              {{ ALERT_SEVERITIES[selectedAlert.severity]?.label }}
            </span>
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium" :class="ALERT_TYPES[selectedAlert.alert_type]?.color">
              {{ ALERT_TYPES[selectedAlert.alert_type]?.label }}
            </span>
            <span v-if="selectedAlert.is_digitally_signed" class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-teal-100 text-teal-800 dark:bg-teal-950/60 dark:text-teal-300 border border-teal-300 dark:border-teal-700 gap-1">
              <ShieldCheck class="w-3.5 h-3.5" /> Firmada Electrónicamente
            </span>
          </div>
          <button @click="showDetailsModal = false" class="text-slate-400 hover:text-slate-600 dark:hover:text-white transition-colors">
            <X class="w-5 h-5" />
          </button>
        </div>
        
        <div class="p-4 sm:p-6 overflow-y-auto custom-scrollbar flex-1 space-y-6 sm:space-y-8">
          <div v-if="detailsError" class="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-sm">
            {{ detailsError }}
          </div>

          <!-- Digital Signature Details Card if signed -->
          <div v-if="selectedAlert.is_digitally_signed && selectedAlert.signature_data" class="p-4 rounded-xl bg-teal-50 dark:bg-teal-950/40 border border-teal-300 dark:border-teal-800 space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold text-teal-900 dark:text-teal-300 flex items-center gap-1.5 uppercase tracking-wider">
                <ShieldCheck class="w-4 h-4 text-teal-600 dark:text-teal-400" />
                Certificación de Firma Digital (.p12)
              </span>
              <span class="text-[10px] text-teal-700 dark:text-teal-400 font-mono">
                {{ formatFullDate(selectedAlert.signature_data.signed_at) }}
              </span>
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs text-slate-700 dark:text-slate-300 pt-1">
              <div><span class="font-semibold text-slate-900 dark:text-white">Firmado por:</span> {{ selectedAlert.signature_data.signer_name }}</div>
              <div><span class="font-semibold text-slate-900 dark:text-white">Entidad Emisora:</span> {{ selectedAlert.signature_data.certificate_issuer }}</div>
              <div class="sm:col-span-2 text-[11px] font-mono text-slate-500 break-all">
                <span class="font-semibold">Huella Digital:</span> {{ selectedAlert.signature_data.certificate_fingerprint }}
              </div>
            </div>
          </div>
          
          <!-- Student Info Card -->
          <div class="bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-4 flex items-start gap-4">
             <div class="w-12 h-12 rounded-full bg-slate-200 dark:bg-slate-800 flex items-center justify-center overflow-hidden shrink-0">
                <img v-if="selectedAlert.students?.student_photo_url" :src="selectedAlert.students.student_photo_url" :alt="`Foto de ${selectedAlert.students?.full_name || 'estudiante'}`" class="w-full h-full object-cover" />
                <User v-else class="w-6 h-6 text-slate-400 dark:text-slate-500" />
              </div>
              <div class="flex-1">
                <h3 class="text-lg font-bold text-slate-900 dark:text-white">{{ selectedAlert.students?.full_name }}</h3>
                <p class="text-sm text-slate-500 dark:text-slate-400">{{ selectedAlert.courses?.name }}</p>
                <div class="mt-2 grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm">
                  <div class="flex flex-col">
                    <span class="text-slate-500 text-xs">Representante</span>
                    <span class="text-slate-800 dark:text-slate-300 font-medium">{{ selectedAlert.students?.representative_name || 'No registrado' }}</span>
                  </div>
                  <div class="flex flex-col">
                    <span class="text-slate-500 text-xs">Teléfono Rep.</span>
                    <span class="text-slate-800 dark:text-slate-300 font-medium">{{ selectedAlert.students?.representative_phone || 'No registrado' }}</span>
                  </div>
                </div>
              </div>
              <div class="flex flex-col gap-2 shrink-0">
                <a 
                  v-if="selectedAlert.students?.representative_phone"
                  :href="getWhatsAppLink(selectedAlert)"
                  target="_blank"
                  rel="noopener noreferrer"
                  @click="markAsConvocado(selectedAlert)"
                  class="inline-flex items-center justify-center gap-2 px-3 py-1.5 rounded-lg bg-[#25D366]/20 text-[#25D366] hover:bg-[#25D366]/30 transition-colors text-xs font-semibold"
                >
                  <MessageCircle class="w-3.5 h-3.5" />
                  Convocar
                </a>
              </div>
          </div>
          
          <!-- Incident Details -->
          <div>
            <h4 class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-3 flex items-center gap-2">
              <FileText class="w-4 h-4 text-slate-500" />
              Reporte del Incidente
            </h4>
            <div class="bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-4 space-y-4">
              <div class="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span class="text-slate-500 text-xs block mb-1">Fecha de Ocurrencia</span>
                  <span class="text-slate-800 dark:text-slate-300 font-medium">{{ formatDate(selectedAlert.date_occurred) }}</span>
                </div>
                <div>
                  <span class="text-slate-500 text-xs block mb-1">Reportado por</span>
                  <span class="text-slate-800 dark:text-slate-300 font-medium">{{ selectedAlert.profiles?.full_name || 'Desconocido' }}</span>
                </div>
              </div>
              <div>
                <span class="text-slate-500 text-xs block mb-1">Descripción</span>
                <p class="text-slate-800 dark:text-slate-300 text-sm leading-relaxed whitespace-pre-wrap">{{ selectedAlert.description }}</p>
              </div>
            </div>
          </div>
          
          <!-- DECE Resolution -->
          <div class="space-y-4">
             <h4 class="text-sm font-medium text-slate-700 dark:text-slate-300 flex items-center gap-2">
              <Briefcase class="w-4 h-4 text-slate-500" />
              Gestión DECE
            </h4>
            
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-600 dark:text-slate-400">Estado de la Alerta</label>
              <div class="flex flex-wrap gap-2">
                <button 
                  v-for="(val, key) in ALERT_STATUSES" 
                  :key="key"
                  type="button"
                  @click="selectedAlert.status = key"
                  class="px-3 py-1.5 text-xs font-medium rounded-full border transition-colors flex items-center gap-1.5"
                  :class="selectedAlert.status === key 
                    ? val.color.replace('/20', '/30') + ' border-' + val.color.split(' ')[1].split('-')[0] + '-500/50'
                    : 'bg-slate-100 dark:bg-slate-900 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-800'"
                >
                  <div class="w-1.5 h-1.5 rounded-full" :class="val.color.split(' ')[0].replace('/20', '')"></div>
                  {{ val.label }}
                </button>
              </div>
            </div>
            
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-600 dark:text-slate-400">Notas / Seguimiento DECE</label>
              <textarea
                v-model="selectedAlert.dece_notes"
                rows="3"
                placeholder="Registro de entrevistas, llamadas, observaciones..."
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-3 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow resize-none"
              ></textarea>
            </div>
            
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-600 dark:text-slate-400">Resolución / Compromiso</label>
              <textarea
                v-model="selectedAlert.resolution"
                rows="3"
                placeholder="Acuerdos firmados, medidas adoptadas..."
                class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-4 py-3 text-sm text-slate-900 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-shadow resize-none"
              ></textarea>
            </div>
          </div>
        </div>
        
        <div class="p-4 sm:p-6 border-t border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/50 flex flex-wrap justify-between items-center gap-3">
          <div class="flex items-center gap-2">
            <!-- Print Physical Acta -->
            <button
              type="button"
              @click="openPrintModal(selectedAlert)"
              class="px-4 py-2 text-xs font-bold text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/50 hover:bg-teal-100 border border-teal-200 dark:border-teal-800 rounded-xl transition-colors flex items-center gap-1.5 shadow-sm"
            >
              <Printer class="w-3.5 h-3.5" />
              <span>Imprimir Físico</span>
            </button>

            <!-- Sign .p12 -->
            <button
              type="button"
              @click="openSignModal(selectedAlert)"
              class="px-4 py-2 text-xs font-bold text-indigo-700 dark:text-indigo-300 bg-indigo-50 dark:bg-indigo-950/50 hover:bg-indigo-100 border border-indigo-200 dark:border-indigo-800 rounded-xl transition-colors flex items-center gap-1.5 shadow-sm"
            >
              <ShieldCheck class="w-3.5 h-3.5" />
              <span>{{ selectedAlert.is_digitally_signed ? 'Refirmar .p12' : 'Firmar .p12' }}</span>
            </button>
          </div>

          <div class="flex items-center gap-2">
            <button 
              @click="showDetailsModal = false"
              class="px-4 py-2 text-xs font-medium text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white transition-colors"
            >
              Cerrar
            </button>
            <button 
              @click="saveDetails"
              :disabled="savingDetails"
              class="inline-flex items-center justify-center rounded-xl bg-indigo-600 px-5 py-2 text-xs font-bold text-white hover:bg-indigo-700 shadow-sm transition-colors ring-1 ring-indigo-500/50 disabled:opacity-50 disabled:cursor-not-allowed gap-2"
            >
              <Loader2 v-if="savingDetails" class="w-3.5 h-3.5 animate-spin" />
              <Save v-else class="w-3.5 h-3.5" />
              Actualizar Alerta
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Print Modal (Physical / Digital preview) -->
    <DecePrintModal
      :show="showPrintModal"
      :alert-data="alertForPrint"
      :institution-name="institutionName"
      :institution-logo-url="institutionLogoUrl"
      :institution-tutor-name="institutionTutorName"
      :selected-academic-year="academicYearStore.selectedYearName"
      @close="showPrintModal = false"
      @open-sign="openSignFromPrint"
    />

    <!-- Digital Sign Modal (.p12 / .pfx) -->
    <DeceDigitalSignModal
      :show="showSignModal"
      :alert-data="alertForSign"
      @close="showSignModal = false"
      @signed="handleAlertSigned"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { normalizeStoragePath, resolvePrivateImageUrl } from '../lib/storageUtils'
import { useAuthStore } from '../stores/auth'
import { useAcademicYearStore } from '../stores/academicYear'
import { useCoursesQuery, useQuartersQuery } from '../composables/useQueries'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'
import DecePrintModal from '../components/dece/DecePrintModal.vue'
import DeceDigitalSignModal from '../components/dece/DeceDigitalSignModal.vue'
import { toast } from 'vue-sonner'
import { 
  ALERT_TYPES, 
  ALERT_SEVERITIES, 
  ALERT_STATUSES, 
  generateWhatsAppMessage 
} from '../lib/alertTypes'

// Icons
import { 
  Plus, Search, User, Eye, MessageCircle, FileText, Briefcase,
  ShieldAlert, ClipboardList, CheckCircle, AlertTriangle, Loader2, Save, X, Mic,
  Printer, ShieldCheck
} from 'lucide-vue-next'

const authStore = useAuthStore()
const academicYearStore = useAcademicYearStore()

// Queries
const { data: coursesData } = useCoursesQuery(computed(() => academicYearStore.selectedYearName))
const courses = computed(() => coursesData.value || [])

const { data: quartersData } = useQuartersQuery()
const quarters = computed(() => quartersData.value || [])

const activeQuarter = computed(() => {
  return quarters.value.find(q => q.is_active)?.id || quarters.value[0]?.id || ''
})

// Filters
const selectedCourse = ref('')
const selectedQuarter = ref('')
const selectedStatus = ref('')
const searchQuery = ref('')

// Data
const alerts = ref([])
const loading = ref(false)
const institutionName = ref('Nuestra Institución')
const institutionLogoUrl = ref('')
const institutionTutorName = ref('')
const institutionRectorName = ref('')

// Print & Signature Modals State
const showPrintModal = ref(false)
const alertForPrint = ref(null)
const showSignModal = ref(false)
const alertForSign = ref(null)

// Derived
const filteredAlerts = computed(() => {
  let result = alerts.value

  if (selectedCourse.value) {
    result = result.filter(a => a.course_id === selectedCourse.value)
  }
  if (selectedQuarter.value) {
    result = result.filter(a => a.quarter_id === selectedQuarter.value)
  }
  if (selectedStatus.value) {
    result = result.filter(a => a.status === selectedStatus.value)
  }
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    result = result.filter(a => 
      a.students?.full_name?.toLowerCase().includes(q) ||
      a.description?.toLowerCase().includes(q)
    )
  }

  return result
})

const stats = computed(() => {
  const current = filteredAlerts.value
  return {
    total: current.length,
    leve: current.filter(a => a.severity === 'LEVE').length,
    grave: current.filter(a => a.severity === 'GRAVE').length,
    muyGrave: current.filter(a => a.severity === 'MUY_GRAVE').length
  }
})

// Fetch Data
const fetchAlerts = async () => {
  loading.value = true
  try {
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    let query = supabase
      .from('student_alerts')
      .select(`
        *,
        students (id, full_name, student_cedula, student_photo_url, representative_name, representative_cedula, representative_phone),
        courses (id, name, academic_year),
        profiles (id, full_name)
      `)
      .order('created_at', { ascending: false })

    if (sId) {
      query = query.or(`school_id.eq.${sId},school_id.is.null`)
    }

    const { data, error } = await query
    if (error) throw error

    alerts.value = await Promise.all((data || []).map(async (alert) => {
      if (!alert.students?.student_photo_url) return alert
      return {
        ...alert,
        students: {
          ...alert.students,
          student_photo_url: await resolvePrivateImageUrl(
            supabase,
            'student-photos',
            normalizeStoragePath(alert.students.student_photo_url, 'student-photos'),
          ).catch(() => ''),
        },
      }
    }))
  } catch (e) {
    console.error('Error fetching alerts:', e)
  } finally {
    loading.value = false
  }
}

const fetchInstitutionConfig = async () => {
  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!sId) return
  const { data, error } = await supabase
    .from('system_config')
    .select('key, value')
    .eq('school_id', sId)
    .in('key', ['institution_name', 'institution_logo_url', 'institution_tutor_name', 'institution_rector_name'])
  
  if (!error && data) {
    const map = Object.fromEntries(data.map(item => [item.key, item.value]))
    if (map.institution_name) institutionName.value = map.institution_name
    institutionTutorName.value = map.institution_tutor_name || ''
    institutionRectorName.value = map.institution_rector_name || ''
    if (map.institution_logo_url) {
      institutionLogoUrl.value = await resolvePrivateImageUrl(
        supabase,
        'institution-assets',
        normalizeStoragePath(map.institution_logo_url, 'institution-assets'),
      ).catch(() => '')
    }
  }
}

// Print & Signature Handlers
const openPrintModal = (alert) => {
  alertForPrint.value = alert
  showPrintModal.value = true
}

const openSignModal = (alert) => {
  alertForSign.value = alert
  showSignModal.value = true
}

const openSignFromPrint = () => {
  if (alertForPrint.value) {
    showPrintModal.value = false
    openSignModal(alertForPrint.value)
  }
}

const handleAlertSigned = async ({ signatureData }) => {
  if (!alertForSign.value?.id) return
  
  const targetId = alertForSign.value.id
  const userId = authStore.user?.id || authStore.profile?.id

  try {
    const updatePayload = {
      is_digitally_signed: true,
      signature_data: signatureData,
      signed_at: signatureData.signed_at,
      signed_by: userId || null
    }

    const { error } = await supabase
      .from('student_alerts')
      .update(updatePayload)
      .eq('id', targetId)

    if (error) throw error

    // Actualizar estado reactivo local
    const index = alerts.value.findIndex(a => a.id === targetId)
    if (index !== -1) {
      alerts.value[index] = {
        ...alerts.value[index],
        ...updatePayload
      }
    }

    if (selectedAlert.value && selectedAlert.value.id === targetId) {
      selectedAlert.value = {
        ...selectedAlert.value,
        ...updatePayload
      }
    }

    if (alertForPrint.value && alertForPrint.value.id === targetId) {
      alertForPrint.value = {
        ...alertForPrint.value,
        ...updatePayload
      }
    }

    showSignModal.value = false
    toast.success('Documento firmado con éxito', {
      description: `Acta DECE firmada electrónicamente por ${signatureData.signer_name}.`
    })

    // Reabrir modal de impresión con la firma digital plasmada
    setTimeout(() => {
      openPrintModal(alerts.value[index] || selectedAlert.value)
    }, 300)
  } catch (err) {
    console.error('Error al guardar firma electrónica en base de datos:', err)
    toast.error('Error al registrar la firma', {
      description: err.message || 'No se pudo guardar la firma digital.'
    })
  }
}

// New Alert Modal
const showNewModal = ref(false)
const savingAlert = ref(false)
const newAlertError = ref('')
const currentCourseStudents = ref([])
const loadingStudents = ref(false)

// Speech Recognition (Dictation)
const isListening = ref(false)

const startDictation = (field = 'description') => {
  if (isListening.value) return
  
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
  if (!SpeechRecognition) {
    alert("Tu navegador no soporta el dictado por voz. Recomendamos usar Chrome o Edge.")
    return
  }

  const recognition = new SpeechRecognition()
  recognition.lang = 'es-EC'
  recognition.interimResults = false
  recognition.maxAlternatives = 1

  recognition.onstart = () => {
    isListening.value = true
  }

  recognition.onresult = (event) => {
    const transcript = event.results[0][0].transcript
    const formattedTranscript = transcript.charAt(0).toUpperCase() + transcript.slice(1)
    
    if (newAlert.value[field]) {
      const currentText = newAlert.value[field].trim()
      const separator = (currentText.endsWith('.') || currentText.endsWith(',')) ? ' ' : '. '
      newAlert.value[field] = currentText + separator + formattedTranscript
    } else {
      newAlert.value[field] = formattedTranscript
    }
  }

  recognition.onerror = (event) => {
    console.error("Error en reconocimiento de voz:", event.error)
    if (event.error !== 'no-speech') {
      newAlertError.value = "Error al acceder al micrófono. Revise los permisos de su navegador."
    }
    isListening.value = false
  }

  recognition.onend = () => {
    isListening.value = false
  }

  recognition.start()
}

const getInitialNewAlert = () => ({
  course_id: selectedCourse.value || '',
  student_id: '',
  quarter_id: activeQuarter.value,
  alert_type: '',
  severity: 'LEVE',
  date_occurred: new Date().toISOString().slice(0, 16),
  description: ''
})
const newAlert = ref(getInitialNewAlert())

const isNewAlertValid = computed(() => {
  return newAlert.value.course_id && 
         newAlert.value.student_id && 
         newAlert.value.alert_type && 
         newAlert.value.description.trim().length > 5
})

const openNewAlertModal = () => {
  newAlertError.value = ''
  newAlert.value = getInitialNewAlert()
  if (newAlert.value.course_id) {
    fetchStudentsForNewAlert()
  }
  showNewModal.value = true
}

const fetchStudentsForNewAlert = async () => {
  if (!newAlert.value.course_id) return
  loadingStudents.value = true
  newAlert.value.student_id = ''
  
  try {
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    let query = supabase
      .from('students')
      .select('id, full_name')
      .eq('course_id', newAlert.value.course_id)
      .order('full_name')

    if (sId) {
      query = query.or(`school_id.eq.${sId},school_id.is.null`)
    }
      
    const { data, error } = await query
    if (error) throw error
    currentCourseStudents.value = data || []
  } catch (e) {
    console.error(e)
  } finally {
    loadingStudents.value = false
  }
}

const saveNewAlert = async () => {
  if (!isNewAlertValid.value) return
  
  savingAlert.value = true
  newAlertError.value = ''
  
  try {
    if (!newAlert.value.quarter_id) {
      newAlert.value.quarter_id = activeQuarter.value
    }
    
    if (!newAlert.value.quarter_id) {
      throw new Error("No hay un periodo (quimestre/trimestre) activo. Por favor configure uno en el panel de Periodos.")
    }

    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    const alertData = {
      ...newAlert.value,
      school_id: sId || authStore.activeSchoolId,
      reported_by: authStore.user.id,
      status: 'PENDIENTE',
      date_occurred: new Date(newAlert.value.date_occurred).toISOString()
    }
    
    const { error } = await supabase
      .from('student_alerts')
      .insert([alertData])
      
    if (error) throw error
    
    showNewModal.value = false
    toast.success('Alerta registrada con éxito')
    fetchAlerts()
  } catch (e) {
    newAlertError.value = e.message || 'Error al guardar la alerta'
  } finally {
    savingAlert.value = false
  }
}

// Details Modal
const showDetailsModal = ref(false)
const selectedAlert = ref(null)
const savingDetails = ref(false)
const detailsError = ref('')

const openDetailsModal = (alert) => {
  selectedAlert.value = JSON.parse(JSON.stringify(alert))
  detailsError.value = ''
  showDetailsModal.value = true
}

const saveDetails = async () => {
  savingDetails.value = true
  detailsError.value = ''
  
  try {
    const updateData = {
      status: selectedAlert.value.status,
      dece_notes: selectedAlert.value.dece_notes,
      resolution: selectedAlert.value.resolution
    }
    
    const { error } = await supabase
      .from('student_alerts')
      .update(updateData)
      .eq('id', selectedAlert.value.id)
      
    if (error) throw error
    
    const index = alerts.value.findIndex(a => a.id === selectedAlert.value.id)
    if (index !== -1) {
      alerts.value[index] = { ...alerts.value[index], ...updateData }
    }
    
    showDetailsModal.value = false
    toast.success('Alerta actualizada correctamente')
  } catch (e) {
    detailsError.value = e.message || 'Error al actualizar'
  } finally {
    savingDetails.value = false
  }
}

// WhatsApp Integration
const getWhatsAppLink = (alert) => {
  if (!alert.students?.representative_phone) return '#'
  
  let phone = alert.students.representative_phone.replace(/\D/g, '')
  if (phone.length === 10 && phone.startsWith('09')) {
    phone = '593' + phone.substring(1)
  }
  
  const alertDataForMessage = {
    student_name: alert.students?.full_name || 'Estudiante',
    alert_type: alert.alert_type,
    date_occurred: alert.date_occurred,
    severity: alert.severity,
    description: alert.description
  }
  
  const text = generateWhatsAppMessage(alertDataForMessage, institutionName.value)
  return `https://wa.me/${phone}?text=${text}`
}

const markAsConvocado = async (alert) => {
  if (alert.status !== 'RESUELTO' && alert.status !== 'ARCHIVADO') {
    const { error } = await supabase
      .from('student_alerts')
      .update({ 
        status: 'CONVOCADO', 
        whatsapp_sent_at: new Date().toISOString() 
      })
      .eq('id', alert.id)
      
    if (!error) {
       const index = alerts.value.findIndex(a => a.id === alert.id)
       if (index !== -1) alerts.value[index].status = 'CONVOCADO'
       
       if (selectedAlert.value && selectedAlert.value.id === alert.id) {
         selectedAlert.value.status = 'CONVOCADO'
       }
    }
  }
}

// Utils
const formatDate = (dateString) => {
  if (!dateString) return ''
  return new Date(dateString).toLocaleDateString('es-EC', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const formatFullDate = (dateString) => {
  if (!dateString) return ''
  return new Date(dateString).toLocaleDateString('es-EC', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

onMounted(() => {
  fetchInstitutionConfig()
  fetchAlerts()
  
  watch(activeQuarter, (newVal) => {
    if (newVal && !selectedQuarter.value) {
      selectedQuarter.value = newVal
    }
  }, { immediate: true })
})
</script>
