import SwiftUI

@main
struct PolyMeshScanApp: App {
    @StateObject private var pb = PocketBase.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if pb.isLoggedIn {
                    HomeView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(pb)
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
    }
}
