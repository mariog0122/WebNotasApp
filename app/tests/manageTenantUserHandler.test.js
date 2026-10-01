import { beforeAll, describe, expect, it, vi } from 'vitest'
import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'
import { transformWithEsbuild } from 'vite'
import { canDeleteTenantUser } from '../../supabase/functions/manage-tenant-user/authorization'

let handlerCode
beforeAll(async () => {
  const source = readFileSync(new URL('../../supabase/functions/manage-tenant-user/index.ts', import.meta.url), 'utf8')
  handlerCode = (await transformWithEsbuild(source.replace(/^import .*$/gm, ''), 'handler.ts', { loader: 'ts' })).code
})

const callerId = '11111111-1111-4111-8111-111111111111'
const targetId = '22222222-2222-4222-8222-222222222222'

function setup({
  targetSchool = 'school-a',
  requestedSchool = 'school-a',
  platform = false,
  legacyPlatformAdmin = platform,
  protectedAccount = false,
  self = false,
  callerRole = 'admin',
  memberships = [],
  targetMemberships = [],
  canManage = true,
} = {}) {
  const deleteUser = vi.fn().mockResolvedValue({ error: null })
  const report = vi.fn().mockResolvedValue({ success: true })
  const caller = {
    auth: { getUser: vi.fn().mockResolvedValue({ data: { user: { id: callerId } }, error: null }) },
    rpc: vi.fn(async (name) => ({
      data: name === 'has_platform_role'
        ? platform
        : name === 'is_platform_admin'
          ? legacyPlatformAdmin
          : canManage,
      error: null,
    })),
  }
  const admin = {
    auth: { admin: { deleteUser } },
    from: vi.fn((table) => {
      const filters = {}
      const resolve = () => {
        if (table === 'profiles') return { data: filters.id === callerId
          ? { id: callerId, school_id: 'school-a', is_active: true, role: callerRole }
          : { id: targetId, school_id: targetSchool, role: 'teacher' }, error: null }
        if (table === 'tenant_memberships') return {
          data: filters.user_id === callerId ? memberships : targetMemberships,
          error: null,
        }
        if (table === 'user_platform_roles') return { data: protectedAccount ? { user_id: targetId } : null, error: null }
        return { data: null, error: null }
      }
      const query = {
        select: () => query,
        eq: (key, value) => { filters[key] = value; return query },
        maybeSingle: async () => resolve(),
        insert: async () => ({ error: null }),
        then: (yes, no) => Promise.resolve(resolve()).then(yes, no),
      }
      return query
    }),
  }
  let handler
  runInNewContext(handlerCode, {
    createClient: (_url, key) => key === 'anon' ? caller : admin,
    canDeleteTenantUser,
    reportEdgeFunctionError: report,
    Deno: {
      env: { get: (name) => ({ SUPABASE_URL: 'https://example.invalid', SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: 'service' })[name] },
      serve: (fn) => { handler = fn },
    },
    Response, console,
  })
  const request = new Request('https://example.invalid', {
    method: 'POST', headers: { Authorization: 'Bearer test', 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'delete', userId: self ? callerId : targetId, schoolId: requestedSchool }),
  })
  return { run: () => handler(request), deleteUser }
}

describe('actual manage-tenant-user request handler', () => {
  it('does not treat the broad legacy platform-support flag as user administration', async () => {
    const ctx = setup({
      requestedSchool: 'school-b',
      targetSchool: 'school-b',
      platform: false,
      legacyPlatformAdmin: true,
      callerRole: 'teacher',
      canManage: false,
    })

    expect((await ctx.run()).status).toBe(403)
    expect(ctx.deleteUser).not.toHaveBeenCalled()
  })

  it('does not carry an administrator role or primary-school permission into a teacher membership', async () => {
    const ctx = setup({
      requestedSchool: 'school-b',
      targetSchool: 'school-b',
      callerRole: 'admin',
      canManage: true,
      memberships: [{ school_id: 'school-b', is_active: true, tenant_roles: { name: 'teacher' } }],
    })

    expect((await ctx.run()).status).toBe(403)
    expect(ctx.deleteUser).not.toHaveBeenCalled()
  })

  it('allows an explicit administrator membership in the target school', async () => {
    const ctx = setup({
      requestedSchool: 'school-b',
      targetSchool: 'school-b',
      callerRole: 'teacher',
      canManage: false,
      memberships: [{ school_id: 'school-b', is_active: true, tenant_roles: { name: 'school_admin' } }],
      targetMemberships: [{ school_id: 'school-b', is_active: true }],
    })

    expect((await ctx.run()).status).toBe(200)
    expect(ctx.deleteUser).toHaveBeenCalledExactlyOnceWith(targetId)
  })

  it('does not delete a multi-school Auth account from one tenant', async () => {
    const ctx = setup({
      targetMemberships: [
        { school_id: 'school-a', is_active: true },
        { school_id: 'school-b', is_active: true },
      ],
    })

    expect((await ctx.run()).status).toBe(409)
    expect(ctx.deleteUser).not.toHaveBeenCalled()
  })

  it('rejects a foreign tenant UUID without calling Auth deletion', async () => {
    const ctx = setup({ targetSchool: 'school-b' })
    expect((await ctx.run()).status).toBe(403)
    expect(ctx.deleteUser).not.toHaveBeenCalled()
  })
  it('retains authorized deletion within the same school', async () => {
    const ctx = setup()
    expect((await ctx.run()).status).toBe(200)
    expect(ctx.deleteUser).toHaveBeenCalledExactlyOnceWith(targetId)
  })
  it('retains platform administrator access across schools', async () => {
    const ctx = setup({ platform: true, targetSchool: 'school-b' })
    expect((await ctx.run()).status).toBe(200)
    expect(ctx.deleteUser).toHaveBeenCalledExactlyOnceWith(targetId)
  })
  it.each([{ protectedAccount: true }, { self: true }])('never deletes protected or own accounts: %j', async (options) => {
    const ctx = setup(options)
    expect((await ctx.run()).status).toBe(409)
    expect(ctx.deleteUser).not.toHaveBeenCalled()
  })
})
