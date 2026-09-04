<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { translateError } from '../lib/errorDictionary'
import { normalizeStoragePath, resolvePrivateImageUrl, uploadPrivateImage } from '../lib/storageUtils'
import { Users, Search, UserPlus, X, Eye, EyeOff, Upload, Download, BookOpen, Check, Layers, Sparkles } from 'lucide-vue-next'
import { toast } from 'vue-sonner'
import { hasAccessPermission, isInstitutionAdmin } from '../lib/permissions'
import { downloadTeachersTemplate } from '../lib/exportUtils'
import { useAcademicYearStore } from '../stores/academicYear'
import AcademicYearBanner from '../components/ui/AcademicYearBanner.vue'

const authStore = useAuthStore()
const academicYearStore = useAcademicYearStore()

const institutionName = ref('')
const institutionLogoUrl = ref('')
const institutionLogoPath = ref('')
const institutionTutorName = ref('')
const institutionRectorName = ref('')
const logoFile = ref(null)
const logoPreview = ref('')
const saving = ref(false)
const saveError = ref('')
const saveMessage = ref('')
const isAdmin = computed(() => isInstitutionAdmin(authStore.accessContext))
const can = (permission) => hasAccessPermission(authStore.accessContext, permission)

const teachers = ref([])
const loadingTeachers = ref(false)
const showInviteTeacher = ref(false)
const invitingTeacher = ref(false)
const showTeacherPassword = ref(false)
const inviteTeacherError = ref('')
const inviteTeacherMessage = ref('')
const teacherInviteForm = ref({ firstName: '', lastName: '', email: '', password: '' })
const createdTeacherResult = ref(null)

// Asignación de Cursos y Materias
const availableCourses = ref([])
const availableCourseSubjects = ref([])
const loadingCourseSubjects = ref(false)
const teacherAssignmentsSummary = ref({})
const inviteSelectedCourseSubjects = ref(new Set())

const showAssignModal = ref(false)
const selectedTeacherForAssign = ref(null)
const teacherAssignedCourseSubjects = ref(new Set())
const savingTeacherAssignments = ref(false)
const assignModalError = ref('')

// Subida masiva de docentes (Excel, CSV, TXT)
const showBulkTeacher = ref(false)
const bulkFile = ref(null)
const bulkFileInput = ref(null)
const bulkPreview = ref([])
const bulkErrors = ref([])
const bulkImporting = ref(false)
const bulkResults = ref([])
const bulkMessage = ref('')

const generateTeacherPassword = (firstName, lastName) => {
  const fInitial = (firstName?.trim()?.[0] || 'D').toUpperCase()
  const lInitial = (lastName?.trim()?.[0] || 'c').toLowerCase()
  const year = new Date().getFullYear()
  const randomNum = Math.floor(100 + Math.random() * 900)
  return `${fInitial}${lInitial}${year}*${randomNum}`
}

