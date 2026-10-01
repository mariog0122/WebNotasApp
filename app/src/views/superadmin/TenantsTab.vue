<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../../lib/supabase'
import { billingProofPath, resolveBillingProofUrl, uploadBillingProof, isPdfBillingProof } from '../../lib/billingProofs'
import { 
  Search, Filter, Building2, MoreVertical,
  Sliders, Shield, Ban, CheckCircle, RefreshCw, X, AlertCircle, Save, DollarSign, FileText, LogIn, Trash2, Download, Upload, Database, FileSpreadsheet, Eye, Sparkles, CheckCheck
} from 'lucide-vue-next'
import { toast } from 'vue-sonner'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { downloadInstitutionsTemplate } from '../../lib/exportUtils'
import { auditReceiptWithAI, getLocalCurrentDateTimeString } from '../../lib/receiptAiAuditor'
import { createTenantStatusManager, tenantStatusSuccessMessage } from '../../lib/superadminTenantStatus'
import { tenantService } from '../../services/tenantService'

const router = useRouter()
const authStore = useAuthStore()

const loading = ref(true)
const tenants = ref([])

const searchQuery = ref('')
const selectedStatusFilter = ref('all')

// Modales state
const selectedTenant = ref(null)
const showDetailsModal = ref(false)
const showFeaturesModal = ref(false)
const tenantFeatures = ref({})
const showReceiptViewerModal = ref(false)
const viewingReceiptTenant = ref(null)

const openReceiptViewer = (tenant) => {
  viewingReceiptTenant.value = tenant
  showReceiptViewerModal.value = true
}

const showLimitsModal = ref(false)
const tenantLimits = ref({
  max_users: 100000,
  max_teachers: 100000,
  max_students: 500,
  storage_mb: 102400,
  max_documents: 100000,
  max_emails_month: 100000,
  max_api_requests: 100000
})
const usageStats = ref(null)

const showSuspendModal = ref(false)
const statusActionTarget = ref(null)
const statusChangingTenantId = ref(null)
const suspendReasonOption = ref('Pago vencido')
const suspendObservation = ref('')
const notifyAdminCheck = ref(true)

const showDeleteModal = ref(false)
const deleteTenantTarget = ref(null)
const deleteConfirmName = ref('')

const showPaymentModal = ref(false)
const showInvoicesModal = ref(false)
const invoices = ref([])
const loadingInvoices = ref(false)
const invoicesError = ref('')
const paymentForm = ref({
  providerReference: '',
  externalInvoiceNumber: '',
  paidAt: getLocalCurrentDateTimeString(),
  notes: ''
})

const aiAuditing = ref(false)
const aiAuditProgress = ref('')
const aiAuditResult = ref(null)

const paymentExpectedAmount = computed(() => {
  if (!selectedTenant.value) return 0
  const implementationFee = selectedTenant.value.implementationFeeStatus === 'pending'
    ? selectedTenant.value.implementationFee
    : 0
  return Number(selectedTenant.value.agreedPrice || 0) + Number(implementationFee || 0)
})

const savingAction = ref(false)
const tenantStatusManager = createTenantStatusManager(supabase)

const openTenantWorkspace = async (tenant) => {
  if (!authStore.setActiveSchoolId(tenant.id)) {
    toast.error('No se pudo establecer el contexto de esta institución.')
    return
  }
  toast.success(`Contexto activo: ${tenant.name}`)
  await router.push('/')
}

const loadTenants = async () => {
  loading.value = true
  try {
    const { data: schools, error: schoolsError } = await supabase
      .from('schools')
      .select('id, name, trade_name, code, country, province, city, status, created_at')
      .order('created_at', { ascending: false })

    if (schoolsError) {
      toast.error('Error cargando instituciones: ' + schoolsError.message)
      return
    }

    if (!schools || schools.length === 0) {
      tenants.value = []
      return
    }

    const schoolIds = schools.map(s => s.id)

    const [subsRes, billingRes, profilesRes, studentsRes] = await Promise.all([
      supabase
        .from('subscriptions')
        .select('id, school_id, status, billing_cycle, agreed_price, started_at, trial_ends_at, next_billing_date, plans(name, monthly_price, annual_price, implementation_fee, trial_days, max_students)')
        .in('school_id', schoolIds),
      supabase
        .from('tenant_billing_profiles')
        .select('school_id, implementation_fee_status, latest_receipt_url')
        .in('school_id', schoolIds),
      supabase
        .from('profiles')
        .select('id, school_id, full_name, email, role')
        .in('school_id', schoolIds),
      supabase
        .from('students')
        .select('id, school_id')
        .in('school_id', schoolIds)
    ])

    const subsMap = new Map()
    if (subsRes.data) {
      subsRes.data.forEach(sub => subsMap.set(sub.school_id, sub))
    }

    const billingMap = new Map()
    if (billingRes.data) {
      billingRes.data.forEach(b => billingMap.set(b.school_id, b))
    }

    const studentsCountMap = new Map()
    if (studentsRes.data) {
      studentsRes.data.forEach(st => {
        studentsCountMap.set(st.school_id, (studentsCountMap.get(st.school_id) || 0) + 1)
      })
    }

    // Fallback: Si latest_receipt_url no está en billing_profiles, verificar en payments
    const { data: paymentsWithReceipt } = await supabase
      .from('payments')
      .select('school_id, receipt_url')
      .not('receipt_url', 'is', null)
      .in('school_id', schoolIds)
      .order('paid_at', { ascending: false })

    const paymentsReceiptMap = new Map()
    if (paymentsWithReceipt) {
      paymentsWithReceipt.forEach(p => {
        if (!paymentsReceiptMap.has(p.school_id) && p.receipt_url) {
          paymentsReceiptMap.set(p.school_id, p.receipt_url)
        }
      })
    }

    const profilesMap = new Map()
    if (profilesRes.data) {
      profilesRes.data.forEach(p => {
        if (!profilesMap.has(p.school_id)) profilesMap.set(p.school_id, [])
        profilesMap.get(p.school_id).push(p)
      })
    }

    tenants.value = await Promise.all(schools.map(async s => {
      const profs = profilesMap.get(s.id) || []
      const admin = profs.find(p => p.role === 'admin' || p.role === 'superadmin') || profs[0]
      const userCount = profs.length
      const studentCount = studentsCountMap.get(s.id) || 0
      const sub = subsMap.get(s.id) || null
      const billing = billingMap.get(s.id) || null
      const receiptUrl = billing?.latest_receipt_url || paymentsReceiptMap.get(s.id) || ''
      const maxStudents = sub?.plans?.max_students || 500

      const isTrial = s.status === 'trial' || sub?.status === 'trial'
      const rawDate = isTrial ? (sub?.trial_ends_at || sub?.next_billing_date) : sub?.next_billing_date
      let nextBillingFormatted = 'Sin programar'
      let daysRemaining = null
      if (rawDate) {
        const dt = new Date(rawDate)
        nextBillingFormatted = dt.toLocaleDateString('es-EC', { year: 'numeric', month: '2-digit', day: '2-digit' })
        const diffMs = dt.getTime() - Date.now()
        daysRemaining = Math.ceil(diffMs / (1000 * 60 * 60 * 24))
      }

      return {
        ...s,
        adminName: admin?.full_name || 'Sin Administrador',
        adminEmail: admin?.email || 'N/A',
        adminId: admin?.id,
        planName: sub?.plans?.name || 'Gratuito',
        planPrice: sub?.agreed_price ?? (sub?.billing_cycle === 'yearly' ? sub?.plans?.annual_price : sub?.plans?.monthly_price) ?? 0,
        agreedPrice: sub?.agreed_price || 0,
        billingCycle: sub?.billing_cycle || 'monthly',
        subscriptionStatus: sub?.status || s.status,
        isTrial,
        trialEndsAt: sub?.trial_ends_at,
        nextBillingDate: sub?.next_billing_date,
        daysRemaining,
        implementationFee: sub?.plans?.implementation_fee || 0,
        implementationFeeStatus: billing?.implementation_fee_status || 'pending',
        latestReceiptPath: receiptUrl ? billingProofPath(receiptUrl) : '',
        latestReceiptUrl: receiptUrl ? await resolveBillingProofUrl(supabase, receiptUrl).catch(() => '') : '',
        userCount,
        studentCount,
        maxStudents,
        nextBilling: nextBillingFormatted,
        nextBillingRaw: rawDate
      }
    }))
  } catch (err) {
    toast.error('Excepción cargando instituciones: ' + err.message)
  } finally {
    loading.value = false
  }
}

const filteredTenants = computed(() => {
  return tenants.value.filter(t => {
    const matchesSearch = 
      t.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      (t.code && t.code.toLowerCase().includes(searchQuery.value.toLowerCase())) ||
      t.adminEmail.toLowerCase().includes(searchQuery.value.toLowerCase())

    const matchesStatus = selectedStatusFilter.value === 'all' || t.status === selectedStatusFilter.value
    return matchesSearch && matchesStatus
  })
})

// NOMBRES EN ESPAÑOL DE MÓDULOS
const MODULE_NAMES_ES = {
  grades: 'Calificaciones y Notas',
  attendance: 'Control de Asistencia',
  enrollment: 'Estudiantes y Matriculación',
  reports: 'Reportes y Libretas',
  projects: 'Proyectos Escolares',
  ai_planning: 'Planificación Educativa con IA (Ecuador)',
  lms: 'Aula Virtual (LMS)',
  payments: 'Colecturía y Pagos',
  ai: 'Asistente de IA General',
  api: 'Integración API'
}

// MÓDULOS / FEATURE FLAGS
const openFeaturesModal = async (tenant) => {
  selectedTenant.value = tenant
  showFeaturesModal.value = true
  
  const feats = {
    grades: true, attendance: true, enrollment: true, 
    reports: true, projects: true, ai_planning: true, lms: false, payments: false, ai: false, api: false
  }

  try {
    const loaded = await tenantService.fetchFeatures(tenant.id)
    Object.assign(feats, loaded)
  } catch (e) {
    console.warn('[TenantsTab] Error cargando módulos:', e)
  }

  tenantFeatures.value = feats
}

const saveFeatures = async () => {
  savingAction.value = true
  try {
    await tenantService.saveFeatures(selectedTenant.value.id, tenantFeatures.value)
    toast.success('Módulos actualizados exitosamente para ' + selectedTenant.value.name)
    showFeaturesModal.value = false
  } catch (err) {
    toast.error('Error guardando módulos: ' + err.message)
  } finally {
    savingAction.value = false
  }
}

// LÍMITES
const openLimitsModal = async (tenant) => {
  selectedTenant.value = tenant
  tenantLimits.value.max_students = tenant.maxStudents || 500
  showLimitsModal.value = true
  
  try {
    const lim = await tenantService.fetchLimits(tenant.id)
    if (lim) {
      tenantLimits.value = { ...tenantLimits.value, ...lim }
    }

    // Consultar conteos reales de la base de datos
    const [studentsRes, usersRes, teachersRes] = await Promise.all([
      supabase.from('students').select('id', { count: 'exact', head: true }).eq('school_id', tenant.id),
      supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('school_id', tenant.id),
      supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('school_id', tenant.id).eq('role', 'docente')
    ])

    const { data: stats } = await supabase.rpc('get_tenant_usage_stats', { p_school_id: tenant.id })

    usageStats.value = {
      users_count: usersRes.count ?? stats?.users_count ?? stats?.users?.current ?? tenant.userCount ?? 0,
      teachers_count: teachersRes.count ?? stats?.teachers_count ?? stats?.teachers?.current ?? 0,
      students_count: studentsRes.count ?? stats?.students_count ?? stats?.students?.current ?? tenant.studentCount ?? 0,
      courses_count: stats?.courses_count ?? 0,
      grades_count: stats?.grades_count ?? 0,
      storage_mb: stats?.storage?.current_mb ?? 0
    }
  } catch (e) {
    console.warn('Fallback para tenant_limits:', e)
  }
}

const saveLimits = async () => {
  savingAction.value = true
  try {
    await tenantService.saveLimits(selectedTenant.value.id, tenantLimits.value)
    toast.success('Límites actualizados exitosamente')
    showLimitsModal.value = false
  } catch (err) {
    toast.error('Error actualizando límites: ' + err.message)
  } finally {
    savingAction.value = false
  }
}

