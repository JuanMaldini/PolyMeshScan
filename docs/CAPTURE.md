# Captura: tiempo real, LiDAR y los dos modos (RTAB-Map / RoomPlan)

Detalle técnico de cómo funciona la captura en el iPhone. Ver [`PLAN.md`](PLAN.md) para la visión
general y el roadmap.

## Qué corre en tiempo real y qué corre en la PC

- **El tiempo real pasa 100% en el iPhone.** La malla en vivo, el tracking, el SLAM/loop closure de
  RTAB-Map, y la detección de RoomPlan — todo corre on-device (Neural Engine + GPU del propio
  iPhone), sin red, sin PC, sin servidor.
- **La PC (`pipeline/`) solo entra si elegís post-procesar** un escaneo ya terminado: mejorar
  calidad (mesh más denso, texturizado, Gaussian Splatting/NeRF), o reconstruir desde fotogrametría
  cuando no hay LiDAR. Nunca es tiempo real — corre offline, cuando vos quieras, sobre un archivo ya
  exportado del teléfono.

**Modelo de cola (confirmado):** un escaneo capturado queda en PocketBase con `status = pending` de
inmediato. El worker de `pipeline/` no necesita estar prendido para que captures — lo prendés vos
cuando quieras (`Start.bat`), toma los `pending`, los procesa uno por uno, y actualiza `status` a
`processing` → `done`/`error`. Es una cola de trabajo asíncrona clásica; el tiempo real ya quedó
resuelto en el teléfono, esto es solo para el paso opcional/pesado.

## Requisito de hardware: LiDAR

El feedback en tiempo real de malla densa (`ARWorldTrackingConfiguration.sceneReconstruction =
.mesh`) y RoomPlan **necesitan LiDAR físico** — limitación de sensor, no de software.

Tienen LiDAR: iPhone 12 Pro/Pro Max en adelante — **solo modelos "Pro"/"Pro Max"** (13 Pro, 14 Pro,
15 Pro, 16 Pro, etc.), y iPad Pro 2020+. Los iPhone "normales" (no Pro) no tienen LiDAR, sin
excepción. **Pendiente:** confirmar el modelo exacto (Ajustes → General → Información).

**Sin LiDAR**, no hay reconstrucción en vivo posible. El camino pasa a ser 100% responsabilidad de
`pipeline/`:

1. Grabar video/fotos con la cámara normal (ARKit igual da tracking de posición de cámara en vivo,
   sin malla densa).
2. Procesar después en la PC con fotogrametría clásica (COLMAP) o Gaussian Splatting/NeRF
   (Nerfstudio/gsplat).
3. Sin feedback instantáneo del modelo final — se ve cuando termina de procesar.

## Modo A — Malla cruda densa (RTAB-Map)

[RTAB-Map](https://github.com/introlab/rtabmap) (BSD) usa `ARMeshAnchor` de ARKit: reconstruye
*todo* como triángulos (paredes, muebles, objetos) sin entender qué es cada cosa. Puntos técnicos
relevantes para el plan:

- Hace **SLAM con cierre de loop** (bag-of-words sobre features visuales) — corrige el drift de
  posición cuando volvés a pasar por un lugar ya escaneado, algo que el `ARMeshAnchor` crudo de
  Apple no hace solo.
- Guarda una **base de datos propia (`.db`, SQLite)** por sesión con el grafo de poses, keyframes e
  imágenes — no solo el mesh final. Esto es valioso para `pipeline/`: si subís el `.db` completo (no
  solo un `.ply`/`.obj` ya exportado), el post-procesado en la PC puede re-optimizar el grafo, correr
  detección de loop closure más pesada, o generar meshing/texturizado de mayor calidad — cosas que
  no se pueden hacer solo a partir del mesh ya "aplanado". Recomendado: que `raw_file` en
  `scanner_scans` guarde el `.db` cuando `capture_mode = raw_mesh`.
- Exporta a PLY / OBJ / LAS, con parámetros ajustables (decimación de malla, resolución de textura).
- Es la base de `app/` en vez de escribir el capturador ARKit desde cero.

Referencia alternativa si hace falta comparar enfoques: [StrayScanner](https://github.com/strayrobots/scanner)
(open source, RGB-D+pose crudo, sin malla en vivo, pensado para reprocesar offline).

## Modo B — RoomPlan (estructura + muebles, el objetivo central)

**RoomPlan** es un framework de Apple (iOS 16+, requiere LiDAR) que corre un modelo de ML on-device
para detectar, en vivo:

- Elementos arquitectónicos: paredes, pisos, techos, puertas, ventanas, aberturas — como geometría
  limpia y parametrizada (planos, no triángulos sueltos).
- **Muebles**: sofá, mesa, silla, cama, heladera, horno, lavarropas, inodoro, bañera, TV, chimenea,
  escalera, almacenamiento, etc. — como volúmenes/cajas con categoría, posición y tamaño.
- Un mini-mapa/plano cenital en vivo que se actualiza mientras caminás — el `CapturedRoom` de
  RoomPlan trae justamente esta info estructurada, y Apple ya incluye la UI de captura con guías
  ("acercate", "andá más despacio") lista para usar, sin que tengamos que programarla desde cero.
- Exporta a USDZ con la estructura paramétrica.

**Confirmado: esto es lo que responde a tu objetivo central** (generar muebles en tiempo real), no
algo que haya que inventar. Dos matices para no generar expectativas de más:

1. **Catálogo cerrado** de categorías de muebles (~15-20 tipos comunes) — no cualquier objeto
   arbitrario, y no aprende muebles nuevos por tu cuenta.
2. Devuelve una **caja/volumen simplificado** (posición, tamaño, categoría) por mueble, no la forma
   exacta y detallada de tu sofá específico.
3. RoomPlan captura **una habitación por sesión**; unir varios ambientes en una sola estructura
   (multi-room) es una capacidad de versiones más nuevas del framework — a confirmar el
   comportamiento exacto disponible cuando lleguemos a esa fase, dado que Apple ajusta esto entre
   versiones de iOS.

Ambos modos son complementarios: RTAB-Map da el detalle denso general, RoomPlan da estructura +
semántica de muebles en vivo. RoomPlan es código Swift propio que se agrega a la app (mismo costo:
cero; misma restricción de build que el resto, ver [`INFRA.md`](INFRA.md)).

## Fase 4 — forma detallada de cada mueble (cruce RoomPlan + malla densa)

Si además de "hay un sofá acá" se quiere la forma real de ese sofá específico: cruzar la caja de
RoomPlan (dónde está, qué categoría es) con la malla densa de RTAB-Map (recortar la geometría real
dentro de esa caja). No viene resuelto de fábrica — es ingeniería propia que armamos nosotros más
adelante, pero sigue siendo 100% on-device y gratis (sin servicios de IA externos de por medio).
