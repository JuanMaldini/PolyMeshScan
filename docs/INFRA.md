# Infraestructura: build, dominio, CI y redes

Ver [`PLAN.md`](PLAN.md) para la visión general. Este documento junta todo lo operativo: compilar
la app, servir el dominio, y las redes entre iPhone/PC/VPS.

## El obstáculo técnico real: compilar para iOS requiere macOS

No importa qué CI se use: **Xcode solo corre en macOS**, y por licencia de Apple no se puede
virtualizar macOS en un VPS Linux genérico. Con **GitHub Actions** (decidido, sobre GitLab porque
sus runners macOS son pagos):

- Runner macOS gratuito de GitHub (repo público) compila el `.ipa`. Paso de build transitorio — no
  pasa ningún dato de escaneo por ahí, solo código fuente.
- Esqueleto de workflow (`.github/workflows/build-ios.yml`), a completar en Fase 0:

  ```yaml
  name: Build iOS app
  on: [push, workflow_dispatch]
  jobs:
    build:
      runs-on: macos-latest
      steps:
        - uses: actions/checkout@v4
        - name: Install deps
          run: ./app/ios/RTABMapApp/Libraries/install_deps.sh
        - name: Build
          run: xcodebuild -project app/ios/RTABMapApp.xcodeproj -scheme RTABMapApp -sdk iphoneos archive -archivePath build/App.xcarchive
        - name: Export unsigned .ipa (o firmado si hay certificado)
          run: echo "TODO: exportOptions.plist + xcodebuild -exportArchive"
        - uses: actions/upload-artifact@v4
          with:
            name: app-ipa
            path: build/*.ipa
  ```

- **Previsualizar la UI "en tu desktop" tiene un límite real:** un runner de GitHub Actions es
  headless — no da una ventana en vivo para tocar la app desde Windows/Linux. Lo que sí se puede
  automatizar: correr la app en el **Simulador de iOS** (disponible en el runner macOS) y generar
  **screenshots/video como artifact** del build, descargable y visible en tu desktop — sirve para
  pantallas de UI que no dependen de sensores reales. El Simulador **no puede** simular cámara/LiDAR
  real (no existe ese hardware en Simulador) — la malla en vivo y RoomPlan solo se validan en el
  iPhone físico. Limitación de Apple, no nuestra.
- Instalación sin pagar Apple: firma gratuita por Apple ID, expira cada 7 días. **AltStore /
  SideStore** (open source, gratis) la re-firman/reinstalan de forma inalámbrica desde una PC
  Windows, sin necesitar Mac/Xcode en el día a día — Mac solo hace falta en el build de GitHub
  Actions. *Nota: el ecosistema AltStore/SideStore cambia rápido de versión a versión — conviene
  revisar la documentación oficial actualizada recién al llegar a Fase 0, en vez de asumir pasos
  exactos ahora.*
- **Environments/secrets:** mínimos a propósito. `.env.example` documenta variables sin secretos
  reales; probablemente no hace falta ningún secret de GitHub Actions para el build en sí (no
  firmamos con certificado pago).

## Dominio, HTTPS y auth

Confirmado: dominio gestionado en **Hostinger**, subdominio `scanner.vmoliver.cloud` ya creado.

- **Verificar** que el registro DNS de `scanner.vmoliver.cloud` sea un registro **A/AAAA apuntando
  a la IP de tu VPS** (no al hosting compartido de Hostinger) — Hostinger vende dominio y hosting
  por separado, y hay que asegurarse de que el subdominio resuelva a tu propio servidor.
- **Caddy** (reverse proxy open source) en el VPS obtiene el certificado Let's Encrypt solo con
  tener el DNS bien apuntado. Esqueleto de `Caddyfile`:

  ```
  scanner.vmoliver.cloud {
      # Viewer protegido: valida sesion de PocketBase antes de servir archivos
      handle /* {
          forward_auth localhost:8091 {
              uri /check
              copy_headers Remote-User Remote-Role
          }
          root * /srv/viewer
          file_server
      }

      # PocketBase (API + admin) en su propio path o subdominio, segun prefieras
      handle /pb/* {
          reverse_proxy localhost:8090
      }
  }
  ```

  El endpoint `forward_auth` (`localhost:8091/check`) es un chico servicio propio (o un plugin de
  Caddy) que valida el token/cookie de PocketBase — se define en detalle en
  [`POCKETBASE.md`](POCKETBASE.md).

## Redes: Tailscale (confirmado, ya lo usás)

Ya está en tu notebook + VPS. Dos problemas distintos, uno de los cuales sí lo necesita:

1. **Subir escaneos del iPhone al pipeline/PocketBase**: no necesita Tailscale — el teléfono habla
   directo por HTTPS contra `scanner.vmoliver.cloud` (dominio público + auth), en WiFi o datos
   móviles. Ninguno de los dos casos de tu flujo (procesar en el celular, o procesar después cuando
   prendas el worker) depende de estar en la misma red.
2. **Refrescar la firma de la app cada 7 días (AltServer/SideStore)**: la firma gratuita de Apple
   expira a los 7 días sí o sí (regla de Apple, no evitable sin pagar el Developer Program), y ese
   refresh necesita que el iPhone y la máquina que corre AltServer se puedan ver en red. Descartado
   el cable, **sumar el iPhone a tu tailnet existente** es la única forma gratis de que esto
   funcione sin depender de coincidir en WiFi física — confirmado, se hace.

Pendiente en el checklist: agregar el iPhone a la tailnet (la app oficial de Tailscale para iOS).
Todo lo demás (subir escaneos, procesar, ver el visor) funciona igual sin él.
