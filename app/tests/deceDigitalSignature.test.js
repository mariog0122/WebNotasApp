import { describe, it, expect } from 'vitest'
import forge from 'node-forge'
import { readPkcs12Certificate, signAlertPayload } from '../src/lib/digitalSignature'
import fs from 'fs'
import path from 'path'

describe('DECE Digital Signature & Physical Printing Module', () => {
  it('correctly creates and reads a PKCS#12 (.p12) certificate and signs an alert payload', async () => {
    // 1. Generate RSA keypair in forge
    const keys = forge.pki.rsa.generateKeyPair(1024)

    // 2. Create self-signed X.509 certificate
    const cert = forge.pki.createCertificate()
    cert.publicKey = keys.publicKey
    cert.serialNumber = '0123456789ABCDEF'
    cert.validity.notBefore = new Date(Date.now() - 1000 * 60 * 60 * 24)
    cert.validity.notAfter = new Date(Date.now() + 1000 * 60 * 60 * 24 * 365) // 1 year valid

    const attrs = [
      { name: 'commonName', value: 'Lic. Maria Perez - Psicologa DECE' },
      { name: 'countryName', value: 'EC' },
      { shortName: 'O', value: 'Unidad Educativa San Francisco' },
      { shortName: 'OU', value: 'Departamento DECE' },
      { name: 'emailAddress', value: 'dece@ue-sanfrancisco.edu.ec' }
    ]
    cert.setSubject(attrs)
    cert.setIssuer(attrs)
    cert.sign(keys.privateKey, forge.md.sha256.create())

    // 3. Package as PKCS#12 (.p12)
    const password = 'TestSecretPassword123'
    const p12Asn1 = forge.pkcs12.toPkcs12Asn1(keys.privateKey, cert, password, {
      generateLocalKeyId: true,
      friendlyName: 'Firma DECE Maria Perez'
    })
    const p12Der = forge.asn1.toDer(p12Asn1).getBytes()

    // Convert to ArrayBuffer
    const buffer = new ArrayBuffer(p12Der.length)
    const view = new Uint8Array(buffer)
    for (let i = 0; i < p12Der.length; i++) {
      view[i] = p12Der.charCodeAt(i)
    }

    // 4. Test readPkcs12Certificate with correct password
    const readResult = await readPkcs12Certificate(buffer, password)
    expect(readResult.success).toBe(true)
    expect(readResult.certInfo.commonName).toBe('Lic. Maria Perez - Psicologa DECE')
    expect(readResult.certInfo.organization).toBe('Unidad Educativa San Francisco')
    expect(readResult.certInfo.hasPrivateKey).toBe(true)
    expect(readResult.certInfo.fingerprint).toBeDefined()

    // 5. Test readPkcs12Certificate with wrong password
    const wrongPassResult = await readPkcs12Certificate(buffer, 'WrongPassword999')
    expect(wrongPassResult.success).toBe(false)
    expect(wrongPassResult.error).toContain('Contraseña')

    // 6. Test signAlertPayload
    const alertMock = {
      id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      institution_name: 'Unidad Educativa San Francisco',
      student_id: 'stu-12345',
      students: {
        full_name: 'Carlos Andrés Benítez Mendoza',
        student_cedula: '0928374651'
      },
      courses: {
        name: '10mo EGB Paralelo A'
      },
      alert_type: 'INDISCIPLINA',
      severity: 'GRAVE',
      date_occurred: new Date().toISOString(),
      description: 'El estudiante fue sorprendido saliendo del aula sin autorización durante la hora de clase.',
      dece_notes: 'Se realiza entrevista con el estudiante y se cita al representante legal.',
      resolution: 'Compromiso firmado de cumplimiento de normas de convivencia escolar.'
    }

    const signResult = signAlertPayload(alertMock, readResult.privateKey, readResult.certInfo)
    expect(signResult.success).toBe(true)
    expect(signResult.signatureData).toBeDefined()
    expect(signResult.signatureData.is_valid).toBe(true)
    expect(signResult.signatureData.algorithm).toBe('SHA256withRSA')
    expect(signResult.signatureData.signer_name).toBe('Lic. Maria Perez - Psicologa DECE')
    expect(signResult.signatureData.signature_hex).toBeDefined()
    expect(signResult.signatureData.document_digest).toBeDefined()
    expect(signResult.signatureData.canonical_payload.alert_id).toBe(alertMock.id)
  })

  it('Alerts view and DECE modals provide both physical printing and electronic signature options', () => {
    const alertsSource = fs.readFileSync(path.resolve(__dirname, '../src/views/Alerts.vue'), 'utf-8')
    const printModalSource = fs.readFileSync(path.resolve(__dirname, '../src/components/dece/DecePrintModal.vue'), 'utf-8')
    const signModalSource = fs.readFileSync(path.resolve(__dirname, '../src/components/dece/DeceDigitalSignModal.vue'), 'utf-8')

    // Alerts view includes modals and trigger buttons
    expect(alertsSource).toContain('DecePrintModal')
    expect(alertsSource).toContain('DeceDigitalSignModal')
    expect(alertsSource).toContain('openPrintModal')
    expect(alertsSource).toContain('openSignModal')
    expect(alertsSource).toContain('handleAlertSigned')
    expect(alertsSource).toContain('is_digitally_signed')
    expect(alertsSource).toContain('signature_data')

    // Print modal contains official sections and physical signature blocks
    expect(printModalSource).toContain('ACTA DE NOTIFICACIÓN Y CITACIÓN A REPRESENTANTE LEGAL')
    expect(printModalSource).toContain('window.print()')
    expect(printModalSource).toContain('Documento Firmado Electrónicamente')
    expect(printModalSource).toContain('REPRESENTANTE LEGAL')
    expect(printModalSource).toContain('DOCENTE TUTOR')
    expect(printModalSource).toContain('CONSEJERÍA ESTUDIANTIL')
    expect(printModalSource).toContain('@media print')

    // Digital sign modal supports .p12 / .pfx files
    expect(signModalSource).toContain('.p12')
    expect(signModalSource).toContain('.pfx')
    expect(signModalSource).toContain('readPkcs12Certificate')
    expect(signModalSource).toContain('signAlertPayload')
    expect(signModalSource).toContain('Huella SHA-256')
  })
})
