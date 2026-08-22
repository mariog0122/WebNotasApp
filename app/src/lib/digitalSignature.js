import forge from 'node-forge'

/**
 * Normaliza y formatea un string ASN1 o campo X509
 */
const getCertAttribute = (attributes, shortName) => {
  if (!attributes) return ''
  const attr = attributes.find(a => a.shortName === shortName || a.name === shortName)
  return attr ? attr.value : ''
}

/**
 * Lee y parsea un archivo de firma electrónica PKCS#12 (.p12 / .pfx)
 * @param {ArrayBuffer} arrayBuffer - Buffer del archivo .p12
 * @param {string} password - Contraseña del certificado
 * @returns {Promise<{success: boolean, certInfo?: object, privateKey?: object, certificate?: object, error?: string}>}
 */
export const readPkcs12Certificate = async (arrayBuffer, password) => {
  try {
    if (!arrayBuffer || arrayBuffer.byteLength === 0) {
      return { success: false, error: 'El archivo de certificado está vacío.' }
    }

    // Convertir ArrayBuffer a string binario para forge
    const bytes = new Uint8Array(arrayBuffer)
    let binary = ''
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }

    // Convertir ASN1 y parsear PKCS#12
    const p12Asn1 = forge.asn1.fromDer(binary)
    const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, password || '')

    // Obtener bolsas de certificados y llaves privadas
    const certBags = p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag] || []
    const keyBags = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })[forge.pki.oids.pkcs8ShroudedKeyBag] ||
                    p12.getBags({ bagType: forge.pki.oids.keyBag })[forge.pki.oids.keyBag] || []

    if (certBags.length === 0 || !certBags[0].cert) {
      return { success: false, error: 'No se encontró un certificado digital válido dentro del archivo .p12.' }
    }

    const cert = certBags[0].cert
    const privateKey = keyBags.length > 0 ? keyBags[0].key : null

    // Extraer atributos del sujeto
    const subjectAttrs = cert.subject.attributes
    const issuerAttrs = cert.issuer.attributes

    const commonName = getCertAttribute(subjectAttrs, 'CN') || 'Firmante Certificado'
    const organization = getCertAttribute(subjectAttrs, 'O') || ''
    const organizationalUnit = getCertAttribute(subjectAttrs, 'OU') || ''
    const country = getCertAttribute(subjectAttrs, 'C') || 'EC'
    const email = getCertAttribute(subjectAttrs, 'emailAddress') || ''

    const issuerCN = getCertAttribute(issuerAttrs, 'CN') || getCertAttribute(issuerAttrs, 'O') || 'Entidad de Certificación Autorizada'
    const issuerO = getCertAttribute(issuerAttrs, 'O') || ''

    // Fechas de vigencia
    const validFrom = cert.validity.notBefore
    const validTo = cert.validity.notAfter
    const now = new Date()
    const isExpired = now > validTo
    const isNotYetValid = now < validFrom

    if (isExpired) {
      return {
        success: false,
        error: `El certificado digital expiró el ${validTo.toLocaleDateString('es-EC')}. Utilice un certificado vigente.`
      }
    }

    if (isNotYetValid) {
      return {
        success: false,
        error: `El certificado digital aún no entra en vigencia (válido desde ${validFrom.toLocaleDateString('es-EC')}).`
      }
    }

    // Calcular Fingerprint SHA-256
    const derCert = forge.asn1.toDer(forge.pki.certificateToAsn1(cert)).getBytes()
    const mdSha256 = forge.md.sha256.create()
    mdSha256.update(derCert)
    const fingerprint = mdSha256.digest().toHex().match(/.{2}/g).join(':').toUpperCase()

    const serialNumber = cert.serialNumber || 'N/A'

    const certInfo = {
      commonName,
      organization,
      organizationalUnit,
      country,
      email,
      issuerCN,
      issuerO,
      serialNumber,
      validFrom: validFrom.toISOString(),
      validTo: validTo.toISOString(),
      fingerprint,
      hasPrivateKey: !!privateKey
    }

    return {
      success: true,
      certInfo,
      certificate: cert,
      privateKey
    }
  } catch (err) {
    console.error('Error al procesar certificado PKCS#12:', err)
    const msg = err.message || ''
    if (msg.includes('Invalid password') || msg.includes('PKCS#12') || msg.includes('MAC') || msg.includes('password')) {
      return { success: false, error: 'Contraseña del certificado digital incorrecta. Por favor verifique e intente nuevamente.' }
    }
    return { success: false, error: 'No se pudo leer el archivo de firma electrónica. Verifique que sea un archivo .p12 o .pfx válido.' }
  }
}

/**
 * Genera la firma digital criptográfica sobre un payload de alerta DECE
 * @param {object} alertData - Datos de la alerta a firmar
 * @param {object} privateKey - Llave privada del certificado
 * @param {object} certInfo - Información del certificado
 * @returns {{success: boolean, signatureData?: object, error?: string}}
 */
export const signAlertPayload = (alertData, privateKey, certInfo) => {
  try {
    if (!privateKey) {
      return { success: false, error: 'La llave privada no está disponible para firmar.' }
    }

    const signingTimestamp = new Date().toISOString()

    // Estructura canónica del documento firmado
    const canonicalPayload = {
      alert_id: alertData.id,
      institution: alertData.institution_name || 'Institución Educativa',
      student_id: alertData.student_id,
      student_name: alertData.students?.full_name || '',
      student_cedula: alertData.students?.student_cedula || '',
      course: alertData.courses?.name || '',
      alert_type: alertData.alert_type,
      severity: alertData.severity,
      date_occurred: alertData.date_occurred,
      description: (alertData.description || '').trim(),
      dece_notes: (alertData.dece_notes || '').trim(),
      resolution: (alertData.resolution || '').trim(),
      signing_timestamp: signingTimestamp,
      signer_name: certInfo.commonName,
      signer_issuer: certInfo.issuerCN,
      signer_serial: certInfo.serialNumber
    }

    const payloadString = JSON.stringify(canonicalPayload)

    // Crear digest SHA-256
    const md = forge.md.sha256.create()
    md.update(payloadString, 'utf8')
    const digestHex = md.digest().toHex()

    // Firmar con RSA PKCS#1 v1.5
    let signatureHex = ''
    try {
      const signatureBytes = privateKey.sign(md)
      signatureHex = forge.util.bytesToHex(signatureBytes)
    } catch (signErr) {
      // Fallback si es otro formato de clave
      signatureHex = forge.util.bytesToHex(forge.pki.rsa.sign(md, privateKey))
    }

    const signatureData = {
      is_valid: true,
      algorithm: 'SHA256withRSA',
      document_digest: digestHex,
      signature_hex: signatureHex,
      signed_at: signingTimestamp,
      signer_name: certInfo.commonName,
      signer_organization: certInfo.organization || 'Ecuador',
      signer_email: certInfo.email,
      certificate_issuer: certInfo.issuerCN,
      certificate_serial: certInfo.serialNumber,
      certificate_valid_from: certInfo.validFrom,
      certificate_valid_to: certInfo.validTo,
      certificate_fingerprint: certInfo.fingerprint,
      canonical_payload: canonicalPayload
    }

    return {
      success: true,
      signatureData
    }
  } catch (err) {
    console.error('Error al generar firma digital:', err)
    return {
      success: false,
      error: `Error generando firma digital: ${err.message || err}`
    }
  }
}
