import SwiftUI

struct HomeView: View {
    @EnvironmentObject var pb: PocketBase
    @State private var scans: [PocketBase.Scan] = []
    @State private var error: String?
    @State private var capture: CaptureMode?

    enum CaptureMode: String, Identifiable {
        case roomplan, raw_mesh
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if scans.isEmpty {
                    VStack(spacing: 8) {
                        Text("sin escaneos")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Theme.muted)
                        Text("+ para empezar")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Theme.muted)
                    }
                }
                List {
                    ForEach(scans) { scan in
                        HStack {
                            Circle()
                                .fill(scan.capture_mode == "roomplan" ? Theme.purple : Theme.cyan)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scan.name)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(Theme.fg)
                                Text("\(scan.capture_mode) · \(String(scan.created.prefix(16)))")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(Theme.muted)
                            }
                            Spacer()
                            Text(scan.status)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(scan.status == "done" ? Theme.green : Theme.muted)
                        }
                        .listRowBackground(Theme.bgAlt)
                    }
                }
                .scrollContentBackground(.hidden)
                .refreshable { await load() }

                if let error {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Theme.red)
                            .padding(8)
                            .background(Theme.surface)
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("escaneos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("salir") { pb.logout() }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Theme.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("roomplan — muebles + estructura") { capture = .roomplan }
                        Button("mesh — malla densa") { capture = .raw_mesh }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .task { await load() }
            .fullScreenCover(item: $capture) { mode in
                switch mode {
                case .roomplan: RoomPlanCaptureView { capture = nil; Task { await load() } }
                case .raw_mesh: MeshCaptureView { capture = nil; Task { await load() } }
                }
            }
        }
    }

    private func load() async {
        do {
            scans = try await pb.listScans()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
