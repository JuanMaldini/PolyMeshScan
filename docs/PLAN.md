# PolyMeshScan — Plan de arquitectura

Escáner 3D LiDAR para iPhone con feedback en tiempo real (estilo Polycam), enfocado en **generar
muebles en tiempo real** (paredes/pisos/objetos identificados mientras escaneás), construido 100%
con infraestructura open source y autoalojada.

Este es el documento índice. Detalle técnico en:
- [`CAPTURE.md`](CAPTURE.md) — tiempo real vs PC, requisito de LiDAR, RTAB-Map y RoomPlan.
- [`INFRA.md`](INFRA.md) — build iOS sin Mac, GitHub Actions, dominio/Caddy, redes/Tailscale.
- [`POCKETBASE.md`](POCKETBASE.md) — colecciones `scanner_users`/`scanner_scans`, reglas, auth.

## 1. Objetivo

Reconstruir espacios interiores (cuartos, casas, ambientes) en 3D usando el LiDAR del iPhone, con:

- Feedback en vivo mientras se escanea, con foco en **reconocer muebles y estructura en tiempo
  real** (no solo malla cruda) — ver [`CAPTURE.md`](CAPTURE.md).
- Post-procesado opcional para mejorar calidad/textura después de capturar.
- Todo autoalojado: sin apps de terceros con cuenta/nube propia, sin visores externos, sin pagar
  suscripciones a Apple ni a plataformas de escaneo.

## 2. Restricciones confirmadas

| Restricción | Detalle |
|---|---|
| Caso de uso | Interiores / inmobiliaria / ambientes, con foco en reconocimiento de muebles |
| Prioridad | Tiempo real primero (malla + muebles en vivo); post-procesado es secundario/opcional |
| Hardware disponible | iPhone **con LiDAR confirmado**, PC con GPU dedicada. **No hay Mac.** |
| Presupuesto | Estrictamente gratis — nada de Apple Developer Program ($99/año), nada de SaaS |
| CI/CD | **GitHub Actions**, repo público (runners macOS gratis) |
| Dominio/DNS | Hostinger — subdominio `scanner.vmoliver.cloud` ya creado, apuntando al VPS |
| Auth | PocketBase existente (misma instancia que `HYWorldWeb`) |
| Redes | Tailscale ya en uso (notebook + VPS); confirmado que se suma el iPhone — necesario para el refresh de AltServer, ver `INFRA.md` |
| Infraestructura | VPS propio para procesamiento/visor. Nada de plataformas externas de datos/visualización |
| Perfil técnico | Vos planificás y validás, yo escribo el código (Swift, Python, web) |

## 3. Estructura de carpetas del repo

```
PolyMeshScan/
├── README.md                  # quick start
├── .env.example                # variables minimas, sin secretos reales
├── Start.bat / Stop.bat        # levantan/detienen el worker local de pipeline/
├── StartApp.bat / StopApp.bat  # AltServer (instalar/refrescar la app en el iPhone por WiFi)
├── docs/                       # este plan y los documentos tecnicos (CAPTURE/INFRA/POCKETBASE)
├── app/                        # app iOS (fork/customizacion de RTAB-Map + RoomPlan)
├── pipeline/                   # procesamiento posterior en PC/GPU (tambien fallback sin LiDAR)
├── viewer/                     # visor web self-hosted (Potree / three.js) para el VPS
├── scripts/                    # logica real detras de los .bat de la raiz (root queda simple)
└── .github/workflows/          # CI: build del .ipa en runner macOS gratuito
```

Nota de nombres: los **runners de CI** (`.github/workflows/`, compilan la app) y el **pipeline de
procesamiento** (`pipeline/`, corre en tu propia PC/GPU) son cosas distintas — separadas a
propósito para no mezclar conceptos.

Los `.bat` quedan en la raíz para poder hacerles doble click, pero son cáscaras finas que llaman a
`scripts/`, donde vive la lógica real. `Start.bat`/`Stop.bat` gobiernan el worker de `pipeline/`.
`StartApp.bat`/`StopApp.bat` gobiernan AltServer (instala/refresca la app real en el iPhone — no
reemplaza ni simula Xcode). Todos son placeholders con TODO hasta que avance cada fase.

## 4. Roadmap por fases

1. **Fase 0 — Setup**: ✅ iPhone confirmado con LiDAR; ✅ DNS de `scanner.vmoliver.cloud` apuntando
   al VPS; ✅ colecciones de PocketBase creadas y corregidas; ✅ RTAB-Map registrado como submódulo
   de `app/rtabmap`; ✅ repo público y pusheado. Falta: primer build vía GitHub Actions, instalar en
   el iPhone vía AltStore/SideStore, sumar el iPhone a la tailnet de Tailscale.
2. **Fase 1 — Captura + muebles en tiempo real**: validar malla en vivo de RTAB-Map, y en paralelo
   integrar **RoomPlan** (objetivo central: muebles/paredes en vivo) — subida directa a
   `scanner_scans`. **Esta fase ya es un producto usable por sí sola, sin ninguna PC prendida**: el
   procesamiento real (mesh + reconocimiento de muebles) ocurre 100% en el iPhone; `status` puede
   guardarse directo en `done` acá (ver [`CAPTURE.md`](CAPTURE.md)).