// SUSPENDER / REACTIVAR
const openSuspendModal = (tenant) => {
  statusActionTarget.value = tenant
  suspendReasonOption.value = 'Pago vencido'
  suspendObservation.value = ''
  showSuspendModal.value = true
}

const closeSuspendModal = () => {
  if (statusChangingTenantId.value) return
  showSuspendModal.value = false
  statusActionTarget.value = null
}

const openPaymentModal = (tenant) => {
  selectedTenant.value = tenant
  aiAuditResult.value = null
  aiAuditing.value = false
  aiAuditProgress.value = ''
  
  paymentForm.value = {
    providerReference: '',
    externalInvoiceNumber: '',
    paidAt: getLocalCurrentDateTimeString(),
    notes: '',
    receiptUrl: tenant.latestReceiptUrl || '',
    receiptPath: tenant.latestReceiptPath || '',
    uploadingReceipt: false
  }
  showPaymentModal.value = true
}

const runAiReceiptAudit = async () => {
  const receiptUrl = paymentForm.value.receiptUrl || selectedTenant.value?.latestReceiptUrl
  if (!receiptUrl) {
    toast.error('No hay comprobante disponible para analizar.')
    return
  }

  aiAuditing.value = true
  aiAuditProgress.value = 'Iniciando escáner de IA...'
  try {
    const result = await auditReceiptWithAI(
      receiptUrl, 
      paymentExpectedAmount.value, 
      (msg) => { aiAuditProgress.value = msg }
    )
    aiAuditResult.value = result

    if (result.success) {
      toast.success('¡Comprobante analizado con IA!')
    } else {
      toast.error('No se pudo completar el análisis OCR: ' + result.message)
    }
  } catch (err) {
    toast.error('Error al ejecutar IA: ' + err.message)
  } finally {
    aiAuditing.value = false
    aiAuditProgress.value = ''
  }
}

const applyAiDetectedData = () => {
  if (!aiAuditResult.value) return
  const r = aiAuditResult.value
  if (r.reference) {
    paymentForm.value.providerReference = r.reference
  }
  if (!paymentForm.value.externalInvoiceNumber) {
    paymentForm.value.externalInvoiceNumber = `FAC-${r.reference?.slice(-6) || Date.now().toString().slice(-6)}`
  }
  if (r.date) {
    paymentForm.value.paidAt = r.date
  }
  const noteParts = []
  if (r.bank) noteParts.push(`Entidad: ${r.bank}`)
  if (r.amount) noteParts.push(`Monto comprobante: $${r.amount.toFixed(2)} USD`)
  if (r.message) noteParts.push(r.message)
  
  paymentForm.value.notes = noteParts.join(' | ')
  toast.success('¡Campos completados automáticamente con los datos detectados por la IA!')
}

const onModalReceiptFileChange = async (e) => {
  const file = e.target.files?.[0]
  if (!file || !selectedTenant.value) return
  paymentForm.value.uploadingReceipt = true
  aiAuditResult.value = null
  try {
    const filePath = await uploadBillingProof(supabase, selectedTenant.value.id, file)
    paymentForm.value.receiptPath = filePath
    paymentForm.value.receiptUrl = await resolveBillingProofUrl(supabase, filePath)
    toast.success('¡Foto del comprobante adjuntada correctamente!')
  } catch (err) {
    toast.error('Error al subir imagen de comprobante: ' + err.message)
  } finally {
    paymentForm.value.uploadingReceipt = false
  }
}

const openInvoicesModal = async (tenant) => {
  selectedTenant.value = tenant
  invoices.value = []
  invoicesError.value = ''
  loadingInvoices.value = true
  showInvoicesModal.value = true

  const { data, error } = await supabase
    .from('invoices')
    .select(`
      id, invoice_number, status, currency, total, issued_at, due_at, paid_at,
      invoice_payment_allocations(
        amount,
        payments(provider, provider_reference, paid_at, receipt_url)
      )
    `)
    .eq('school_id', tenant.id)
    .order('issued_at', { ascending: false })
    .limit(50)

  if (error) invoicesError.value = 'No se pudo cargar el historial de facturas.'
  else invoices.value = data || []
  loadingInvoices.value = false
}

const invoiceStatusLabel = (status) => ({
  draft: 'Borrador',
  issued: 'Emitida',
  partially_paid: 'Pago parcial',
  paid: 'Pagada',
  partially_refunded: 'Devolución parcial',
  refunded: 'Devuelta',
  overdue: 'Vencida',
  void: 'Anulada'
}[status] || status)

const statusLabel = (status) => ({
  active: 'Activa',
  trial: 'En Prueba',
  past_due: 'Pago Vencido',
  grace_period: 'Período de Gracia',
  suspended: 'Suspendida',
  cancelled: 'Cancelada'
}[status] || status)

const money = (amount, currency = 'USD') => new Intl.NumberFormat('es-EC', {
  style: 'currency',
  currency
}).format(Number(amount || 0))

const shortDate = (value) => value
  ? new Intl.DateTimeFormat('es-EC', { dateStyle: 'medium' }).format(new Date(value))
  : '—'

const calculateNewBillingDatePreview = (tenant) => {
  if (!tenant) return '—'
  const isTrialActive = tenant.isTrial && tenant.trialEndsAt && new Date(tenant.trialEndsAt) > new Date()
  const base = isTrialActive ? new Date(tenant.trialEndsAt) : new Date()
  const isYearly = tenant.billingCycle === 'yearly'
  const nextDate = new Date(base)
  if (isYearly) {
    nextDate.setFullYear(nextDate.getFullYear() + 1)
  } else {
    nextDate.setMonth(nextDate.getMonth() + 1)
  }
  return nextDate.toLocaleDateString('es-EC', { year: 'numeric', month: 'short', day: 'numeric' })
}

const recordPayment = async () => {
  if (!paymentForm.value.providerReference.trim() || !paymentForm.value.externalInvoiceNumber.trim()) {
    toast.error('La referencia bancaria y el número de factura son obligatorios.')
    return
  }

  savingAction.value = true
  try {
    const receiptUrl = paymentForm.value.receiptPath || selectedTenant.value.latestReceiptPath || null
    const paidAtIso = new Date(paymentForm.value.paidAt).toISOString()
    const amountVal = paymentExpectedAmount.value

    const { data, error: rpcError } = await supabase.rpc('record_manual_payment', {
      p_school_id: selectedTenant.value.id,
      p_amount: amountVal,
      p_provider_reference: paymentForm.value.providerReference.trim(),
      p_external_invoice_number: paymentForm.value.externalInvoiceNumber.trim(),
      p_paid_at: paidAtIso,
      p_notes: paymentForm.value.notes.trim() || null,
      p_receipt_url: receiptUrl
    })

    if (rpcError) throw rpcError

    toast.success(`Pago registrado y verificado correctamente para ${selectedTenant.value.name}`)
    showPaymentModal.value = false
    await loadTenants()
  } catch (err) {
    toast.error('Error registrando el pago: ' + (err.message || 'Error de conexión'))
  } finally {
    savingAction.value = false
  }
}

const executeStatusChange = async (newStatus, targetTenant) => {
  if (!targetTenant?.id) {
    toast.error('No se pudo identificar la institución sobre la que se ejecutó la acción.')
    return false
  }
  if (statusChangingTenantId.value) return false

  statusChangingTenantId.value = targetTenant.id
  try {
    const reasonText = newStatus === 'suspended' ? suspendReasonOption.value : 'Reactivación manual autorizada'
    const observation = newStatus === 'suspended'
      ? suspendObservation.value
      : 'Reactivado por SuperAdmin fuera del flujo de cobro.'

    const result = await tenantStatusManager.changeStatus({
      targetInstitutionId: targetTenant.id,
      newStatus,
      reason: reasonText,
      observation
    })

    if (result.skipped) return false
    toast.success(tenantStatusSuccessMessage(newStatus, targetTenant.name, result.changed !== false))
    showSuspendModal.value = false
    statusActionTarget.value = null
    await loadTenants()
    return true
  } catch (err) {
    toast.error(err.message || 'No se pudo cambiar el estado de la institución. Intenta nuevamente.')
    return false
  } finally {
    statusChangingTenantId.value = null
  }
}

const generatingBackup = ref(false)
const autoBackupBeforeDelete = ref(true)

const generateTenantBackupData = async (schoolId, schoolName) => {
  const [
    schoolRes,
    configRes,
    profilesRes,
    membershipsRes,
    coursesRes,
    subjectsRes,
    studentsRes,
    quartersRes,
    gradeDefsRes,
    alertsRes,
    subsRes,
    billingProfileRes,
    invoicesRes,
    paymentsRes,
    academicYearsRes,
    tenantLimitsRes,
  ] = await Promise.all([
    supabase.from('schools').select('*').eq('id', schoolId).maybeSingle(),
    supabase.from('system_config').select('*').eq('school_id', schoolId),
    supabase.from('profiles').select('id, full_name, email, role, phone, is_active, created_at').eq('school_id', schoolId),
    supabase.from('tenant_memberships').select('*').eq('school_id', schoolId),
    supabase.from('courses').select('*').eq('school_id', schoolId),
    supabase.from('subjects').select('*').eq('school_id', schoolId),
    supabase.from('students').select('*').eq('school_id', schoolId),
    supabase.from('quarters').select('*').eq('school_id', schoolId),
    supabase.from('grade_definitions').select('*').eq('school_id', schoolId),
    supabase.from('student_alerts').select('*').eq('school_id', schoolId),
    supabase.from('subscriptions').select('*').eq('school_id', schoolId),
    supabase.from('tenant_billing_profiles').select('*').eq('school_id', schoolId),
    supabase.from('invoices').select('*').eq('school_id', schoolId),
    supabase.from('payments').select('*').eq('school_id', schoolId),
    supabase.from('academic_years').select('*').eq('school_id', schoolId),
    supabase.from('tenant_limits').select('*').eq('school_id', schoolId).maybeSingle(),
  ])

  const backupQueries = {
    institución: schoolRes,
    configuración: configRes,
    perfiles: profilesRes,
    membresías: membershipsRes,
    cursos: coursesRes,
    materias: subjectsRes,
    estudiantes: studentsRes,
    períodos: quartersRes,
    definiciones: gradeDefsRes,
    alertas: alertsRes,
    suscripciones: subsRes,
    facturación: billingProfileRes,
    facturas: invoicesRes,
    pagos: paymentsRes,
    años_lectivos: academicYearsRes,
    límites: tenantLimitsRes,
  }
  for (const [label, result] of Object.entries(backupQueries)) {
    if (result.error) throw new Error(`No se pudo respaldar ${label}: ${result.error.message}`)
  }
  if (!schoolRes.data) throw new Error('La institución ya no existe o no está disponible.')

  const courseIds = (coursesRes.data || []).map(c => c.id)
  let courseSubjectsData = []
  if (courseIds.length > 0) {
    const { data: csData, error: csError } = await supabase
      .from('course_subjects')
      .select('*')
      .eq('school_id', schoolId)
      .in('course_id', courseIds)
    if (csError) throw new Error(`No se pudieron respaldar las asignaciones: ${csError.message}`)
    if (csData) courseSubjectsData = csData
  }

  const studentIds = (studentsRes.data || []).map(s => s.id)
  let gradesData = []
  let qualGradesData = []
  let suppExamsData = []

  if (studentIds.length > 0) {
    const chunkSize = 100
    for (let i = 0; i < studentIds.length; i += chunkSize) {
      const chunk = studentIds.slice(i, i + chunkSize)
      const [gRes, qgRes, seRes] = await Promise.all([
        supabase.from('grades').select('*').in('student_id', chunk),
        supabase.from('qualitative_grades').select('*').in('student_id', chunk),
        supabase.from('supplementary_exams').select('*').in('student_id', chunk),
      ])
      if (gRes.error) throw new Error(`No se pudieron respaldar las calificaciones: ${gRes.error.message}`)
      if (qgRes.error) throw new Error(`No se pudieron respaldar las calificaciones cualitativas: ${qgRes.error.message}`)
      if (seRes.error) throw new Error(`No se pudieron respaldar los exámenes supletorios: ${seRes.error.message}`)
      if (gRes.data) gradesData.push(...gRes.data)
      if (qgRes.data) qualGradesData.push(...qgRes.data)
      if (seRes.data) suppExamsData.push(...seRes.data)
    }
  }

  return {
    system: 'LOGREVA / WebNotas',
    version: '1.0',
    exported_at: new Date().toISOString(),
    school_id: schoolId,
    school_name: schoolName,
    summary: {
      total_users: (profilesRes.data || []).length,
      total_courses: (coursesRes.data || []).length,
      total_subjects: (subjectsRes.data || []).length,
      total_students: (studentsRes.data || []).length,
      total_grades: gradesData.length + qualGradesData.length,
      total_alerts: (alertsRes.data || []).length
    },
    data: {
      school: schoolRes.data || null,
      system_config: configRes.data || [],
      user_profiles: profilesRes.data || [],
      tenant_memberships: membershipsRes.data || [],
      courses: coursesRes.data || [],
      subjects: subjectsRes.data || [],
      course_subjects: courseSubjectsData,
      quarters: quartersRes.data || [],
      students: studentsRes.data || [],
      grade_definitions: gradeDefsRes.data || [],
      grades_numeric: gradesData,
      grades_qualitative: qualGradesData,
      supplementary_exams: suppExamsData,
      student_alerts: alertsRes.data || [],
      subscriptions: subsRes.data || [],
      billing_profiles: billingProfileRes.data || [],
      invoices: invoicesRes.data || [],
      payments: paymentsRes.data || [],
      academic_years: academicYearsRes.data || [],
      tenant_limits: tenantLimitsRes.data || null,
    }
  }
}

