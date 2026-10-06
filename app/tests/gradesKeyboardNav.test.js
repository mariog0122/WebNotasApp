import { describe, expect, it } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8')

describe('Sprint 5: Grades Keyboard Navigation, Accessibility & Database encryption Contracts', () => {
  it('implements full keyboard navigation (ArrowUp, ArrowDown, Tab, Enter) in GradesSubjectsSection.vue', () => {
    const gradesSource = read('src/components/grades/GradesSubjectsSection.vue')

    // Verifies navigation functions in <script setup>
    expect(gradesSource).toContain('const handleGradeKeyDown')
    expect(gradesSource).toContain('const focusGradeCell')
    expect(gradesSource).toContain('const getDefColIndex')
    expect(gradesSource).toContain('scrollerRef')

    // Verifies handling of key events
    expect(gradesSource).toContain("event.key === 'ArrowDown'")
    expect(gradesSource).toContain("event.key === 'ArrowUp'")
    expect(gradesSource).toContain("event.key === 'Enter'")
    expect(gradesSource).toContain("event.key === 'Tab'")
    expect(gradesSource).toContain("event.key === 'ArrowRight'")
    expect(gradesSource).toContain("event.key === 'ArrowLeft'")

    // Verifies data-grade-input attribute bindings on inputs
    expect(gradesSource).toContain(':data-grade-input="`${idx}-${getDefColIndex(def.id)}`"')
    expect(gradesSource).toContain('@keydown="handleGradeKeyDown($event, idx, getDefColIndex(def.id))"')
  })

  it('implements WCAG 2.1 accessibility attributes and live region for autosave', () => {
    const gradesSource = read('src/components/grades/GradesSubjectsSection.vue')

    // Verifies live region for screen readers
    expect(gradesSource).toContain('id="grade-autosave-status"')
    expect(gradesSource).toContain('role="status"')
    expect(gradesSource).toContain('aria-live="polite"')
    expect(gradesSource).toContain('aria-atomic="true"')

    // Verifies aria-describedby and aria-label references
    expect(gradesSource).toContain('aria-describedby="grade-autosave-status"')
    expect(gradesSource).toContain(':aria-label="`Calificación ${def.name} para ${student.full_name}`"')

    // Qualitative mode accessibility
    expect(gradesSource).toContain(':data-grade-qualitative="idx"')
    expect(gradesSource).toContain(':aria-label="`Calificación cualitativa para ${student.full_name}`"')
  })

  it('verifies the final Vault-backed encryption contract for institution_ai_settings', () => {
    const migrationPath = path.resolve(root, '../supabase/migrations/20260911015014_move_ai_key_encryption_to_vault.sql')
    expect(fs.existsSync(migrationPath)).toBe(true)

    const migrationSource = fs.readFileSync(migrationPath, 'utf8')

    expect(migrationSource).toContain("vault.create_secret(")
    expect(migrationSource).toContain("name = 'education_ai_key_encryption_secret'")

    // Encryption / Decryption functions
    expect(migrationSource).toContain('create or replace function public.encrypt_ai_api_key')
    expect(migrationSource).toContain('create or replace function public.decrypt_ai_api_key')
    expect(migrationSource).toContain('security definer')
    expect(migrationSource).toContain('security definer')
    expect(migrationSource).toContain('set search_path = pg_catalog, extensions, public, vault')
    expect(migrationSource).toContain('extensions.pgp_sym_encrypt')
    expect(migrationSource).toContain('extensions.pgp_sym_decrypt')

    // Security hardening: restricted strictly to service_role
    expect(migrationSource).toContain('revoke all on function public.encrypt_ai_api_key(text) from public, anon, authenticated')
    expect(migrationSource).toContain('grant execute on function public.encrypt_ai_api_key(text) to service_role')
    expect(migrationSource).toContain('revoke all on function public.decrypt_ai_api_key(text) from public, anon, authenticated')
    expect(migrationSource).toContain('grant execute on function public.decrypt_ai_api_key(text) to service_role')
  })
})
