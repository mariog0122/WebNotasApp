<script setup>
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useNetwork } from '../composables/useNetwork'
import { useAuthStore } from '../stores/auth'
import { useSubjectsQuery } from '../composables/useQueries'
import { useQueryClient } from '@tanstack/vue-query'
import { exportSubjectsToExcel, downloadSubjectsTemplate } from '../lib/exportUtils'
import SkeletonTable from '../components/ui/SkeletonTable.vue'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'

const showModal = ref(false)
const showImportModal = ref(false)
const editingSubject = ref(null)
const { isOnline } = useNetwork()
const authStore = useAuthStore()
const queryClient = useQueryClient()

const subjectsQuery = useSubjectsQuery()
const subjects = computed(() => subjectsQuery.data.value || [])
const loading = computed(() => subjectsQuery.isLoading.value)

const searchQuery = ref('')
const filteredSubjects = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return subjects.value
  return subjects.value.filter(s => s.name.toLowerCase().includes(q))
})

const form = ref({
  name: ''
})

// --- Import Modal State ---
const importFileInput = ref(null)
const importFile = ref(null)
const importFileName = ref('')
const importParsing = ref(false)
const importProcessing = ref(false)
const importParsedSubjects = ref([])
const importErrors = ref([])
const importSuccessMsg = ref('')

const openModal = (subject = null) => {
  editingSubject.value = subject
  if (subject) {
    form.value = { ...subject }
  } else {
    form.value = {
      name: ''
    }
  }
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editingSubject.value = null
}

const openImportModal = () => {
  importFile.value = null
  importFileName.value = ''
  importParsedSubjects.value = []
  importErrors.value = []
  importSuccessMsg.value = ''
  showImportModal.value = true
}

const closeImportModal = () => {
  showImportModal.value = false
  importFile.value = null
  importFileName.value = ''
  importParsedSubjects.value = []
  importErrors.value = []
  importSuccessMsg.value = ''
}

const confirmModal = ref({
  show: false,
  title: '',
  message: '',
  action: null,
  processing: false
})

const closeConfirmModal = () => {
  confirmModal.value.show = false
}

const executeConfirmAction = async () => {
  if (confirmModal.value.action) {
    confirmModal.value.processing = true
    await confirmModal.value.action()
    confirmModal.value.processing = false
    confirmModal.value.show = false
  }
}

const saveSubject = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!sId) {
    alert('No hay una institución activa seleccionada.')
    return
  }
  try {
    const payload = { name: form.value.name.trim(), school_id: sId }
    if (!payload.name) throw new Error('El nombre de la asignatura no puede estar vacío.')

    if (editingSubject.value) {
      const { error } = await supabase
        .from('subjects')
        .update(payload)
        .eq('id', editingSubject.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase
        .from('subjects')
        .insert(payload)
      if (error) throw error
    }
    await queryClient.invalidateQueries({ queryKey: ['subjects'] })
    closeModal()
  } catch (error) {
    confirmModal.value = {
      show: true,
      title: 'Error',
      message: 'Error guardando asignatura: ' + error.message,
      processing: false,
      action: null
    }
  }
}

const deleteSubject = async (id) => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  confirmModal.value = {
    show: true,
    title: 'Eliminar Asignatura',
    message: '¿Estás seguro de eliminar esta asignatura? Se desvinculará de los cursos donde esté asignada.',
    processing: false,
    action: async () => {
      try {
        let query = supabase.from('subjects').delete().eq('id', id)
        if (sId) {
          query = query.eq('school_id', sId)
        }
        const { error } = await query
        if (error) throw error
        await queryClient.invalidateQueries({ queryKey: ['subjects'] })
      } catch (error) {
        confirmModal.value = {
          show: true,
          title: 'Error',
          message: 'Error eliminando asignatura: ' + error.message,
          processing: false,
          action: null
        }
      }
    }
  }
}

// --- Excel Import Logic ---
const normalizeHeader = (val) => {
  return String(val || '')
    .trim()
    .toUpperCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
}

