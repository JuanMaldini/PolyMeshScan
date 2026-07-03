# app/

App iOS de captura en tiempo real. Punto de partida: fork/customización de
[RTAB-Map](https://github.com/introlab/rtabmap), no un capturador ARKit desde cero. Ver
`../docs/CAPTURE.md` para el porqué y las dos técnicas de captura consideradas (malla densa vs
RoomPlan).

`rtabmap/` es un **git submodule** (ver `../.gitmodules`) apuntando a `introlab/rtabmap`. No hace
falta clonarlo a mano: `Start.bat` corre `scripts/setup-app.bat`, que hace
`git submodule update --init --recursive` y trae el contenido real la primera vez que se ejecuta en
una PC nueva. El código de la app en sí vive en `rtabmap/app/ios/RTABMapApp` una vez inicializado.

Si más adelante querés customizar el código y versionarlo en tu propio GitHub, la forma prolija es
forkear `introlab/rtabmap` a tu cuenta y cambiar la URL en `.gitmodules` — no es necesario para
arrancar.

