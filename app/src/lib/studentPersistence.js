import { getFileExt, uploadPhoto } from './studentUtils'

const createStudentId = () => {
  const id = globalThis.crypto?.randomUUID?.()
  if (!id) throw new Error('Este navegador no puede generar un identificador seguro para el estudiante.')
  return id
}

const cleanupUploadedPhotos = async (client, uploadedPaths) => {
  if (uploadedPaths.length === 0) return
  try {
    const { error } = await client.storage.from('student-photos').remove(uploadedPaths)
    if (error) console.warn('No se pudieron limpiar fotos huérfanas del estudiante:', error)
  } catch (error) {
    console.warn('No se pudieron limpiar fotos huérfanas del estudiante:', error)
  }
}

export const saveStudentRecord = async ({
  client,
  schoolId,
  studentId = null,
  payload,
  studentPhotoFile = null,
  representativePhotoFile = null,
}) => {
  if (!client || !schoolId || !payload?.course_id) {
    throw new Error('Faltan datos institucionales para guardar el estudiante.')
  }

  const targetId = studentId || createStudentId()
  const uploadedPaths = []
  const finalPayload = { ...payload }

  try {
    if (studentPhotoFile) {
      const path = `${schoolId}/students/${targetId}/student-${Date.now()}.${getFileExt(studentPhotoFile)}`
      finalPayload.student_photo_url = await uploadPhoto(client, studentPhotoFile, path)
      uploadedPaths.push(finalPayload.student_photo_url)
    }
    if (representativePhotoFile) {
      const path = `${schoolId}/students/${targetId}/representative-${Date.now()}.${getFileExt(representativePhotoFile)}`
      finalPayload.representative_photo_url = await uploadPhoto(client, representativePhotoFile, path)
      uploadedPaths.push(finalPayload.representative_photo_url)
    }

    const { data, error } = await client.rpc('save_student_record', {
      p_school_id: schoolId,
      p_student_id: targetId,
      p_payload: finalPayload,
    })
    if (error) throw error
    if (
      !data?.success
      || data.student_id !== targetId
      || data.school_id !== schoolId
      || data.course_id !== finalPayload.course_id
    ) {
      throw new Error('El servidor no confirmó el guardado del estudiante.')
    }
    return data
  } catch (error) {
    await cleanupUploadedPhotos(client, uploadedPaths)
    throw error
  }
}
