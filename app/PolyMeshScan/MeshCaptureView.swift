import SwiftUI
import ARKit
import RealityKit

/// Captura de malla densa cruda con ARKit (sceneReconstruction .mesh).
/// Muestra la malla en vivo sobre la camara; al terminar exporta OBJ y sube.
struct MeshCaptureView: View {
    let onClose: () -> Void
    @StateObject private var session = MeshSession()
    @State private var finished: MeshResult?

    var body: some View {
        ZStack {
            ARMeshRepresentable(session: session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button("cancelar") { session.stop(); onClose() }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Theme.red)
                        .padding(10)
                        .background(Theme.surface.opacity(0.8))
                        .cornerRadius(8)
                    Spacer()
                    Text(session.stats)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(Theme.cyan)
                        .padding(8)
                        .background(Theme.surface.opacity(0.8))
                        .cornerRadius(8)
                }
                Spacer()
                Button("terminar escaneo") {
                    if let r = session.finish() { finished = r }
                }
                .buttonStyle(FilledButtonStyle(color: Theme.green))
                .padding(.horizontal, 40)
            }
            .padding()
        }
        .sheet(item: $finished) { result in
            MeshUploadSheet(result: result, onDone: onClose)
                .interactiveDismissDisabled()
        }
    }
}

struct MeshResult: Identifiable {
    let id = UUID()
    let objURL: URL
    let thumbnail: Data?
    let vertexCount: Int
}

// MARK: - Sesion AR

@MainActor
final class MeshSession: NSObject, ObservableObject, ARSessionDelegate {
    let arView = ARView(frame: .zero)
    @Published var stats = "iniciando..."

    func start() {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            stats = "sin LiDAR"; return
        }
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.environmentTexturing = .none
        arView.debugOptions.insert(.showSceneUnderstanding) // malla en vivo
        arView.session.delegate = self
        arView.session.run(config)
    }

    func stop() { arView.session.pause() }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let meshes = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshes.isEmpty else { return }
        Task { @MainActor in
            let total = self.arView.session.currentFrame?.anchors
                .compactMap { $0 as? ARMeshAnchor }
                .reduce(0) { $0 + $1.geometry.vertices.count } ?? 0
            self.stats = "\(total / 1000)k vertices"
        }
    }

    func finish() -> MeshResult? {
        guard let frame = arView.session.currentFrame else { return nil }
        let meshes = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshes.isEmpty else { return nil }

        var thumb: Data?
        let snapshot = arView.snapshotView(afterScreenUpdates: false)
        if let snapshot {
            let renderer = UIGraphicsImageRenderer(bounds: snapshot.bounds)
            let img = renderer.image { _ in
                snapshot.drawHierarchy(in: snapshot.bounds, afterScreenUpdates: false)
            }
            thumb = img.jpegData(compressionQuality: 0.6)
        }
        arView.session.pause()

        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("mesh.obj")
            let count = try MeshExporter.exportOBJ(meshes: meshes, to: url)
            return MeshResult(objURL: url, thumbnail: thumb, vertexCount: count)
        } catch {
            stats = "error export: \(error.localizedDescription)"
            return nil
        }
    }
}

struct ARMeshRepresentable: UIViewRepresentable {
    let session: MeshSession
    func makeUIView(context: Context) -> ARView {
        DispatchQueue.main.async { session.start() }
        return session.arView
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - Upload

struct MeshUploadSheet: View {
    let result: MeshResult
    let onDone: () -> Void
    @EnvironmentObject var pb: PocketBase
    @State private var name = "Mesh \(RoomPlanUploadSheet.stamp())"
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("malla lista")
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundColor(Theme.fg)
            Text("\(result.vertexCount / 1000)k vertices")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.green)

            TextField("nombre", text: $name)
                .modifier(FieldStyle())

            if let error {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Theme.red)
            }

            Button(busy ? "subiendo..." : "subir") {
                busy = true; error = nil
                Task {
                    do {
                        try await pb.createScan(
                            name: name, captureMode: "raw_mesh",
                            rawFile: result.objURL,
                            thumbnail: result.thumbnail, furnitureJSON: nil)
                        onDone()
                    } catch {
                        self.error = error.localizedDescription
                        busy = false
                    }
                }
            }
            .buttonStyle(FilledButtonStyle())
            .disabled(busy || name.isEmpty)

            Button("descartar") { onDone() }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.red)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationBackground(Theme.bg)
    }
}
