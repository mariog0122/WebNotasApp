// @ts-ignore: Deno npm specifier resolution in IDE
import { createClient } from 'npm:@supabase/supabase-js@2.49.8'

declare const Deno: {
  serve: (handler: (req: Request) => Promise<Response> | Response) => void
  env: {
    get: (key: string) => string | undefined
  }
}

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

const allowedTenantRoles = new Set([
  'school_admin', 'rector', 'vicerrector', 'secretary',
  'inspector', 'counselor', 'teacher',
])

type ManageUserRequest = {
  action?: 'create' | 'delete'
  userId?: string
  firstName?: string
  lastName?: string
  email?: string
  password?: string
  schoolId?: string
  role?: string
}

type TenantMembershipItem = {
  school_id: string
  is_active: boolean
  tenant_roles?: { name?: string } | null
}

Deno.serve(async (req: Request) => {
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

  let createdUserId: string | null = null

  try {
    const token = authorization.replace(/^Bearer\s+/i, '')
    const { data: userData, error: userError } = await callerClient.auth.getUser(token)
    if (userError || !userData.user) return respond({ success: false, message: 'Sesión no válida.' }, 401)

    const [{ data: callerProfile, error: profileError }, { data: callerMemberships }] = await Promise.all([
      adminClient
        .from('profiles')
        .select('id, school_id, is_active, role')
        .eq('id', userData.user.id)
        .maybeSingle(),
      adminClient
        .from('tenant_memberships')
        .select('school_id, is_active, tenant_roles(name)')
        .eq('user_id', userData.user.id)
        .eq('is_active', true),
    ])

    if (profileError || !callerProfile?.is_active) {
      return respond({ success: false, message: 'Acceso denegado.' }, 403)
    }

    const { data: isPlatformAdmin } = await callerClient.rpc('is_platform_admin')
    const { data: canManageTenantUsers } = await callerClient.rpc('has_tenant_permission', {
      perm_code: 'users.manage',
    })

    const body = (await req.json()) as ManageUserRequest
    const targetSchoolId = body.schoolId?.trim() || callerProfile.school_id

    const activeMemberships: TenantMembershipItem[] = (callerMemberships as unknown as TenantMembershipItem[]) || []
    const isMemberOfTarget = activeMemberships.some((m: TenantMembershipItem) => m.school_id === targetSchoolId)
    const isOwnSchool = Boolean(targetSchoolId && (targetSchoolId === callerProfile.school_id || isMemberOfTarget))

    const targetMembership = activeMemberships.find((m: TenantMembershipItem) => m.school_id === targetSchoolId)
    const membershipRoleName = (targetMembership?.tenant_roles as { name?: string } | undefined)?.name

    const isSchoolAdmin =
      ['admin', 'school_admin', 'rector'].includes(callerProfile.role) ||
      (membershipRoleName ? ['school_admin', 'rector', 'admin'].includes(membershipRoleName) : false)

    const isAuthorized =
      isPlatformAdmin === true || (isOwnSchool && (isSchoolAdmin || canManageTenantUsers === true))

    if (!isAuthorized || !targetSchoolId) {
      return respond({ success: false, message: 'Acceso denegado para esta institución.' }, 403)
    }

    if (body.action === 'create') {
      const firstName = body.firstName?.trim() ?? ''
      const lastName = body.lastName?.trim() ?? ''
      const fullName = `${firstName} ${lastName}`.trim()
      const email = body.email?.trim().toLowerCase() ?? ''
      const password = body.password ?? ''
      const schoolId = body.schoolId?.trim() ?? ''
      const tenantRoleName = body.role?.trim() ?? 'school_admin'
      const phone = body.phone?.trim() ?? ''

      if (firstName.length < 2 || lastName.length < 2 || !schoolId) {
        return respond({ success: false, message: 'Nombre, apellido e institución son obligatorios.' }, 400)
      }
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return respond({ success: false, message: 'Correo no válido.' }, 400)
      }
      if (password.length < 6) {
        return respond({ success: false, message: 'La contraseña debe tener al menos 6 caracteres.' }, 400)
      }
      if (!allowedTenantRoles.has(tenantRoleName)) {
        return respond({ success: false, message: 'Rol institucional no permitido.' }, 400)
      }

      // Validación obligatoria y de unicidad de teléfono para administradores de colegio
      if (['school_admin', 'rector', 'admin'].includes(tenantRoleName)) {
        if (!phone) {
          return respond({ success: false, message: 'El número de teléfono es obligatorio para el Administrador del colegio.' }, 400)
        }
        const cleanPhone = phone.trim()
        const digitsOnly = cleanPhone.replace(/\D/g, '')
        if (digitsOnly.length < 8) {
          return respond({ success: false, message: 'El número de teléfono del administrador debe contener al menos 8 dígitos.' }, 400)
        }

        const { data: existingPhoneUser, error: phoneLookupError } = await adminClient
          .from('profiles')
          .select('id, email, phone')
          .or(`phone.eq.${cleanPhone},phone.eq.${digitsOnly}`)
          .limit(1)

        if (!phoneLookupError && existingPhoneUser && existingPhoneUser.length > 0) {
          return respond({
            success: false,
            message: `El número de teléfono ${cleanPhone} ya está registrado en el sistema. Debe usar un número diferente para el administrador del colegio.`,
          }, 409)
        }
      }

      const { data: existingProfile } = await adminClient
        .from('profiles')
        .select('id, email')
        .eq('email', email)
        .maybeSingle()

      if (existingProfile) {
        return respond({ success: false, message: 'El correo electrónico ya pertenece a un usuario registrado.' }, 409)
      }

      const [{ data: school, error: schoolError }, { data: tenantRole, error: tenantRoleError }] =
        await Promise.all([
          adminClient.from('schools').select('id, name, status, is_active').eq('id', schoolId).maybeSingle(),
          adminClient.from('tenant_roles').select('id, name').eq('name', tenantRoleName).maybeSingle(),
        ])

      if (schoolError || !school?.is_active || ['suspended', 'cancelled'].includes(school.status)) {
        return respond({ success: false, message: 'La institución seleccionada no está habilitada.' }, 409)
      }
      if (tenantRoleError || !tenantRole) {
        return respond({ success: false, message: 'El rol institucional no existe.' }, 400)
      }

      const schoolName = school?.name || 'Institución Educativa'
      const loginUrl = 'https://sandybrown-alpaca-347737.hostingersite.com/login?reason=access'

      // Creación directa en Supabase Auth con contraseña confirmada
      const { data: created, error: createError } = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName },
        app_metadata: { school_id: schoolId, tenant_role: tenantRoleName },
      })
      if (createError || !created.user) {
        throw createError || new Error('AUTH_USER_CREATE_FAILED')
      }
      createdUserId = created.user.id

      const profileRole = tenantRoleName === 'teacher' ? 'teacher' : 'admin'

      const { error: profileError } = await adminClient.from('profiles').upsert({
        id: createdUserId,
        email,
        full_name: fullName,
        phone: phone || null,
        role: profileRole,
        school_id: schoolId,
        is_active: true,
      }, { onConflict: 'id' })
      if (profileError) throw profileError

      const { error: membershipError } = await adminClient.from('tenant_memberships').upsert({
        user_id: createdUserId,
        school_id: schoolId,
        tenant_role_id: tenantRole.id,
        is_active: true,
      }, { onConflict: 'user_id,school_id' })
      if (membershipError) throw membershipError

      const { error: auditError } = await adminClient.from('audit_log').insert({
        school_id: schoolId,
        user_id: userData.user.id,
        action: 'TENANT_USER_CREATED',
        table_name: 'profiles',
        record_id: createdUserId,
        new_values: { email, tenant_role: tenantRoleName, email_confirmed: true },
      })
      if (auditError) console.error('manage-tenant-user audit failed', auditError.message)

      // Enviar correo con credenciales directas de acceso desde el dominio .site
      if (password) {
        const emailSubject = `Tus credenciales de acceso a LOGREVA - ${schoolName}`
        const emailHtmlBody = `
          <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 28px; background-color: #0f172a; color: #f8fafc; border-radius: 16px; border: 1px solid #1e293b;">
            <div style="text-align: center; margin-bottom: 24px;">
              <span style="font-size: 28px; font-weight: 800; letter-spacing: 1px; color: #6366f1;">LOGREVA</span>
              <p style="margin: 4px 0 0 0; font-size: 13px; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.5px;">Sistema de Gestión Académica</p>
            </div>

            <h2 style="color: #ffffff; margin-top: 0; font-size: 20px; font-weight: 700;">¡Hola ${fullName}!</h2>
            <p style="font-size: 14px; line-height: 1.6; color: #cbd5e1; margin-bottom: 20px;">
              Has sido registrado como docente en <strong>${schoolName}</strong> dentro de la plataforma <strong>LOGREVA</strong>. A continuación encontrarás tus credenciales de acceso al sistema:
            </p>

            <div style="background-color: #1e293b; padding: 20px; border-radius: 12px; margin: 20px 0; border: 1px solid #334155;">
              <p style="margin: 0 0 12px 0; font-size: 13px;">
                <strong style="color: #94a3b8; display: block; margin-bottom: 4px;">Usuario / Correo Electrónico:</strong>
                <code style="color: #38bdf8; background: #0f172a; padding: 6px 12px; border-radius: 6px; font-size: 14px; display: inline-block; font-family: monospace;">${email}</code>
              </p>
              <p style="margin: 0 0 12px 0; font-size: 13px;">
                <strong style="color: #94a3b8; display: block; margin-bottom: 4px;">Contraseña de Acceso:</strong>
                <code style="color: #34d399; background: #0f172a; padding: 6px 12px; border-radius: 6px; font-size: 14px; display: inline-block; font-family: monospace; font-weight: bold;">${password}</code>
              </p>
              <p style="margin: 0; font-size: 13px;">
                <strong style="color: #94a3b8; display: block; margin-bottom: 4px;">Institución:</strong>
                <span style="color: #e2e8f0; font-weight: 600;">${schoolName}</span>
              </p>
            </div>

            <div style="text-align: center; margin: 28px 0;">
              <a href="${loginUrl}" target="_blank" style="display: inline-block; background-color: #6366f1; color: #ffffff; text-decoration: none; padding: 12px 28px; border-radius: 10px; font-weight: bold; font-size: 14px; box-shadow: 0 4px 12px rgba(99, 102, 241, 0.35);">
                Ingresar a la Plataforma
              </a>
              <p style="margin: 10px 0 0 0; font-size: 12px; color: #64748b;">
                O copia este enlace en tu navegador: <br/>
                <a href="${loginUrl}" style="color: #38bdf8; word-break: break-all; text-decoration: underline;">${loginUrl}</a>
              </p>
            </div>

            <div style="border-top: 1px solid #1e293b; padding-top: 16px; margin-top: 24px;">
              <p style="font-size: 12px; color: #94a3b8; line-height: 1.5; margin: 0;">
                🔒 <strong>Recomendación de seguridad:</strong> Te sugerimos ingresar a tu perfil una vez dentro para actualizar tu contraseña personal en cualquier momento.
              </p>
            </div>
          </div>
        `

        // Envío A: Hostinger Mailer direct HTTP API (.site domain)
        try {
          await fetch('https://sandybrown-alpaca-347737.hostingersite.com/api/send-email.php', {
            method: 'POST',
            headers: {
              'Authorization': 'Bearer LOGREVA_MAILER_SECRET_2026',
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              to: email,
              subject: emailSubject,
              html: emailHtmlBody,
            }),
          })
        } catch (mailErr) {
          console.warn('Error enviando correo por Hostinger mailer:', mailErr)
        }

        // Envío B: Resend fallback si está configurado
        const resendApiKey = Deno.env.get('RESEND_API_KEY')
        if (resendApiKey) {
          try {
            await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${resendApiKey}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                from: Deno.env.get('EMAIL_FROM') || 'LOGREVA <notificaciones@adyronweb.site>',
                to: [email],
                subject: emailSubject,
                html: emailHtmlBody,
              }),
            })
          } catch (resendErr) {
            console.warn('Fallback Resend falló:', resendErr)
          }
        }
      }

      return respond({ success: true, user_id: createdUserId, message: 'Docente creado exitosamente y credenciales enviadas por correo.' }, 201)
    }

    if (body.action === 'delete') {
      const targetUserId = body.userId?.trim() ?? ''
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(targetUserId)) {
        return respond({ success: false, message: 'Usuario no válido.' }, 400)
      }
      if (targetUserId === userData.user.id) {
        return respond({ success: false, code: 'SELF_DELETE_FORBIDDEN', message: 'No puedes eliminar tu propia cuenta.' }, 409)
      }

      const [{ data: targetProfile, error: targetError }, { data: platformRole, error: platformError }] =
        await Promise.all([
          adminClient.from('profiles').select('id, email, full_name, role, school_id').eq('id', targetUserId).maybeSingle(),
          adminClient.from('user_platform_roles').select('user_id').eq('user_id', targetUserId).maybeSingle(),
        ])

      if (targetError || !targetProfile) return respond({ success: false, message: 'Usuario no encontrado.' }, 404)
      if (platformError) throw platformError
      if (platformRole) {
        return respond({ success: false, message: 'Las cuentas de plataforma no se eliminan desde este módulo.' }, 409)
      }

      const { error: deleteError } = await adminClient.auth.admin.deleteUser(targetUserId)
      if (deleteError) throw deleteError

      const { error: auditError } = await adminClient.from('audit_log').insert({
        school_id: targetProfile.school_id,
        user_id: userData.user.id,
        action: 'TENANT_USER_DELETED',
        table_name: 'profiles',
        record_id: targetUserId,
        old_values: { email: targetProfile.email, full_name: targetProfile.full_name, role: targetProfile.role },
      })
      if (auditError) console.error('manage-tenant-user audit failed', auditError.message)

      return respond({ success: true, message: 'Usuario eliminado de Auth y de la institución.' })
    }

    return respond({ success: false, message: 'Acción no válida.' }, 400)
  } catch (error) {
    if (createdUserId) {
      await adminClient.from('profiles').delete().eq('id', createdUserId)
      await adminClient.auth.admin.deleteUser(createdUserId).catch(() => undefined)
    }
    const rawMsg = error instanceof Error ? error.message : String(error || '')
    console.error('manage-tenant-user failed:', rawMsg)

    let clientMsg = 'No fue posible completar la operación de usuario.'
    if (rawMsg.includes('already been registered') || rawMsg.includes('already exists') || rawMsg.includes('duplicate key')) {
      clientMsg = 'Este correo electrónico ya se encuentra registrado en el sistema.'
    } else if (rawMsg.includes('Password') || rawMsg.includes('password')) {
      clientMsg = 'La contraseña debe cumplir con los requisitos mínimos de seguridad (al menos 8 caracteres).'
    } else if (rawMsg) {
      clientMsg = rawMsg
    }

    return respond({ success: false, message: clientMsg }, 400)
  }
})
