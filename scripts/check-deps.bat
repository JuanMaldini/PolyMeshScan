@echo off
REM check-deps.bat - verifica herramientas base antes de instalar/arrancar nada.
REM TODO: sumar chequeos especificos cuando se defina el runtime del pipeline (Python/Node).

where git >nul 2>nul
if errorlevel 1 (
  echo [PolyMeshScan] Falta git. Instalalo desde https://git-scm.com/download/win
  exit /b 1
)

where python >nul 2>nul
if errorlevel 1 (
  echo [PolyMeshScan] Falta Python. Instalalo desde https://www.python.org/downloads/
  exit /b 1
)

echo [PolyMeshScan] Dependencias base OK.
exit /b 0
