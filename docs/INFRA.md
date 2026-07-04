# Infraestructura: build, dominio, CI y redes

Ver [`PLAN.md`](PLAN.md) para la visión general. Este documento junta todo lo operativo: compilar
la app, servir el dominio, y las redes entre iPhone/PC/VPS.

## El obstáculo técnico real: compilar para iOS requiere macOS

No importa qué CI se use: **Xcode solo corre en macOS**, y por licencia de Apple no se puede
virtualizar macOS en un VPS Linux genérico. Con **GitHub Actions** (decidido, sobre GitLab porque
sus runners macOS son pagos):

- Runner macOS gratuito de GitHub (repo público) compila el `.ipa`. Paso de build transitorio — no
  pasa ningún dato de escaneo por ahí, solo código fuente.
- Workflow real: [`.github/workflows/build-ios.yml`](../.github/workflows/build-ios.yml). Como la
  app es SwiftUI pura (sin las dependencias C++ de RTAB-Map — ver decisión en
  [`app/README.md`](../app/README.md)), el build tarda minutos, no horas, y no necesita cache ni
  submódulos. Usa **XcodeGen** para generar el `.xcodeproj` desde `app/project.yml` (así no se
  versiona un proyecto de Xcode que no podemos editar sin Mac), compila **sin firma**
  (`CODE_SIGNING_ALLOWED=NO`) y empaqueta el `.app` en un `.ipa` sin firmar como artifact —
  SideStore lo firma al instalarlo. Triggers acotados: `workflow_dispatch` manual + push que
  toque `app/**` (cambios de docs no gastan runner).

- **Previsualizar la UI "en tu desktop" tiene un límite real:** un runner de GitHub Actions es
  headless — no da una ventana en vivo para tocar la app desde Windows/Linux. Lo que sí se puede
  automatizar: correr la app en el **Simulador de iOS** (disponible en el runner macOS) y generar
  **screenshots/video como artifact** del build, descargable y visible en tu desktop — sirve para
  pantallas de UI que no dependen de sensores reales. El Simulador **no puede** simular cámara/LiDAR
  real (no existe ese hardware en Simulador) — la malla en vivo y RoomPlan solo se validan en el
  iPhone físico. Limitación de Apple, no nuestra.
- Instalación sin pagar Apple: firma gratuita por Apple ID, expira cada 7 días. **Decidido:
  SideStore** (open source, gratis) en vez de AltStore. Diferencia clave: AltStore necesita que
  AltServer (en la PC) "vea" el iPhone en red para cada refresh, y ese descubrimiento usa
  Bonjour/mDNS — que **Tailscale no propaga por defecto**, o sea que la tailnet no garantizaba el
  refresh. SideStore en cambio se **refresca on-device** (usa una VPN loopback local + un pairing
  file generado una única vez desde la PC): después de la instalación inicial, el teléfono se
  renueva solo, sin PC prendida y sin red compartida. La PC con Windows solo hace falta la primera
  vez (instalar SideStore con AltServer/Jitterbug y generar el pairing file). *Nota: el ecosistema
  cambia rápido — revisar la doc oficial de SideStore al llegar a ese paso.* Límites de la firma
  gratuita a tener presentes: máx. 3 apps sideloaded activas y 10 App IDs por semana por Apple ID
  (SideStore mismo cuenta como una app).
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

  El endpoint `forward_auth` (`localhost:8091/check`) valida el token/cookie de PocketBase.
  **Decidido: implementarlo como ruta custom dentro del mismo PocketBase** usando `pb_hooks`
  (JavaScript embebido en PocketBase, sin proceso extra en el VPS) en vez de un servicio aparte —
  ver [`POCKETBASE.md`](POCKETBASE.md). En ese caso el `forward_auth` del Caddyfile apunta a
  `localhost:8090` (el propio PocketBase).

## Redes: Tailscale (confirmado, ya lo usás)

Ya está en tu notebook + VPS. Dos problemas distintos, uno de los cuales sí lo necesita:

1. **Subir escaneos del iPhone al pipeline/PocketBase**: no necesita Tailscale — el teléfono habla
   directo por HTTPS contra `scanner.vmoliver.cloud` (dominio público + auth), en WiFi o datos
   móviles. Ninguno de los dos casos de tu flujo (procesar en el celular, o procesar después cuando
   prendas el worker) depende de estar en la misma red.
2. **Refrescar la firma de la app cada 7 días**: la firma gratuita de Apple expira a los 7 días sí
   o sí (regla de Apple, no evitable sin pagar el Developer Program). Con la decisión de usar
   **SideStore** (refresh on-device, ver arriba), este problema **ya no depende de la red**: ni
   Tailscale ni WiFi compartida son necesarios para el refresh — solo para la instalación inicial
   hace falta la PC. Tener el iPhone en la tailnet (ya hecho) igual suma: acceso a servicios
   internos y respaldo si algún paso de SideStore requiere ver la PC.
