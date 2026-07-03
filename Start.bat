@echo off
REM Start.bat - prepara el entorno local y levanta el worker de procesamiento (pipeline/).
setlocal
call "%~dp0scripts\check-deps.bat" || goto :eof
call "%~dp0scripts\ensure-env.bat"
call "%~dp0scripts\setup-app.bat"
call "%~dp0scripts\install-pipeline.bat"
call "%~dp0scripts\worker-start.bat"
endlocal
