# pipeline/

Procesamiento posterior en PC/GPU (no tiempo real). Dos roles:

1. Mejorar calidad de un escaneo LiDAR ya capturado (RTAB-Map desktop → Open3D → export final).
2. Único camino de reconstrucción si el dispositivo no tiene LiDAR (fotogrametría/COLMAP,
   Gaussian Splatting con Nerfstudio/gsplat).

Ver [`../docs/CAPTURE.md`](../docs/CAPTURE.md) (tiempo real vs PC) y [`../docs/PLAN.md`](../docs/PLAN.md)
sección 4 (roadmap). Todavía sin código — pendiente Fase 2, y es opcional/diferida: la Fase 1
(captura con RTAB-Map/RoomPlan) ya funciona sin que este worker exista o corra.
