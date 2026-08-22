<template>
  <div v-if="show" class="fixed inset-0 z-[100] flex items-center justify-center p-4">
    <!-- Backdrop -->
    <div class="absolute inset-0 bg-slate-900/70 backdrop-blur-sm" @click="close"></div>

    <!-- Modal Panel -->
    <div class="relative bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl w-full max-w-lg overflow-hidden shadow-2xl flex flex-col max-h-[90vh]">
      <!-- Header -->
      <div class="p-5 border-b border-slate-200 dark:border-slate-800 flex justify-between items-center bg-slate-50 dark:bg-slate-900/70">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-xl bg-indigo-100 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400 flex items-center justify-center font-bold">
            <KeyRound class="w-5 h-5" />
          </div>
          <div>
            <h3 class="text-base font-bold text-slate-900 dark:text-white">Firma Electrónica (.p12 / .pfx)</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400">Validez legal para actas y notificaciones DECE</p>
          </div>
        </div>
        <button @click="close" class="text-slate-400 hover:text-slate-600 dark:hover:text-white transition-colors">
          <X class="w-5 h-5" />
        </button>
      </div>

      <!-- Body -->
      <div class="p-5 overflow-y-auto custom-scrollbar flex-1 space-y-4">
        <!-- Error alert -->
        <div v-if="errorMessage" class="p-3.5 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-600 dark:text-rose-400 text-xs flex items-start gap-2.5">
          <AlertCircle class="w-4 h-4 shrink-0 mt-0.5" />
          <div class="flex-1">{{ errorMessage }}</div>
        </div>

        <!-- Success info if cert verified -->
        <div v-if="certDetails" class="p-4 rounded-xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-300 dark:border-emerald-800 space-y-2 text-xs">
          <div class="flex items-center gap-2 text-emerald-800 dark:text-emerald-300 font-bold">
            <CheckCircle2 class="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
            Certificado Digital Válido
          </div>
          <div class="grid grid-cols-1 gap-1 text-slate-700 dark:text-slate-300 pt-1">
            <div><span class="font-semibold text-slate-900 dark:text-white">Firmante:</span> {{ certDetails.commonName }}</div>
            <div v-if="certDetails.organization"><span class="font-semibold text-slate-900 dark:text-white">Entidad:</span> {{ certDetails.organization }}</div>
            <div><span class="font-semibold text-slate-900 dark:text-white">Emisor:</span> {{ certDetails.issuerCN }}</div>
            <div><span class="font-semibold text-slate-900 dark:text-white">Válido hasta:</span> {{ formatDate(certDetails.validTo) }}</div>
            <div class="text-[11px] text-slate-500 break-all pt-1 font-mono">
              <span class="font-semibold">Huella SHA-256:</span> {{ certDetails.fingerprint }}
            </div>
          </div>
        </div>

        <!-- File upload box -->
        <div class="space-y-1.5">
          <label class="text-xs font-semibold text-slate-700 dark:text-slate-300 flex items-center justify-between">
            <span>Archivo de Firma (.p12 o .pfx)</span>
            <span v-if="selectedFileName" class="text-[11px] text-indigo-600 dark:text-indigo-400 font-medium truncate max-w-[200px]">
              {{ selectedFileName }}
            </span>
          </label>

          <div
            @dragover.prevent="isDragging = true"
            @dragleave.prevent="isDragging = false"
            @drop.prevent="handleFileDrop"
            @click="triggerFileInput"
            class="border-2 border-dashed rounded-xl p-4 text-center cursor-pointer transition-all flex flex-col items-center justify-center gap-2"
            :class="isDragging 
              ? 'border-indigo-500 bg-indigo-50/50 dark:bg-indigo-950/30' 
              : selectedFile 
                ? 'border-emerald-400 dark:border-emerald-700 bg-emerald-50/30 dark:bg-emerald-950/20'
                : 'border-slate-300 dark:border-slate-700 hover:border-indigo-400 dark:hover:border-indigo-600 bg-slate-50/50 dark:bg-slate-900/40'"
          >
            <input
              ref="fileInputRef"
              type="file"
              accept=".p12,.pfx,application/x-pkcs12"
              class="hidden"
              @change="handleFileSelect"
            />
            <div class="w-10 h-10 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-500 dark:text-slate-400">
              <Upload v-if="!selectedFile" class="w-5 h-5" />
              <FileCheck v-else class="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
            </div>
            <div>
              <p class="text-xs font-bold text-slate-800 dark:text-slate-200">
                {{ selectedFileName || 'Haz clic o arrastra tu archivo .p12 / .pfx aquí' }}
              </p>
              <p class="text-[11px] text-slate-500 mt-0.5">
                Compatible con Banco Central, Security Data, ANFAC, Uanataca, Consejo de la Judicatura
              </p>
            </div>
          </div>
        </div>

        <!-- Certificate password -->
        <div class="space-y-1.5">
          <label class="text-xs font-semibold text-slate-700 dark:text-slate-300">
            Contraseña de la Firma Electrónica
          </label>
          <div class="relative">
            <input
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              placeholder="Ingresa la clave de tu archivo .p12"
              @keydown.enter="processSignature"
              class="w-full pl-3.5 pr-10 py-2.5 bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl text-xs text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500/50"
            />
            <button
              type="button"
              @click="showPassword = !showPassword"
              class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
            >
              <Eye v-if="!showPassword" class="w-4 h-4" />
              <EyeOff v-else class="w-4 h-4" />
            </button>
          </div>
          <p class="text-[11px] text-slate-500">
            🔒 Tu contraseña y certificado se procesan 100% de forma local en tu navegador. No se almacenan en ningún servidor.
          </p>
        </div>
      </div>

      <!-- Footer -->
      <div class="p-4 border-t border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/70 flex justify-end gap-2.5">
        <button
          type="button"
          @click="close"
          class="px-4 py-2 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-colors"
        >
          Cancelar
        </button>
        <button
          type="button"
          @click="processSignature"
          :disabled="!selectedFile || !password || isProcessing"
          class="px-5 py-2 text-xs font-bold text-white bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed rounded-xl transition-colors shadow-sm ring-1 ring-indigo-500/50 flex items-center gap-2"
        >
          <Loader2 v-if="isProcessing" class="w-3.5 h-3.5 animate-spin" />
          <ShieldCheck v-else class="w-3.5 h-3.5" />
          <span>{{ isProcessing ? 'Firmando documento...' : 'Firmar Documento DECE' }}</span>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { readPkcs12Certificate, signAlertPayload } from '../../lib/digitalSignature'