const parseTeacherText = (text) => {
  const lines = text.split(/\r?\n/).map(l => l.trim()).filter(Boolean)
  const entries = []
  const errors = []
  if (!lines.length) return { entries, errors }

  const detectDelimiter = (line) => {
    const commaCount = (line.match(/,/g) || []).length
    const semiCount = (line.match(/;/g) || []).length
    const tabCount = (line.match(/\t/g) || []).length
    const pipeCount = (line.match(/\|/g) || []).length
    if (semiCount > commaCount) return ';'
    if (tabCount > commaCount) return '\t'
    if (pipeCount > commaCount) return '|'
    return ','
  }

  const parseLineParts = (line) => {
    const delimiter = detectDelimiter(line)
    const parts = []
    let current = ''
    let inQuotes = false
    for (let i = 0; i < line.length; i++) {
      const char = line[i]
      if (char === '"') {
        inQuotes = !inQuotes
      } else if (char === delimiter && !inQuotes) {
        parts.push(current.trim().replace(/^["']|["']$/g, ''))
        current = ''
      } else {
        current += char
      }
    }
    parts.push(current.trim().replace(/^["']|["']$/g, ''))
    return parts
  }

  // Detect header row
  let headerIdx = -1
  let colName = -1, colLast = -1, colEmail = -1, colUser = -1, colPass = -1

  for (let r = 0; r < Math.min(lines.length, 5); r++) {
    const parts = parseLineParts(lines[r])
    let foundEmail = -1, foundName = -1, foundLast = -1, foundUser = -1, foundPass = -1

    parts.forEach((p, cIdx) => {
      const val = p.toUpperCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim()
      if (val.includes('APELLIDO')) foundLast = cIdx
      else if (val.includes('NOMBRE')) foundName = cIdx
      if (val.includes('CORREO') || val.includes('EMAIL')) foundEmail = cIdx
      if (val.includes('USUARIO') || val.includes('USERNAME') || val.includes('USER')) foundUser = cIdx
      if (val.includes('CONTRASE') || val.includes('PASSWORD') || val.includes('CLAVE')) foundPass = cIdx
    })

    if (foundEmail !== -1 && (foundName !== -1 || foundLast !== -1)) {
      headerIdx = r
      colEmail = foundEmail
      colName = foundName
      colLast = foundLast
      colUser = foundUser
      colPass = foundPass
      break
    }
  }

  const startLine = headerIdx !== -1 ? headerIdx + 1 : 0

  for (let i = startLine; i < lines.length; i++) {
    const line = lines[i]
    const parts = parseLineParts(line)
    if (!parts.length) continue

    let firstName = ''
    let lastName = ''
    let email = ''
    let username = ''
    let customPassword = ''

    if (headerIdx !== -1) {
      firstName = colName !== -1 ? (parts[colName] || '').trim() : ''
      lastName = colLast !== -1 ? (parts[colLast] || '').trim() : ''
      email = colEmail !== -1 ? (parts[colEmail] || '').trim() : ''
      username = colUser !== -1 ? (parts[colUser] || '').trim() : ''
      customPassword = colPass !== -1 ? (parts[colPass] || '').trim() : ''
    } else {
      const emailIdx = parts.findIndex(p => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(p))
      if (emailIdx !== -1) {
        email = parts[emailIdx]
        const remaining = parts.filter((_, idx) => idx !== emailIdx && isNaN(Number(_)))
        if (remaining.length >= 2) {
          firstName = remaining[0]
          lastName = remaining.slice(1).join(' ')
        } else if (remaining.length === 1) {
          const nameParts = remaining[0].split(' ')
          firstName = nameParts[0] || ''
          lastName = nameParts.slice(1).join(' ') || 'Docente'
        }
      } else if (parts.length >= 3) {
        firstName = parts[0]
        lastName = parts[1]
        email = parts[2]
      } else if (parts.length === 2) {
        const nameParts = parts[0].split(' ')
        firstName = nameParts[0] || ''
        lastName = nameParts.slice(1).join(' ') || 'Docente'
        email = parts[1]
      }
    }

    if (!lastName && firstName.includes(' ')) {
      const nParts = firstName.split(' ')
      firstName = nParts[0]
      lastName = nParts.slice(1).join(' ')
    } else if (!firstName && lastName.includes(' ')) {
      const nParts = lastName.split(' ')
      firstName = nParts[0]
      lastName = nParts.slice(1).join(' ')
    }

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      if (firstName || lastName || email) {
        errors.push(`Línea ${i + 1}: Correo no válido (${email || 'vacío'})`)
      }
      continue
    }

    if (!firstName && !lastName) continue

    const finalPass = (customPassword && customPassword.length >= 6) ? customPassword : generateTeacherPassword(firstName, lastName)

    entries.push({
      firstName: firstName || 'Docente',
      lastName: lastName || 'Institucional',
      fullName: `${firstName} ${lastName}`.trim() || 'Docente Institucional',
      email: email.toLowerCase(),
      username: username || email.split('@')[0],
      generatedPassword: finalPass,
      isCustomPassword: Boolean(customPassword && customPassword.length >= 6)
    })
  }

  return { entries, errors }
}

const onBulkFileChange = async (event) => {
  const file = event.target.files?.[0] || null
  bulkFile.value = file
  bulkPreview.value = []
  bulkErrors.value = []
  bulkResults.value = []
  bulkMessage.value = ''

  if (!file) return

  const fileName = file.name.toLowerCase()
  if (!/\.(xlsx|csv|txt)$/.test(fileName)) {
    bulkErrors.value = ['Formato no permitido. Selecciona un archivo .xlsx, .csv o .txt']
    return
  }

  try {
    if (fileName.endsWith('.xlsx')) {
      const { default: readXlsxFile } = await import('read-excel-file/browser')
      const rows = await readXlsxFile(file)
      const entries = []
      const errors = []

      let headerIdx = -1
      let colName = -1, colLast = -1, colEmail = -1, colUser = -1, colPass = -1

      rows.forEach((row, rIdx) => {
        if (headerIdx !== -1) return
        row.forEach((cell, cIdx) => {
          const val = String(cell || '')
            .toUpperCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .trim()
          if (val.includes('APELLIDO')) colLast = cIdx
          else if (val.includes('NOMBRE')) colName = cIdx
          if (val.includes('CORREO') || val.includes('EMAIL')) colEmail = cIdx
          if (val.includes('USUARIO') || val.includes('USERNAME') || val.includes('USER')) colUser = cIdx
          if (val.includes('CONTRASE') || val.includes('PASSWORD') || val.includes('CLAVE')) colPass = cIdx
        })
        if (colEmail !== -1 && (colName !== -1 || colLast !== -1)) headerIdx = rIdx
      })

      const startRow = headerIdx !== -1 ? headerIdx + 1 : 0
      for (let i = startRow; i < rows.length; i++) {
        const row = rows[i]
        if (!row || !row.length) continue

        let fName = colName !== -1 ? String(row[colName] || '').trim() : ''
        let lName = colLast !== -1 ? String(row[colLast] || '').trim() : ''
        let mail = colEmail !== -1 ? String(row[colEmail] || '').trim() : ''
        let uName = colUser !== -1 ? String(row[colUser] || '').trim() : ''
        let cPass = colPass !== -1 ? String(row[colPass] || '').trim() : ''

        if (headerIdx === -1) {
          fName = String(row[0] || '').trim()
          lName = String(row[1] || '').trim()
          mail = String(row[row.length - 1] || '').trim()
        }

        if (!lName && fName.includes(' ')) {
          const parts = fName.split(' ')
          fName = parts[0]
          lName = parts.slice(1).join(' ')
        }

        if (!mail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(mail)) {
          if (fName || lName || mail) errors.push(`Fila ${i + 1}: Correo no válido (${mail || 'vacío'})`)
          continue
        }
        if (!fName && !lName) continue

        const finalPass = (cPass && cPass.length >= 6) ? cPass : generateTeacherPassword(fName, lName)

        entries.push({
          firstName: fName || 'Docente',
          lastName: lName || 'Institucional',
          fullName: `${fName} ${lName}`.trim() || 'Docente Institucional',
          email: mail.toLowerCase(),
          username: uName || mail.split('@')[0],
          generatedPassword: finalPass,
          isCustomPassword: Boolean(cPass && cPass.length >= 6)
        })
      }

      bulkPreview.value = entries
      bulkErrors.value = errors
    } else {
      const text = await file.text()
      const { entries, errors } = parseTeacherText(text)
      bulkPreview.value = entries
      bulkErrors.value = errors
    }
  } catch (err) {
    bulkErrors.value = ['Error leyendo el archivo: ' + err.message]
  }
}

const openBulkTeacherModal = () => {
  showBulkTeacher.value = true
  bulkFile.value = null
  bulkPreview.value = []
  bulkErrors.value = []
  bulkResults.value = []
  bulkMessage.value = ''
}

const processBulkTeachers = async () => {
  if (!bulkPreview.value.length) return
  bulkImporting.value = true
  bulkResults.value = []
  bulkMessage.value = ''

  const results = []
  const sId = authStore.activeSchoolId

  for (const item of bulkPreview.value) {
    try {
      const { data, error } = await supabase.functions.invoke('manage-tenant-user', {
        body: {
          action: 'create',
          firstName: item.firstName,
          lastName: item.lastName,
          email: item.email,
          password: item.generatedPassword,
          role: 'teacher',
          schoolId: sId
        }
      })

      if (error) {
        let errStr = 'Error al registrar'
        try {
          const body = await error.context?.json()
          if (body?.message) errStr = body.message
        } catch {}
        results.push({
          fullName: item.fullName,
          email: item.email,
          password: item.generatedPassword,
          status: 'error',
          message: errStr
        })
      } else if (data?.success === false) {
        results.push({
          fullName: item.fullName,
          email: item.email,
          password: item.generatedPassword,
          status: 'error',
          message: data.message || 'Fallo en registro'
        })
      } else {
        const waText = encodeURIComponent(
          `🏫 *${institutionName.value || 'Institución'}*\n¡Hola ${item.fullName}! Tu cuenta de docente ha sido creada.\n\n🌐 *Acceso:* https://sandybrown-alpaca-347737.hostingersite.com/login?reason=access\n✉️ *Correo:* ${item.email}\n🔑 *Contraseña:* ${item.generatedPassword}`
        )
        results.push({
          fullName: item.fullName,
          email: item.email,
          password: item.generatedPassword,
          status: 'success',
          message: 'Usuario creado y credenciales enviadas por correo (.site)',
          whatsappUrl: `https://api.whatsapp.com/send?text=${waText}`
        })
      }
    } catch (err) {
      results.push({
        fullName: item.fullName,
        email: item.email,
        password: item.generatedPassword,
        status: 'error',
        message: err.message
      })
    }
  }

  bulkResults.value = results
  bulkImporting.value = false
  const okCount = results.filter(r => r.status === 'success').length
  bulkMessage.value = `Proceso completado. ${okCount} de ${results.length} docentes registrados exitosamente.`
  await fetchTeachers()
}

const copyAllBulkAccessData = async () => {
  if (!bulkResults.value.length) return
  const text = bulkResults.value
    .filter(r => r.status === 'success')
    .map(r => `👤 ${r.fullName} | ✉️ ${r.email} | 🔑 Clave: ${r.password} | 🌐 https://sandybrown-alpaca-347737.hostingersite.com/login?reason=access`)
    .join('\n')
  try {
    await navigator.clipboard.writeText(text)
    toast.success('¡Todos los accesos fueron copiados!')
  } catch {
    toast.error('No se pudo copiar.')
  }
}

const changeTeacherRole = async (teacher, newRole) => {
  const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!schoolId) return

  try {
    const { error: profError } = await supabase
      .from('profiles')
      .update({ role: newRole })
      .eq('id', teacher.id)

    if (profError) throw profError

    // Also update tenant_memberships
    await supabase
      .from('tenant_memberships')
      .update({ role: newRole })
      .eq('user_id', teacher.id)
      .eq('school_id', schoolId)

    const roleLabels = {
      teacher: 'Docente',
      admin: 'Rector / Administrador',
      inspector: 'Inspector General',
      secretary: 'Secretaría'
    }
    toast.success(`Rol de ${teacher.full_name || teacher.email} actualizado a ${roleLabels[newRole] || newRole}`)
    await fetchTeachers()
  } catch (err) {
    toast.error('Error al actualizar rol: ' + err.message)
  }
}

const fetchTeacherAssignmentsSummary = async () => {
  const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!schoolId) return
  try {
    const { data } = await supabase
      .from('course_subjects')
      .select('id, course_id, subject_id, teacher_id')
      .eq('school_id', schoolId)
      .not('teacher_id', 'is', null)

    const summary = {}
    ;(data || []).forEach(cs => {
      if (!summary[cs.teacher_id]) {
        summary[cs.teacher_id] = { courseIds: new Set(), subjectCount: 0 }
      }
      summary[cs.teacher_id].courseIds.add(cs.course_id)
      summary[cs.teacher_id].subjectCount++
    })

    const finalSummary = {}
    Object.keys(summary).forEach(tid => {
      finalSummary[tid] = {
        courseCount: summary[tid].courseIds.size,
        subjectCount: summary[tid].subjectCount
      }
    })
    teacherAssignmentsSummary.value = finalSummary
  } catch (err) {
    console.error('Error fetching teacher assignments summary:', err)
  }
}

const fetchAvailableCoursesAndSubjects = async () => {
  const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!schoolId) return
  loadingCourseSubjects.value = true
  try {
    let coursesQuery = supabase
      .from('courses')
      .select('id, name, level, track, academic_year')
      .eq('school_id', schoolId)
      .order('name')
    if (academicYearStore.selectedYearName) {
      coursesQuery = coursesQuery.eq('academic_year', academicYearStore.selectedYearName)
    }
    const { data: cData, error: cErr } = await coursesQuery
    if (cErr) throw cErr
    availableCourses.value = cData || []

    const { data: csData, error: csErr } = await supabase
      .from('course_subjects')
      .select('id, course_id, subject_id, teacher_id, subjects(name)')
      .eq('school_id', schoolId)
    if (csErr) throw csErr
    availableCourseSubjects.value = csData || []
  } catch (err) {
    console.error('Error loading courses/subjects for assignment:', err)
  } finally {
    loadingCourseSubjects.value = false
  }
}

const getSubjectsForCourse = (courseId) => {
  return availableCourseSubjects.value.filter(cs => cs.course_id === courseId)
}

const isInviteSubjectAssigned = (csId) => {
  return inviteSelectedCourseSubjects.value.has(csId)
}

const toggleInviteSubject = (csId) => {
  if (inviteSelectedCourseSubjects.value.has(csId)) {
    inviteSelectedCourseSubjects.value.delete(csId)
  } else {
    inviteSelectedCourseSubjects.value.add(csId)
  }
}

const isTeacherAssigned = (csId) => {
  return teacherAssignedCourseSubjects.value.has(csId)
}

const toggleTeacherAssignment = (csId) => {
  if (teacherAssignedCourseSubjects.value.has(csId)) {
    teacherAssignedCourseSubjects.value.delete(csId)
  } else {
    teacherAssignedCourseSubjects.value.add(csId)
  }
}

const openAssignTeacherModal = async (teacher) => {
  selectedTeacherForAssign.value = teacher
  assignModalError.value = ''
  showAssignModal.value = true
  await fetchAvailableCoursesAndSubjects()

  const assignedIds = availableCourseSubjects.value
    .filter(cs => cs.teacher_id === teacher.id)
    .map(cs => cs.id)
  teacherAssignedCourseSubjects.value = new Set(assignedIds)
}

const saveTeacherAssignments = async () => {
  if (!selectedTeacherForAssign.value) return
  savingTeacherAssignments.value = true
  assignModalError.value = ''
  try {
    const teacherId = selectedTeacherForAssign.value.id
    const selectedSet = teacherAssignedCourseSubjects.value

    const previouslyAssigned = availableCourseSubjects.value
      .filter(cs => cs.teacher_id === teacherId)
      .map(cs => cs.id)

    const toUnassign = previouslyAssigned.filter(id => !selectedSet.has(id))
    if (toUnassign.length > 0) {
      const { error: unassignErr } = await supabase
        .from('course_subjects')
        .update({ teacher_id: null })
        .in('id', toUnassign)
      if (unassignErr) throw unassignErr
    }

    const toAssign = Array.from(selectedSet).filter(id => !previouslyAssigned.includes(id))
    if (toAssign.length > 0) {
      const { error: assignErr } = await supabase
        .from('course_subjects')
        .update({ teacher_id: teacherId })
        .in('id', toAssign)
      if (assignErr) throw assignErr
    }

    toast.success('Asignaciones actualizadas', {
      description: `Se actualizaron las materias y cursos para ${selectedTeacherForAssign.value.full_name || selectedTeacherForAssign.value.email}.`
    })
    showAssignModal.value = false
    await Promise.all([
      fetchTeachers(),
      fetchTeacherAssignmentsSummary()
    ])
  } catch (err) {
    assignModalError.value = 'Error al guardar asignaciones: ' + translateError(err)
    toast.error('Error al asignar', { description: translateError(err) })
  } finally {
    savingTeacherAssignments.value = false
  }
}

const fetchTeachers = async () => {
  if (!isAdmin.value) return
  loadingTeachers.value = true
  try {
    const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!schoolId) return

    const { data, error } = await supabase
      .from('profiles')
      .select('id, full_name, email, role')
      .eq('school_id', schoolId)
      .neq('role', 'super_admin')
      .order('full_name')
    if (!error) {
      teachers.value = data || []
    }
    await fetchTeacherAssignmentsSummary()
  } finally {
    loadingTeachers.value = false
  }
}

const openTeacherInvite = async () => {
  teacherInviteForm.value = { firstName: '', lastName: '', email: '', password: '' }
  inviteTeacherError.value = ''
  inviteTeacherMessage.value = ''
  createdTeacherResult.value = null
  inviteSelectedCourseSubjects.value = new Set()
  showInviteTeacher.value = true
  await fetchAvailableCoursesAndSubjects()
}

const inviteTeacher = async () => {
  inviteTeacherError.value = ''
  inviteTeacherMessage.value = ''
  createdTeacherResult.value = null

  const firstName = teacherInviteForm.value.firstName.trim()
  const lastName = teacherInviteForm.value.lastName.trim()
  const email = teacherInviteForm.value.email.trim().toLowerCase()
  const password = teacherInviteForm.value.password

  if (firstName.length < 2 || lastName.length < 2 || !email.includes('@') || password.length < 6) {
    inviteTeacherError.value = 'Nombre, apellido, correo e ingrese una contraseña de al menos 6 caracteres.'
    return
  }

  invitingTeacher.value = true
  try {
    const { data, error } = await supabase.functions.invoke('manage-tenant-user', {
      body: {
        action: 'create',
        firstName,
        lastName,
        email,
        password,
        role: 'teacher',
        schoolId: authStore.activeSchoolId
      }
    })
    if (error) {
      let msg = 'No fue posible crear el docente.'
      try {
        const body = await error.context?.json()
        if (body?.message) msg = body.message
      } catch {}
      throw new Error(msg)
    }
    if (!data?.success) throw new Error(data?.message || 'No fue posible crear el docente.')

    const createdUserId = data?.user_id
    if (createdUserId && inviteSelectedCourseSubjects.value.size > 0) {
      const csIdsToAssign = Array.from(inviteSelectedCourseSubjects.value)
      await supabase
        .from('course_subjects')
        .update({ teacher_id: createdUserId })
        .in('id', csIdsToAssign)
    }

    createdTeacherResult.value = {
      email,
      password,
      fullName: `${firstName} ${lastName}`,
      loginUrl: 'https://sandybrown-alpaca-347737.hostingersite.com/login?reason=access'
    }
    inviteTeacherMessage.value = data.message || 'Docente creado exitosamente.'
    await Promise.all([
      fetchTeachers(),
      fetchTeacherAssignmentsSummary()
    ])
  } catch (error) {
    inviteTeacherError.value = error.message || 'No fue posible procesar la solicitud.'
  } finally {
    invitingTeacher.value = false
  }
}

const quarters = ref([])

const loadingQuarters = ref(false)
const quartersError = ref('')

const fetchQuarters = async () => {
  loadingQuarters.value = true
  quartersError.value = ''
  try {
    const { data, error } = await supabase.from('quarters').select('id, name, is_active, is_locked').eq('school_id', authStore.activeSchoolId).order('name')
    if (error) throw error
    quarters.value = data || []
  } catch (error) {
    quartersError.value = translateError(error)
  }
  loadingQuarters.value = false
}

const toggleQuarterLock = async (quarter) => {
  if (!isAdmin.value) return
  const newStatus = !quarter.is_locked
  try {
    const { error } = await supabase.from('quarters').update({ is_locked: newStatus }).eq('id', quarter.id)
    if (error) throw error
    quarter.is_locked = newStatus
  } catch (err) {
    alert('Error al cambiar candado del periodo: ' + translateError(err))
  }
}

const setActiveQuarter = async (quarter) => {
  if (!isAdmin.value) return
  if (quarter.is_active) return
  try {
    // Primero desactivamos todos (usamos un ineq para afectar a todos los ids)
    const allIds = quarters.value.map(q => q.id)
    await supabase.from('quarters').update({ is_active: false }).in('id', allIds)
    // Luego activamos el seleccionado
    const { error } = await supabase.from('quarters').update({ is_active: true }).eq('id', quarter.id)
    if (error) throw error
    
    quarters.value.forEach(q => q.is_active = false)
    quarter.is_active = true
  } catch (err) {
    alert('Error al establecer periodo activo: ' + translateError(err))
  }
}

const fetchInstitutionConfig = async () => {
  const schoolId = authStore.activeSchoolId || authStore.profile?.school_id
  if (!schoolId) return
  const { data, error } = await supabase
    .from('system_config')
    .select('key, value')
    .eq('school_id', schoolId)
    .in('key', ['institution_name', 'institution_logo_url', 'institution_tutor_name', 'institution_rector_name'])
  if (error) {
    saveError.value = 'Error cargando configuracion: ' + translateError(error)
    return
  }
  const map = Object.fromEntries((data || []).map(item => [item.key, item.value]))
  institutionName.value = map.institution_name || ''
  institutionLogoPath.value = normalizeStoragePath(map.institution_logo_url, 'institution-assets')
  institutionLogoUrl.value = await resolvePrivateImageUrl(
    supabase,
    'institution-assets',
    institutionLogoPath.value,
  ).catch(() => '')
  institutionTutorName.value = map.institution_tutor_name || ''
  institutionRectorName.value = map.institution_rector_name || ''
  logoPreview.value = institutionLogoUrl.value || ''
}

const getFileExt = (file) => {
  const parts = file.name.split('.')
  return parts.length > 1 ? parts.pop().toLowerCase() : 'jpg'
}

const uploadLogo = async (file, path) => {
  return uploadPrivateImage(supabase, 'institution-assets', file, path)
}

const onLogoChange = (event) => {
  const file = event.target.files?.[0] || null
  logoFile.value = file
  if (file) {
    logoPreview.value = URL.createObjectURL(file)
  } else {
    logoPreview.value = institutionLogoUrl.value || ''
  }
}

const saveInstitution = async () => {
  saveError.value = ''
  saveMessage.value = ''
  if (!isAdmin.value) {
    saveError.value = 'Solo administradores pueden actualizar la institución.'
    return
  }
  if (!institutionName.value.trim()) {
    saveError.value = 'El nombre de la institución es obligatorio.'
    return
  }
  saving.value = true
  try {
    const sId = authStore.activeSchoolId || authStore.profile?.school_id
    if (!sId) {
      saveError.value = 'No tienes una institución asignada.'
      saving.value = false
      return
    }

    let logoPath = institutionLogoPath.value
    if (logoFile.value) {
      const ext = getFileExt(logoFile.value)
      const path = `${sId}/institution/logo-${Date.now()}.${ext}`
      logoPath = await uploadLogo(logoFile.value, path)
    }

    const payload = [
      { school_id: sId, key: 'institution_name', value: institutionName.value.trim(), description: 'Nombre de la institución' },
      { school_id: sId, key: 'institution_logo_url', value: logoPath || '', description: 'Logo de la institución' },
      { school_id: sId, key: 'institution_tutor_name', value: institutionTutorName.value.trim(), description: 'Nombre del tutor' },
      { school_id: sId, key: 'institution_rector_name', value: institutionRectorName.value.trim(), description: 'Nombre del rector' }
    ]
    const { error } = await supabase
      .from('system_config')
      .upsert(payload, { onConflict: 'school_id, key' })
    if (error) throw error
    institutionLogoPath.value = logoPath || ''
    const resolvedUrl = await resolvePrivateImageUrl(supabase, 'institution-assets', logoPath).catch(() => '')
    institutionLogoUrl.value = resolvedUrl
    logoPreview.value = resolvedUrl || (logoFile.value ? URL.createObjectURL(logoFile.value) : '')
    logoFile.value = null
    saveMessage.value = 'Datos actualizados correctamente.'
    window.dispatchEvent(new CustomEvent('institution-config-updated'))
  } catch (error) {
    saveError.value = 'Error guardando configuración: ' + translateError(error)
  }
  saving.value = false
}

const onLogoPreviewError = () => {
  if (logoPreview.value && !logoPreview.value.includes('/public/')) {
    const path = normalizeStoragePath(logoPreview.value, 'institution-assets')
    if (path && !path.startsWith('http')) {
      const { data } = supabase.storage.from('institution-assets').getPublicUrl(path)
      if (data?.publicUrl) {
        logoPreview.value = data.publicUrl
        return
      }
    }
  }
  logoPreview.value = ''
}

onMounted(() => {
  fetchInstitutionConfig()
  fetchQuarters()
  fetchTeachers()
})
</script>

<template>
  <div class="app-shell">
    <main class="app-container">
      <div class="px-2 sm:px-0">
        <!-- Academic Year Banner -->
        <AcademicYearBanner module-name="Panel Principal" />

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
          <div class="flex items-center gap-4">
            <div class="h-16 w-16 rounded-2xl border border-slate-200 bg-white flex items-center justify-center overflow-hidden shadow-sm">
              <img v-if="logoPreview" :src="logoPreview" alt="Logo institucional" class="h-full w-full object-contain p-1" @error="onLogoPreviewError" />
              <span v-else class="text-slate-500 text-xs">Logo</span>
            </div>
            <div>
              <h1 class="app-title">Panel de Control Institucional</h1>
              <p class="app-subtitle">{{ institutionName || 'Nombre de la Institución' }}</p>
            </div>
          </div>
        </div>

        <div class="app-card p-6 mb-8">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
            <h2 class="text-lg font-semibold text-slate-900 dark:text-white">Identidad de la Institución</h2>
            <span v-if="!isAdmin" class="text-xs text-amber-700 bg-amber-100 border border-amber-200 px-2 py-1 rounded">
              Solo administradores pueden editar
            </span>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-600">Nombre de la Institución</label>
              <input v-model="institutionName" :disabled="!isAdmin" type="text" class="app-input mt-1 disabled:opacity-60">
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-600">Logo (PNG/JPG)</label>
              <input type="file" accept="image/*" @change="onLogoChange" :disabled="!isAdmin" class="mt-1 block w-full text-sm text-slate-500 disabled:opacity-60" />
              <p class="text-xs text-slate-500 mt-1">Se mostrará en el panel y reportes.</p>
            </div>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            <div>
              <label class="block text-sm font-medium text-slate-600">Nombre del Rector</label>
              <input v-model="institutionRectorName" :disabled="!isAdmin" type="text" class="app-input mt-1 disabled:opacity-60">
            </div>
          </div>
          <div class="mt-4 flex items-center gap-3">
            <button @click="saveInstitution" :disabled="saving || !isAdmin" class="app-btn app-btn-primary disabled:opacity-50">
              {{ saving ? 'Guardando...' : 'Guardar Cambios' }}
            </button>
            <span v-if="saveMessage" class="text-sm text-emerald-600">{{ saveMessage }}</span>
            <span v-if="saveError" class="text-sm text-rose-600">{{ saveError }}</span>
          </div>
        </div>

        <div class="app-card-soft p-5 mb-8">
          <h2 class="text-lg font-semibold text-teal-900 mb-4 flex items-center gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-teal-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Guía de Flujo de Trabajo
          </h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 1</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Configuración</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Configure los datos de la institución (Nombre, Logo, Autoridades) en este mismo panel.</p>
            </div>
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 2</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Catálogos</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Vaya a <strong>Asignaturas</strong> y <strong>Cursos</strong> para definir las materias y paralelos disponibles.</p>
            </div>
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 3</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Matriculación</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">Vaya a <strong>Estudiantes</strong> para registrar a los alumnos y asignarlos a sus cursos.</p>
            </div>
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 4</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Calificaciones</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">En <strong>Docentes / Notas</strong>, seleccione el curso y asignatura para ingresar los insumos y notas.</p>
            </div>
            <div class="bg-white dark:bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-200 dark:border-slate-700">
              <div class="text-xs font-bold text-teal-600 uppercase mb-1">Paso 5</div>
              <h3 class="font-semibold text-slate-800 dark:text-slate-200 text-sm mb-2">Reportes</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">El sistema calcula promedios automáticamente. Genere actas y libretas desde la sección de Notas.</p>
            </div>
          </div>
        </div>

        <!-- TEACHER MANAGEMENT (ADMIN ONLY) -->
        <div v-if="isAdmin" class="app-card p-6 mb-8 border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-sm rounded-2xl">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
            <h2 class="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <Users class="h-5 w-5 text-indigo-600 dark:text-indigo-400" />
              Gestión de Personal Docente e Institucional
            </h2>
            <div class="flex flex-wrap items-center gap-2">
              <button 
                type="button" 
                @click="downloadTeachersTemplate" 
                class="app-btn app-btn-ghost text-xs bg-emerald-50 dark:bg-emerald-950/50 hover:bg-emerald-100 dark:hover:bg-emerald-900/60 text-emerald-800 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800 font-semibold flex items-center gap-1.5 py-2 px-3 shadow-sm cursor-pointer"
                title="Descargar plantilla oficial CSV para carga masiva de docentes"
              >
                <Download class="w-4 h-4" /> Plantilla CSV
              </button>
              <button type="button" @click="openBulkTeacherModal" class="app-btn app-btn-ghost text-xs bg-indigo-50 dark:bg-indigo-950/50 hover:bg-indigo-100 dark:hover:bg-indigo-900/60 text-indigo-800 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800 font-semibold flex items-center gap-1.5 py-2 px-3 cursor-pointer">
                <Upload class="w-4 h-4" /> Carga masiva de docentes (CSV/TXT)
              </button>
              <button type="button" @click="openTeacherInvite" class="app-btn app-btn-primary min-h-10 text-xs sm:text-sm font-semibold">
                <UserPlus class="w-4 h-4" /> Invitar docente
              </button>
            </div>
          </div>
          <p v-if="inviteTeacherMessage" role="status" class="mb-4 text-sm font-medium text-emerald-700 dark:text-emerald-400">
            {{ inviteTeacherMessage }}
          </p>
          
          <div v-if="loadingTeachers" class="text-sm text-slate-500 dark:text-slate-400 py-4 text-center">Cargando personal docente...</div>
          <div v-else class="overflow-x-auto bg-slate-50/50 dark:bg-slate-950/60 rounded-xl border border-slate-200 dark:border-slate-800">
            <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-800">
              <thead class="bg-slate-100/80 dark:bg-slate-800/80">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider">Nombre</th>
                  <th class="px-4 py-3 text-left text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider">Correo Electrónico</th>
                  <th class="px-4 py-3 text-center text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider">Cursos y Asignaturas</th>
                  <th class="px-4 py-3 text-center text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider">Rol Asignado</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-200 dark:divide-slate-800">
                <tr v-for="t in teachers" :key="t.id" class="hover:bg-slate-100/50 dark:hover:bg-slate-800/50 transition-colors">
                  <td class="px-4 py-3 text-sm font-semibold text-slate-900 dark:text-white">{{ t.full_name || 'Sin nombre' }}</td>
                  <td class="px-4 py-3 text-sm font-medium text-slate-600 dark:text-slate-300">{{ t.email }}</td>
                  <td class="px-4 py-3 text-center">
                    <div class="flex items-center justify-center gap-2">
                      <span v-if="teacherAssignmentsSummary[t.id]?.courseCount > 0" class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-50 dark:bg-emerald-950/60 text-emerald-700 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800">
                        <Check class="w-3 h-3 text-emerald-600" />
                        {{ teacherAssignmentsSummary[t.id]?.courseCount }} {{ teacherAssignmentsSummary[t.id]?.courseCount === 1 ? 'curso' : 'cursos' }} ({{ teacherAssignmentsSummary[t.id]?.subjectCount }} {{ teacherAssignmentsSummary[t.id]?.subjectCount === 1 ? 'mat.' : 'mats.' }})
                      </span>
                      <span v-else class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-medium bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400">
                        Sin asignaciones
                      </span>
                      <button 
                        type="button" 
                        @click="openAssignTeacherModal(t)"
                        class="text-xs font-semibold py-1 px-2.5 rounded-lg bg-indigo-50 dark:bg-indigo-950/50 hover:bg-indigo-100 dark:hover:bg-indigo-900/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800 flex items-center gap-1 shadow-sm transition-colors cursor-pointer"
                        title="Asignar o editar los cursos y asignaturas que impartirá este docente"
                      >
                        <BookOpen class="w-3.5 h-3.5" /> Asignar
                      </button>
                    </div>
                  </td>
                  <td class="px-4 py-3 text-center">
                    <select 
                      :value="t.role || 'teacher'" 
                      @change="changeTeacherRole(t, $event.target.value)"
                      class="text-xs font-semibold py-1.5 px-3 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-indigo-500 shadow-sm cursor-pointer transition-colors"
                      title="Cambiar rol del usuario"
                    >
                      <option value="teacher">Docente</option>
                      <option value="admin">Rector / Administrador</option>
                      <option value="inspector">Inspector</option>
                      <option value="secretary">Secretaría</option>
                    </select>
                  </td>
                </tr>
                <tr v-if="teachers.length === 0">
                  <td colspan="4" class="px-4 py-8 text-center text-sm text-slate-500 dark:text-slate-400">No hay docentes vinculados a tu institución.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div v-if="isAdmin" class="app-card p-6 mb-8 border border-amber-200 dark:border-amber-900/40 bg-amber-50/30 dark:bg-amber-950/20 shadow-sm rounded-2xl">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-amber-600 dark:text-amber-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
              </svg>
              Gestión de Períodos de Calificación
            </h2>
            <div class="text-xs text-amber-800 dark:text-amber-300 bg-amber-100 dark:bg-amber-900/60 border border-amber-200 dark:border-amber-800 px-3 py-1 rounded-full font-bold">Control de Rector</div>
          </div>
          
          <div v-if="loadingQuarters" class="text-sm text-slate-500 dark:text-slate-400 py-4 text-center">Cargando períodos...</div>
          <div v-else-if="quartersError" class="text-sm text-rose-600 dark:text-rose-400 py-4">{{ quartersError }}</div>
          <div v-else class="overflow-x-auto bg-slate-50/50 dark:bg-slate-950/60 rounded-xl border border-slate-200 dark:border-slate-800">
            <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-800">
              <thead class="bg-amber-100/50 dark:bg-amber-900/30">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider">Período</th>
                  <th class="px-4 py-3 text-center text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider">Activo (Por Defecto)</th>
                  <th class="px-4 py-3 text-center text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider">Estado (Bloqueo)</th>
                  <th class="px-4 py-3 text-center text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider">Acción</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-200 dark:divide-slate-800">
                <tr v-for="q in quarters" :key="q.id" class="hover:bg-slate-100/50 dark:hover:bg-slate-800/50 transition-colors">
                  <td class="px-4 py-3 text-sm font-bold text-slate-900 dark:text-white">
                    {{ q.name }}
                  </td>
                  <td class="px-4 py-3 text-center">
                    <input type="radio" name="active_quarter" :checked="q.is_active" @change="setActiveQuarter(q)" 
                           class="h-4 w-4 text-teal-600 focus:ring-teal-500 border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 cursor-pointer">
                  </td>
                  <td class="px-4 py-3 text-center">
                    <span v-if="q.is_locked" class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-rose-100 dark:bg-rose-950/80 text-rose-800 dark:text-rose-300 border border-rose-200 dark:border-rose-800">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
                      </svg>
                      Cerrado
                    </span>
                    <span v-else class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-100 dark:bg-emerald-950/80 text-emerald-800 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                        <path d="M10 2a5 5 0 00-5 5v2a2 2 0 00-2 2v5a2 2 0 002 2h10a2 2 0 002-2v-5a2 2 0 00-2-2H7V7a3 3 0 015.905-.75 1 1 0 001.937-.5A5.002 5.002 0 0010 2z" />
                      </svg>
                      Abierto
                    </span>
                  </td>
                  <td class="px-4 py-3 text-center">
                    <button @click="toggleQuarterLock(q)" 
                            :class="['px-3 py-1.5 text-xs font-semibold rounded-lg border transition-colors focus:ring-2 focus:outline-none shadow-sm', 
                                     q.is_locked ? 'bg-white dark:bg-slate-800 text-emerald-700 dark:text-emerald-400 border-emerald-300 dark:border-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-950/40 focus:ring-emerald-500' : 'bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300 border-rose-300 dark:border-rose-800 hover:bg-rose-100 dark:hover:bg-rose-900/50 focus:ring-rose-500']">
                      {{ q.is_locked ? 'Desbloquear Período' : 'Bloquear (Cerrar) Período' }}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p class="mt-3 text-xs text-slate-500 dark:text-slate-400">
            <strong>Nota:</strong> Los períodos bloqueados previenen que los docentes modifiquen calificaciones en dicho período. Actívelo cuando hayan finalizado las juntas de curso.
          </p>
        </div>

        <!-- ═══════════════════════════════════════════════════════════════ -->
        <!-- TARJETAS DE ACCESO RÁPIDO A MÓDULOS (RESPONSIVO TOTAL)      -->
        <!-- ═══════════════════════════════════════════════════════════════ -->
        <div class="dash-modules-grid">
          <!-- Cursos -->
          <router-link 
            v-if="isAdmin" 
            to="/courses" 
            class="dash-module-card group"
            style="--accent-color: #0d9488; --accent-glow: rgba(13,148,136,0.12);"
          >
            <div class="dash-module-top">
              <div class="dash-module-icon" style="background: linear-gradient(135deg, #0d9488, #14b8a6); box-shadow: 0 4px 12px rgba(13,148,136,0.25);">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/>
                  <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>
                </svg>
              </div>
              <span class="dash-module-badge">Gestión Académica</span>
            </div>
            <div class="dash-module-body">
              <h3 class="dash-module-title">Cursos</h3>
              <p class="dash-module-desc">Gestionar aulas, niveles y paralelos</p>
            </div>
            <div class="dash-module-footer">
              <span class="dash-module-link" style="color: #0d9488;">
                Ver listado
                <svg class="dash-arrow" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
              </span>
            </div>
          </router-link>

          <!-- Asignaturas -->
          <router-link 
            v-if="isAdmin" 
            to="/subjects" 
            class="dash-module-card group"
            style="--accent-color: #10b981; --accent-glow: rgba(16,185,129,0.12);"
          >
            <div class="dash-module-top">
              <div class="dash-module-icon" style="background: linear-gradient(135deg, #10b981, #059669); box-shadow: 0 4px 12px rgba(16,185,129,0.25);">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                  <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
                  <line x1="9" y1="7" x2="17" y2="7"/>
                  <line x1="9" y1="11" x2="14" y2="11"/>
                </svg>
              </div>
              <span class="dash-module-badge">Catálogo</span>
            </div>
            <div class="dash-module-body">
              <h3 class="dash-module-title">Asignaturas</h3>
              <p class="dash-module-desc">Materias y contenidos curriculares</p>
            </div>
            <div class="dash-module-footer">
              <span class="dash-module-link" style="color: #059669;">
                Administrar
                <svg class="dash-arrow" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
              </span>
            </div>
          </router-link>

          <!-- Estudiantes -->
          <router-link 
            v-if="can('students.read')" 
            to="/students" 
            class="dash-module-card group"
            style="--accent-color: #f59e0b; --accent-glow: rgba(245,158,11,0.12);"
          >
            <div class="dash-module-top">
              <div class="dash-module-icon" style="background: linear-gradient(135deg, #f59e0b, #d97706); box-shadow: 0 4px 12px rgba(245,158,11,0.25);">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M22 10v6M2 10l10-5 10 5-10 5z"/>
                  <path d="M6 12v5c0 2 3 3 6 3s6-1 6-3v-5"/>
                </svg>
              </div>
              <span class="dash-module-badge">Registro</span>
            </div>
            <div class="dash-module-body">
              <h3 class="dash-module-title">Estudiantes</h3>
              <p class="dash-module-desc">Inscripción y fichas estudiantiles</p>
            </div>
            <div class="dash-module-footer">
              <span class="dash-module-link" style="color: #d97706;">
                Inscribir estudiantes
                <svg class="dash-arrow" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
              </span>
            </div>
          </router-link>

          <!-- Notas y Actas -->
          <router-link 
            v-if="can('grades.read')" 
            to="/grades" 
            class="dash-module-card group"
            style="--accent-color: #ef4444; --accent-glow: rgba(239,68,68,0.12);"
          >
            <div class="dash-module-top">
              <div class="dash-module-icon" style="background: linear-gradient(135deg, #ef4444, #dc2626); box-shadow: 0 4px 12px rgba(239,68,68,0.25);">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                  <polyline points="14 2 14 8 20 8"/>
                  <line x1="8" y1="13" x2="16" y2="13"/>
                  <line x1="8" y1="17" x2="13" y2="17"/>
                  <path d="M10 9l1.5 1.5L15 7" stroke-width="1.8"/>
                </svg>
              </div>
              <span class="dash-module-badge">Docentes</span>
            </div>
            <div class="dash-module-body">
              <h3 class="dash-module-title">Notas y Actas</h3>
              <p class="dash-module-desc">Calificaciones, juntas y evaluaciones</p>
            </div>
            <div class="dash-module-footer">
              <span class="dash-module-link" style="color: #dc2626;">
                Ingresar calificaciones
                <svg class="dash-arrow" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
              </span>
            </div>
          </router-link>
        </div>
      </div>
    </main>

    <div
      v-if="showInviteTeacher"
      class="modal-container"
      role="dialog"
      aria-modal="true"
      aria-labelledby="invite-teacher-title"
      @keydown.esc="showInviteTeacher = false"
    >
      <div class="modal-backdrop" aria-hidden="true" @click="showInviteTeacher = false"></div>
      <div class="modal-panel sm:max-w-xl w-full">
        <div class="modal-header modal-header-accent flex items-start justify-between gap-4">
          <div>
            <h2 id="invite-teacher-title" class="modal-title" style="color:#fff">Gestión de Docentes</h2>
            <p class="modal-subtitle">Agrega o invita docentes y asigna sus cursos y materias.</p>
          </div>
          <button type="button" @click="showInviteTeacher = false" aria-label="Cerrar modal docente" class="min-w-11 min-h-11 flex items-center justify-center rounded-xl text-white hover:bg-white/10">
            <X class="w-5 h-5" />
          </button>
        </div>

        <div v-if="createdTeacherResult" class="modal-body space-y-4 text-slate-900 dark:text-slate-200">
          <div class="p-4 bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800/80 rounded-xl space-y-3">
            <h3 class="font-extrabold text-emerald-700 dark:text-emerald-400 text-base">¡Docente Creado Exitosamente!</h3>
            <div class="space-y-1.5 text-xs">
              <p><strong class="text-slate-700 dark:text-slate-400">Docente:</strong> {{ createdTeacherResult.fullName }}</p>
              <p><strong class="text-slate-700 dark:text-slate-400">Usuario / Correo:</strong> <code class="text-indigo-700 dark:text-indigo-300 font-mono select-all">{{ createdTeacherResult.email }}</code></p>
              <p><strong class="text-slate-700 dark:text-slate-400">Contraseña Temporal:</strong> <code class="text-emerald-700 dark:text-emerald-300 font-mono select-all">{{ createdTeacherResult.password }}</code></p>
               <p><strong class="text-slate-700 dark:text-slate-400">Enlace de Acceso:</strong> <a :href="createdTeacherResult.loginUrl" target="_blank" rel="noopener noreferrer" class="text-sky-600 dark:text-sky-400 font-mono underline select-all break-all">{{ createdTeacherResult.loginUrl }}</a></p>
            </div>
          </div>

          <div class="flex justify-end gap-3 pt-2">
            <button type="button" @click="showInviteTeacher = false" class="app-btn app-btn-primary">
              Aceptar y Cerrar
            </button>
          </div>
        </div>

        <form v-else class="modal-body space-y-4" @submit.prevent="inviteTeacher">
          <div class="space-y-3">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label for="teacher-first-name" class="modal-label">Nombre *</label>
                <input id="teacher-first-name" v-model="teacherInviteForm.firstName" type="text" autocomplete="given-name" required class="app-input" placeholder="Ej. Roberto" />
              </div>
              <div>
                <label for="teacher-last-name" class="modal-label">Apellido *</label>
                <input id="teacher-last-name" v-model="teacherInviteForm.lastName" type="text" autocomplete="family-name" required class="app-input" placeholder="Ej. Vera" />
              </div>
            </div>
            <div>
              <label for="teacher-email-create" class="modal-label">Correo institucional *</label>
              <input id="teacher-email-create" v-model="teacherInviteForm.email" type="email" autocomplete="email" required class="app-input" placeholder="docente@colegio.edu.ec" />
            </div>
            <div>
              <label for="teacher-password" class="modal-label">Contraseña temporal *</label>
              <div class="relative">
                <input id="teacher-password" v-model="teacherInviteForm.password" :type="showTeacherPassword ? 'text' : 'password'" minlength="8" required class="app-input pr-10" placeholder="Mínimo 8 caracteres" />
                <button 
                  type="button" 
                  @click="showTeacherPassword = !showTeacherPassword" 
                  class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-800 dark:hover:text-white transition p-1"
                  :title="showTeacherPassword ? 'Ocultar contraseña' : 'Ver contraseña'"
                >
                  <EyeOff v-if="showTeacherPassword" class="w-4 h-4" />
                  <Eye v-else class="w-4 h-4" />
                </button>
              </div>
              <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">El docente podrá ingresar de inmediato con esta clave.</p>
            </div>

            <!-- Asignación de Cursos y Materias para el nuevo docente -->
            <div class="pt-3 border-t border-slate-200 dark:border-slate-800">
              <div class="flex items-center justify-between mb-2">
                <label class="modal-label flex items-center gap-1.5 font-bold text-slate-900 dark:text-white">
                  <BookOpen class="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                  Asignar Cursos y Asignaturas (Opcional)
                </label>
                <span v-if="inviteSelectedCourseSubjects.size > 0" class="text-xs font-semibold text-emerald-600 dark:text-emerald-400">
                  {{ inviteSelectedCourseSubjects.size }} materias seleccionadas
                </span>
              </div>
              <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
                Selecciona las materias que impartirá el docente. El docente solo verá sus cursos y materias asignadas.
              </p>

              <div v-if="loadingCourseSubjects" class="text-center py-4 text-xs text-slate-500">
                <span class="app-spinner mr-1.5"></span> Cargando cursos y materias...
              </div>
              <div v-else-if="availableCourses.length === 0" class="p-3 bg-slate-50 dark:bg-slate-950/60 rounded-xl border border-slate-200 dark:border-slate-800 text-xs text-slate-500 text-center">
                No hay cursos registrados para este año lectivo.
              </div>
              <div v-else class="space-y-3 max-h-56 overflow-y-auto pr-1">
                <div v-for="course in availableCourses" :key="course.id" class="p-2.5 bg-slate-50 dark:bg-slate-950/60 border border-slate-200 dark:border-slate-800 rounded-xl">
                  <div class="flex items-center justify-between font-bold text-xs text-slate-800 dark:text-slate-200 mb-1.5">
                    <span class="flex items-center gap-1">
                      <span class="w-2 h-2 rounded-full bg-indigo-500"></span>
                      {{ course.name }}
                    </span>
                    <span class="text-[10px] text-slate-400 font-normal">{{ course.level || '' }}</span>
                  </div>
                  <div v-if="getSubjectsForCourse(course.id).length === 0" class="text-[11px] text-slate-400 italic">
                    Sin materias agregadas a este curso.
                  </div>
                  <div v-else class="grid grid-cols-1 sm:grid-cols-2 gap-1.5">
                    <label 
                      v-for="cs in getSubjectsForCourse(course.id)" 
                      :key="cs.id" 
                      class="flex items-center gap-2 p-1.5 rounded-lg border text-xs cursor-pointer transition-colors"
                      :class="isInviteSubjectAssigned(cs.id) ? 'bg-indigo-50 dark:bg-indigo-950/40 border-indigo-300 dark:border-indigo-800 text-indigo-900 dark:text-indigo-200 font-semibold' : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-100/50'"
                    >
                      <input 
                        type="checkbox" 
                        :checked="isInviteSubjectAssigned(cs.id)" 
                        @change="toggleInviteSubject(cs.id)" 
                        class="h-3.5 w-3.5 text-indigo-600 rounded border-slate-300 focus:ring-indigo-500 cursor-pointer"
                      />
                      <span class="truncate">{{ cs.subjects?.name || 'Materia' }}</span>
                    </label>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <p v-if="inviteTeacherError" role="alert" class="text-sm text-rose-500 font-semibold">{{ inviteTeacherError }}</p>

          <div class="flex flex-col-reverse sm:flex-row justify-end gap-3 pt-2">
            <button type="button" @click="showInviteTeacher = false" class="app-btn app-btn-ghost">Cancelar</button>
            <button type="submit" :disabled="invitingTeacher" class="app-btn app-btn-primary disabled:opacity-50">
              {{ invitingTeacher ? 'Creando…' : 'Crear Docente' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- MODAL DE ASIGNACION DE CURSOS Y MATERIAS A DOCENTE EXISTENTE -->
    <div
      v-if="showAssignModal"
      class="modal-container"
      role="dialog"
      aria-modal="true"
      aria-labelledby="assign-teacher-title"
      @keydown.esc="showAssignModal = false"
    >
      <div class="modal-backdrop" aria-hidden="true" @click="showAssignModal = false"></div>
      <div class="modal-panel sm:max-w-2xl w-full">
        <div class="modal-header modal-header-accent flex items-start justify-between gap-4">
          <div>
            <h2 id="assign-teacher-title" class="modal-title" style="color:#fff">Asignar Cursos y Materias</h2>
            <p class="modal-subtitle">
              Docente: <strong>{{ selectedTeacherForAssign?.full_name || selectedTeacherForAssign?.email }}</strong>
            </p>
          </div>
          <button type="button" @click="showAssignModal = false" aria-label="Cerrar modal" class="min-w-11 min-h-11 flex items-center justify-center rounded-xl text-white hover:bg-white/10">
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="modal-body space-y-4 text-slate-900 dark:text-slate-200">
          <div class="flex items-center justify-between">
            <p class="text-xs text-slate-600 dark:text-slate-400">
              Marca las asignaturas que este docente impartirá en cada curso. El docente solo podrá acceder a las materias marcadas.
            </p>
            <span class="text-xs font-bold text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/60 px-2.5 py-1 rounded-lg border border-indigo-200 dark:border-indigo-800 shrink-0">
              {{ teacherAssignedCourseSubjects.size }} asignadas
            </span>
          </div>

          <div v-if="loadingCourseSubjects" class="text-center py-8 text-xs text-slate-500">
            <span class="app-spinner mr-2"></span> Cargando cursos y asignaturas...
          </div>
          <div v-else-if="availableCourses.length === 0" class="p-6 bg-slate-50 dark:bg-slate-950/60 rounded-xl border border-slate-200 dark:border-slate-800 text-center text-xs text-slate-500">
            No hay cursos configurados en la institución para el año lectivo actual.
          </div>
          <div v-else class="space-y-4 max-h-[50vh] overflow-y-auto pr-1">
            <div 
              v-for="course in availableCourses" 
              :key="course.id" 
              class="p-4 bg-slate-50 dark:bg-slate-950/60 border border-slate-200 dark:border-slate-800 rounded-2xl space-y-2.5"
            >
              <div class="flex items-center justify-between border-b border-slate-200/80 dark:border-slate-800/80 pb-2">
                <span class="font-bold text-sm text-slate-900 dark:text-white flex items-center gap-2">
                  <BookOpen class="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                  {{ course.name }}
                </span>
                <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">
                  {{ course.level || 'Sin nivel' }}
                </span>
              </div>

              <div v-if="getSubjectsForCourse(course.id).length === 0" class="text-xs text-slate-400 italic py-1">
                Este curso no tiene materias añadidas a su malla. Puedes asignarlas en el módulo de Cursos.
              </div>
              <div v-else class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <label 
                  v-for="cs in getSubjectsForCourse(course.id)" 
                  :key="cs.id" 
                  class="flex items-center gap-2.5 p-2.5 rounded-xl border text-xs cursor-pointer transition-all select-none"
                  :class="isTeacherAssigned(cs.id) ? 'bg-indigo-50 dark:bg-indigo-950/50 border-indigo-300 dark:border-indigo-700/80 text-indigo-950 dark:text-indigo-100 font-bold ring-1 ring-indigo-500/20' : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-100/60 dark:hover:bg-slate-800/40'"
                >
                  <input 
                    type="checkbox" 
                    :checked="isTeacherAssigned(cs.id)" 
                    @change="toggleTeacherAssignment(cs.id)" 
                    class="h-4 w-4 text-indigo-600 rounded border-slate-300 focus:ring-indigo-500 cursor-pointer"
                  />
                  <div class="flex-1 min-w-0">
                    <span class="truncate block">{{ cs.subjects?.name || 'Materia' }}</span>
                    <span v-if="cs.teacher_id && cs.teacher_id !== selectedTeacherForAssign?.id" class="text-[10px] text-amber-600 dark:text-amber-400 block truncate font-normal">
                      (Asignada a otro docente)
                    </span>
                  </div>
                </label>
              </div>
            </div>
          </div>

          <p v-if="assignModalError" role="alert" class="text-xs text-rose-500 font-semibold">
            {{ assignModalError }}
          </p>

          <div class="flex justify-end gap-3 pt-2 border-t border-slate-200 dark:border-slate-800">
            <button type="button" @click="showAssignModal = false" class="app-btn app-btn-ghost">Cancelar</button>
            <button 
              type="button" 
              @click="saveTeacherAssignments" 
              :disabled="savingTeacherAssignments" 
              class="app-btn app-btn-primary flex items-center gap-1.5"
            >
              <span v-if="savingTeacherAssignments" class="app-spinner w-3.5 h-3.5"></span>
              <span>{{ savingTeacherAssignments ? 'Guardando...' : 'Guardar Asignaciones' }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- MODAL DE CARGA MASIVA DE DOCENTES -->
    <div v-if="showBulkTeacher" class="modal-container" role="dialog" aria-modal="true">
      <div class="modal-backdrop" @click="showBulkTeacher = false"></div>
      <div class="modal-panel sm:max-w-2xl w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-800 rounded-2xl shadow-2xl p-6">
        <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-800 pb-3 mb-4">
          <h3 class="font-bold text-lg text-slate-900 dark:text-white flex items-center gap-2">
            <Upload class="w-5 h-5 text-indigo-600 dark:text-indigo-400" /> Carga Masiva de Docentes (CSV / TXT)
          </h3>
          <button type="button" @click="showBulkTeacher = false" class="text-slate-400 hover:text-slate-900 dark:hover:text-white p-1">
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="space-y-4">
          <!-- Banner para descargar plantilla CSV oficial -->
          <div class="bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 rounded-2xl p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 shadow-sm">
            <div class="text-xs text-emerald-900 dark:text-emerald-200">
              <p class="font-bold flex items-center gap-1.5 text-emerald-800 dark:text-emerald-300 text-sm">
                <span>📊</span> ¿No dispones de la plantilla oficial de docentes?
              </p>
              <p class="text-emerald-700 dark:text-emerald-400 mt-1">
                Descarga la plantilla oficial en CSV (.csv), completa los nombres, apellidos y correos institucionales, y súbela aquí.
              </p>
            </div>
            <button 
              type="button" 
              @click="downloadTeachersTemplate" 
              class="px-4 py-2 text-xs font-bold bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl transition-colors shrink-0 shadow-sm flex items-center gap-1.5 cursor-pointer"
            >
              <Download class="w-4 h-4" /> Descargar Plantilla CSV
            </button>
          </div>

          <p class="text-xs text-slate-600 dark:text-slate-400">
            Sube un archivo en formato <strong>.csv</strong> o <strong>.txt</strong> con el listado de docentes.
            Columnas soportadas: <code>Nombres</code>, <code>Apellidos</code>, <code>Correo Electrónico</code> y opcionalmente <code>Contraseña</code>.
            Si el archivo incluye una contraseña personalizada, se asignará directamente. En caso contrario, el sistema generará una contraseña segura automáticamente. Cada docente recibirá sus credenciales de acceso por correo desde el dominio oficial <strong>.site</strong> de LOGREVA.
          </p>

          <div>
            <input 
              ref="bulkFileInput" 
              type="file" 
              accept=".csv,.txt,.xlsx" 
              @change="onBulkFileChange" 
              class="w-full text-xs text-slate-600 dark:text-slate-400 file:mr-3 file:py-2 file:px-4 file:rounded-xl file:border-0 file:text-xs file:font-semibold file:bg-indigo-600 file:text-white hover:file:bg-indigo-500 cursor-pointer bg-slate-50 dark:bg-slate-950 p-2 border border-slate-200 dark:border-slate-800 rounded-xl"
            />
          </div>

          <div v-if="bulkErrors.length > 0" class="p-3 bg-rose-50 dark:bg-rose-950/60 border border-rose-200 dark:border-rose-800/80 rounded-xl text-xs text-rose-700 dark:text-rose-300 space-y-1">
            <p v-for="(err, idx) in bulkErrors" :key="idx">⚠️ {{ err }}</p>
          </div>

          <!-- VISTA PREVIA -->
          <div v-if="bulkPreview.length > 0 && bulkResults.length === 0" class="space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-xs font-semibold text-indigo-700 dark:text-indigo-300">Vista previa: {{ bulkPreview.length }} docentes detectados</span>
              <button 
                type="button" 
                @click="processBulkTeachers" 
                :disabled="bulkImporting" 
                class="app-btn app-btn-primary text-xs py-2 px-4 disabled:opacity-50"
              >
                {{ bulkImporting ? 'Creando cuentas...' : 'Confirmar e Importar Docentes' }}
              </button>
            </div>

            <div class="max-h-60 overflow-y-auto border border-slate-200 dark:border-slate-800 rounded-xl bg-slate-50 dark:bg-slate-950 p-2">
              <table class="w-full text-xs text-left">
                <thead class="text-slate-600 dark:text-slate-400 border-b border-slate-200 dark:border-slate-800">
                  <tr>
                    <th class="p-2">Docente</th>
                    <th class="p-2">Usuario / Correo</th>
                    <th class="p-2">Contraseña</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-200 dark:divide-slate-800/60 text-slate-700 dark:text-slate-300 font-mono">
                  <tr v-for="(doc, idx) in bulkPreview" :key="idx" class="hover:bg-slate-100 dark:hover:bg-slate-900">
                    <td class="p-2 font-sans font-medium text-slate-900 dark:text-white">{{ doc.fullName }}</td>
                    <td class="p-2 text-indigo-700 dark:text-indigo-300">
                      <div>{{ doc.email }}</div>
                      <div v-if="doc.username" class="text-[10px] text-slate-400 font-sans">Usuario: {{ doc.username }}</div>
                    </td>
                    <td class="p-2 text-emerald-700 dark:text-emerald-300 font-semibold">
                      <span>{{ doc.generatedPassword }}</span>
                      <span v-if="doc.isCustomPassword" class="ml-1 text-[9px] px-1.5 py-0.2 bg-indigo-100 text-indigo-800 dark:bg-indigo-950 dark:text-indigo-300 rounded font-sans">CSV</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- RESULTADOS -->
          <div v-if="bulkResults.length > 0" class="space-y-3">
            <div class="p-3 bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800/60 rounded-xl text-xs text-emerald-800 dark:text-emerald-300 flex items-center justify-between">
              <span>{{ bulkMessage }}</span>
              <button type="button" @click="copyAllBulkAccessData" class="px-3 py-1 bg-emerald-700 hover:bg-emerald-600 text-white rounded-lg font-bold text-[11px]">
                📋 Copiar todos
              </button>
            </div>

            <div class="max-h-64 overflow-y-auto border border-slate-200 dark:border-slate-800 rounded-xl bg-slate-50 dark:bg-slate-950 p-2">
              <table class="w-full text-xs text-left">
                <thead class="text-slate-600 dark:text-slate-400 border-b border-slate-200 dark:border-slate-800">
                  <tr>
                    <th class="p-2">Docente</th>
                    <th class="p-2">Correo</th>
                    <th class="p-2">Clave</th>
                    <th class="p-2 text-center">Acciones</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-200 dark:divide-slate-800/60 text-slate-700 dark:text-slate-300">
                  <tr v-for="(res, idx) in bulkResults" :key="idx" class="hover:bg-slate-100 dark:hover:bg-slate-900">
                    <td class="p-2 font-medium text-slate-900 dark:text-white">{{ res.fullName }}</td>
                    <td class="p-2 font-mono text-indigo-700 dark:text-indigo-300">{{ res.email }}</td>
                    <td class="p-2 font-mono text-emerald-700 dark:text-emerald-300">{{ res.password }}</td>
                    <td class="p-2 text-center">
                      <a 
                        v-if="res.status === 'success' && res.whatsappUrl" 
                        :href="res.whatsappUrl" 
                        target="_blank" 
                        rel="noopener noreferrer"
                        class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-[11px] font-bold transition"
                        title="Enviar credenciales por WhatsApp"
                      >
                        💬 WhatsApp
                      </a>
                      <span v-else-if="res.status === 'error'" class="text-rose-600 dark:text-rose-400 text-[11px] font-semibold">
                        {{ res.message }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-3 border-t border-slate-200 dark:border-slate-800 pt-4 mt-4">
          <button type="button" @click="showBulkTeacher = false" class="app-btn app-btn-ghost text-xs">
            Cerrar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ═══════════════════════════════════════════════════════════════════ */
/* DASHBOARD MODULE CARDS — Ultra-Responsive System                   */
/* ═══════════════════════════════════════════════════════════════════ */

/* Grid auto-fit: se adapta inteligentemente al ancho disponible */
.dash-modules-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}

@media (min-width: 580px) {
  .dash-modules-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 1.25rem;
  }
}

@media (min-width: 1300px) {
  .dash-modules-grid {
    grid-template-columns: repeat(4, 1fr);
    gap: 1.25rem;
  }
}

/* Card Container */
.dash-module-card {
  display: flex;
  flex-direction: column;
  text-decoration: none;
  border-radius: 1.25rem;
  background: #ffffff;
  border: 1px solid rgba(226, 232, 240, 0.9);
  padding: 1.25rem;
  transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.03), 0 1px 2px rgba(0, 0, 0, 0.02);
  position: relative;
  overflow: hidden;
}

:root.dark .dash-module-card,
.dark .dash-module-card {
  background: rgba(30, 41, 59, 0.7);
  border-color: rgba(51, 65, 85, 0.6);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
}

.dash-module-card:hover {
  transform: translateY(-3px);
  border-color: var(--accent-color);
  box-shadow: 0 12px 28px -4px var(--accent-glow), 0 4px 12px rgba(0, 0, 0, 0.05);
}

/* Top Section: Icon + Category Badge */
.dash-module-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.875rem;
}

