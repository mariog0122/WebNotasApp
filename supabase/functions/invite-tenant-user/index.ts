import { createClient } from 'npm:@supabase/supabase-js@2.49.8'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const respond = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

type InviteRequest = {
  fullName?: string
  email?: string
  role?: 'teacher'
  schoolId?: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return respond({ success: false, message: 'Método no permitido.' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const authorization = req.headers.get('Authorization') ?? ''

  if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization.startsWith('Bearer ')) {
    return respond({ success: false, message: 'Solicitud no autenticada.' }, 401)
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  let invitedUserId: string | null = null

  try {
    const token = authorization.replace(/^Bearer\s+/i, '')
    const { data: userData, error: userError } = await callerClient.auth.getUser(token)
    if (userError || !userData.user) return respond({ success: false, message: 'Sesión no válida.' }, 401)

    const body = (await req.json()) as InviteRequest
    const fullName = body.fullName?.trim() ?? ''
    const email = body.email?.trim().toLowerCase() ?? ''
    const role = body.role ?? 'teacher'

    const { data: callerProfile, error: profileError } = await adminClient
      .from('profiles')
      .select('id, school_id, is_active')
      .eq('id', userData.user.id)
      .single()

    if (profileError || !callerProfile?.is_active) {
      return respond({ success: false, message: 'Acceso denegado.' }, 403)
    }

    const { data: isPlatformAdmin } = await callerClient.rpc('is_platform_admin')
    const { data: canInviteTenantUsers } = await callerClient.rpc('has_tenant_permission', {
      perm_code: 'users.invite',
    })
    const { data: canManageTenantUsers } = await callerClient.rpc('has_tenant_permission', {
      perm_code: 'users.manage',
    })

    const targetSchoolId = body.schoolId?.trim() || callerProfile.school_id
    const isOwnTenant = Boolean(targetSchoolId && targetSchoolId === callerProfile.school_id)
    const isSchoolAdmin = ['admin', 'school_admin', 'rector'].includes(callerProfile.role)

    const isAuthorized = isPlatformAdmin === true || (isOwnTenant && (isSchoolAdmin || canInviteTenantUsers === true || canManageTenantUsers === true))

    if (!targetSchoolId || !isAuthorized) {
      return respond({ success: false, message: 'Acceso denegado para esta institución.' }, 403)
    }

    const { data: targetSchool, error: targetSchoolError } = await adminClient
      .from('schools')
      .select('id, status, is_active')
      .eq('id', targetSchoolId)
      .maybeSingle()
    if (
      targetSchoolError
      || !targetSchool?.is_active
      || ['suspended', 'cancelled'].includes(targetSchool.status)
    ) {
      return respond({ success: false, message: 'La institución no está habilitada para recibir invitaciones.' }, 409)
    }

    if (role !== 'teacher') return respond({ success: false, message: 'Rol no permitido.' }, 400)
    if (fullName.length < 3 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return respond({ success: false, message: 'Nombre o correo no válido.' }, 400)
    }

    const { data: existingProfile, error: existingError } = await adminClient
      .from('profiles')
      .select('id, school_id, role')
      .eq('email', email)
      .maybeSingle()
    if (existingError) throw existingError

    let teacherUserId: string
    let invitationSent = false

    if (existingProfile) {
      if (existingProfile.school_id !== targetSchoolId || existingProfile.role !== 'teacher') {
        return respond({ success: false, message: 'El correo ya pertenece a otro usuario o institución.' }, 409)
      }
      teacherUserId = existingProfile.id
    } else {
      const { data: invitation, error: invitationError } = await adminClient.auth.admin.inviteUserByEmail(
        email,
        { data: { full_name: fullName, role, school_id: targetSchoolId } },
      )
      if (invitationError || !invitation.user) throw invitationError || new Error('INVITATION_FAILED')
      teacherUserId = invitation.user.id
      invitedUserId = invitation.user.id
      invitationSent = true
    }

    const { data: tenantRole, error: roleError } = await adminClient
      .from('tenant_roles')
      .select('id')
      .eq('name', 'teacher')
      .single()
    if (roleError || !tenantRole) throw roleError || new Error('TEACHER_ROLE_MISSING')

    const { error: teacherProfileError } = await adminClient.from('profiles').upsert({
      id: teacherUserId,
      school_id: targetSchoolId,
      email,
      full_name: fullName,
      role,
      is_active: true,
    }, { onConflict: 'id' })
    if (teacherProfileError) throw teacherProfileError

    const { error: membershipError } = await adminClient.from('tenant_memberships').upsert({
      user_id: teacherUserId,
      school_id: targetSchoolId,
      tenant_role_id: tenantRole.id,
      is_active: true,
    }, { onConflict: 'user_id,school_id' })
    if (membershipError) throw membershipError

    const { error: auditError } = await adminClient.from('audit_log').insert({
      school_id: targetSchoolId,
      user_id: userData.user.id,
      action: 'TENANT_USER_INVITED',
      table_name: 'profiles',
      record_id: teacherUserId,
      new_values: { email, role, invitation_sent: invitationSent },
    })
    if (auditError) throw auditError

    return respond({
      success: true,
      invitation_sent: invitationSent,
      user_id: teacherUserId,
      message: invitationSent ? 'Invitación enviada al docente.' : 'El docente ya estaba vinculado.',
    })
  } catch (error) {
    if (invitedUserId) await adminClient.auth.admin.deleteUser(invitedUserId).catch(() => undefined)
    console.error('invite-tenant-user failed', error instanceof Error ? error.message : 'unknown')
    return respond({ success: false, message: 'No fue posible invitar al docente.' }, 500)
  }
})
