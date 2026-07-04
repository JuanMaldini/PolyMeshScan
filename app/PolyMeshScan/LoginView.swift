import SwiftUI

struct LoginView: View {
    @EnvironmentObject var pb: PocketBase
    @State private var url = UserDefaults.standard.string(forKey: "pb_url") ?? "https://"
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("PolyMeshScan")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.fg)
            Text("lidar · roomplan · self-hosted")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.muted)
                .padding(.bottom, 24)

            TextField("servidor (PocketBase)", text: $url)
                .keyboardType(.URL)
                .modifier(FieldStyle())
            TextField("email", text: $email)
                .keyboardType(.emailAddress)
                .modifier(FieldStyle())
            SecureField("password", text: $password)
                .modifier(FieldStyle())

            if let error {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Theme.red)
            }

            Button(busy ? "..." : "login") {
                Task {
                    busy = true; error = nil
                    do { try await pb.login(url: url, email: email, password: password) }
                    catch { self.error = error.localizedDescription }
                    busy = false
                }
            }
            .buttonStyle(FilledButtonStyle())
            .disabled(busy || email.isEmpty || password.isEmpty)
            Spacer()
            Spacer()
        }
        .padding(24)
        .background(Theme.bg.ignoresSafeArea())
    }
}
