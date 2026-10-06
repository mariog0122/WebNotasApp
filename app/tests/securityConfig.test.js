import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const readAppFile = (relativePath) =>
  readFileSync(new URL(`../${relativePath}`, import.meta.url), 'utf8')

describe('production security invariants', () => {
  it('never caches Supabase API responses in the service worker', () => {
    const viteConfig = readAppFile('vite.config.js')
    const appBootstrap = readAppFile('src/main.js')

    expect(viteConfig).not.toContain('supabase-api-cache')
    expect(viteConfig).not.toMatch(/runtimeCaching[\s\S]*supabase/i)
    expect(appBootstrap).not.toContain('persistQueryClient')
  })

  it('does not provision fallback teacher profiles in the browser', () => {
    const authStore = readAppFile('src/stores/auth.js')

    expect(authStore).not.toMatch(/from\(['"]profiles['"]\)[\s\S]{0,300}\.insert\(/)
    expect(authStore).not.toMatch(/role:\s*['"]teacher['"]/) 
  })

  it('does not expose public account registration in the login view', () => {
    const loginView = readAppFile('src/views/Login.vue')
    const dashboardView = readAppFile('src/views/Dashboard.vue')

    expect(loginView).not.toMatch(/signUp\s*\(/)
    expect(loginView).not.toMatch(/registr(?:ar|o|arse)/i)
    expect(dashboardView).not.toContain("rpc('invite_teacher_by_email'")
  })

  it('does not simulate impersonation by replacing the client profile', () => {
    const authStore = readAppFile('src/stores/auth.js')

    expect(authStore).not.toContain('startImpersonation')
    expect(authStore).not.toContain('originalProfile')
  })

  it('does not make absolute tenant-isolation promises', () => {
    const privacyView = readAppFile('src/views/Privacy.vue')

    expect(privacyView).not.toMatch(/estrictamente aislados/i)
    expect(privacyView).not.toMatch(/ningún tercero/i)
  })

  it('ships reproducible production security headers for supported hosts', () => {
    const vercel = JSON.parse(readAppFile('vercel.json'))
    const staticHeaders = readAppFile('public/_headers')
    const serialized = JSON.stringify(vercel)

    for (const source of [serialized, staticHeaders]) {
      expect(source).toContain('Content-Security-Policy')
      expect(source).toContain("default-src 'self'")
      expect(source).toContain("frame-ancestors 'none'")
      expect(source).toContain("object-src 'none'")
      expect(source).toContain('Strict-Transport-Security')
      expect(source).toContain('X-Content-Type-Options')
      expect(source).toContain('Referrer-Policy')
      expect(source).toContain('Permissions-Policy')
      expect(source).not.toContain("'unsafe-eval'")
    }
  })

  it('ships Hostinger SPA routing, HTTPS and security headers in .htaccess', () => {
    const hostinger = readAppFile('public/.htaccess')

    expect(hostinger).toContain('RewriteEngine On')
    expect(hostinger).toContain('RewriteCond %{REQUEST_FILENAME} !-f')
    expect(hostinger).toContain('RewriteCond %{REQUEST_FILENAME} !-d')
    expect(hostinger).toMatch(/RewriteRule\s+\.\s+\/index\.html\s+\[L\]/)
    expect(hostinger).toContain('https://%{HTTP_HOST}%{REQUEST_URI}')
    expect(hostinger).toContain('Content-Security-Policy')
    expect(hostinger).toContain("frame-ancestors 'none'")
    expect(hostinger).toContain('Strict-Transport-Security')
    expect(hostinger).toContain('Cache-Control')
    expect(hostinger).not.toContain("'unsafe-eval'")
  })
})
