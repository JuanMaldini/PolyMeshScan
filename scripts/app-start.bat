@echo off
REM app-start.bat - lo que SI se puede hacer desde Windows para el lado "app".
REM IMPORTANTE: Xcode y el Simulador de iOS no corren en Windows (limitacion de Apple).
REM Este script NO compila ni previsualiza la app real. Lo que hace (cuando este implementado):
REM   1. Arranca AltServer para instalar/refrescar la app en tu iPhone via WiFi,
REM      usando el .ipa que compila GitHub Actions (ver .github/workflows).
REM Requisito: iPhone y esta PC en la misma red WiFi (o tunel, a confirmar).
echo [PolyMeshScan] TODO: integracion con AltServer/SideStore aun no implementada (Fase 0).
echo [PolyMeshScan] Ver docs/PLAN.md seccion 6.
exit /b 0