.dash-module-icon {
  width: 2.75rem;
  height: 2.75rem;
  min-width: 2.75rem;
  border-radius: 0.875rem;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #ffffff;
  flex-shrink: 0;
  transition: transform 0.25s ease;
}

.dash-module-card:hover .dash-module-icon {
  transform: scale(1.08);
}

.dash-module-badge {
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #64748b;
  background: rgba(241, 245, 249, 0.9);
  padding: 0.25rem 0.6rem;
  border-radius: 9999px;
  white-space: nowrap;
}

:root.dark .dash-module-badge,
.dark .dash-module-badge {
  color: #94a3b8;
  background: rgba(51, 65, 85, 0.5);
}

/* Body Section: Title + Description */
.dash-module-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  margin-bottom: 1rem;
}

.dash-module-title {
  font-size: 1.2rem;
  font-weight: 800;
  color: #0f172a;
  line-height: 1.3;
  letter-spacing: -0.01em;
  margin: 0;
}

:root.dark .dash-module-title,
.dark .dash-module-title {
  color: #f8fafc;
}

.dash-module-desc {
  font-size: 0.75rem;
  color: #64748b;
  line-height: 1.4;
  margin: 0;
}

:root.dark .dash-module-desc,
.dark .dash-module-desc {
  color: #94a3b8;
}

/* Footer Section: CTA Link with Animated Arrow */
.dash-module-footer {
  margin-top: auto;
  padding-top: 0.5rem;
  border-top: 1px solid rgba(241, 245, 249, 0.8);
}

:root.dark .dash-module-footer,
.dark .dash-module-footer {
  border-top-color: rgba(51, 65, 85, 0.4);
}

.dash-module-link {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.8125rem;
  font-weight: 700;
  transition: gap 0.2s ease;
}

.dash-arrow {
  transition: transform 0.2s ease;
}

.dash-module-card:hover .dash-arrow {
  transform: translateX(4px);
}
</style>
