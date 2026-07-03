# pipeline/

Procesamiento posterior en PC/GPU (no tiempo real). Dos roles:

1. Mejorar calidad de un escaneo LiDAR ya capturado (RTAB-Map desktop → Open3D → export final).
2. Único camino de reconstrucción si el dispositivo no tiene LiDAR (fotogrametría/COLMAP,
   Gaussian Splatting con Nerfstudio/gsplat).

Ver `../docs/PLAN.md` secciones 3, 4 y 7. Todavía sin código — pendiente Fase 2 del roadmap.
