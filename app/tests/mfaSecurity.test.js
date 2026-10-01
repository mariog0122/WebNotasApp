import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  getMfaStatus,
  isAal2Required,
  enrollTotpFactor,
  verifyAndActivateFactor,
  challengeAndVerifyLogin,
  unenrollFactor,
} from '../src/lib/mfa'

describe('MFA & 2FA Security Layer (BK-03)', () => {
  let mockSupabase

  beforeEach(() => {
    mockSupabase = {
      auth: {
        mfa: {
          listFactors: vi.fn(),
          getAuthenticatorAssuranceLevel: vi.fn(),
          enroll: vi.fn(),
          challenge: vi.fn(),
          verify: vi.fn(),
          challengeAndVerify: vi.fn(),
          unenroll: vi.fn(),
        },
      },
    }
  })

  describe('getMfaStatus', () => {
    it('returns isEnrolled: false when client has no verified factors', async () => {
      mockSupabase.auth.mfa.listFactors.mockResolvedValue({
        data: { all: [{ id: 'f-1', status: 'unverified', factor_type: 'totp' }] },
        error: null,
      })
      mockSupabase.auth.mfa.getAuthenticatorAssuranceLevel.mockResolvedValue({
        data: { currentLevel: 'aal1', nextLevel: 'aal1' },
        error: null,
      })

      const status = await getMfaStatus(mockSupabase)
      expect(status.isEnrolled).toBe(false)
      expect(status.hasMfa).toBe(false)
      expect(status.verifiedFactors).toHaveLength(0)
      expect(status.currentLevel).toBe('aal1')
    })

    it('returns isEnrolled: true when at least one verified factor exists', async () => {
      mockSupabase.auth.mfa.listFactors.mockResolvedValue({
        data: {
          all: [
            { id: 'f-verified', status: 'verified', factor_type: 'totp', friendly_name: 'App' },
          ],
        },
        error: null,
      })
      mockSupabase.auth.mfa.getAuthenticatorAssuranceLevel.mockResolvedValue({
        data: { currentLevel: 'aal2', nextLevel: 'aal2' },
        error: null,
      })

      const status = await getMfaStatus(mockSupabase)
      expect(status.isEnrolled).toBe(true)
      expect(status.hasMfa).toBe(true)
      expect(status.verifiedFactors).toHaveLength(1)
      expect(status.verifiedFactors[0].id).toBe('f-verified')
      expect(status.currentLevel).toBe('aal2')
    })

    it('handles legacy or missing mfa methods gracefully without throwing', async () => {
      const dummyClient = { auth: {} }
      const status = await getMfaStatus(dummyClient)
      expect(status.isEnrolled).toBe(false)
      expect(status.factors).toHaveLength(0)
      expect(status.error).toBeNull()
    })

    it('captures API errors and returns fallback structure', async () => {
      mockSupabase.auth.mfa.listFactors.mockRejectedValue(new Error('Network error'))
      const status = await getMfaStatus(mockSupabase)
      expect(status.isEnrolled).toBe(false)
      expect(status.error).toBeTruthy()
    })
  })

  describe('isAal2Required', () => {
    it('returns true when nextLevel is aal2 and currentLevel is aal1', async () => {
      mockSupabase.auth.mfa.getAuthenticatorAssuranceLevel.mockResolvedValue({
        data: { currentLevel: 'aal1', nextLevel: 'aal2' },
        error: null,
      })
      const required = await isAal2Required(mockSupabase)
      expect(required).toBe(true)
    })

    it('returns false when nextLevel is aal1', async () => {
      mockSupabase.auth.mfa.getAuthenticatorAssuranceLevel.mockResolvedValue({
        data: { currentLevel: 'aal1', nextLevel: 'aal1' },
        error: null,
      })
      const required = await isAal2Required(mockSupabase)
      expect(required).toBe(false)
    })

    it('returns false when currentLevel is already elevated to aal2', async () => {
      mockSupabase.auth.mfa.getAuthenticatorAssuranceLevel.mockResolvedValue({
        data: { currentLevel: 'aal2', nextLevel: 'aal2' },
        error: null,
      })
      const required = await isAal2Required(mockSupabase)
      expect(required).toBe(false)
    })

    it('returns false if assurance check fails or client is unauthenticated', async () => {
      mockSupabase.auth.mfa.getAuthenticatorAssuranceLevel.mockResolvedValue({
        data: null,
        error: { message: 'session_not_found' },
      })
      const required = await isAal2Required(mockSupabase)
      expect(required).toBe(false)
    })
  })

  describe('enrollTotpFactor', () => {
    it('requests TOTP enrollment with standard parameters and returns formatted payload', async () => {
      mockSupabase.auth.mfa.enroll.mockResolvedValue({
        data: {
          id: 'factor-totp-123',
          type: 'totp',
          totp: {
            qr_code: '<svg>mock-qr</svg>',
            secret: 'JBSWY3DPEHPK3PXP',
            uri: 'otpauth://totp/LOGREVA:docente@colegio.edu.ec?secret=JBSWY3DPEHPK3PXP',
          },
        },
        error: null,
      })

      const res = await enrollTotpFactor({
        issuer: 'LOGREVA-TEST',
        friendlyName: 'Docente Móvil',
        supabaseClient: mockSupabase,
      })

      expect(mockSupabase.auth.mfa.enroll).toHaveBeenCalledWith({
        factorType: 'totp',
        issuer: 'LOGREVA-TEST',
        friendlyName: 'Docente Móvil',
      })
      expect(res.factorId).toBe('factor-totp-123')
      expect(res.qrCode).toBe('<svg>mock-qr</svg>')
      expect(res.secret).toBe('JBSWY3DPEHPK3PXP')
    })

    it('throws when supabase returns enrollment error', async () => {
      mockSupabase.auth.mfa.enroll.mockResolvedValue({
        data: null,
        error: new Error('User already has max factors'),
      })

      await expect(
        enrollTotpFactor({ supabaseClient: mockSupabase }),
      ).rejects.toThrow('User already has max factors')
    })
  })

  describe('verifyAndActivateFactor', () => {
    it('validates 6-digit length strictly', async () => {
      await expect(
        verifyAndActivateFactor({ factorId: 'f-1', code: '12345', supabaseClient: mockSupabase }),
      ).rejects.toThrow('El código de verificación debe contener exactamente 6 dígitos numéricos.')

      await expect(
        verifyAndActivateFactor({ factorId: 'f-1', code: '1234567', supabaseClient: mockSupabase }),
      ).rejects.toThrow('El código de verificación debe contener exactamente 6 dígitos numéricos.')
    })

    it('calls challengeAndVerify directly when supported', async () => {
      mockSupabase.auth.mfa.challengeAndVerify.mockResolvedValue({
        data: { user: { id: 'u1' } },
        error: null,
      })

      const res = await verifyAndActivateFactor({
        factorId: 'f-1',
        code: ' 654 321 ',
        supabaseClient: mockSupabase,
      })

      expect(mockSupabase.auth.mfa.challengeAndVerify).toHaveBeenCalledWith({
        factorId: 'f-1',
        code: '654321',
      })
      expect(res.user.id).toBe('u1')
    })

    it('uses fallback challenge and verify if challengeAndVerify is not a function', async () => {
      delete mockSupabase.auth.mfa.challengeAndVerify
      mockSupabase.auth.mfa.challenge.mockResolvedValue({
        data: { id: 'ch-999' },
        error: null,
      })
      mockSupabase.auth.mfa.verify.mockResolvedValue({
        data: { user: { id: 'u1' } },
        error: null,
      })

      const res = await verifyAndActivateFactor({
        factorId: 'f-1',
        code: '112233',
        supabaseClient: mockSupabase,
      })

      expect(mockSupabase.auth.mfa.challenge).toHaveBeenCalledWith({ factorId: 'f-1' })
      expect(mockSupabase.auth.mfa.verify).toHaveBeenCalledWith({
        factorId: 'f-1',
        challengeId: 'ch-999',
        code: '112233',
      })
      expect(res.user.id).toBe('u1')
    })
  })

  describe('challengeAndVerifyLogin', () => {
    it('resolves factorId from listFactors if not passed explicitly', async () => {
      mockSupabase.auth.mfa.listFactors.mockResolvedValue({
        data: {
          all: [{ id: 'auto-factor-id', status: 'verified', factor_type: 'totp' }],
        },
        error: null,
      })
      mockSupabase.auth.mfa.getAuthenticatorAssuranceLevel.mockResolvedValue({
        data: { currentLevel: 'aal1', nextLevel: 'aal2' },
        error: null,
      })
      mockSupabase.auth.mfa.challengeAndVerify.mockResolvedValue({
        data: { user: { id: 'logged-in' } },
        error: null,
      })

      const res = await challengeAndVerifyLogin({
        code: '998877',
        supabaseClient: mockSupabase,
      })

      expect(mockSupabase.auth.mfa.challengeAndVerify).toHaveBeenCalledWith({
        factorId: 'auto-factor-id',
        code: '998877',
      })
      expect(res.user.id).toBe('logged-in')
    })

    it('rejects with MFA_FACTOR_NOT_FOUND when no verified factor exists', async () => {
      mockSupabase.auth.mfa.listFactors.mockResolvedValue({
        data: { all: [] },
        error: null,
      })
      mockSupabase.auth.mfa.getAuthenticatorAssuranceLevel.mockResolvedValue({
        data: { currentLevel: 'aal1', nextLevel: 'aal1' },
        error: null,
      })

      await expect(
        challengeAndVerifyLogin({
          code: '123456',
          supabaseClient: mockSupabase,
        }),
      ).rejects.toThrow('No se encontró un factor TOTP verificado para autenticar.')
    })
  })

  describe('unenrollFactor', () => {
    it('invokes unenroll with target factor id', async () => {
      mockSupabase.auth.mfa.unenroll.mockResolvedValue({
        data: { id: 'factor-del' },
        error: null,
      })

      const res = await unenrollFactor({ factorId: 'factor-del', supabaseClient: mockSupabase })
      expect(mockSupabase.auth.mfa.unenroll).toHaveBeenCalledWith({ factorId: 'factor-del' })
      expect(res.id).toBe('factor-del')
    })

    it('throws when unenroll is not supported or returns error', async () => {
      mockSupabase.auth.mfa.unenroll.mockResolvedValue({
        data: null,
        error: new Error('Cannot delete sole MFA factor under organization policy'),
      })

      await expect(
        unenrollFactor({ factorId: 'factor-del', supabaseClient: mockSupabase }),
      ).rejects.toThrow('Cannot delete sole MFA factor under organization policy')
    })
  })
})
