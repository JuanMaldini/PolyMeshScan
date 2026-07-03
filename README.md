# PolyMeshScan

Escáner 3D LiDAR para iPhone, tiempo real, 100% open source y autoalojado. Objetivo central:
reconocer muebles y estructura (paredes/pisos) en vivo mientras escaneás.

Documentación:
- [`docs/PLAN.md`](docs/PLAN.md) — plan de arquitectura, roadmap, estado actual
- [`docs/CAPTURE.md`](docs/CAPTURE.md) — RTAB-Map / RoomPlan, requisito de LiDAR
- [`docs/INFRA.md`](docs/INFRA.md) — build iOS sin Mac, GitHub Actions, dominio/Caddy, redes
- [`docs/POCKETBASE.md`](docs/POCKETBASE.md) — colecciones, reglas, auth

## Estructura

- `docs/` — plan y decisiones
- `app/` — app iOS (RTAB-Map + eventualmente RoomPlan)
- `pipeline/` — procesamiento posterior en PC/GPU (también fallback sin LiDAR)
- `viewer/` — visor web self-hosted (Potree/three.js) para tu VPS
- `scripts/` — lógica real de los `.bat` de abajo
- `.github/workflows/` — build del `.ipa` en runner macOS gratuito de GitHub Actions

## Uso rápido (Windows)

| Script | Qué hace |
|---|---|
| `Start.bat` | Verifica dependencias, crea `.env`, instala/actualiza `pipeline/`, levanta el worker local |
| `Stop.bat` | Detiene el worker local |
| `StartApp.bat` | Arranca AltServer (instala/refresca la app en tu iPhone por WiFi, sin Mac) |
| `StopApp.bat` | Detiene AltServer |

Todo marcado como TODO en `scripts/` hasta que avancemos de fase (ver roadmap en `docs/PLAN.md`).
