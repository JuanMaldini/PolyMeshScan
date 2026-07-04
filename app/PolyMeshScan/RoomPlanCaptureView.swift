import SwiftUI
import RoomPlan

/// Captura RoomPlan: usa la UI oficial de Apple (guias en vivo, mini-mapa,
/// deteccion de muebles/paredes on-device). Al terminar exporta USDZ + JSON
/// y abre la hoja de subida.
struct RoomPlanCaptureView: View {
    let onClose: () -> Void
    @State private var coordinator = RoomPlanCoordinator()
    @State private var result: CapturedRoom?
    @State private var scanning = true

    var body: some View {
        ZStack {
            RoomCaptureRepresentable(coordinator: coordinator)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button("cancelar") { coordinator.stop(); onClose() }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Theme.red)
                        .padding(10)
                        .background(Theme.surface.opacity(0.8))
                        .cornerRadius(8)
                    Spacer()
                }
                Spacer()
                if scanning {
                    Button("terminar escaneo") {
                        scanning = false
                        coordinator.stop() // dispara didPresent -> result
                    }
                    .buttonStyle(FilledButtonStyle(color: Theme.green))
                    .padding(.horizontal, 40)
                }
            }
            .padding()
        }
        .onAppear {
            coordinator.onResult = { room in result = room }
        }
        .sheet(item: $result) { room in
            RoomPlanUploadSheet(room: room, onDone: onClose)
                .interactiveDismissDisabled()
        }
    }
}

extension CapturedRoom: @retroactive Identifiable {
    public var id: UUID { identifier }
}

// MARK: - UIKit bridge

final class RoomPlanCoordinator: NSObject, RoomCaptureViewDelegate {
    var captureView: RoomCaptureView!
    var onResult: ((CapturedRoom) -> Void)?

    func start() {
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }
    func stop() {
        captureView.captureSession.stop()
    }
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        true // dejar que RoomPlan procese el resultado final
    }
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        guard error == nil else { return }
        onResult?(processedResult)
    }
    // RoomCaptureViewDelegate exige NSCoding
    func encode(with coder: NSCoder) {}
    required init?(coder: NSCoder) { super.init() }
    override init() { super.init() }
}

struct RoomCaptureRepresentable: UIViewRepresentable {
    let coordinator: RoomPlanCoordinator

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.delegate = coordinator
        coordinator.captureView = view
        DispatchQueue.main.async { coordinator.start() }
        return view
    }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}

// MARK: - Upload

struct RoomPlanUploadSheet: View {
    let room: CapturedRoom
    let onDone: () -> Void
    @EnvironmentObject var pb: PocketBase
    @State private var name = "Ambiente \(Self.stamp())"
    @State private var busy = false
    @State private var error: String?

    static func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: .now)
    }

    var furnitureCount: Int { room.objects.count }
    var wallCount: Int { room.walls.count }

    var body: some View {
        VStack(spacing: 16) {
            Text("escaneo listo")
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundColor(Theme.fg)
            Text("\(wallCount) paredes · \(furnitureCount) muebles detectados")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.green)

            TextField("nombre", text: $name)
                .modifier(FieldStyle())

            if let error {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Theme.red)
            }

            Button(busy ? "subiendo..." : "subir") { upload() }
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

    private func upload() {
        busy = true; error = nil
        Task {
            do {
                let dir = FileManager.default.temporaryDirectory
                let usdz = dir.appendingPathComponent("room.usdz")
                try room.export(to: usdz, exportOptions: .parametric)

                // furniture_json: resumen liviano para el viewer (cajas + categorias)
                let objects = room.objects.map { obj -> [String: Any] in
                    let t = obj.transform
                    return [
                        "category": String(describing: obj.category),
                        "confidence": String(describing: obj.confidence),
                        "dimensions": [obj.dimensions.x, obj.dimensions.y, obj.dimensions.z],
                        "position": [t.columns.3.x, t.columns.3.y, t.columns.3.z],
                    ]
                }
                let walls = room.walls.map { w -> [String: Any] in
                    let t = w.transform
                    return [
                        "dimensions": [w.dimensions.x, w.dimensions.y, w.dimensions.z],
                        "position": [t.columns.3.x, t.columns.3.y, t.columns.3.z],
                    ]
                }
                let json = try JSONSerialization.data(
                    withJSONObject: ["objects": objects, "walls": walls])

                try await pb.createScan(
                    name: name,
                    captureMode: "roomplan",
                    rawFile: usdz,
                    thumbnail: nil,
                    furnitureJSON: String(data: json, encoding: .utf8)
                )
                onDone()
            } catch {
                self.error = error.localizedDescription
                busy = false
            }
        }
    }
}
