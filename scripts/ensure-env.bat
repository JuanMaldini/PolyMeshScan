@echo off
REM ensure-env.bat - crea .env a partir de .env.example si todavia no existe.
set ROOT=%~dp0..

if exist "%ROOT%\.env" (
  echo [PolyMeshScan] .env ya existe, no se toca.
  exit /b 0
)

if not exist "%ROOT%\.env.example" (
  echo [PolyMeshScan] No hay .env.example en el root todavia.
  exit /b 1
)

copy "%ROOT%\.env.example" "%ROOT%\.env" >nul
echo [PolyMeshScan] Creado .env desde .env.example. Revisalo y completa los valores que falten.
exit /b 0
