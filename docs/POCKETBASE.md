# PocketBase: colecciones y auth

Reusa la instancia existente (misma URL que `HYWorldWeb`), con dos colecciones nuevas y aisladas.
Ver [`PLAN.md`](PLAN.md) para el contexto general.

## `scanner_users` (tipo Auth)

Ya creada, tal como está en el screenshot — coincide con lo planeado:

| Campo | Tipo | Notas |
|---|---|---|
| `id`, `password`, `tokenKey`, `email`, `emailVisibility`, `verified` | — | de fábrica, colección Auth |
| `name` | text | nombre para mostrar, opcional |
| `role` | select (`admin`, `viewer`) | `admin` por defecto (sos vos); deja la puerta abierta a compartir acceso de solo lectura después |
| `created`, `updated` | date | automáticos |

Reglas: dejar `listRule`/`viewRule` en blanco o `id = @request.auth.id` (cada usuario solo se ve a
sí mismo). Esta colección es la que valida el `forward_auth` de Caddy antes de servir `viewer/`.

## `scanner_scans` (tipo Base)

Nombre real que usaste (no `scans` a secas) — actualizado en toda la documentación para que
coincida con lo que ya está creado. Ya con los dos ajustes hechos (`owner` Single, `processed_at`
Date).

| Campo | Tipo | Notas |
|---|---|---|
| `name` | text (requerido) | ej. "Living room — 2026-07-08" |
| `owner` | relation → `scanner_users` (Single) | quién lo capturó |
| `capture_mode` | select (`raw_mesh`, `roomplan`, `photogrammetry`) | qué técnica se usó — ver [`CAPTURE.md`](CAPTURE.md) |
| `status` | select (`pending`, `processing`, `done`, `error`) | campo clave de la cola async — en la práctica hoy la app escribe `done` directo al crear (ver nota abajo y [`CAPTURE.md`](CAPTURE.md)); `pending` recién se usa cuando exista el worker de `pipeline/` (Fase 2) |
| `raw_file` | file (single) | export crudo del iPhone — para `raw_mesh` idealmente el `.db` de RTAB-Map, no solo un `.ply` ya aplanado (ver `CAPTURE.md`) |
| `processed_file` | file (single) | resultado del pipeline; hasta que exista el worker (Fase 2), puede quedar vacío o ser el mismo archivo que `raw_file` |
| `thumbnail` | file (single) | miniatura para el dashboard |
| `furniture_json` | json | si `capture_mode = roomplan`: categorías + posición de muebles detectados |
| `processed_at` | date | cuándo terminó el worker (no aplica todavía, Fase 2) |
| `error_log` | text | si `status = error` |
| `notes` | text | libre |
| `created`, `updated` | date | automáticos, no hace falta definirlos |

Reglas sugeridas:
- `listRule` / `viewRule`: `owner = @request.auth.id`
- `createRule`: `@request.auth.id != ""` (para que la app del iPhone suba directo, autenticada
  contra PocketBase, sin pasar por otro backend)
- `updateRule`: dejarla para el worker de `pipeline/` (que actualiza `status`/`processed_file`) —
  usar una cuenta de servicio (un `scanner_users` con `role = admin` dedicado al worker) en vez de
  reusar tu propio usuario, para poder revocar ese acceso por separado si hace falta.

## Integración con Caddy (`forward_auth`)

El endpoint que Caddy llama (`localhost:8091/check` en el `Caddyfile` de [`INFRA.md`](INFRA.md)) es
un servicio chico (a implementar en Fase 3) que:

1. Lee la cookie/token de sesión de PocketBase de la request.
2. La valida contra la API de PocketBase (`/api/collections/scanner_users/auth-refresh` o
   equivalente).
3. Devuelve 200 si es válida (Caddy sirve `viewer/`), o 401 si no (Caddy corta antes de tocar los
   archivos).

Esto protege los archivos en el servidor, no solo la pantalla de login del frontend — un login solo
del lado del cliente no alcanza para archivos estáticos servidos directo.