const downloadTenantBackup = async (tenant) => {
  if (!tenant) return
  generatingBackup.value = true
  try {
    const backupData = await generateTenantBackupData(tenant.id, tenant.name)
    const jsonStr = JSON.stringify(backupData, null, 2)
    const blob = new Blob([jsonStr], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const sanitizedName = tenant.name.replace(/[^a-zA-Z0-9_\-]/g, '_')
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
    const fileName = `respaldo_db_${sanitizedName}_${timestamp}.json`

    const link = document.createElement('a')
    link.href = url
    link.download = fileName
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)

    toast.success(`Respaldo descargado: ${fileName}`)
  } catch (err) {
    toast.error('Error generando respaldo: ' + err.message)
  } finally {
    generatingBackup.value = false
  }
}

const openDeleteModal = (tenant) => {
  deleteTenantTarget.value = tenant
  deleteConfirmName.value = ''
  autoBackupBeforeDelete.value = true
  showDeleteModal.value = true
}

const executeDeleteTenant = async () => {
  if (!deleteTenantTarget.value) return
  if (deleteConfirmName.value.trim() !== deleteTenantTarget.value.name.trim()) {
    toast.error('El nombre ingresado no coincide exactamente con el de la institución.')
    return
  }

  savingAction.value = true
  try {
    if (autoBackupBeforeDelete.value) {
      toast.info('Generando copia de respaldo antes de eliminar...')
      await downloadTenantBackup(deleteTenantTarget.value)
    }

    const { data, error } = await supabase.rpc('delete_tenant', {
      p_school_id: deleteTenantTarget.value.id
    })

    if (error) throw error
    if (!data?.success) throw new Error('La función segura rechazó la eliminación de la institución.')

    toast.success(data?.message || `La institución "${deleteTenantTarget.value.name}" fue eliminada correctamente.`)
    showDeleteModal.value = false
    deleteTenantTarget.value = null
    deleteConfirmName.value = ''
    await loadTenants()
  } catch (err) {
    toast.error('Error al eliminar la institución: ' + err.message)
  } finally {
    savingAction.value = false
  }
}

// State for JSON Database Import/Restore
const showRestoreJsonModal = ref(false)
const restoreFileInput = ref(null)
const restoreFile = ref(null)
const restoreData = ref(null)
const restoreSummary = ref(null)
const restoreErrors = ref([])
const restoring = ref(false)
const restoreTargetOption = ref('new_school') // 'new_school' | 'existing_school'
const restoreTargetTenantId = ref('')
const restoreNewSchoolName = ref('')
const restoreNewSchoolAmie = ref('')

const openRestoreJsonModal = () => {
  showRestoreJsonModal.value = true
  restoreFile.value = null
  restoreData.value = null
  restoreSummary.value = null
  restoreErrors.value = []
  restoreTargetOption.value = 'new_school'
  restoreTargetTenantId.value = tenants.value[0]?.id || ''
  restoreNewSchoolName.value = ''
  restoreNewSchoolAmie.value = ''
}

const onRestoreFileChange = async (event) => {
  const file = event.target.files?.[0] || null
  restoreFile.value = file
  restoreData.value = null
  restoreSummary.value = null
  restoreErrors.value = []

  if (!file) return

  if (!file.name.toLowerCase().endsWith('.json')) {
    restoreErrors.value = ['Por favor selecciona un archivo en formato JSON (.json).']
    return
  }
  if (file.size > 25 * 1024 * 1024) {
    restoreErrors.value = ['El respaldo supera el límite seguro de 25 MB.']
    return
  }

  try {
    const text = await file.text()
    const parsed = JSON.parse(text)
    
    // Check if it is a WebNotas / LOGREVA tenant backup
    const isFullBackup = parsed.data && typeof parsed.data === 'object'
    const schoolObj = isFullBackup ? (parsed.data.school || {}) : (parsed.school || {})
    const coursesArr = isFullBackup ? (parsed.data.courses || []) : (parsed.courses || [])
    const studentsArr = isFullBackup ? (parsed.data.students || []) : (parsed.students || [])
    const subjectsArr = isFullBackup ? (parsed.data.subjects || []) : (parsed.subjects || [])
    const gradesNum = isFullBackup ? (parsed.data.grades_numeric || []) : (parsed.grades_numeric || [])
    const gradesQual = isFullBackup ? (parsed.data.grades_qualitative || []) : (parsed.grades_qualitative || [])
    const configArr = isFullBackup ? (parsed.data.system_config || []) : (parsed.system_config || [])
    const quartersArr = isFullBackup ? (parsed.data.quarters || []) : (parsed.quarters || [])
    const profilesArr = isFullBackup ? (parsed.data.user_profiles || []) : (parsed.user_profiles || [])
    const academicYearsArr = isFullBackup ? (parsed.data.academic_years || []) : (parsed.academic_years || [])
    const supplementaryArr = isFullBackup ? (parsed.data.supplementary_exams || []) : (parsed.supplementary_exams || [])
    const tenantLimitsObj = isFullBackup ? (parsed.data.tenant_limits || null) : (parsed.tenant_limits || null)
    if (tenantLimitsObj !== null && (typeof tenantLimitsObj !== 'object' || Array.isArray(tenantLimitsObj))) {
      throw new Error('La sección tenant_limits no contiene un objeto válido.')
    }

    const sections = {
      courses: coursesArr,
      students: studentsArr,
      subjects: subjectsArr,
      grades_numeric: gradesNum,
      grades_qualitative: gradesQual,
      system_config: configArr,
      quarters: quartersArr,
      user_profiles: profilesArr,
      academic_years: academicYearsArr,
      supplementary_exams: supplementaryArr,
      tenant_limits: tenantLimitsObj,
    }
    for (const [name, rows] of Object.entries(sections)) {
      if (!Array.isArray(rows)) throw new Error(`La sección ${name} no contiene una lista válida.`)
    }

    const courseSubjectsArr = isFullBackup ? (parsed.data.course_subjects || []) : (parsed.course_subjects || [])
    const gradeDefinitionsArr = isFullBackup ? (parsed.data.grade_definitions || []) : (parsed.grade_definitions || [])
    if (!Array.isArray(courseSubjectsArr) || !Array.isArray(gradeDefinitionsArr)) {
      throw new Error('Las relaciones académicas del respaldo no tienen un formato válido.')
    }

    restoreData.value = {
      school: schoolObj,
      courses: coursesArr,
      students: studentsArr,
      subjects: subjectsArr,
      grades_numeric: gradesNum,
      grades_qualitative: gradesQual,
      course_subjects: courseSubjectsArr,
      grade_definitions: gradeDefinitionsArr,
      quarters: quartersArr,
      system_config: configArr,
      user_profiles: profilesArr,
      academic_years: academicYearsArr,
      supplementary_exams: supplementaryArr,
    }

    restoreNewSchoolName.value = schoolObj.name || parsed.school_name || 'Institución Restaurada'
    restoreNewSchoolAmie.value = schoolObj.amie_code || schoolObj.code || ''

    restoreSummary.value = {
      schoolName: schoolObj.name || parsed.school_name || 'Sin nombre institucional',
      coursesCount: coursesArr.length,
      studentsCount: studentsArr.length,
      subjectsCount: subjectsArr.length,
      gradesCount: gradesNum.length + gradesQual.length,
      quartersCount: quartersArr.length,
      configCount: configArr.length,
      academicYearsCount: academicYearsArr.length,
      supplementaryCount: supplementaryArr.length,
    }
  } catch (err) {
    restoreErrors.value = ['Error al procesar el archivo JSON: ' + err.message]
  }
}

