// Design tokens lifted from Merly (Sources/Merly/Theme.swift) so the two apps
// read as one family. Change them there first, then mirror here.

import AppKit
import SwiftUI

struct Theme {
    let text: Color
    let text2: Color
    let text3: Color
    let panelTint: Color
    let panelEdge: Color
    let overlayTint: Color
    let cardBackground: Color
    let cardBackgroundHover: Color
    let cardBorder: Color
    let chip: Color

    static let light = Theme(
        text: Color(hex: 0x1D1D1F),
        text2: Color(.sRGB, red: 40/255, green: 40/255, blue: 46/255, opacity: 0.82),
        text3: Color(.sRGB, red: 50/255, green: 50/255, blue: 56/255, opacity: 0.58),
        panelTint: Color(.sRGB, red: 250/255, green: 250/255, blue: 252/255, opacity: 0.45),
        panelEdge: Color.white.opacity(0.7),
        overlayTint: Color(.sRGB, red: 246/255, green: 250/255, blue: 252/255, opacity: 0.55),
        cardBackground: Color.white.opacity(0.72),
        cardBackgroundHover: Color.white.opacity(0.92),
        cardBorder: Color.black.opacity(0.07),
        chip: Color.black.opacity(0.05)
    )

    static let dark = Theme(
        text: Color(hex: 0xF5F5F7),
        text2: Color(.sRGB, red: 238/255, green: 238/255, blue: 246/255, opacity: 0.82),
        text3: Color(.sRGB, red: 232/255, green: 232/255, blue: 242/255, opacity: 0.56),
        panelTint: Color(.sRGB, red: 28/255, green: 28/255, blue: 32/255, opacity: 0.38),
        panelEdge: Color.white.opacity(0.10),
        overlayTint: Color(.sRGB, red: 16/255, green: 22/255, blue: 26/255, opacity: 0.55),
        cardBackground: Color.white.opacity(0.055),
        cardBackgroundHover: Color.white.opacity(0.10),
        cardBorder: Color.white.opacity(0.09),
        chip: Color.white.opacity(0.08)
    )

    static func resolve(_ scheme: ColorScheme) -> Theme {
        scheme == .dark ? .dark : .light
    }

    static let warn = Color(hex: 0xE8A33D)

    static func snappy(_ duration: Double) -> Animation {
        .timingCurve(0.32, 0.72, 0, 1, duration: duration)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.dark
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

struct IconButton: View {
    let systemName: String
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? theme.text : theme.text2)
                .frame(width: 28, height: 28)
                .background(hovering ? theme.chip : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointerCursor()
    }
}

/// `NSCursor.push()`/`pop()` must stay balanced or the cursor sticks app-wide,
/// so this pops on every way out, disappearing included.
private struct PointerCursorModifier: ViewModifier {
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside, !pushed {
                    pushed = true
                    NSCursor.pointingHand.push()
                } else if !inside {
                    pop()
                }
            }
            .onDisappear { pop() }
    }

    private func pop() {
        guard pushed else { return }
        pushed = false
        NSCursor.pop()
    }
}

extension View {
    func pointerCursor() -> some View {
        modifier(PointerCursorModifier())
    }
}
