import { createClient } from 'npm:@supabase/supabase-js@2.49.8'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const jsonResponse = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

type ProvisionRequest = {
  name?: string
  tradeName?: string
  code?: string
  country?: string
  province?: string
  city?: string
  timezone?: string
  adminName?: string
  adminEmail?: string
  adminPassword?: string
  adminPhone?: string
  planId?: string
  billingCycle?: 'monthly' | 'yearly'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return jsonResponse({ success: false, message: 'Método no permitido.' }, 405)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const authorization = req.headers.get('Authorization') ?? ''

  if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization.startsWith('Bearer ')) {
    return jsonResponse({ success: false, message: 'Solicitud no autenticada.' }, 401)
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  let createdSchoolId: string | null = null
  let createdUserId: string | null = null

  try {
    const token = authorization.replace(/^Bearer\s+/i, '')
    const { data: userData, error: userError } = await callerClient.auth.getUser(token)
    if (userError || !userData.user) {
      return jsonResponse({ success: false, message: 'Sesión no válida.' }, 401)
    }

    const { data: isPlatformAdmin, error: roleError } = await callerClient.rpc('is_platform_admin')
    if (roleError || isPlatformAdmin !== true) {
      return jsonResponse({ success: false, message: 'Acceso denegado.' }, 403)
    }

    const body = (await req.json()) as ProvisionRequest
    const name = body.name?.trim() ?? ''
    const adminName = body.adminName?.trim() ?? ''
    const adminEmail = body.adminEmail?.trim().toLowerCase() ?? ''
    const adminPhone = body.adminPhone?.trim() ?? ''
    const adminPassword = body.adminPassword ?? ''
    const code = (body.code?.trim() || name.slice(0, 4)).toUpperCase()

    if (!name || !adminName || !adminEmail || !adminPhone || !body.planId || adminPassword.length < 8) {
      return jsonResponse({ success: false, message: 'Nombre, correo, teléfono móvil del administrador, contraseña y plan son obligatorios.' }, 400)
    }
    const cleanPhone = adminPhone.trim()
    const digitsOnly = cleanPhone.replace(/\D/g, '')
    if (digitsOnly.length < 8) {
      return jsonResponse({ success: false, message: 'El número de teléfono del administrador debe contener al menos 8 dígitos.' }, 400)
    }

    // Verificar si el teléfono ya pertenece a otro perfil en la plataforma
    const { data: existingPhoneUser, error: phoneLookupError } = await adminClient
      .from('profiles')
      .select('id, email, phone')
      .or(`phone.eq.${cleanPhone},phone.eq.${digitsOnly}`)
      .limit(1)

    if (!phoneLookupError && existingPhoneUser && existingPhoneUser.length > 0) {
      return jsonResponse({
        success: false,
        message: `El número de teléfono ${cleanPhone} ya está registrado en el sistema. Debe usar un número diferente para el administrador del colegio.`,
      }, 400)
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(adminEmail)) {
      return jsonResponse({ success: false, message: 'Correo del administrador no válido.' }, 400)
    }
    if (!['monthly', 'yearly'].includes(body.billingCycle ?? 'monthly')) {
      return jsonResponse({ success: false, message: 'Ciclo de facturación no válido.' }, 400)
    }

    const { data: provision, error: provisionError } = await callerClient.rpc('provision_tenant_wizard', {
      p_name: name,
      p_trade_name: body.tradeName?.trim() || name,
      p_code: code,
      p_country: body.country?.trim() || 'Ecuador',
      p_province: body.province?.trim() || null,
      p_city: body.city?.trim() || null,
      p_timezone: body.timezone?.trim() || 'America/Guayaquil',
      p_admin_name: adminName,
      p_admin_email: adminEmail,
      p_admin_phone: body.adminPhone?.trim() || null,
      p_plan_id: body.planId,
      p_billing_cycle: body.billingCycle ?? 'monthly',
      p_price: 0,
    })

    if (provisionError || !provision?.success || !provision.school_id) {
      return jsonResponse({
        success: false,
        message: provision?.message || 'No fue posible crear la institución.',
      }, 400)
    }

    createdSchoolId = provision.school_id
    let administratorUserId: string | null = null
    let accountCreated = false

    const loginUrl = 'https://sandybrown-alpaca-347737.hostingersite.com/'

    // 1. Invitar al usuario por correo (esto crea el usuario y dispara AUTOMÁTICAMENTE el correo de Supabase Auth)
    const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(adminEmail, {
      redirectTo: loginUrl,
      data: { full_name: adminName, school_id: createdSchoolId, role: 'admin', tenant_role: 'school_admin' }
    })

    if (!inviteError && inviteData?.user) {
      administratorUserId = inviteData.user.id
      createdUserId = inviteData.user.id
      accountCreated = true

      // Asignar contraseña establecida en el wizard
      if (adminPassword && adminPassword.length >= 8) {
        await adminClient.auth.admin.updateUserById(administratorUserId, {
          password: adminPassword,
          email_confirm: true
        }).catch((e) => console.error('Error actualizando contraseña del admin:', e.message))
      }
    } else {
      // Si el correo ya existía o falla la invitación directa, intentar crear/actualizar
      const { data: created, error: createError } = await adminClient.auth.admin.createUser({
        email: adminEmail,
        password: adminPassword,
        email_confirm: true,
        user_metadata: { full_name: adminName },
        app_metadata: { role: 'admin', school_id: createdSchoolId, tenant_role: 'school_admin' },
      })

      if (!createError && created?.user) {
        administratorUserId = created.user.id
        createdUserId = created.user.id
        accountCreated = true
      } else {
        const { data: userList } = await adminClient.auth.admin.listUsers()
        const userFound = userList?.users?.find(u => u.email?.toLowerCase() === adminEmail)

        if (!userFound) {
          throw new Error(createError?.message || inviteError?.message || 'No se pudo crear la cuenta de administrador.')
        }

        administratorUserId = userFound.id
        accountCreated = false

        if (adminPassword && adminPassword.length >= 8) {
          await adminClient.auth.admin.updateUserById(administratorUserId, {
            password: adminPassword,
            email_confirm: true,
            user_metadata: { full_name: adminName },
            app_metadata: { role: 'admin', school_id: createdSchoolId, tenant_role: 'school_admin' }
          }).catch((e) => console.warn('No se pudo actualizar clave de usuario existente:', e.message))
        }
      }

      // Enviar enlace de restablecimiento / acceso por correo si fue creado sin invitación previa
      await adminClient.auth.resetPasswordForEmail(adminEmail, {
        redirectTo: loginUrl
      }).catch((e) => console.error('Error enviando correo de acceso:', e.message))
    }

    // 2. Obtener rol de school_admin
    const { data: tenantRole, error: tenantRoleError } = await adminClient
      .from('tenant_roles')
      .select('id')
      .eq('name', 'school_admin')
      .maybeSingle()
    if (tenantRoleError || !tenantRole) throw tenantRoleError || new Error('El rol de school_admin no se encuentra en el sistema.')

    // 3. Crear o actualizar perfil en la tabla profiles
    const { error: profileError } = await adminClient.from('profiles').upsert({
      id: administratorUserId,
      email: adminEmail,
      full_name: adminName,
      phone: body.adminPhone?.trim() || null,
      role: 'admin',
      school_id: createdSchoolId,
      is_active: true,
    }, { onConflict: 'id' })
    if (profileError) throw profileError

    // 4. Crear membresía del tenant
    const { error: membershipError } = await adminClient.from('tenant_memberships').upsert({
      user_id: administratorUserId,
      school_id: createdSchoolId,
      tenant_role_id: tenantRole.id,
      is_active: true,
    }, { onConflict: 'user_id,school_id' })
    if (membershipError) throw membershipError

    // 5. Registrar en auditoría de forma segura
    try {
      await adminClient.from('audit_log').insert({
        school_id: createdSchoolId,
        user_id: userData.user.id,
        action: 'TENANT_PROVISIONED',
        table_name: 'schools',
        record_id: createdSchoolId,
        new_values: {
          administrator_user_id: administratorUserId,
          administrator_email: adminEmail,
          account_created: accountCreated,
          plan_id: body.planId,
          billing_cycle: body.billingCycle ?? 'monthly',
        },
      })
    } catch (auditErr) {
      console.warn('Audit log write failed:', auditErr)
    }

    // 6. Enviar correo de bienvenida con credenciales mediante Hostinger Mailer Endpoint y/o Resend
    const emailHtmlBody = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; background-color: #0f172a; color: #f8fafc; border-radius: 16px;">
        <h2 style="color: #818cf8; margin-top: 0; font-size: 22px;">¡Bienvenido a LOGREVA!</h2>
        <p style="font-size: 15px; line-height: 1.5; color: #cbd5e1;">Hola <strong>${adminName}</strong>, se ha creado exitosamente la institución <strong>${name}</strong>.</p>

        <div style="background-color: #1e293b; padding: 18px; border-radius: 12px; margin: 24px 0; border: 1px solid #334155;">
          <p style="margin: 0 0 10px 0; font-size: 14px;"><strong style="color: #94a3b8;">Enlace de acceso a la plataforma:</strong><br/><a href="${loginUrl}" style="color: #38bdf8; font-weight: bold; text-decoration: underline;">${loginUrl}</a></p>
          <p style="margin: 0 0 10px 0; font-size: 14px;"><strong style="color: #94a3b8;">Usuario / Correo de acceso:</strong><br/><code style="color: #e2e8f0; background: #0f172a; padding: 4px 10px; border-radius: 6px; font-size: 15px;">${adminEmail}</code></p>
          <p style="margin: 0; font-size: 14px;"><strong style="color: #94a3b8;">Contraseña Temporal:</strong><br/><code style="color: #34d399; background: #0f172a; padding: 4px 10px; border-radius: 6px; font-size: 15px;">${adminPassword}</code></p>
        </div>

        <p style="font-size: 13px; color: #94a3b8; line-height: 1.4;">Por razones de seguridad, te sugerimos ingresar a la plataforma y actualizar tu contraseña si lo deseas.</p>
      </div>
    `

    // Método A: Hostinger Mailer direct HTTP API
    try {
      await fetch('https://sandybrown-alpaca-347737.hostingersite.com/api/send-email.php', {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer LOGREVA_MAILER_SECRET_2026',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: adminEmail,
          subject: `Bienvenido a LOGREVA - Credenciales de acceso para ${name}`,
          html: emailHtmlBody,
        }),
      })
    } catch (hostingerMailErr) {
      console.warn('Error enviando por Hostinger mailer:', hostingerMailErr)
    }

    // Método B: Resend API (si está configurada)
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
            from: Deno.env.get('EMAIL_FROM') || 'LOGREVA <onboarding@resend.dev>',
            to: [adminEmail],
            subject: `Bienvenido a LOGREVA - Credenciales de acceso para ${name}`,
            html: emailHtmlBody,
          }),
        })
      } catch (emailErr) {
        console.warn('No se pudo enviar por Resend:', emailErr)
      }
    }

    return jsonResponse({
      ...provision,
      success: true,
      account_created: accountCreated,
      administrator_user_id: administratorUserId,
      loginUrl,
      adminEmail,
      adminPassword: adminPassword,
      message: accountCreated
        ? 'Institución y administrador creados exitosamente.'
        : 'Institución creada y administrador existente vinculado.',
    })
  } catch (error) {
    if (createdUserId) {
      await adminClient.from('profiles').delete().eq('id', createdUserId).catch(() => undefined)
      await adminClient.auth.admin.deleteUser(createdUserId).catch(() => undefined)
    }
    if (createdSchoolId) {
      await adminClient.from('schools').delete().eq('id', createdSchoolId).catch(() => undefined)
    }

    const errMessage = error instanceof Error ? error.message : 'No fue posible completar el alta de la institución.'
    console.error('provision-tenant failed:', errMessage)
    return jsonResponse({
      success: false,
      message: errMessage,
    }, 400)
  }
})
