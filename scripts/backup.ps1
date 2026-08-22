[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$DatabaseUrl = $env:SUPABASE_DB_URL,
  [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\backups')
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  throw 'Define SUPABASE_DB_URL o usa -DatabaseUrl. No guardes esta credencial en el repositorio.'
}

$pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
if (-not $pgDump) {
  throw 'pg_dump no está instalado o no está disponible en PATH.'
}

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$backupPath = Join-Path $resolvedOutput "webnotas-$timestamp.dump"
$manifestPath = "$backupPath.sha256"

if ($PSCmdlet.ShouldProcess($backupPath, 'Crear respaldo PostgreSQL cifrado en tránsito')) {
  & $pgDump.Source --dbname=$DatabaseUrl --format=custom --no-owner --no-privileges --file=$backupPath
  if ($LASTEXITCODE -ne 0) { throw "pg_dump terminó con código $LASTEXITCODE" }

  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupPath).Hash.ToLowerInvariant()
  Set-Content -LiteralPath $manifestPath -Value "$hash  $([System.IO.Path]::GetFileName($backupPath))" -Encoding utf8NoBOM
  Write-Output $backupPath
  Write-Output $manifestPath
}

