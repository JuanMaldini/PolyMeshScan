@echo off
REM install-pipeline.bat - instala/actualiza dependencias minimas de pipeline/ (ver requirements.txt).
REM COLMAP/Nerfstudio/gsplat no estan aca todavia - se suman mas adelante (Fase 2 avanzada / Fase 4).
setlocal
cd /d "%~dp0.."

pip install -r pipeline\requirements.txt
if errorlevel 1 (
  echo [PolyMeshScan] Fallo pip install. Verifica que Python/pip esten en el PATH.
  exit /b 1
)

echo [PolyMeshScan] Dependencias de pipeline/ instaladas.
endlocal
