export type DeleteTenantUserAuthorization = {
  isPlatformAdmin: boolean
  requestedSchoolId: string | null | undefined
  targetUserSchoolId: string | null | undefined
}

export function canDeleteTenantUser({
  isPlatformAdmin,
  requestedSchoolId,
  targetUserSchoolId,
}: DeleteTenantUserAuthorization): boolean {
  if (isPlatformAdmin) return true
  return Boolean(
    requestedSchoolId
    && targetUserSchoolId
    && requestedSchoolId === targetUserSchoolId,
  )
}
