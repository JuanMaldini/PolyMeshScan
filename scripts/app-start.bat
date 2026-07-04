@echo off
REM app-start.bat - lo que SI se puede hacer desde Windows para el lado "app".
REM IMPORTANTE: Xcode y el Simulador de iOS no corren en Windows (limitacion de Apple).
REM Decision actualizada (ver docs/INFRA.md): se usa SideStore, que se refresca ON-DEVICE.
REM La PC solo hace falta UNA vez, para la instalacion inicial de SideStore en el iPhone.
REM Despues de eso el refresh de 7 dias ocurre solo en el telefono - este script queda
REM practicamente sin trabajo recurrente.
echo [PolyMeshScan] SideStore se refresca on-device; la PC solo participa en la instalacion inicial.
echo [PolyMeshScan] Pasos de instalacion inicial: docs/INFRA.md.
exit /b 0