const parseExcelFile = async (file) => {
  importParsing.value = true
  importErrors.value = []
  importParsedSubjects.value = []
  importSuccessMsg.value = ''

  try {
    const fileName = file.name.toLowerCase()
    let rawRows = []

    if (fileName.endsWith('.csv') || fileName.endsWith('.txt')) {
      const text = await file.text()
      const lines = text.split(/\r\n|\n|\r/).filter(l => l.trim().length > 0)
      rawRows = lines.map(line => {
        let delimiter = ','
        const commaCount = (line.match(/,/g) || []).length
        const semiCount = (line.match(/;/g) || []).length
        const tabCount = (line.match(/\t/g) || []).length
        const pipeCount = (line.match(/\|/g) || []).length
        if (semiCount > commaCount) delimiter = ';'
        else if (tabCount > commaCount) delimiter = '\t'
        else if (pipeCount > commaCount) delimiter = '|'

        // Parse CSV with quotes handling
        const row = []
        let current = ''
        let inQuotes = false
        for (let i = 0; i < line.length; i++) {
          const char = line[i]
          if (char === '"') {
            inQuotes = !inQuotes
          } else if (char === delimiter && !inQuotes) {
            row.push(current.trim().replace(/^["']|["']$/g, ''))
            current = ''
          } else {
            current += char
          }
        }
        row.push(current.trim().replace(/^["']|["']$/g, ''))
        return row
      })
    } else {
      const { default: readXlsxFile } = await import('read-excel-file/browser')
      rawRows = await readXlsxFile(file)
    }

    if (!rawRows || rawRows.length === 0) {
      importErrors.value.push('El archivo seleccionado está vacío.')
      importParsing.value = false
      return
    }

    // Find header row or column
    let colSubject = -1
    let startRow = 0

    for (let r = 0; r < Math.min(rawRows.length, 5); r++) {
      const row = rawRows[r]
      for (let c = 0; c < row.length; c++) {
        const h = normalizeHeader(row[c])
        if (h.includes('ASIGNATURA') || h.includes('MATERIA') || h.includes('NOMBRE') || h.includes('SUBJECT')) {
          colSubject = c
          startRow = r + 1
          break
        }
      }
      if (colSubject !== -1) break
    }

    // If no header found, assume column 0 or 1 contains the names
    if (colSubject === -1) {
      // Find the first column with non-numeric text
      for (let r = 0; r < rawRows.length; r++) {
        const row = rawRows[r]
        for (let c = 0; c < row.length; c++) {
          const val = String(row[c] || '').trim()
          if (val && isNaN(Number(val)) && val.length > 2) {
            colSubject = c
            startRow = 0
            break
          }
        }
        if (colSubject !== -1) break
      }
      if (colSubject === -1) colSubject = 0
    }

    const existingNamesSet = new Set(subjects.value.map(s => s.name.trim().toLowerCase()))
    const parsedList = []
    const seenInFile = new Set()

    for (let i = startRow; i < rawRows.length; i++) {
      const row = rawRows[i]
      if (!row || row.length === 0) continue
      const rawName = String(row[colSubject] || '').trim()
      if (!rawName || rawName === 'undefined' || rawName === 'null') continue

      const norm = rawName.toLowerCase()
      // Skip if it looks like a header repeated in data
      if (norm === 'nombre' || norm === 'asignatura' || norm === 'materia' || norm === 'no' || norm === 'n°') continue

      const isDuplicateInFile = seenInFile.has(norm)
      const isAlreadyInDb = existingNamesSet.has(norm)

      seenInFile.add(norm)
      parsedList.push({
        name: rawName,
        isExisting: isAlreadyInDb,
        isDuplicateInFile: isDuplicateInFile,
        selected: !isAlreadyInDb && !isDuplicateInFile
      })
    }

    if (parsedList.length === 0) {
      importErrors.value.push('No se encontraron materias válidas en el archivo.')
    } else {
      importParsedSubjects.value = parsedList
    }
  } catch (err) {
    importErrors.value.push('Error al procesar el archivo Excel: ' + err.message)
  } finally {
    importParsing.value = false
  }
}

const handleFileSelect = (event) => {
  const file = event.target.files?.[0]
  if (!file) return
  importFile.value = file
  importFileName.value = file.name
  parseExcelFile(file)
}

const handleFileDrop = (event) => {
  event.preventDefault()
  const file = event.dataTransfer.files?.[0]
  if (!file) return
  importFile.value = file
  importFileName.value = file.name
  parseExcelFile(file)
}

const validImportCount = computed(() => {
  return importParsedSubjects.value.filter(s => s.selected).length
})

const submitImportSubjects = async () => {
  if (!isOnline.value) {
    alert('Acción no permitida: Estás trabajando sin conexión.')
    return
  }
  const sId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!sId) {
    alert('No hay una institución activa seleccionada.')
    return
  }

  const toInsert = importParsedSubjects.value
    .filter(s => s.selected)
    .map(s => ({
      name: s.name.trim(),
      school_id: sId
    }))

  if (toInsert.length === 0) {
    alert('No hay asignaturas seleccionadas para importar.')
    return
  }

  importProcessing.value = true
  importErrors.value = []

  try {
    const { error } = await supabase.from('subjects').insert(toInsert)
    if (error) throw error

    await queryClient.invalidateQueries({ queryKey: ['subjects'] })
    importSuccessMsg.value = `¡Se importaron ${toInsert.length} asignaturas exitosamente!`
    setTimeout(() => {
      closeImportModal()
    }, 1200)
  } catch (err) {
    importErrors.value.push('Error al guardar en la base de datos: ' + err.message)
  } finally {
    importProcessing.value = false
  }
}
</script>

<template>
  <div class="app-shell min-h-screen">
    <main class="app-container py-6">
      <div class="px-2 sm:px-0">
        <!-- Academic Year Banner -->
        <AcademicYearBanner module-name="Asignaturas" />

        <!-- Header & Action Bar -->
        <div class="mb-6 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          <div>
            <h1 class="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">
              Gestión de Asignaturas
            </h1>
            <p class="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
              Catálogo institucional de asignaturas y materias académicas.
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-2.5">
            <!-- Descargar Plantilla Oficial CSV -->
            <button 
              @click="downloadSubjectsTemplate" 
              class="inline-flex items-center gap-2 px-3.5 py-2 text-xs sm:text-sm font-semibold rounded-xl border border-emerald-300 dark:border-emerald-700/60 bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-100 dark:hover:bg-emerald-900/50 transition-colors shadow-sm"
              title="Descargar formato CSV (.csv) para rellenar o copiar materias"
            >
              <svg class="w-4 h-4 text-emerald-600 dark:text-emerald-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <span>Descargar Plantilla CSV</span>
            </button>

            <!-- Importar Masivo Excel -->
            <button 
              @click="openImportModal" 
              class="inline-flex items-center gap-2 px-3.5 py-2 text-xs sm:text-sm font-semibold rounded-xl border border-blue-300 dark:border-blue-700/60 bg-blue-50 dark:bg-blue-950/40 text-blue-700 dark:text-blue-300 hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors shadow-sm"
              title="Subir archivo Excel con catálogo de asignaturas"
            >
              <svg class="w-4 h-4 text-blue-600 dark:text-blue-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
              </svg>
              <span>Importar Excel</span>
            </button>

            <!-- Exportar Catálogo Actual -->
            <button 
              v-if="subjects.length > 0"
              @click="exportSubjectsToExcel(subjects)" 
              class="inline-flex items-center gap-2 px-3.5 py-2 text-xs sm:text-sm font-semibold rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors shadow-sm"
              title="Descargar catálogo actual en Excel"
            >
              <svg class="w-4 h-4 text-slate-500 dark:text-slate-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
              <span>Exportar</span>
            </button>

            <!-- Nueva Asignatura Manual -->
            <button 
              @click="openModal()" 
              class="app-btn app-btn-primary text-xs sm:text-sm h-10 px-4 justify-center font-bold shadow-sm"
            >
              + Nueva Asignatura
            </button>
          </div>
        </div>

        <!-- Buscador y contador de materias -->
        <div class="mb-4 flex flex-col sm:flex-row items-center justify-between gap-3 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-3 rounded-2xl shadow-sm">
          <div class="relative w-full sm:w-80">
            <svg class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input 
              v-model="searchQuery" 
              type="text" 
              placeholder="Buscar asignatura..." 
              class="app-input pl-9 w-full text-xs sm:text-sm h-9"
            />
          </div>
          <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">
            Total: <strong class="text-slate-800 dark:text-slate-200">{{ subjects.length }}</strong> asignaturas registradas
          </span>
        </div>

        <!-- VISTA MÓVIL (< 768px) -->
        <div class="block md:hidden space-y-3 mb-6 min-h-[300px]">
          <div v-if="loading" class="space-y-3">
            <SkeletonTable :rows="4" :columns="1" />
          </div>
          <div v-else-if="filteredSubjects.length === 0" class="app-card p-6 text-center text-sm text-slate-500">
            {{ searchQuery ? 'No se encontraron asignaturas con ese criterio.' : 'No hay asignaturas registradas.' }}
          </div>
          <div 
            v-else 
            v-for="subject in filteredSubjects" 
            :key="'mobile-sbj-'+subject.id" 
            class="app-card p-4 border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-sm rounded-xl flex items-center justify-between gap-3"
          >
            <span class="text-sm font-bold text-slate-900 dark:text-white truncate">{{ subject.name }}</span>
            <div class="flex items-center gap-2 shrink-0">
              <button @click="openModal(subject)" class="px-3 py-1.5 text-xs font-semibold bg-blue-50 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300 rounded-lg hover:bg-blue-100 transition-colors min-h-[38px]">
                Editar
              </button>
              <button @click="deleteSubject(subject.id)" class="px-3 py-1.5 text-xs font-semibold bg-rose-50 text-rose-700 dark:bg-rose-950/60 dark:text-rose-300 rounded-lg hover:bg-rose-100 transition-colors min-h-[38px]">
                Eliminar
              </button>
            </div>
          </div>
        </div>

        <!-- VISTA DESKTOP (>= 768px) -->
        <div class="hidden md:block app-card overflow-hidden min-h-[300px] border border-slate-200 dark:border-slate-800 rounded-2xl bg-white dark:bg-slate-900 shadow-sm">
          <div v-if="loading" class="p-4">
            <SkeletonTable :rows="4" :columns="2" />
          </div>
          <table v-else class="app-table w-full">
            <thead>
              <tr class="bg-slate-50 dark:bg-slate-800/50 border-b border-slate-200 dark:border-slate-800 text-xs font-bold text-slate-500 uppercase tracking-wider">
                <th class="py-3.5 px-6 text-left">Nombre de Asignatura</th>
                <th class="py-3.5 px-6 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
              <tr v-if="filteredSubjects.length === 0">
                <td colspan="2" class="text-center text-sm text-slate-500 py-10">
                  {{ searchQuery ? 'No se encontraron asignaturas con ese criterio.' : 'No hay asignaturas registradas. Haz clic en "+ Nueva Asignatura" o "Importar Excel".' }}
                </td>
              </tr>
              <tr v-else v-for="subject in filteredSubjects" :key="subject.id" class="hover:bg-slate-50/70 dark:hover:bg-slate-800/40 transition-colors">
                <td class="py-3.5 px-6 text-sm font-semibold text-slate-900 dark:text-white">{{ subject.name }}</td>
                <td class="py-3.5 px-6 text-right space-x-3">
                  <button @click="openModal(subject)" class="text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 font-semibold text-xs">
                    Editar
                  </button>
                  <button @click="deleteSubject(subject.id)" class="text-rose-600 hover:text-rose-800 dark:text-rose-400 dark:hover:text-rose-300 font-semibold text-xs">
                    Eliminar
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </main>

    <!-- Create/Edit Modal -->
    <div v-if="showModal" class="modal-container" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeModal"></div>
      <div class="modal-panel">
        <div class="modal-header modal-header-accent">
          <h3 class="modal-title" style="color:#fff">{{ editingSubject ? 'Editar Asignatura' : 'Nueva Asignatura' }}</h3>
          <p class="modal-subtitle">{{ editingSubject ? 'Modifica el nombre de la asignatura.' : 'Ingresa el nombre de la nueva asignatura.' }}</p>
        </div>
        <div class="modal-body">
          <div class="modal-field">
            <label class="modal-label">Nombre</label>
            <input v-model="form.name" type="text" class="app-input" placeholder="Ej: Matemáticas" @keyup.enter="saveSubject">
          </div>
        </div>
        <div class="modal-footer">
          <button @click="closeModal" class="app-btn app-btn-ghost">Cancelar</button>
          <button @click="saveSubject" class="app-btn app-btn-primary">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
            Guardar
          </button>
        </div>
      </div>
    </div>

    <!-- Import Excel Modal -->
    <div v-if="showImportModal" class="modal-container" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeImportModal"></div>
      <div class="modal-panel max-w-2xl">
        <div class="modal-header bg-gradient-to-r from-blue-600 to-indigo-700 text-white">
          <h3 class="modal-title text-white flex items-center gap-2">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Carga Masiva de Asignaturas (Excel / CSV)
          </h3>
          <p class="modal-subtitle text-blue-100">
            Sube tu archivo con la lista de materias para crearlas de forma instantánea.
          </p>
        </div>

        <div class="modal-body space-y-4 max-h-[70vh] overflow-y-auto">
          <!-- Step 1: Template helper banner -->
          <div class="bg-blue-50 dark:bg-blue-950/40 border border-blue-200 dark:border-blue-800 rounded-xl p-3.5 flex items-center justify-between gap-3">
            <div class="text-xs text-blue-800 dark:text-blue-200">
              <p class="font-bold">¿Aún no tienes el formato?</p>
              <p class="text-blue-600 dark:text-blue-300">Descarga la plantilla oficial en CSV (.csv), añade tu lista de materias y súbela aquí.</p>
            </div>
            <button 
              @click="downloadSubjectsTemplate" 
              class="px-3.5 py-2 text-xs font-bold bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors shrink-0 shadow-sm flex items-center gap-1.5 cursor-pointer"
            >
              📥 Descargar Plantilla CSV
            </button>
          </div>

          <!-- Drag & drop box -->
          <div 
            @dragover.prevent 
            @drop="handleFileDrop"
            @click="$refs.importFileInput?.click()"
            class="border-2 border-dashed border-slate-300 dark:border-slate-700 hover:border-blue-500 dark:hover:border-blue-400 bg-slate-50 dark:bg-slate-800/50 hover:bg-blue-50/40 dark:hover:bg-blue-950/20 rounded-2xl p-6 text-center cursor-pointer transition-all"
          >
            <input 
              ref="importFileInput" 
              type="file" 
              accept=".csv,.xlsx,.xls,.txt" 
              class="hidden" 
              @change="handleFileSelect" 
            />
            
            <div v-if="importParsing" class="py-4 space-y-2">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="text-xs font-semibold text-slate-600 dark:text-slate-300">Leyendo y validando materias del archivo...</p>
            </div>

            <div v-else-if="importFileName" class="space-y-1">
              <span class="inline-flex p-3 rounded-full bg-emerald-100 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 mb-2">
                <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </span>
              <p class="text-sm font-bold text-slate-900 dark:text-white">{{ importFileName }}</p>
              <p class="text-xs text-blue-600 dark:text-blue-400 font-semibold hover:underline">Haz clic para cambiar archivo</p>
            </div>

            <div v-else class="space-y-2">
              <div class="inline-flex p-3 rounded-full bg-blue-100 dark:bg-blue-900/40 text-blue-600 dark:text-blue-400 mb-1">
                <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                </svg>
              </div>
              <p class="text-sm font-bold text-slate-800 dark:text-slate-200">Arrastra tu archivo CSV o Excel aquí o haz clic para buscar</p>
              <p class="text-xs text-slate-500 dark:text-slate-400">Soporta .csv, .txt y .xlsx (cualquier columna con nombres de materias)</p>
            </div>
          </div>

          <!-- Errors banner -->
          <div v-if="importErrors.length > 0" class="p-3 bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 rounded-xl text-xs text-rose-700 dark:text-rose-300 space-y-1">
            <p class="font-bold">Avisos del archivo:</p>
            <ul class="list-disc pl-4 space-y-0.5">
              <li v-for="(err, idx) in importErrors" :key="idx">{{ err }}</li>
            </ul>
          </div>

          <!-- Success banner -->
          <div v-if="importSuccessMsg" class="p-3 bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 rounded-xl text-xs text-emerald-700 dark:text-emerald-300 font-bold text-center">
            {{ importSuccessMsg }}
          </div>

          <!-- Preview Table -->
          <div v-if="importParsedSubjects.length > 0" class="space-y-2">
            <div class="flex items-center justify-between text-xs text-slate-600 dark:text-slate-300 px-1">
              <span class="font-bold">Vista previa de asignaturas detectadas ({{ importParsedSubjects.length }})</span>
              <span class="font-semibold text-emerald-600 dark:text-emerald-400">
                {{ validImportCount }} listas para importar
              </span>
            </div>

            <div class="border border-slate-200 dark:border-slate-800 rounded-xl overflow-hidden max-h-56 overflow-y-auto">
              <table class="w-full text-left text-xs">
                <thead class="bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 sticky top-0">
                  <tr>
                    <th class="py-2 px-3 w-8"></th>
                    <th class="py-2 px-3 font-bold">Asignatura</th>
                    <th class="py-2 px-3 font-bold text-right">Estado</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
                  <tr 
                    v-for="(item, idx) in importParsedSubjects" 
                    :key="'preview-'+idx"
                    :class="{'bg-slate-50/50 dark:bg-slate-800/30': !item.selected}"
                  >
                    <td class="py-2 px-3">
                      <input 
                        type="checkbox" 
                        v-model="item.selected" 
                        :disabled="item.isExisting"
                        class="rounded border-slate-300 text-blue-600 focus:ring-blue-500"
                      />
                    </td>
                    <td class="py-2 px-3 font-medium text-slate-900 dark:text-white">
                      {{ item.name }}
                    </td>
                    <td class="py-2 px-3 text-right">
                      <span 
                        v-if="item.isExisting" 
                        class="inline-block px-2 py-0.5 text-[10px] font-bold rounded-full bg-slate-100 dark:bg-slate-800 text-slate-500"
                      >
                        Ya existe
                      </span>
                      <span 
                        v-else-if="item.isDuplicateInFile" 
                        class="inline-block px-2 py-0.5 text-[10px] font-bold rounded-full bg-amber-100 dark:bg-amber-950 text-amber-700 dark:text-amber-300"
                      >
                        Duplicada en archivo
                      </span>
                      <span 
                        v-else 
                        class="inline-block px-2 py-0.5 text-[10px] font-bold rounded-full bg-emerald-100 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-300"
                      >
                        Nueva
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div class="modal-footer flex items-center justify-between">
          <button @click="closeImportModal" class="app-btn app-btn-ghost text-xs">
            Cancelar
          </button>
          <button 
            @click="submitImportSubjects" 
            :disabled="validImportCount === 0 || importProcessing || importParsing"
            class="app-btn app-btn-primary text-xs font-bold disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span v-if="importProcessing" class="inline-flex items-center gap-2">
              <svg class="animate-spin h-3.5 w-3.5 text-white" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
              </svg>
              Importando...
            </span>
            <span v-else>
              Importar {{ validImportCount }} Asignaturas
            </span>
          </button>
        </div>
      </div>
    </div>

    <!-- Confirm Modal -->
    <div v-if="confirmModal.show" class="modal-container" style="z-index:70" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="closeConfirmModal"></div>
      <div class="modal-panel" style="max-width:28rem;">
        <div class="modal-body text-center" style="padding:32px 24px;">
          <div class="confirm-icon-ring" :class="confirmModal.action ? 'danger' : 'warning'">
            <svg class="h-7 w-7" :class="confirmModal.action ? 'text-rose-600' : 'text-amber-600'" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <h3 class="modal-title text-center">{{ confirmModal.title }}</h3>
          <p class="text-sm text-slate-500 mt-2">{{ confirmModal.message }}</p>
        </div>
        <div class="modal-footer justify-center">
          <button @click="closeConfirmModal" :disabled="confirmModal.processing" class="app-btn app-btn-ghost">
            {{ confirmModal.action ? 'Cancelar' : 'Cerrar' }}
          </button>
          <button v-if="confirmModal.action" @click="executeConfirmAction" :disabled="confirmModal.processing" class="app-btn app-btn-danger disabled:opacity-50">
            {{ confirmModal.processing ? 'Procesando...' : 'Confirmar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
