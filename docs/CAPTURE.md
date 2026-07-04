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

**¿Necesitás un runner/worker corriendo en la PC para que esto funcione? No, para lo que vas a usar
ahora — no.** Como tu iPhone tiene LiDAR y el objetivo central (RoomPlan: paredes + muebles en
tiempo real) se resuelve entero on-device, el flujo del día a día es: escaneás → la app exporta el
resultado (ya "terminado", no crudo) → lo sube directo a `scanner_scans` → listo, sin que ninguna PC
tenga que estar prendida ni conectada. El worker de `pipeline/` (y por lo tanto `Start.bat`
corriendo en tu PC) recién hace falta cuando decidas usar Fase 2/4 — mejorar calidad con Open3D,
o el cruce RoomPlan + malla densa para forma detallada de muebles — que ya definimos como algo
para más adelante, no parte del camino inicial. Hasta entonces, `scanner_scans.status` puede
guardarse directamente en `done` en vez de `pending` (no hay nada pendiente de procesar), y
`processed_file` puede quedar vacío o ser el mismo archivo que `raw_file` hasta que exista un
pipeline real que lo mejore.

## Requisito de hardware: LiDAR

El feedback en tiempo real de malla densa (`ARWorldTrackingConfiguration.sceneReconstruction =
.mesh`) y RoomPlan **necesitan LiDAR físico** — limitación de sensor, no de software.

Tienen LiDAR: iPhone 12 Pro/Pro Max en adelante — **solo modelos "Pro"/"Pro Max"** (13 Pro, 14 Pro,
15 Pro, 16 Pro, etc.), y iPad Pro 2020+. Los iPhone "normales" (no Pro) no tienen LiDAR, sin
excepción. **Confirmado: el iPhone de Juan tiene LiDAR** — el camino real (más abajo) es el que
aplica; la sección de "sin LiDAR" queda solo como referencia si en el futuro se agrega otro
dispositivo sin el sensor.

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

## Referencias visuales por tipo de producto/salida

| Producto | Fase | Referencia |
|---|---|---|
| RoomPlan — estructura + muebles en vivo | Fase 1 (núcleo) | [Overview oficial de Apple](https://developer.apple.com/augmented-reality/roomplan/), [WWDC22 — Create parametric 3D room scans](https://developer.apple.com/videos/play/wwdc2022/10127/), [WWDC23 — mejoras](https://developer.apple.com/videos/play/wwdc2023/10192/) |
| Malla cruda densa (RTAB-Map) | Fase 1 (alternativo/complementario) | [Video demo en YouTube](https://www.youtube.com/watch?v=rVpIcrgD5c0), [página del proyecto](http://introlab.github.io/rtabmap/), [App Store](https://apps.apple.com/us/app/rtab-map-3d-lidar-scanner/id1564774365) (para ver capturas, aunque nuestra app sea el fork propio) |
| Visor self-hosted de point clouds | Fase 3 | [Demo en vivo de Potree](https://potree.org/potree/examples/viewer.html) |
| Gaussian Splatting (calidad avanzada) | Fase 4 (opcional) | [Nerfstudio — método Splatfacto](https://docs.nerf.studio/nerfology/methods/splat.html), [gsplat en GitHub](https://github.com/nerfstudio-project/gsplat) |

Notar que ninguno de estos links es "el producto final" — son referencias de la técnica/tecnología
detrás de cada fase, para tener una idea visual de qué tipo de resultado esperar en cada una.
