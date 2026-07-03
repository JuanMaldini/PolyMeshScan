@echo off
REM setup-app.bat - clona/actualiza RTAB-Map como submodulo de app/rtabmap.
REM Ya esta registrado en el repo (.gitmodules + puntero al commit) - este script
REM solo hace el fetch real del contenido, la primera vez que se corre en una PC nueva.
setlocal
cd /d "%~dp0.."

git submodule update --init --recursive
if errorlevel 1 (
  echo [PolyMeshScan] Fallo el submodule update. Verifica que git este instalado y que haya red.
  exit /b 1
)

echo [PolyMeshScan] RTAB-Map listo en app\rtabmap.
endlocal