const executeJsonRestore = async () => {
  if (!restoreData.value) return
  restoring.value = true
  try {
    const creatingSchool = restoreTargetOption.value === 'new_school'
    const targetSchoolId = creatingSchool ? null : restoreTargetTenantId.value
    if (!creatingSchool && !targetSchoolId) {
      throw new Error('Selecciona una institución destino para restaurar.')
    }

    const schoolName = (restoreNewSchoolName.value || 'Institución Restaurada').trim()
    const schoolCode = (restoreNewSchoolAmie.value || `REST-${Date.now().toString().slice(-6)}`).trim()
    const { data, error } = await supabase.rpc('restore_tenant_academic_backup', {
      p_backup: restoreData.value,
      p_target_school_id: targetSchoolId,
      p_new_school_name: creatingSchool ? schoolName : null,
      p_new_school_code: creatingSchool ? schoolCode : null
    })

    if (error) throw error
    if (!data?.success || !data?.school_id) {
      throw new Error('La base de datos no confirmó la restauración académica completa.')
    }

    toast.success('Restauración académica completada', {
      description: `${Number(data.courses) || 0} cursos, ${Number(data.students) || 0} estudiantes y ${Number(data.grades) || 0} calificaciones restaurados.`
    })
    showRestoreJsonModal.value = false
    restoreFile.value = null
    restoreData.value = null
    restoreSummary.value = null
    await loadTenants()
  } catch (err) {
    toast.error('Error restaurando datos académicos: ' + (err.message || 'Error desconocido'))
  } finally {
    restoring.value = false
  }
}
onMounted(() => {
  loadTenants()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Controles de Filtros y Acciones Rápidas -->
    <div class="flex flex-col lg:flex-row items-center justify-between gap-4 bg-white dark:bg-slate-900/80 p-4 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm">
      <!-- Búsqueda -->
      <div class="relative flex-1 w-full">
        <Search class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input 
          v-model="searchQuery" 
          type="text" 
          placeholder="Buscar por institución, código o correo admin..." 
          class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl pl-9 pr-4 py-2 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 outline-none transition-all placeholder:text-slate-400 dark:placeholder:text-slate-500"
        />
      </div>

      <!-- Filtro por Estado y Acciones de Base de Datos -->
      <div class="flex flex-wrap items-center gap-2 w-full lg:w-auto">
        <div class="flex items-center gap-2">
          <Filter class="w-4 h-4 text-slate-400 shrink-0" />
          <select 
            v-model="selectedStatusFilter"
            class="bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 outline-none w-full sm:w-auto cursor-pointer"
          >
            <option value="all">Todos los estados</option>
            <option value="active">Activa</option>
            <option value="trial">En Prueba</option>
            <option value="past_due">Pago Vencido</option>
            <option value="grace_period">Período de Gracia</option>
            <option value="suspended">Suspendida</option>
            <option value="cancelled">Cancelada</option>
          </select>
        </div>

        <button 
          type="button" 
          @click="downloadInstitutionsTemplate" 
          class="px-3.5 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 text-slate-700 border border-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 dark:text-slate-200 dark:border-slate-700 rounded-xl transition-all flex items-center gap-1.5 cursor-pointer"
          title="Descargar plantilla CSV oficial para registro de instituciones"
        >
          <FileSpreadsheet class="w-4 h-4 text-emerald-500 dark:text-emerald-400" /> Plantilla CSV
        </button>

        <button 
          type="button" 
          @click="openRestoreJsonModal" 
          class="px-3.5 py-2 text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl transition-all flex items-center gap-1.5 cursor-pointer shadow-md shadow-indigo-600/20"
          title="Restaurar datos académicos institucionales desde un respaldo JSON"
        >
          <Database class="w-4 h-4 text-indigo-200" /> Restaurar Respaldo JSON
        </button>
      </div>
    </div>

    <!-- Tabla Profesional de Instituciones -->
    <div class="bg-white dark:bg-slate-900/80 border border-slate-200 dark:border-slate-800 rounded-2xl overflow-hidden shadow-sm">
      <div class="overflow-x-auto">
        <table class="w-full text-left text-sm min-w-[1000px]">
          <thead class="bg-slate-50 dark:bg-slate-950 text-slate-600 dark:text-slate-400 border-b border-slate-200 dark:border-slate-800 text-xs font-semibold uppercase tracking-wider">
            <tr>
              <th class="px-5 py-3.5 sticky left-0 bg-slate-50 dark:bg-slate-950 z-20 shadow-[2px_0_4px_rgba(0,0,0,0.05)] dark:shadow-[2px_0_4px_rgba(0,0,0,0.3)] w-44 sm:w-64">Institución</th>
              <th class="px-5 py-3.5">Plan & Costo</th>
              <th class="px-5 py-3.5">Administrador</th>
              <th class="px-5 py-3.5">Estudiantes / Cupo</th>
              <th class="px-5 py-3.5">Estado</th>
              <th class="px-5 py-3.5">Próx. Renovación / Fin Prueba</th>
              <th class="px-5 py-3.5 text-right">Acciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-200 dark:divide-slate-800/60 text-slate-700 dark:text-slate-300">
            <tr v-if="loading">
              <td colspan="7" class="py-12 text-center text-slate-500">Cargando directorio de instituciones...</td>
            </tr>
            <tr v-else-if="filteredTenants.length === 0">
              <td colspan="7" class="py-12 text-center text-slate-500">No se encontraron instituciones registradas.</td>
            </tr>
            <tr v-else v-for="t in filteredTenants" :key="t.id" class="hover:bg-slate-50/80 dark:hover:bg-slate-800/40 transition-colors group">
              <!-- Nombre Institución -->
              <td class="px-5 py-4 sticky left-0 bg-white group-hover:bg-slate-50 dark:bg-slate-900 dark:group-hover:bg-[#12182b] z-10 shadow-[2px_0_4px_rgba(0,0,0,0.05)] dark:shadow-[2px_0_4px_rgba(0,0,0,0.3)] w-44 sm:w-64">
                <div class="font-bold text-slate-900 dark:text-white flex items-center gap-2">
                  <Building2 class="w-4 h-4 text-indigo-600 dark:text-indigo-400 shrink-0" />
                  <span>{{ t.name }}</span>
                </div>
                <div class="text-xs text-slate-500 dark:text-slate-400 mt-1 flex flex-wrap items-center gap-1.5">
                  <span>{{ t.city || 'Ecuador' }} • Cód: <span class="font-mono text-slate-700 dark:text-slate-300">{{ t.code || 'N/A' }}</span></span>
                  <button 
                    v-if="t.latestReceiptUrl"
                    @click="openReceiptViewer(t)"
                    class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-emerald-50 dark:bg-emerald-500/20 hover:bg-emerald-100 dark:hover:bg-emerald-500/30 text-emerald-700 dark:text-emerald-300 text-[11px] font-bold border border-emerald-200 dark:border-emerald-500/40 transition-colors shadow-xs cursor-pointer"
                    title="Ver comprobante de pago subido por la institución"
                  >
                    📷 Comprobante
                  </button>
                </div>
              </td>

              <!-- Plan -->
              <td class="px-5 py-4">
                <div class="font-semibold text-slate-900 dark:text-slate-200">{{ t.planName }}</div>
                <div class="text-xs text-emerald-600 dark:text-emerald-400 font-medium">${{ t.planPrice }} / {{ t.billingCycle === 'yearly' ? 'año' : 'mes' }}</div>
              </td>

              <!-- Administrador -->
              <td class="px-5 py-4">
                <div class="font-medium text-slate-900 dark:text-slate-200">{{ t.adminName }}</div>
                <div class="text-xs text-slate-500 dark:text-slate-400">{{ t.adminEmail }}</div>
              </td>

              <!-- Estudiantes y Cupo del Plan -->
              <td class="px-5 py-4">
                <div class="space-y-1 min-w-[140px]">
                  <div class="flex items-center justify-between text-xs gap-1.5">
                    <span class="font-bold text-slate-900 dark:text-white font-mono">{{ t.studentCount }} / {{ t.maxStudents }}</span>
                    <span :class="[
                      'text-[10px] font-bold px-1.5 py-0.2 rounded',
                      t.studentCount >= t.maxStudents ? 'bg-rose-50 text-rose-700 border border-rose-200 dark:bg-rose-500/20 dark:text-rose-300 dark:border-rose-500/40' :
                      t.studentCount >= t.maxStudents * 0.85 ? 'bg-amber-50 text-amber-700 border border-amber-200 dark:bg-amber-500/20 dark:text-amber-300 dark:border-amber-500/40' :
                      'text-slate-600 bg-slate-100 dark:text-slate-400 dark:bg-slate-800'
                    ]">
                      {{ t.studentCount >= t.maxStudents ? '100% LLENO' : `${Math.round((t.studentCount / (t.maxStudents || 1)) * 100)}%` }}
                    </span>
                  </div>
                  <div class="w-full h-1.5 bg-slate-200 dark:bg-slate-800 rounded-full overflow-hidden">
                    <div 
                      class="h-full rounded-full transition-all duration-300"
                      :class="[
                        t.studentCount >= t.maxStudents ? 'bg-rose-500' :
                        t.studentCount >= t.maxStudents * 0.85 ? 'bg-amber-500' :
                        'bg-emerald-500'
                      ]"
                      :style="{ width: `${Math.min(100, Math.round((t.studentCount / (t.maxStudents || 1)) * 100))}%` }"
                    ></div>
                  </div>
                  <div class="text-[10px] text-slate-500 dark:text-slate-400">{{ t.userCount }} usuarios registrados</div>
                </div>
              </td>

              <!-- Estado Badge -->
              <td class="px-5 py-4">
                <span :class="[
                  'px-2.5 py-1 rounded-full text-xs font-semibold uppercase tracking-wider',
                  t.status === 'active' ? 'bg-emerald-50 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-500/20' :
                  t.status === 'trial' ? 'bg-sky-50 dark:bg-sky-500/10 text-sky-700 dark:text-sky-400 border border-sky-200 dark:border-sky-500/20' :
                  t.status === 'past_due' ? 'bg-amber-50 dark:bg-amber-500/10 text-amber-700 dark:text-amber-400 border border-amber-200 dark:border-amber-500/20' :
                  t.status === 'suspended' ? 'bg-rose-50 dark:bg-rose-500/10 text-rose-700 dark:text-rose-400 border border-rose-200 dark:border-rose-500/20' :
                  'bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-400 border border-slate-200 dark:border-slate-700'
                ]">
                  {{ statusLabel(t.status) }}
                </span>
              </td>

              <!-- Renovación / Fin de Prueba -->
              <td class="px-5 py-4 text-xs font-mono">
                <div class="flex flex-col">
                  <span class="text-slate-900 dark:text-white font-bold">{{ t.nextBilling }}</span>
                  <span v-if="t.isTrial && t.daysRemaining !== null" :class="t.daysRemaining <= 3 ? 'text-rose-600 dark:text-rose-400 font-bold' : 'text-sky-600 dark:text-sky-400'" class="text-[11px]">
                    {{ t.daysRemaining > 0 ? `Prueba (${t.daysRemaining}d)` : 'Prueba finalizada' }}
                  </span>
                  <span v-else-if="t.status === 'active'" class="text-emerald-600 dark:text-emerald-400 text-[11px]">
                    Renovación {{ t.billingCycle === 'yearly' ? 'Anual' : 'Mensual' }}
                  </span>
                  <span v-else class="text-slate-500 dark:text-slate-400 text-[11px]">
                    {{ statusLabel(t.status) }}
                  </span>
                </div>
              </td>

              <!-- Acciones Contextuales -->
              <td class="px-5 py-4 text-right">
                <div class="flex items-center justify-end gap-1.5">
                  <button 
                    v-if="t.latestReceiptUrl"
                    @click="openReceiptViewer(t)"
                    title="Ver foto del comprobante de pago subido"
                    aria-label="Ver comprobante de pago"
                    class="p-2 rounded-lg bg-indigo-50 hover:bg-indigo-100 text-indigo-600 border border-indigo-200 dark:bg-indigo-950/80 dark:hover:bg-indigo-900 dark:text-indigo-300 dark:border-indigo-700/60 transition-colors shadow-xs cursor-pointer"
                  >
                    <Eye class="w-4 h-4" />
                  </button>

                  <button
                    @click="openTenantWorkspace(t)"
                    title="Abrir espacio institucional"
                    aria-label="Abrir espacio institucional"
                    class="p-2 rounded-lg bg-indigo-50 hover:bg-indigo-100 text-indigo-600 border border-indigo-200 dark:bg-indigo-950/60 dark:hover:bg-indigo-900 dark:text-indigo-300 dark:border-indigo-800/50 transition-colors cursor-pointer"
                  >
                    <LogIn class="w-4 h-4" />
                  </button>
                  <button 
                    @click="openFeaturesModal(t)"
                    title="Gestionar Módulos"
                    aria-label="Gestionar módulos"
                    class="p-2 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 border border-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 dark:text-slate-300 dark:border-slate-700 transition-colors cursor-pointer"
                  >
                    <Sliders class="w-4 h-4" />
                  </button>

                  <button 
                    @click="openLimitsModal(t)"
                    title="Gestionar Límites"
                    aria-label="Gestionar límites"
                    class="p-2 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 border border-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 dark:text-slate-300 dark:border-slate-700 transition-colors cursor-pointer"
                  >
                    <Shield class="w-4 h-4" />
                  </button>

                  <button 
                    @click="openPaymentModal(t)"
                    title="Registrar Pago"
                    aria-label="Registrar pago"
                    class="p-2 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-600 border border-emerald-200 dark:bg-emerald-950/60 dark:hover:bg-emerald-900 dark:text-emerald-300 dark:border-emerald-800/50 transition-colors cursor-pointer"
                  >
                    <DollarSign class="w-4 h-4" />
                  </button>

                  <button
                    @click="openInvoicesModal(t)"
                    title="Ver facturas"
                    aria-label="Ver historial de facturas"
                    class="p-2 rounded-lg bg-sky-50 hover:bg-sky-100 text-sky-600 border border-sky-200 dark:bg-sky-950/60 dark:hover:bg-sky-900 dark:text-sky-300 dark:border-sky-800/50 transition-colors cursor-pointer"
                  >
                    <FileText class="w-4 h-4" />
                  </button>

                  <button 
                    v-if="t.status !== 'suspended'"
                    @click="openSuspendModal(t)"
                    title="Suspender Institución"
                    aria-label="Suspender institución"
                    class="p-2 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-600 border border-rose-200 dark:bg-rose-950/60 dark:hover:bg-rose-900 dark:text-rose-300 dark:border-rose-800/50 transition-colors cursor-pointer"
                  >
                    <Ban class="w-4 h-4" />
                  </button>

                  <button 
                    v-else
                    @click="executeStatusChange('active', t)"
                    :disabled="statusChangingTenantId !== null"
                    :title="statusChangingTenantId === t.id ? 'Reactivando institución...' : 'Reactivar Institución'"
                    aria-label="Reactivar institución"
                    class="p-2 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-600 border border-emerald-200 dark:bg-emerald-950/60 dark:hover:bg-emerald-900 dark:text-emerald-300 dark:border-emerald-800/50 transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-wait"
                  >
                    <RefreshCw v-if="statusChangingTenantId === t.id" class="w-4 h-4 animate-spin" />
                    <CheckCircle v-else class="w-4 h-4" />
                  </button>

                  <button 
                    @click="downloadTenantBackup(t)"
                    :disabled="generatingBackup"
                    title="Descargar Respaldo (JSON)"
                    aria-label="Descargar respaldo de base de datos"
                    class="p-2 rounded-lg bg-indigo-50 hover:bg-indigo-100 text-indigo-600 border border-indigo-200 dark:bg-indigo-950/80 dark:hover:bg-indigo-900 dark:text-indigo-300 dark:border-indigo-800/70 transition-colors disabled:opacity-50 cursor-pointer"
                  >
                    <Download class="w-4 h-4" />
                  </button>

                  <button 
                    @click="openDeleteModal(t)"
                    title="Eliminar Institución"
                    aria-label="Eliminar institución"
                    class="p-2 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-600 border border-rose-200 dark:bg-rose-950/80 dark:hover:bg-rose-900 dark:text-rose-400 dark:border-rose-800/70 transition-colors cursor-pointer"
                  >
                    <Trash2 class="w-4 h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- MODAL FEATURE FLAGS -->
    <div v-if="showFeaturesModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm" role="dialog" aria-modal="true" aria-labelledby="features-dialog-title">
      <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl">
        <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-800 pb-3">
          <h3 id="features-dialog-title" class="font-bold text-lg text-slate-900 dark:text-white">Módulos Habilitados para {{ selectedTenant?.name }}</h3>
          <button @click="showFeaturesModal = false" aria-label="Cerrar gestión de módulos" class="text-slate-400 hover:text-slate-700 dark:hover:text-white cursor-pointer"><X class="w-5 h-5" /></button>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm text-slate-700 dark:text-slate-200">
          <label v-for="(val, key) in tenantFeatures" :key="key" class="flex items-center gap-3 p-3 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 cursor-pointer hover:border-slate-300 dark:hover:border-slate-700">
            <input type="checkbox" v-model="tenantFeatures[key]" class="w-4 h-4 rounded bg-white dark:bg-slate-900 border-slate-300 dark:border-slate-700 text-indigo-600 focus:ring-indigo-500" />
            <span class="font-medium text-slate-800 dark:text-slate-200">{{ MODULE_NAMES_ES[key] || key }}</span>
          </label>
        </div>

        <div class="flex justify-end gap-3 pt-3 border-t border-slate-200 dark:border-slate-800">
          <button @click="showFeaturesModal = false" class="px-4 py-2 rounded-xl text-sm font-semibold text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer">Cancelar</button>
          <button @click="saveFeatures" :disabled="savingAction" class="px-4 py-2 rounded-xl text-sm font-bold bg-indigo-600 hover:bg-indigo-500 text-white flex items-center gap-2 cursor-pointer shadow-md shadow-indigo-600/20">
            <Save class="w-4 h-4" /> Guardar Módulos
          </button>
        </div>
      </div>
    </div>

    <!-- MODAL LÍMITES OPERATIVOS -->
    <div
      v-if="showLimitsModal"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
      role="dialog"
      aria-modal="true"
      aria-labelledby="limits-dialog-title"
      @keydown.esc="showLimitsModal = false"
    >
      <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-5 shadow-2xl max-h-[90vh] overflow-y-auto">
        <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-800 pb-3">
          <div>
            <h3 id="limits-dialog-title" class="font-bold text-lg text-slate-900 dark:text-white">Límites de {{ selectedTenant?.name }}</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">El cupo de estudiantes lo determina el plan contratado.</p>
          </div>
          <button @click="showLimitsModal = false" aria-label="Cerrar gestión de límites" class="text-slate-400 hover:text-slate-700 dark:hover:text-white min-w-11 min-h-11 flex items-center justify-center rounded-xl cursor-pointer">
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="grid grid-cols-2 sm:grid-cols-4 gap-2.5" aria-label="Uso actual de la institución">
          <div class="rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-3">
            <div class="text-[11px] text-slate-500 dark:text-slate-400">Usuarios</div>
            <div class="font-bold text-slate-900 dark:text-white text-base mt-0.5 font-mono">{{ usageStats?.users_count ?? 0 }} <span class="text-xs text-slate-400 font-normal">/ {{ tenantLimits.max_users }}</span></div>
          </div>
          <div class="rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-3">
            <div class="text-[11px] text-slate-500 dark:text-slate-400">Docentes</div>
            <div class="font-bold text-slate-900 dark:text-white text-base mt-0.5 font-mono">{{ usageStats?.teachers_count ?? 0 }} <span class="text-xs text-slate-400 font-normal">/ {{ tenantLimits.max_teachers }}</span></div>
          </div>
          <div class="rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-3">
            <div class="text-[11px] text-slate-500 dark:text-slate-400">Estudiantes</div>
            <div class="font-bold text-emerald-600 dark:text-emerald-400 text-base mt-0.5 font-mono">{{ usageStats?.students_count ?? 0 }} <span class="text-xs text-slate-400 font-normal">/ {{ tenantLimits.max_students }}</span></div>
          </div>
          <div class="rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-3">
            <div class="text-[11px] text-slate-500 dark:text-slate-400">Almacenamiento</div>
            <div class="font-bold text-slate-900 dark:text-white text-base mt-0.5 font-mono">{{ usageStats?.storage_mb ?? 0 }} <span class="text-xs text-slate-400 font-normal">MB</span></div>
          </div>
        </div>

        <!-- CUPO COMERCIAL DEL PLAN CON BARRA DE PROGRESO -->
        <div class="rounded-2xl border border-indigo-200 dark:border-indigo-900/60 bg-gradient-to-br from-indigo-50/70 via-white to-slate-50 dark:from-indigo-950/40 dark:via-slate-900 dark:to-slate-950 p-4 space-y-2.5">
          <div class="flex items-center justify-between">
            <div>
              <span class="text-[11px] font-bold text-indigo-700 dark:text-indigo-400 uppercase tracking-wider">Cupo comercial del plan contratado</span>
              <div class="text-xl font-extrabold text-slate-900 dark:text-white mt-0.5">
                {{ usageStats?.students_count ?? 0 }} <span class="text-slate-500 dark:text-slate-400 text-sm font-normal">de</span> {{ tenantLimits.max_students }} estudiantes
              </div>
            </div>
            <div class="text-right">
              <span :class="[
                'text-xs font-black px-2 py-0.5 rounded-full uppercase tracking-wide',
                (usageStats?.students_count || 0) >= tenantLimits.max_students ? 'bg-rose-50 text-rose-700 border border-rose-200 dark:bg-rose-500/20 dark:text-rose-400 dark:border-rose-500/40' :
                (usageStats?.students_count || 0) >= tenantLimits.max_students * 0.85 ? 'bg-amber-50 text-amber-700 border border-amber-200 dark:bg-amber-500/20 dark:text-amber-400 dark:border-amber-500/40' :
                'bg-emerald-50 text-emerald-700 border border-emerald-200 dark:bg-emerald-500/20 dark:text-emerald-400 dark:border-emerald-500/40'
              ]">
                {{ (usageStats?.students_count || 0) >= tenantLimits.max_students ? 'Capacidad Agotada (100%)' : `${Math.round(((usageStats?.students_count || 0) / (tenantLimits.max_students || 1)) * 100)}% Usado` }}
              </span>
            </div>
          </div>

          <!-- Barra de progreso -->
          <div class="w-full h-2.5 bg-slate-200 dark:bg-slate-800 rounded-full overflow-hidden">
            <div 
              class="h-full rounded-full transition-all duration-500"
              :class="[
                (usageStats?.students_count || 0) >= tenantLimits.max_students ? 'bg-rose-500 shadow-sm shadow-rose-500/50' :
                (usageStats?.students_count || 0) >= tenantLimits.max_students * 0.85 ? 'bg-amber-500' :
                'bg-emerald-500'
              ]"
              :style="{ width: `${Math.min(100, Math.round(((usageStats?.students_count || 0) / (tenantLimits.max_students || 1)) * 100))}%` }"
            ></div>
          </div>
          
          <div class="flex items-center justify-between text-[11px] text-slate-500 dark:text-slate-400">
            <span>Plan: <strong class="text-slate-800 dark:text-slate-200">{{ selectedTenant?.planName }}</strong></span>
            <span>Restantes: <strong class="text-slate-900 dark:text-white">{{ Math.max(0, tenantLimits.max_students - (usageStats?.students_count || 0)) }} cupos</strong></span>
          </div>
        </div>

        <!-- BANNERS DE ESTADO DE CAPACIDAD Y ACCIÓN PROFESIONAL -->
        <!-- 1. LÍMITE ALCANZADO (100%) -->
        <div v-if="(usageStats?.students_count || 0) >= tenantLimits.max_students" class="rounded-2xl border border-rose-200 dark:border-rose-500/40 bg-rose-50 dark:bg-gradient-to-br dark:from-rose-950/70 dark:via-slate-900 dark:to-rose-950/50 p-4 space-y-3 shadow-sm">
          <div class="flex items-start gap-3">
            <div class="p-2.5 bg-rose-100 text-rose-700 dark:bg-rose-500/20 dark:text-rose-400 rounded-xl border border-rose-200 dark:border-rose-500/30 shrink-0">
              <AlertCircle class="w-5 h-5 animate-pulse" />
            </div>
            <div class="space-y-1">
              <h4 class="text-xs font-bold text-rose-800 dark:text-rose-200 uppercase tracking-wide">
                🚫 Capacidad Máxima de Estudiantes Alcanzada ({{ usageStats?.students_count }} / {{ tenantLimits.max_students }})
              </h4>
              <p class="text-xs text-rose-700 dark:text-rose-200/90 leading-relaxed">
                La institución ha alcanzado el 100% de los cupos de estudiantes incluidos en su suscripción actual (<strong>{{ selectedTenant?.planName }}</strong>).
              </p>
            </div>
          </div>

          <div class="pt-3 border-t border-rose-200 dark:border-rose-900/50 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs">
            <div class="text-slate-700 dark:text-slate-300 text-xs flex items-center gap-1.5">
              <span>📞 Para ampliar cupos, comunicarse con <strong>Servicio al Cliente y Soporte de Adyron WebNotas</strong>.</span>
            </div>
            <a 
              :href="`https://wa.me/593981881691?text=Hola%2C%20solicito%20ampliación%20de%20cupo%20de%20estudiantes%20para%20la%20institución%20${encodeURIComponent(selectedTenant?.name || '')}`" 
              target="_blank" 
              rel="noopener noreferrer"
              class="w-full sm:w-auto px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl font-bold text-xs transition-all shadow-md shadow-rose-600/20 inline-flex items-center justify-center gap-1.5 shrink-0"
            >
              <span>💬 Contactar Soporte / Ventas</span>
            </a>
          </div>
        </div>

        <!-- 2. ALERTA PREVENTIVA (85%+ CAPACIDAD) -->
        <div v-else-if="(usageStats?.students_count || 0) >= tenantLimits.max_students * 0.85" class="rounded-2xl border border-amber-200 dark:border-amber-500/30 bg-amber-50 dark:bg-amber-950/30 p-3.5 space-y-2">
          <div class="flex items-center gap-2 text-amber-800 dark:text-amber-300 text-xs font-bold">
            <AlertCircle class="w-4 h-4 text-amber-600 dark:text-amber-400" />
            <span>Alerta de Capacidad: {{ Math.round(((usageStats?.students_count || 0) / (tenantLimits.max_students || 1)) * 100) }}% Utilizado</span>
          </div>
          <p class="text-xs text-amber-700 dark:text-amber-200/90 leading-relaxed">
            La institución cuenta con <strong>{{ usageStats?.students_count }}</strong> estudiantes registrados. Quedan únicamente <strong>{{ tenantLimits.max_students - (usageStats?.students_count || 0) }} cupos disponibles</strong>. Se sugiere contactar a la institución para coordinar un upgrade antes de que se bloqueen nuevas matrículas.
          </p>
        </div>

        <!-- 3. ESTADO NORMAL (<85%) -->
        <div v-else class="rounded-xl border border-emerald-200 dark:border-emerald-500/20 bg-emerald-50 dark:bg-emerald-950/20 p-3 flex items-center justify-between text-xs">
          <div class="flex items-center gap-2 text-emerald-700 dark:text-emerald-400 font-medium">
            <CheckCircle class="w-4 h-4 text-emerald-600 dark:text-emerald-400 shrink-0" />
            <span>Uso normal: {{ usageStats?.students_count || 0 }} de {{ tenantLimits.max_students }} estudiantes activos ({{ Math.round(((usageStats?.students_count || 0) / (tenantLimits.max_students || 1)) * 100) }}%)</span>
          </div>
          <span class="text-slate-500 dark:text-slate-400 text-[11px] font-mono">{{ tenantLimits.max_students - (usageStats?.students_count || 0) }} cupos libres</span>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label for="limit-max-users" class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">Máximo de usuarios</label>
            <input id="limit-max-users" v-model.number="tenantLimits.max_users" type="number" min="1" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-700 rounded-xl p-2.5 text-base text-slate-900 dark:text-white outline-none focus:border-indigo-500" />
          </div>
          <div>
            <label for="limit-max-teachers" class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">Máximo de docentes</label>
            <input id="limit-max-teachers" v-model.number="tenantLimits.max_teachers" type="number" min="1" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-700 rounded-xl p-2.5 text-base text-slate-900 dark:text-white outline-none focus:border-indigo-500" />
          </div>
          <div class="sm:col-span-2">
            <label for="limit-storage" class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">Almacenamiento máximo (MB)</label>
            <input id="limit-storage" v-model.number="tenantLimits.storage_mb" type="number" min="1" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-700 rounded-xl p-2.5 text-base text-slate-900 dark:text-white outline-none focus:border-indigo-500" />
          </div>
        </div>

        <div class="flex flex-col-reverse sm:flex-row justify-end gap-3 pt-3 border-t border-slate-200 dark:border-slate-800">
          <button @click="showLimitsModal = false" class="px-4 py-2.5 rounded-xl text-sm font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer">Cancelar</button>
          <button @click="saveLimits" :disabled="savingAction" class="px-4 py-2.5 rounded-xl text-sm font-bold bg-indigo-600 hover:bg-indigo-500 text-white disabled:opacity-50 cursor-pointer shadow-md shadow-indigo-600/20">
            {{ savingAction ? 'Guardando…' : 'Guardar límites operativos' }}
          </button>
        </div>
      </div>
    </div>

    <!-- MODAL REGISTRO DE PAGO -->
    <div v-if="showPaymentModal" class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/80 backdrop-blur-sm overflow-y-auto" role="dialog" aria-modal="true" aria-labelledby="payment-dialog-title">
      <div class="bg-white dark:bg-slate-900 border border-emerald-200 dark:border-emerald-900/60 rounded-2xl max-w-3xl w-full p-5 sm:p-6 space-y-4 shadow-2xl my-auto max-h-[92vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-800 pb-3 flex-shrink-0">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-emerald-50 dark:bg-emerald-500/10 border border-emerald-200 dark:border-emerald-500/30 flex items-center justify-center text-emerald-600 dark:text-emerald-400">
              <DollarSign class="w-5 h-5" />
            </div>
            <div>
              <h3 id="payment-dialog-title" class="font-bold text-base sm:text-lg text-slate-900 dark:text-white">
                Registrar Conciliación de Pago
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Verifica la transferencia o depósito bancario institucional</p>
            </div>
          </div>
          <button @click="showPaymentModal = false" aria-label="Cerrar registro de pago" class="p-2 rounded-xl text-slate-400 hover:text-slate-700 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Scrollable Content -->
        <div class="overflow-y-auto pr-1 space-y-4 flex-1">
          <!-- Banner resumen -->
          <div class="rounded-xl bg-slate-50 dark:bg-gradient-to-br dark:from-slate-950 dark:to-slate-900 border border-slate-200 dark:border-slate-800 p-4 text-sm">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 items-center">
              <div>
                <span class="text-slate-500 dark:text-slate-400 text-xs block">Institución educativa</span>
                <strong class="font-bold text-slate-900 dark:text-white text-base block">{{ selectedTenant?.name }}</strong>
                <span class="text-xs text-indigo-600 dark:text-indigo-400 font-semibold">{{ selectedTenant?.planName }} · Ciclo {{ selectedTenant?.billingCycle === 'yearly' ? 'Anual' : 'Mensual' }}</span>
              </div>
              <div class="sm:text-right bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800/40 rounded-xl p-3 sm:p-2.5">
                <span class="text-slate-600 dark:text-slate-300 text-xs block font-medium">Monto a conciliar</span>
                <span class="text-2xl font-black text-emerald-600 dark:text-emerald-400 block tracking-tight">${{ paymentExpectedAmount }} <span class="text-xs font-bold text-emerald-600 dark:text-emerald-500">USD</span></span>
              </div>
            </div>
            
            <div class="mt-3 pt-2.5 border-t border-slate-200 dark:border-slate-800 flex flex-wrap items-center justify-between gap-2 text-xs">
              <div v-if="selectedTenant?.implementationFeeStatus === 'pending'" class="inline-flex items-center gap-1.5 text-amber-800 dark:text-amber-300 bg-amber-50 dark:bg-amber-500/10 px-2.5 py-1 rounded-lg border border-amber-200 dark:border-amber-500/20 font-medium">
                ⚡ Incluye ${{ selectedTenant?.implementationFee }} USD de implementación inicial
              </div>
              <div v-else class="text-slate-500 dark:text-slate-400">
                Tarifa recurrente de suscripción
              </div>
              <div class="flex items-center gap-1.5 text-slate-700 dark:text-slate-300 ml-auto">
                <span class="text-slate-500 dark:text-slate-400">Próxima renovación:</span>
                <span class="text-emerald-700 dark:text-emerald-400 font-mono font-bold bg-emerald-100 dark:bg-emerald-950/60 px-2 py-0.5 rounded border border-emerald-200 dark:border-emerald-800/50">
                  {{ calculateNewBillingDatePreview(selectedTenant) }}
                </span>
              </div>
            </div>
          </div>

          <!-- ASISTENTE DE AUDITORÍA CON IA -->
          <div v-if="paymentForm.receiptUrl" class="rounded-xl border border-indigo-200 dark:border-indigo-500/30 bg-indigo-50/60 dark:bg-gradient-to-r dark:from-indigo-950/60 dark:via-purple-950/40 dark:to-slate-950 p-3.5 space-y-2.5">
            <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2.5">
              <div class="flex items-center gap-2">
                <div class="w-8 h-8 rounded-lg bg-indigo-100 dark:bg-indigo-500/20 border border-indigo-200 dark:border-indigo-500/40 flex items-center justify-center text-indigo-700 dark:text-indigo-300 shrink-0">
                  <Sparkles class="w-4 h-4 text-indigo-600 dark:text-indigo-400 animate-pulse" />
                </div>
                <div>
                  <h4 class="text-xs font-bold text-slate-900 dark:text-white flex items-center gap-1.5">
                    IA Auditora de Comprobantes Bancarios
                  </h4>
                  <p class="text-[11px] text-indigo-700 dark:text-indigo-300/80">Reconocimiento óptico inteligente (OCR) y cuadre automático de valores</p>
                </div>
              </div>

              <button 
                type="button" 
                @click="runAiReceiptAudit" 
                :disabled="aiAuditing"
                class="w-full sm:w-auto px-3.5 py-1.5 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 shadow-md shadow-indigo-600/20 transition-all disabled:opacity-50 cursor-pointer"
              >
                <RefreshCw v-if="aiAuditing" class="w-3.5 h-3.5 animate-spin" />
                <Sparkles v-else class="w-3.5 h-3.5 text-amber-300" />
                <span>{{ aiAuditing ? (aiAuditProgress || 'Analizando con IA...') : 'Analizar y Cuadrar con IA' }}</span>
              </button>
            </div>

            <!-- RESULTADO DE LA AUDITORÍA IA -->
            <div v-if="aiAuditResult" class="pt-2 border-t border-indigo-200 dark:border-indigo-900/40 space-y-2 text-xs">
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-2 bg-white dark:bg-slate-950/80 p-2.5 rounded-lg border border-indigo-200 dark:border-indigo-900/40">
                <div>
                  <span class="text-[10px] text-slate-500 dark:text-slate-400 block font-medium">🏦 Banco / Entidad</span>
                  <strong class="text-slate-900 dark:text-white font-bold text-xs">{{ aiAuditResult.bank }}</strong>
                </div>
                <div>
                  <span class="text-[10px] text-slate-500 dark:text-slate-400 block font-medium">💵 Monto Detectado</span>
                  <strong :class="aiAuditResult.isMatch ? 'text-emerald-600 dark:text-emerald-400' : 'text-amber-600 dark:text-amber-400'" class="font-black text-xs">
                    {{ aiAuditResult.amount ? `$${aiAuditResult.amount.toFixed(2)} USD` : 'No detectado' }}
                  </strong>
                </div>
                <div>
                  <span class="text-[10px] text-slate-500 dark:text-slate-400 block font-medium">🏷️ Comprobante / Ref</span>
                  <strong class="text-indigo-600 dark:text-indigo-300 font-mono text-xs">{{ aiAuditResult.reference }}</strong>
                </div>
              </div>

              <!-- Mensaje de Cuadre y botón autocompletar -->
              <div :class="[
                'p-2 rounded-lg flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2 text-[11px] font-medium border',
                aiAuditResult.status === 'exact_match' ? 'bg-emerald-50 text-emerald-800 border-emerald-200 dark:bg-emerald-950/50 dark:text-emerald-300 dark:border-emerald-800/60' :
                aiAuditResult.status === 'overpayment' ? 'bg-sky-50 text-sky-800 border-sky-200 dark:bg-sky-950/50 dark:text-sky-300 dark:border-sky-800/60' :
                'bg-amber-50 text-amber-800 border-amber-200 dark:bg-amber-950/50 dark:text-amber-300 dark:border-amber-800/60'
              ]">
                <div class="flex items-center gap-1.5">
                  <CheckCheck v-if="aiAuditResult.isMatch" class="w-4 h-4 text-emerald-600 dark:text-emerald-400 shrink-0" />
                  <AlertCircle v-else class="w-4 h-4 text-amber-600 dark:text-amber-400 shrink-0" />
                  <span>{{ aiAuditResult.message }}</span>
                </div>
                <button 
                  type="button" 
                  @click="applyAiDetectedData"
                  class="w-full sm:w-auto px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg text-xs font-bold shrink-0 transition-colors shadow-sm cursor-pointer flex items-center justify-center gap-1"
                >
                  <CheckCircle class="w-3.5 h-3.5" />
                  <span>⚡ Autocompletar datos</span>
                </button>
              </div>
            </div>
          </div>

          <!-- Grid de 2 columnas: Comprobante (Izq) + Datos (Der) -->
          <div class="grid grid-cols-1 md:grid-cols-12 gap-4 items-start">
            <!-- Columna Izquierda: Comprobante (5 cols) -->
            <div class="md:col-span-5 space-y-2 bg-slate-50 dark:bg-slate-950 p-3.5 rounded-xl border border-slate-200 dark:border-slate-800 h-full flex flex-col justify-between">
              <div>
                <label class="block text-xs font-bold text-indigo-700 dark:text-indigo-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                  📷 Comprobante / Recibo
                </label>

                <div v-if="paymentForm.receiptUrl" class="space-y-2">
                  <div class="relative group rounded-lg overflow-hidden border border-indigo-200 dark:border-indigo-900/60 bg-white dark:bg-slate-900 max-h-40 flex items-center justify-center p-1">
                    <img 
                      v-if="!isPdfBillingProof(paymentForm.receiptPath || paymentForm.receiptUrl)"
                      :src="paymentForm.receiptUrl" 
                      alt="Comprobante" 
                      class="max-h-36 w-auto object-contain rounded" 
                    />
                    <div v-else class="py-6 text-center text-xs text-indigo-600 dark:text-indigo-300 flex flex-col items-center gap-1">
                      <FileText class="w-8 h-8 text-indigo-500 dark:text-indigo-400" />
                      <span>Documento PDF</span>
                    </div>
                  </div>
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-[11px] text-emerald-600 dark:text-emerald-400 font-semibold">✓ Comprobante cargado</span>
                    <a :href="paymentForm.receiptUrl" target="_blank" rel="noopener noreferrer" class="px-2.5 py-1 rounded-lg bg-indigo-50 hover:bg-indigo-100 text-indigo-700 dark:bg-indigo-600/30 dark:hover:bg-indigo-600/50 dark:text-indigo-300 font-bold text-xs transition-colors border border-indigo-200 dark:border-transparent">
                      👁️ Ver completo
                    </a>
                  </div>
                </div>

                <div v-else class="p-4 rounded-lg border border-dashed border-slate-300 dark:border-slate-800 text-center text-xs text-slate-500">
                  Sin foto de comprobante previa
                </div>
              </div>

              <div class="pt-2 border-t border-slate-200 dark:border-slate-800/80">
                <label class="block text-[11px] text-slate-600 dark:text-slate-400 mb-1">Cargar o reemplazar foto:</label>
                <input 
                  type="file" 
                  accept="image/jpeg,image/png,image/webp,application/pdf"
                  @change="onModalReceiptFileChange"
                  :disabled="paymentForm.uploadingReceipt"
                  class="block w-full text-xs text-slate-500 dark:text-slate-400 file:mr-2 file:py-1 file:px-2.5 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-slate-100 file:text-slate-700 dark:file:bg-slate-800 dark:file:text-indigo-300 hover:file:bg-slate-200 dark:hover:file:bg-slate-700 cursor-pointer"
                />
              </div>
            </div>

            <!-- Columna Derecha: Formulario (7 cols) -->
            <div class="md:col-span-7 space-y-3 bg-slate-50/70 dark:bg-slate-950/60 p-3.5 rounded-xl border border-slate-200 dark:border-slate-800">
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Referencia bancaria *</label>
                  <input v-model="paymentForm.providerReference" type="text" placeholder="Ej: TRANSF-892341" class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-2.5 text-xs text-slate-900 dark:text-white outline-none focus:border-indigo-500 transition-colors" />
                </div>
                <div>
                  <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Nº factura externa *</label>
                  <input v-model="paymentForm.externalInvoiceNumber" type="text" placeholder="Ej: FAC-001-0982" class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-2.5 text-xs text-slate-900 dark:text-white outline-none focus:border-indigo-500 transition-colors" />
                </div>
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Fecha y hora del pago *</label>
                <input v-model="paymentForm.paidAt" type="datetime-local" class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-2.5 text-xs text-slate-900 dark:text-white outline-none focus:border-indigo-500 transition-colors" />
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-700 dark:text-slate-400 mb-1">Notas / Observaciones</label>
                <textarea v-model="paymentForm.notes" rows="2" placeholder="Detalles adicionales del depósito..." class="w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-2.5 text-xs text-slate-900 dark:text-white outline-none focus:border-indigo-500 transition-colors resize-none"></textarea>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="flex items-center justify-end gap-3 pt-3 border-t border-slate-200 dark:border-slate-800 flex-shrink-0">
          <button @click="showPaymentModal = false" class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer">
            Cancelar
          </button>
          <button @click="recordPayment" :disabled="savingAction || paymentForm.uploadingReceipt" class="px-5 py-2.5 rounded-xl text-xs font-bold bg-emerald-600 hover:bg-emerald-500 text-white disabled:opacity-50 flex items-center gap-1.5 shadow-md shadow-emerald-600/20 transition-all cursor-pointer">
            <CheckCircle class="w-4 h-4" />
            <span>{{ savingAction ? 'Registrando...' : 'Confirmar pago verificado' }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- MODAL HISTORIAL DE FACTURAS -->
    <div
      v-if="showInvoicesModal"
      class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/60 backdrop-blur-sm"
      role="dialog"
      aria-modal="true"
      aria-labelledby="invoices-dialog-title"
      @keydown.esc="showInvoicesModal = false"
    >
      <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-sky-900/60 rounded-2xl max-w-3xl w-full p-4 sm:p-6 space-y-4 shadow-2xl max-h-[90vh] overflow-y-auto">
        <div class="flex items-start justify-between gap-4 border-b border-slate-200 dark:border-slate-800 pb-3">
          <div>
            <h3 id="invoices-dialog-title" class="font-bold text-lg text-slate-900 dark:text-white flex items-center gap-2">
              <FileText class="w-5 h-5 text-sky-500 dark:text-sky-400" /> Historial de facturas
            </h3>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">{{ selectedTenant?.name }} · últimas 50</p>
          </div>
          <button
            type="button"
            @click="showInvoicesModal = false"
            aria-label="Cerrar historial de facturas"
            class="min-w-11 min-h-11 flex items-center justify-center rounded-xl text-slate-400 hover:text-slate-700 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <p v-if="loadingInvoices" role="status" class="py-8 text-center text-sm text-slate-500 dark:text-slate-400">Cargando facturas…</p>
        <p v-else-if="invoicesError" role="alert" class="rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900 p-4 text-sm text-rose-700 dark:text-rose-300">{{ invoicesError }}</p>
        <div v-else-if="invoices.length === 0" class="rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-8 text-center">
          <FileText class="w-8 h-8 text-slate-400 dark:text-slate-600 mx-auto" />
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-3">Todavía no hay facturas conciliadas para esta institución.</p>
        </div>
        <ul v-else class="space-y-3" aria-label="Facturas conciliadas">
          <li v-for="invoice in invoices" :key="invoice.id" class="rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-4">
            <div class="flex flex-col sm:flex-row sm:items-start justify-between gap-3">
              <div>
                <div class="font-mono font-bold text-slate-900 dark:text-white break-all">{{ invoice.invoice_number }}</div>
                <div class="text-xs text-slate-500 dark:text-slate-400 mt-1">Emitida {{ shortDate(invoice.issued_at) }} · vence {{ shortDate(invoice.due_at) }}</div>
              </div>
              <div class="sm:text-right">
                <div class="text-lg font-extrabold text-emerald-600 dark:text-emerald-400">{{ money(invoice.total, invoice.currency) }}</div>
                <span :class="[
                  'inline-flex mt-1 px-2.5 py-1 rounded-full text-xs font-semibold border',
                  invoice.status === 'paid' ? 'bg-emerald-50 border-emerald-200 text-emerald-700 dark:bg-emerald-500/10 dark:border-emerald-500/20 dark:text-emerald-300' :
                  invoice.status === 'overdue' ? 'bg-rose-50 border-rose-200 text-rose-700 dark:bg-rose-500/10 dark:border-rose-500/20 dark:text-rose-300' :
                  'bg-amber-50 border-amber-200 text-amber-700 dark:bg-amber-500/10 dark:border-amber-500/20 dark:text-amber-300'
                ]">{{ invoiceStatusLabel(invoice.status) }}</span>
              </div>
            </div>
            <div v-if="invoice.invoice_payment_allocations?.length" class="mt-3 pt-3 border-t border-slate-200 dark:border-slate-800 text-xs text-slate-500 dark:text-slate-400">
              <div v-for="allocation in invoice.invoice_payment_allocations" :key="allocation.payments?.provider_reference || allocation.amount" class="flex flex-col sm:flex-row sm:justify-between gap-1">
                <span>{{ allocation.payments?.provider || 'pago' }} · {{ allocation.payments?.provider_reference || 'sin referencia' }}</span>
                <span>{{ money(allocation.amount, invoice.currency) }} · {{ shortDate(allocation.payments?.paid_at) }}</span>
              </div>
            </div>
          </li>
        </ul>
      </div>
    </div>

    <!-- MODAL VISTA PREVIA DE COMPROBANTE -->
    <div v-if="showReceiptViewerModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-md" role="dialog" aria-modal="true" aria-labelledby="receipt-viewer-title">
      <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-indigo-900/80 rounded-2xl max-w-2xl w-full p-6 space-y-4 shadow-2xl">
        <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-800 pb-3">
          <div>
            <h3 id="receipt-viewer-title" class="font-bold text-lg text-slate-900 dark:text-white flex items-center gap-2">
              <Eye class="w-5 h-5 text-indigo-600 dark:text-indigo-400" /> Comprobante de Pago
            </h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">{{ viewingReceiptTenant?.name }}</p>
          </div>
          <button @click="showReceiptViewerModal = false" aria-label="Cerrar visor" class="text-slate-400 hover:text-slate-700 dark:hover:text-white"><X class="w-5 h-5" /></button>
        </div>

        <div class="bg-slate-50 dark:bg-slate-950 rounded-xl p-3 border border-slate-200 dark:border-slate-800 flex items-center justify-center min-h-[250px] max-h-[65vh] overflow-hidden">
          <img 
            v-if="viewingReceiptTenant?.latestReceiptUrl && !isPdfBillingProof(viewingReceiptTenant.latestReceiptPath || viewingReceiptTenant.latestReceiptUrl)"
            :src="viewingReceiptTenant?.latestReceiptUrl" 
            alt="Comprobante de pago" 
            class="max-h-[60vh] max-w-full object-contain rounded-lg shadow-md" 
          />
          <div v-else-if="viewingReceiptTenant?.latestReceiptUrl" class="text-center py-12 space-y-3">
            <FileText class="w-16 h-16 text-indigo-500 dark:text-indigo-400 mx-auto" />
            <p class="text-sm text-slate-700 dark:text-slate-300 font-semibold">Documento PDF de comprobante adjunto</p>
            <a :href="viewingReceiptTenant?.latestReceiptUrl" target="_blank" rel="noopener noreferrer" class="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold transition-all shadow-md">
              Abrir documento PDF ↗
            </a>
          </div>
          <div v-else class="text-center py-12 text-slate-400 dark:text-slate-500">
            No hay imagen de comprobante disponible.
          </div>
        </div>

        <div class="flex items-center justify-between border-t border-slate-200 dark:border-slate-800 pt-3">
          <a 
            v-if="viewingReceiptTenant?.latestReceiptUrl"
            :href="viewingReceiptTenant?.latestReceiptUrl" 
            target="_blank" 
            rel="noopener noreferrer" 
            class="px-3.5 py-2 text-xs font-semibold bg-slate-100 hover:bg-slate-200 text-slate-700 dark:bg-slate-800 dark:hover:bg-slate-700 dark:text-slate-200 rounded-xl transition-all flex items-center gap-1.5"
          >
            Abrir en pestaña nueva ↗
          </a>
          <div class="flex items-center gap-2">
            <button @click="showReceiptViewerModal = false" class="px-4 py-2 text-xs font-semibold text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-white">
              Cerrar
            </button>
            <button 
              @click="showReceiptViewerModal = false; openPaymentModal(viewingReceiptTenant)" 
              class="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all shadow-lg shadow-emerald-600/20"
            >
              <DollarSign class="w-4 h-4" /> Registrar Pago
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- MODAL SUSPENSIÓN -->
    <div v-if="showSuspendModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-sm" role="dialog" aria-modal="true" aria-labelledby="suspend-dialog-title">
      <div class="bg-white dark:bg-slate-900 border border-rose-200 dark:border-rose-900/60 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl">
        <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-800 pb-3">
          <h3 id="suspend-dialog-title" class="font-bold text-lg text-rose-600 dark:text-rose-400 flex items-center gap-2">
            <Ban class="w-5 h-5" /> Suspender Institución
          </h3>
          <button @click="closeSuspendModal" :disabled="statusChangingTenantId !== null" aria-label="Cerrar suspensión" class="text-slate-400 hover:text-slate-700 dark:hover:text-white disabled:opacity-50"><X class="w-5 h-5" /></button>
        </div>

        <p class="text-sm text-slate-600 dark:text-slate-300">
          Al suspender a <strong class="text-slate-900 dark:text-white">{{ statusActionTarget?.name }}</strong>, se bloqueará el acceso a todos sus rectores y docentes. Los datos se mantendrán intactos.
        </p>

        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">Motivo de Suspensión</label>
          <select v-model="suspendReasonOption" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-2.5 text-sm text-slate-900 dark:text-white outline-none focus:border-rose-500">
            <option value="Pago vencido">Pago vencido</option>
            <option value="Incumplimiento de términos">Incumplimiento de términos</option>
            <option value="Solicitado por la institución">Solicitado por la institución</option>
            <option value="Mantenimiento extraordinario">Mantenimiento extraordinario</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">Observaciones</label>
          <textarea v-model="suspendObservation" placeholder="Detalles de la suspensión..." rows="2" class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl p-2.5 text-sm text-slate-900 dark:text-white outline-none focus:border-rose-500"></textarea>
        </div>

        <div class="flex justify-end gap-3 pt-2">
          <button @click="closeSuspendModal" :disabled="statusChangingTenantId !== null" class="px-4 py-2 rounded-xl text-sm font-semibold text-slate-500 hover:text-slate-800 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors disabled:opacity-50">Cancelar</button>
          <button @click="executeStatusChange('suspended', statusActionTarget)" :disabled="statusChangingTenantId !== null" class="px-4 py-2 rounded-xl text-sm font-bold bg-rose-600 hover:bg-rose-500 text-white shadow-md shadow-rose-600/20 disabled:opacity-50 disabled:cursor-wait">
            {{ statusChangingTenantId ? 'Suspendiendo...' : 'Confirmar Suspensión' }}
          </button>
        </div>
      </div>
    </div>

    <!-- MODAL ELIMINAR INSTITUCIÓN -->
    <div v-if="showDeleteModal && deleteTenantTarget" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-sm" role="dialog" aria-modal="true" aria-labelledby="delete-tenant-dialog-title">
      <div class="bg-white dark:bg-slate-900 border border-rose-200 dark:border-rose-900/60 rounded-2xl max-w-md w-full p-6 space-y-5 shadow-2xl">
        <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-800 pb-3">
          <div class="flex items-center gap-2 text-rose-600 dark:text-rose-400">
            <AlertCircle class="w-5 h-5" />
            <h3 id="delete-tenant-dialog-title" class="font-extrabold text-lg text-slate-900 dark:text-white">Eliminar Institución</h3>
          </div>
          <button @click="showDeleteModal = false" aria-label="Cerrar modal de eliminación" class="text-slate-400 hover:text-slate-700 dark:hover:text-white">
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="space-y-3">
          <div class="p-3.5 bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900/50 rounded-xl text-xs text-rose-700 dark:text-rose-300 space-y-1">
            <p class="font-bold uppercase tracking-wider text-rose-600 dark:text-rose-400">⚠️ Acción Irreversible</p>
            <p>Se eliminará permanentemente la institución <strong class="text-slate-900 dark:text-white">{{ deleteTenantTarget.name }}</strong> (Cód: {{ deleteTenantTarget.code || 'N/A' }}) junto a su configuración, suscripción y registros vinculados.</p>
          </div>

          <div class="p-3.5 bg-indigo-50/70 dark:bg-indigo-950/40 border border-indigo-200 dark:border-indigo-800/60 rounded-xl space-y-2.5">
            <label class="flex items-center gap-2 text-xs text-indigo-800 dark:text-indigo-300 font-semibold cursor-pointer">
              <input type="checkbox" v-model="autoBackupBeforeDelete" class="w-4 h-4 rounded bg-white dark:bg-slate-900 border-slate-300 dark:border-slate-700 text-indigo-600 focus:ring-indigo-500" />
              <span>Generar y descargar respaldo completo (.json) antes de eliminar</span>
            </label>
            <button 
              type="button" 
              @click="downloadTenantBackup(deleteTenantTarget)" 
              :disabled="generatingBackup" 
              class="w-full py-2 bg-indigo-100 hover:bg-indigo-200 border border-indigo-200 text-indigo-800 dark:bg-indigo-900/80 dark:hover:bg-indigo-800 dark:border-indigo-700 dark:text-indigo-200 font-bold text-xs rounded-xl flex items-center justify-center gap-2 transition"
            >
              <Download class="w-4 h-4" />
              {{ generatingBackup ? 'Generando archivo de respaldo...' : 'Descargar archivo de respaldo ahora (.json)' }}
            </button>
          </div>

          <p class="text-xs text-slate-600 dark:text-slate-300">
            Para confirmar, escribe exactamente el nombre de la institución:
          </p>
          <p class="text-xs font-mono font-bold text-indigo-700 dark:text-indigo-300 bg-slate-100 dark:bg-slate-950 p-2.5 rounded-xl border border-slate-200 dark:border-slate-800 select-all text-center">
            {{ deleteTenantTarget.name }}
          </p>

          <input 
            v-model="deleteConfirmName" 
            type="text" 
            placeholder="Escribe el nombre aquí..." 
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-rose-500 outline-none"
          />
        </div>

        <div class="flex items-center justify-end gap-3 border-t border-slate-200 dark:border-slate-800 pt-4">
          <button 
            type="button"
            @click="showDeleteModal = false" 
            class="px-4 py-2 rounded-xl text-sm font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            Cancelar
          </button>
          <button 
            type="button"
            @click="executeDeleteTenant" 
            :disabled="savingAction || deleteConfirmName.trim() !== deleteTenantTarget.name.trim()"
            class="px-4 py-2 rounded-xl text-sm font-bold bg-rose-600 hover:bg-rose-500 text-white transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-2 shadow-lg shadow-rose-950/50 cursor-pointer"
          >
            <Trash2 class="w-4 h-4" />
            {{ savingAction ? 'Eliminando...' : 'Eliminar Permanentemente' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Modal para restaurar datos académicos desde JSON -->
    <div v-if="showRestoreJsonModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-sm">
      <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl max-w-2xl w-full p-6 space-y-5 shadow-2xl overflow-y-auto max-h-[90vh]">
        <!-- Header -->
        <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-800 pb-4">
          <div class="flex items-center gap-3">
            <div class="p-2.5 rounded-xl bg-indigo-50 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-500/20">
              <Database class="w-6 h-6" />
            </div>
            <div>
              <h3 class="text-lg font-bold text-slate-900 dark:text-white">Restaurar Respaldo Académico (JSON)</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Restaura configuración, años lectivos, cursos, estudiantes y calificaciones en una sola transacción.</p>
            </div>
          </div>
          <button @click="showRestoreJsonModal = false" class="p-1 rounded-lg text-slate-400 hover:text-slate-700 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Body -->
        <div class="space-y-4">
          <div>
            <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-2">Selecciona archivo de base de datos (.json):</label>
            <input 
              ref="restoreFileInput" 
              type="file" 
              accept=".json" 
              @change="onRestoreFileChange" 
              class="w-full text-xs text-slate-600 dark:text-slate-400 file:mr-3 file:py-2 file:px-4 file:rounded-xl file:border-0 file:text-xs file:font-semibold file:bg-indigo-600 file:text-white hover:file:bg-indigo-500 cursor-pointer bg-slate-50 dark:bg-slate-950 p-2 border border-slate-200 dark:border-slate-800 rounded-xl"
            />
          </div>

          <!-- Errores de lectura -->
          <div v-if="restoreErrors.length > 0" class="p-3.5 bg-rose-50 dark:bg-rose-950/60 border border-rose-200 dark:border-rose-800/80 rounded-xl text-xs text-rose-700 dark:text-rose-300 space-y-1">
            <p v-for="(err, idx) in restoreErrors" :key="idx">⚠️ {{ err }}</p>
          </div>

          <!-- Vista Previa de Datos Detectados -->
          <div v-if="restoreSummary" class="space-y-3 p-4 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-2xl">
            <div class="flex items-center justify-between pb-2 border-b border-slate-200 dark:border-slate-800">
              <span class="text-xs font-bold text-indigo-600 dark:text-indigo-400 flex items-center gap-1.5">
                <CheckCircle class="w-4 h-4 text-emerald-500 dark:text-emerald-400" /> Respaldo JSON Validado
              </span>
              <span class="text-[11px] text-slate-500 dark:text-slate-400">{{ restoreSummary.schoolName }}</span>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 text-xs">
              <div class="p-2.5 bg-white dark:bg-slate-900/80 rounded-xl border border-slate-200 dark:border-slate-800/80 shadow-xs">
                <span class="text-slate-500 dark:text-slate-400 block text-[10px]">Cursos</span>
                <strong class="text-slate-900 dark:text-white font-mono text-sm">{{ restoreSummary.coursesCount }}</strong>
              </div>
              <div class="p-2.5 bg-white dark:bg-slate-900/80 rounded-xl border border-slate-200 dark:border-slate-800/80 shadow-xs">
                <span class="text-slate-500 dark:text-slate-400 block text-[10px]">Estudiantes</span>
                <strong class="text-slate-900 dark:text-white font-mono text-sm">{{ restoreSummary.studentsCount }}</strong>
              </div>
              <div class="p-2.5 bg-white dark:bg-slate-900/80 rounded-xl border border-slate-200 dark:border-slate-800/80 shadow-xs">
                <span class="text-slate-500 dark:text-slate-400 block text-[10px]">Asignaturas</span>
                <strong class="text-slate-900 dark:text-white font-mono text-sm">{{ restoreSummary.subjectsCount }}</strong>
              </div>
              <div class="p-2.5 bg-white dark:bg-slate-900/80 rounded-xl border border-slate-200 dark:border-slate-800/80 shadow-xs">
                <span class="text-slate-500 dark:text-slate-400 block text-[10px]">Calificaciones</span>
                <strong class="text-slate-900 dark:text-white font-mono text-sm">{{ restoreSummary.gradesCount }}</strong>
              </div>
              <div class="p-2.5 bg-white dark:bg-slate-900/80 rounded-xl border border-slate-200 dark:border-slate-800/80 shadow-xs">
                <span class="text-slate-500 dark:text-slate-400 block text-[10px]">Periodos</span>
                <strong class="text-slate-900 dark:text-white font-mono text-sm">{{ restoreSummary.quartersCount }}</strong>
              </div>
              <div class="p-2.5 bg-white dark:bg-slate-900/80 rounded-xl border border-slate-200 dark:border-slate-800/80 shadow-xs">
                <span class="text-slate-500 dark:text-slate-400 block text-[10px]">Configuraciones</span>
                <strong class="text-slate-900 dark:text-white font-mono text-sm">{{ restoreSummary.configCount }}</strong>
              </div>
            </div>

            <!-- Opciones de destino -->
            <div class="pt-2 border-t border-slate-200 dark:border-slate-800 space-y-3">
              <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300">Modo de Restauración:</label>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <label :class="['p-3 rounded-xl border text-xs cursor-pointer flex items-center gap-2 transition-all', restoreTargetOption === 'new_school' ? 'bg-indigo-50 border-indigo-500 text-indigo-900 dark:bg-indigo-950/60 dark:border-indigo-600 dark:text-white' : 'bg-white border-slate-200 text-slate-600 dark:bg-slate-900 dark:border-slate-800 dark:text-slate-400']">
                  <input type="radio" value="new_school" v-model="restoreTargetOption" class="text-indigo-600 focus:ring-indigo-500" />
                  <div>
                    <strong class="block text-slate-900 dark:text-white">Crear Nueva Institución</strong>
                    <span class="text-[10px] text-slate-500 dark:text-slate-400">Restaura como nuevo colegio independiente</span>
                  </div>
                </label>

                <label :class="['p-3 rounded-xl border text-xs cursor-pointer flex items-center gap-2 transition-all', restoreTargetOption === 'existing_school' ? 'bg-indigo-50 border-indigo-500 text-indigo-900 dark:bg-indigo-950/60 dark:border-indigo-600 dark:text-white' : 'bg-white border-slate-200 text-slate-600 dark:bg-slate-900 dark:border-slate-800 dark:text-slate-400']">
                  <input type="radio" value="existing_school" v-model="restoreTargetOption" class="text-indigo-600 focus:ring-indigo-500" />
                  <div>
                    <strong class="block text-slate-900 dark:text-white">Restaurar en Existente</strong>
                    <span class="text-[10px] text-slate-500 dark:text-slate-400">Solo se permite si no contiene datos académicos</span>
                  </div>
                </label>
              </div>

              <!-- Formulario según opción -->
              <div v-if="restoreTargetOption === 'new_school'" class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                <div>
                  <label class="block text-[11px] text-slate-600 dark:text-slate-400 mb-1">Nombre de la Institución:</label>
                  <input v-model="restoreNewSchoolName" type="text" class="w-full bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white outline-none focus:border-indigo-500" />
                </div>
                <div>
                  <label class="block text-[11px] text-slate-600 dark:text-slate-400 mb-1">Código AMIE / RUC:</label>
                  <input v-model="restoreNewSchoolAmie" type="text" class="w-full bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white font-mono outline-none focus:border-indigo-500" />
                </div>
              </div>

              <div v-else class="pt-2">
                <label class="block text-[11px] text-slate-600 dark:text-slate-400 mb-1">Selecciona la Institución Destino:</label>
                <select v-model="restoreTargetTenantId" class="w-full bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white outline-none focus:border-indigo-500">
                  <option v-for="t in tenants" :key="t.id" :value="t.id">{{ t.name }} ({{ t.code || 'S/N' }})</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="flex items-center justify-end gap-3 border-t border-slate-200 dark:border-slate-800 pt-4">
          <button 
            type="button" 
            @click="showRestoreJsonModal = false" 
            class="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white rounded-xl"
          >
            Cancelar
          </button>
          <button 
            type="button" 
            @click="executeJsonRestore" 
            :disabled="restoring || !restoreData" 
            class="px-5 py-2.5 text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl flex items-center gap-2 transition disabled:opacity-50 shadow-lg shadow-indigo-600/30 cursor-pointer"
          >
            <Upload class="w-4 h-4" />
            {{ restoring ? 'Restaurando Datos Académicos...' : 'Iniciar Restauración Académica' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
