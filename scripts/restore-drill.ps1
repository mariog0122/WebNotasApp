[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)] [string]$BackupPath,
  [string]$RestoreDatabaseUrl = $env:RESTORE_DATABASE_URL,
  [switch]$AcknowledgeNonProductionTarget
)

$ErrorActionPreference = 'Stop'
$resolvedBackup = [System.IO.Path]::GetFullPath($BackupPath)

if (-not (Test-Path -LiteralPath $resolvedBackup -PathType Leaf)) {
  throw "No existe el respaldo: $resolvedBackup"
}
if ([string]::IsNullOrWhiteSpace($RestoreDatabaseUrl)) {
  throw 'Define RESTORE_DATABASE_URL con una base temporal, nunca producción.'
}
if (-not $AcknowledgeNonProductionTarget) {
  throw 'Repite con -AcknowledgeNonProductionTarget después de verificar que el destino es temporal y desechable.'
}

$pgRestore = Get-Command pg_restore -ErrorAction SilentlyContinue
if (-not $pgRestore) { throw 'pg_restore no está instalado o no está disponible en PATH.' }

$manifestPath = "$resolvedBackup.sha256"
if (Test-Path -LiteralPath $manifestPath) {
  $expected = ((Get-Content -LiteralPath $manifestPath -Raw).Trim() -split '\s+')[0]
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedBackup).Hash.ToLowerInvariant()
  if ($actual -ne $expected) { throw 'El checksum SHA256 del respaldo no coincide.' }
}

if ($PSCmdlet.ShouldProcess('BASE TEMPORAL CONFIRMADA', 'Restaurar y validar respaldo')) {
  & $pgRestore.Source --dbname=$RestoreDatabaseUrl --clean --if-exists --no-owner --no-privileges $resolvedBackup
  if ($LASTEXITCODE -ne 0) { throw "pg_restore terminó con código $LASTEXITCODE" }

  $psql = Get-Command psql -ErrorAction SilentlyContinue
  if (-not $psql) { throw 'psql no está instalado; la restauración terminó pero falta validación.' }
  & $psql.Source $RestoreDatabaseUrl --set=ON_ERROR_STOP=1 --command="select count(*) as schools from public.schools; select count(*) as students from public.students; select count(*) as grades from public.grades;"
  if ($LASTEXITCODE -ne 0) { throw "La validación psql terminó con código $LASTEXITCODE" }
}

