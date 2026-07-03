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
| Hardware disponible | iPhone (LiDAR a confirmar), PC con GPU dedicada. **No hay Mac.** |
| Presupuesto | Estrictamente gratis — nada de Apple Developer Program ($99/año), nada de SaaS |
| CI/CD | **GitHub Actions**, repo público (runners macOS gratis) |
| Dominio/DNS | Hostinger — subdominio `scanner.vmoliver.cloud` ya creado, apuntando al VPS |
| Auth | PocketBase existente (misma instancia que `HYWorldWeb`) |
| Redes | Tailscale ya en uso (notebook + VPS) — opcional, ver `INFRA.md` |
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

1. **Fase 0 — Setup**: confirmar si el iPhone tiene LiDAR; clonar RTAB-Map en `app/`; primer build
   vía GitHub Actions; instalar en el iPhone vía AltStore/SideStore; ✅ colecciones de PocketBase
   creadas; ✅ DNS de `scanner.vmoliver.cloud` creado (falta verificar que apunte al VPS).
2. **Fase 1 — Captura + muebles en tiempo real**: validar malla en vivo de RTAB-Map, y en paralelo
   integrar **RoomPlan** (objetivo central: muebles/paredes en vivo) — subida directa a
   `scanner_scans` con `status = pending`.
3. **Fase 2 — Pipeline en `pipeline/`**: worker que consume `status = pending`, post-procesa
   (RTAB-Map desktop → Open3D → export final, o fotogrametría si no hay LiDAR), actualiza
   `status`/`processed_file`.
4. **Fase 3 — Visor en `viewer/`**: Potree/three.js en `scanner.vmoliver.cloud`, protegido con
   `forward_auth` de Caddy contra PocketBase.
5. **Fase 4 — Calidad avanzada (opcional)**: Gaussian Splatting/NeRF; cruce RoomPlan + malla densa
   para forma detallada de cada mueble (no solo caja/categoría).

## 5. Estado actual (checklist)

- [x] Plan de arquitectura y estructura de carpetas
- [x] Decisión: GitHub Actions (no GitLab) para el build de iOS
- [x] Decisión: RTAB-Map como base de captura + RoomPlan para muebles/estructura
- [x] Dominio: `scanner.vmoliver.cloud` creado en Hostinger
- [x] PocketBase: colecciones `scanner_users` y `scanner_scans` creadas (2 ajustes pendientes, ver
      [`POCKETBASE.md`](POCKETBASE.md): `owner` debería ser relation Single no Multiple,
      `processed_at` debería ser tipo Date no texto)
- [ ] Confirmar modelo de iPhone (¿tiene LiDAR?)
- [ ] Verificar que el DNS de `scanner.vmoliver.cloud` apunte a la IP del VPS (no al hosting de
      Hostinger)
- [ ] Repo en GitHub creado (público) para minutos gratis de runner macOS
- [ ] Clonar RTAB-Map en `app/` y correr el primer build (`.github/workflows/build-ios.yml`)
- [ ] Instalar AltStore/SideStore y hacer el primer sideload al iPhone
- [ ] Caddy + `Caddyfile` en el VPS (esqueleto en [`INFRA.md`](INFRA.md))
- [ ] Endpoint de `forward_auth` que valida contra PocketBase
- [ ] Definir dependencias reales de `pipeline/` (Python + Open3D/COLMAP/Nerfstudio)
- [ ] Decidir si sumar el iPhone a la tailnet de Tailscale (opcional, para refresh de AltServer)

## 6. Alternativas consideradas y descartadas

- **App nativa Swift/ARKit desde cero**: descartada frente a RTAB-Map ya probado en producción.
- **Apps cerradas (Polycam, Scaniverse, 3D Scanner App, Kiri Engine)**: descartadas por no ser open
  source ni autoalojadas.
- **GitLab (CI propio)**: descartado a favor de GitHub Actions por los runners macOS gratuitos.
- **GitLab SaaS runners macOS**: descartado por costo.

## 7. Próximas decisiones abiertas

- ¿Confirmás el modelo de tu iPhone (¿tiene LiDAR)? Define si arrancamos por malla en vivo/RoomPlan
  o directo por fotogrametría en `pipeline/`.
- ¿Repo público en GitHub confirmado?
- ¿Sumamos el iPhone al tailnet de Tailscale, o preferís reinstalar por cable cuando haga falta?
- ¿El alta de `scanner_scans` la hace la app del iPhone directo contra PocketBase, o preferís un
  endpoint intermedio?
- Para Fase 4 (forma detallada de muebles): ¿alcanza con la caja/categoría de RoomPlan al
  principio, o el cruce con malla densa es prioritario desde ya?
- ¿Arreglamos ya los dos ajustes de `scanner_scans` (`owner` Single, `processed_at` Date) o los
  dejamos para cuando empecemos a escribir el worker?
