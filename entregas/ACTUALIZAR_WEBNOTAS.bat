@echo off
setlocal
title Actualizar WebNotas
set "PROYECTO=D:\PROGRAMACION\PROGRAMAS HECHOS\NUEVOS ARCHIVOS DE ESCRITORIO 14-02-2026\webnotas"
set "RAMA=claude/kind-edison-1zlalz"

echo ============================================
echo   Actualizando WebNotas desde GitHub
echo ============================================
echo.

where git >nul 2>nul || (echo [ERROR] Git no esta instalado. Descargalo de https://git-scm.com & pause & exit /b 1)
where npm >nul 2>nul || (echo [ERROR] Node.js no esta instalado. Descargalo de https://nodejs.org & pause & exit /b 1)
cd /d "%PROYECTO%" || (echo [ERROR] No se encontro la carpeta: %PROYECTO% & pause & exit /b 1)

rem Windows marca la carpeta como "de otro usuario" (dubious ownership); se autoriza una sola vez.
set "SEGURA=%CD:\=/%"
git config --global --get-all safe.directory 2>nul | findstr /x /i /c:"%SEGURA%" >nul || git config --global --add safe.directory "%SEGURA%"
git rev-parse --is-inside-work-tree >nul 2>nul || (echo [ERROR] Git sigue sin poder abrir la carpeta. Copia este mensaje a Claude. & pause & exit /b 1)

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "ANTERIOR=%%b"
echo Rama actual: %ANTERIOR%

echo.
echo [1/4] Guardando tus cambios locales (respaldo)...
set "PENDIENTES="
for /f "delims=" %%l in ('git status --porcelain') do set "PENDIENTES=1"
if defined PENDIENTES (
  git add -A
  git commit -q -m "Respaldo local antes de actualizar" || (echo [ERROR] No se pudo guardar el respaldo. & pause & exit /b 1)
  echo       Cambios guardados en %ANTERIOR%.
) else (
  echo       No habia cambios pendientes.
)

echo.
echo [2/4] Descargando los cambios de GitHub...
git fetch origin || (echo [ERROR] No se pudo conectar con GitHub. & pause & exit /b 1)
git checkout %RAMA% 2>nul || git checkout -b %RAMA% origin/%RAMA% || (echo [ERROR] No se pudo cambiar de rama. & pause & exit /b 1)
git pull --no-edit origin %RAMA% || (echo [ERROR] Fallo la descarga. & pause & exit /b 1)

if /i not "%ANTERIOR%"=="%RAMA%" (
  echo.
  echo [3/4] Uniendo lo que tenias en %ANTERIOR%...
  git merge --no-edit %ANTERIOR% >nul 2>nul && echo       Listo. || (
    git merge --abort
    echo [AVISO] Tus cambios de %ANTERIOR% chocan con los nuevos. No se perdio nada:
    echo         siguen guardados en la rama %ANTERIOR%. Avisale a Claude.
  )
) else (
  echo [3/4] Nada que unir.
)

echo.
echo [4/4] Instalando librerias nuevas (puede tardar unos minutos)...
cd app
call npm install || (echo [ERROR] Fallo npm install. & pause & exit /b 1)

echo.
echo ============================================
echo   LISTO. Tu proyecto esta actualizado.
echo   Tu archivo app\.env.local no se toco.
echo   Para probar:  cd app  y luego  npm run dev
echo ============================================
pause
