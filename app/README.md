# app/

App iOS **propia en SwiftUI** (minimal, tema Tokyo Night): login contra PocketBase (solo login,
sin registro — los usuarios se crean desde el admin), lista de escaneos, y dos modos de captura
**excluyentes por sesión** (ver `../docs/CAPTURE.md`):

- **roomplan** — muebles + estructura en vivo con la UI oficial de RoomPlan. Exporta USDZ +
  `furniture_json` (cajas/categorías, listo para renderizar en el viewer con three.js).
- **raw_mesh** — malla densa cruda con ARKit (`sceneReconstruction = .mesh`), visible en vivo.
  Exporta OBJ + thumbnail.

Ambos suben directo a `scanner_scans` con `status = done` (sin pipeline todavía).

## Por qué app propia y no el fork de RTAB-Map (decisión revisada)

El plan original partía del fork de RTAB-Map. Se cambió porque: (1) el objetivo central
(muebles en vivo) lo resuelve RoomPlan, que es Swift puro; (2) la malla densa en vivo la da
ARKit directamente; (3) compilar RTAB-Map iOS en CI tarda horas (OpenCV/PCL/VTK desde fuente)
vs minutos de una app SwiftUI; (4) UI propia minimal vs hackear una app C++ existente.
Lo que se pierde (SLAM con loop closure, la `.db` re-optimizable) pertenece a la calidad
avanzada — queda para `pipeline/` (Fase 2), donde RTAB-Map desktop sí aplica.

`rtabmap/` sigue como submodule solo como **referencia para el pipeline** — no participa del
build de la app ni del CI.

## Build

No hay `.xcodeproj` versionado: `project.yml` + [XcodeGen](https://github.com/yonaskolb/XcodeGen)
lo generan en el runner de GitHub Actions (`.github/workflows/build-ios.yml`), que compila sin
firma y publica `PolyMeshScan.ipa` como artifact. SideStore firma al instalar (ver
`../docs/INFRA.md`).

```
app/
├── project.yml            # definicion del proyecto (XcodeGen)
└── PolyMeshScan/
    ├── App.swift          # entrypoint
    ├── Theme.swift        # paleta Tokyo Night + estilos
    ├── PocketBase.swift   # auth + upload multipart a scanner_scans
    ├── LoginView.swift
    ├── HomeView.swift     # lista + menu de captura
    ├── RoomPlanCaptureView.swift
    ├── MeshCaptureView.swift
    └── MeshExporter.swift # ARMeshAnchor -> OBJ
```
