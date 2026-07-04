import SwiftUI

/// Paleta Tokyo Night — minimal, oscuro.
enum Theme {
    static let bg      = Color(hex: 0x1A1B26)
    static let bgAlt   = Color(hex: 0x24283B)
    static let surface = Color(hex: 0x16161E)
    static let fg      = Color(hex: 0xC0CAF5)
    static let muted   = Color(hex: 0x565F89)
    static let accent  = Color(hex: 0x7AA2F7) // azul
    static let green   = Color(hex: 0x9ECE6A)
    static let red     = Color(hex: 0xF7768E)
    static let purple  = Color(hex: 0xBB9AF7)
    static let cyan    = Color(hex: 0x7DCFFF)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Estilos compartidos
struct FilledButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(Theme.surface)
            .cornerRadius(10)
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.body, design: .monospaced))
            .padding(12)
            .background(Theme.bgAlt)
            .cornerRadius(10)
            .foregroundColor(Theme.fg)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }
}
