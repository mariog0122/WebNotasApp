import { describe, expect, it } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'

const readAppFile = (relativePath) =>
  readFileSync(new URL(`../${relativePath}`, import.meta.url), 'utf8')

const readRootFile = (relativePath) =>
  readFileSync(new URL(`../../${relativePath}`, import.meta.url), 'utf8')

describe('Superadmin user CRUD', () => {
  it('creates confirmed password users and deletes them only from a verified server function', () => {
    const functionSource = readRootFile('supabase/functions/manage-tenant-user/index.ts')

    expect(functionSource).toContain('auth.getUser')
    expect(functionSource).toContain("rpc('is_platform_admin')")
    expect(functionSource).toContain('SUPABASE_SERVICE_ROLE_KEY')
    expect(functionSource).toContain('auth.admin.createUser')
    expect(functionSource).toContain('email_confirm: true')
    expect(functionSource).toContain('password')
    expect(functionSource).toContain('auth.admin.deleteUser')
    expect(functionSource).toContain('SELF_DELETE_FORBIDDEN')
  })

  it('exposes create and delete actions from the isolated Superadmin users module', () => {
    const usersView = readAppFile('src/modules/superadmin/users/UsersTab.vue')
    const superadminView = readAppFile('src/views/SuperAdmin.vue')

    expect(usersView).toContain("functions.invoke('manage-tenant-user'")
    expect(usersView).toContain("action: 'create'")
    expect(usersView).toContain("action: 'delete'")
    expect(usersView).toContain('Confirmar eliminación')
    expect(superadminView).toContain("activeTab === 'users'")
  })

  it('cascades the public profile when Auth deletes a user', () => {
    const migration = readRootFile('supabase/migrations/20260810_fix_auth_user_deletion.sql')

    expect(migration).toMatch(/profiles_id_fkey[\s\S]*references auth\.users\s*\(id\)[\s\S]*on delete cascade/i)
  })
})

describe('environment-aware Supabase Auth URLs', () => {
  it('centralizes the application URL and targets the reset-password route', () => {
    const appUrl = readAppFile('src/lib/appUrl.js')
    const loginView = readAppFile('src/views/Login.vue')
    const router = readAppFile('src/router/index.js')

    expect(appUrl).toContain('import.meta.env.VITE_APP_URL')
    expect(appUrl).toContain('APP_URL')
    expect(loginView).toContain("`${APP_URL}/reset-password`")
    expect(loginView).not.toContain('window.location.origin')
    expect(router).toContain("path: '/reset-password'")
    expect(router).toContain("path: '/change-password'")
    expect(router).toContain("path: '/auth/callback'")
  })

  it('uses Hostinger in staging without contaminating development', () => {
    const stagingPath = new URL('../.env.staging', import.meta.url)
    const developmentPath = new URL('../.env.development', import.meta.url)

    expect(existsSync(stagingPath)).toBe(true)
    expect(readFileSync(stagingPath, 'utf8')).toContain(
      'VITE_APP_URL=https://sandybrown-alpaca-347737.hostingersite.com',
    )
    expect(readFileSync(stagingPath, 'utf8')).not.toMatch(/localhost|127\.0\.0\.1/)
    expect(existsSync(developmentPath)).toBe(true)
    expect(readFileSync(developmentPath, 'utf8')).toMatch(/localhost/)
  })
})