3. **Fase 2 — Pipeline en `pipeline/` (opcional, diferida)**: worker que consume escaneos con
   `status = pending`, post-procesa (RTAB-Map desktop → Open3D → export final, o fotogrametría si
   no hay LiDAR), actualiza `status`/`processed_file`. No hace falta para usar la Fase 1 — recién
   se activa cuando se quiera mejorar calidad de algo ya capturado.
4. **Fase 3 — Visor en `viewer/`**: Potree/three.js en `scanner.vmoliver.cloud`, protegido con
   `forward_auth` de Caddy contra PocketBase.
5. **Fase 4 — Calidad avanzada (opcional)**: Gaussian Splatting/NeRF; cruce RoomPlan + malla densa
   para forma detallada de cada mueble (no solo caja/categoría) — confirmado que arrancamos sin
   esto, se evalúa después.

## 5. Estado actual (checklist)

- [x] Plan de arquitectura y estructura de carpetas
- [x] Decisión: GitHub Actions (no GitLab) para el build de iOS
- [x] Decisión: RTAB-Map como base de captura + RoomPlan para muebles/estructura
- [x] Dominio: `scanner.vmoliver.cloud` creado en Hostinger
- [x] PocketBase: colecciones `scanner_users` y `scanner_scans` creadas, `owner`/`processed_at`
      corregidos
- [x] Confirmado: el iPhone tiene LiDAR
- [x] DNS de `scanner.vmoliver.cloud` apuntando al VPS, confirmado
- [x] RTAB-Map registrado como submódulo en `app/rtabmap` (`.gitmodules` + puntero al commit
      `cb34c4b`); `Start.bat` → `scripts/setup-app.bat` hace `git submodule update --init
      --recursive` para traer el contenido real en cualquier PC nueva
- [x] `pipeline/requirements.txt` definido (Open3D, numpy, pillow, requests) — COLMAP/Nerfstudio
      quedan para más adelante, son instalaciones más pesadas
- [x] Repo en GitHub pasado a **público** (minutos de runner macOS gratis e ilimitados)
- [x] Commit y push de todo lo preparado (submódulo, `.gitmodules`, docs, scripts)
- [ ] Primer build vía GitHub Actions (`.github/workflows/build-ios.yml`, esqueleto en
      [`INFRA.md`](INFRA.md))
- [ ] Instalar AltStore/SideStore y hacer el primer sideload al iPhone
- [ ] Caddy + `Caddyfile` en el VPS (esqueleto en [`INFRA.md`](INFRA.md))
- [ ] Endpoint de `forward_auth` que valida contra PocketBase
- [ ] Sumar el iPhone a la tailnet de Tailscale (decidido, ver sección 7 — necesario porque
      descartaste el cable)

## 6. Alternativas consideradas y descartadas

- **App nativa Swift/ARKit desde cero**: descartada frente a RTAB-Map ya probado en producción.
- **Apps cerradas (Polycam, Scaniverse, 3D Scanner App, Kiri Engine)**: descartadas por no ser open
  source ni autoalojadas.
- **GitLab (CI propio)**: descartado a favor de GitHub Actions por los runners macOS gratuitos.
- **GitLab SaaS runners macOS**: descartado por costo.

## 7. Decisiones resueltas (última ronda)

Nota sobre workflow con Claude: yo no tengo credenciales para hacer `git push` desde este entorno —
edito los archivos locales de tu carpeta, y el commit/push lo hacés vos (como ya veníamos haciendo,
funciona bien). Si en algún momento preferís que actúe directo sobre el repo vía API, se conecta el
conector de GitHub desde la configuración de conectores — no es necesario para seguir avanzando.

- **Tailscale: sí, confirmado.** Descartado el cable, Tailscale deja de ser "opcional" — es la
  única forma gratis de que el refresh de AltServer funcione sin coincidir de red. El motivo real:
  la firma gratuita de Apple expira a los 7 días sí o sí (regla de Apple, no evitable sin pagar), y
  ese refresh necesita que el iPhone y la máquina que corre AltServer se puedan ver en red. Sin
  WiFi compartida y sin cable, la única alternativa gratis es una VPN — y como ya tenés Tailscale
  andando, sumar el iPhone ahí es directamente la opción de menor esfuerzo. (La única otra manera
  de evitar el problema de raíz sería pagar el Apple Developer Program para tener una firma de
  ~1 año en vez de 7 días — descartado por presupuesto.)
- **Alta de `scanner_scans`: confirmado, siempre directo desde la app del iPhone a PocketBase**, sin
  endpoint intermedio. Las reglas de `createRule`/`updateRule` en [`POCKETBASE.md`](POCKETBASE.md)
  ya contemplan esto.
- **Fase 4 (forma detallada de muebles): confirmado, por defecto simple.** Arrancamos con la
  caja/categoría de RoomPlan tal cual, sin cruzarla con la malla densa; el cruce queda para más
  adelante si hace falta, no es parte del camino inicial.

No quedan decisiones abiertas bloqueantes — el plan está cerrado para arrancar Fase 0.