import { 
  KeyRound, X, AlertCircle, CheckCircle2, Upload, FileCheck, Eye, EyeOff, 
  Loader2, ShieldCheck 
} from 'lucide-vue-next'

const props = defineProps({
  show: {
    type: Boolean,
    default: false
  },
  alertData: {
    type: Object,
    default: null
  }
})

const emit = defineEmits(['close', 'signed'])

const fileInputRef = ref(null)
const selectedFile = ref(null)
const selectedFileName = ref('')
const password = ref('')
const showPassword = ref(false)
const isDragging = ref(false)
const isProcessing = ref(false)
const errorMessage = ref('')
const certDetails = ref(null)

const resetForm = () => {
  selectedFile.value = null
  selectedFileName.value = ''
  password.value = ''
  showPassword.value = false
  isDragging.value = false
  isProcessing.value = false
  errorMessage.value = ''
  certDetails.value = null
  if (fileInputRef.value) {
    fileInputRef.value.value = ''
  }
}

watch(() => props.show, (val) => {
  if (val) {
    resetForm()
  }
})

const close = () => {
  emit('close')
}

const triggerFileInput = () => {
  fileInputRef.value?.click()
}

const handleFileSelect = (e) => {
  const file = e.target.files?.[0]
  if (file) {
    setCertificateFile(file)
  }
}

const handleFileDrop = (e) => {
  isDragging.value = false
  const file = e.dataTransfer.files?.[0]
  if (file) {
    setCertificateFile(file)
  }
}

const setCertificateFile = (file) => {
  errorMessage.value = ''
  certDetails.value = null
  const ext = file.name.toLowerCase()
  if (!ext.endsWith('.p12') && !ext.endsWith('.pfx')) {
    errorMessage.value = 'Formato no soportado. Seleccione un archivo de firma electrónica válido (.p12 o .pfx).'
    return
  }
  selectedFile.value = file
  selectedFileName.value = file.name
}

const processSignature = async () => {
  if (!selectedFile.value) {
    errorMessage.value = 'Por favor selecciona tu archivo de firma electrónica (.p12 o .pfx).'
    return
  }
  if (!password.value) {
    errorMessage.value = 'Por favor ingresa la contraseña del certificado digital.'
    return
  }
  if (!props.alertData) {
    errorMessage.value = 'No se encontraron datos de la alerta para firmar.'
    return
  }

  isProcessing.value = true
  errorMessage.value = ''

  try {
    const arrayBuffer = await selectedFile.value.arrayBuffer()
    const parseResult = await readPkcs12Certificate(arrayBuffer, password.value)

    if (!parseResult.success) {
      errorMessage.value = parseResult.error || 'Error al validar la firma electrónica.'
      isProcessing.value = false
      return
    }

    certDetails.value = parseResult.certInfo

    // Generar la firma criptográfica sobre el payload de la alerta
    const signResult = signAlertPayload(props.alertData, parseResult.privateKey, parseResult.certInfo)
    if (!signResult.success) {
      errorMessage.value = signResult.error || 'No se pudo generar la firma digital.'
      isProcessing.value = false
      return
    }

    // Emitir el resultado firmado con los metadatos completos
    emit('signed', {
      signatureData: signResult.signatureData,
      certInfo: parseResult.certInfo
    })
  } catch (err) {
    console.error('Error durante el proceso de firma:', err)
    errorMessage.value = err.message || 'Ocurrió un error inesperado al procesar la firma digital.'
  } finally {
    isProcessing.value = false
  }
}

const formatDate = (isoString) => {
  if (!isoString) return ''
  try {
    return new Date(isoString).toLocaleDateString('es-EC', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })
  } catch {
    return isoString
  }
}
</script>
