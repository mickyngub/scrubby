import SwiftUI

struct CleaningView: View {
    @ObservedObject var session: CleaningSession

    @State private var rocking = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let theme = Theme.resolve(scheme)
        let done = session.phase != .cleaning
        ZStack {
            VisualEffect(material: .fullScreenUI)
            theme.overlayTint
            if !reduceMotion { BubbleField() }
            VStack(spacing: 0) {
                CritterView(mood: done ? .sparkly : .scrubbing, px: 160, hopTrigger: session.keysCaught, hopsOnHover: false)
                    .rotationEffect(.degrees(done || reduceMotion ? 0 : (rocking ? 4 : -4)), anchor: .bottom)
                    .animation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true), value: rocking)
                    .onAppear { rocking = true }
                Text(done ? "Sparkly clean" : "Keyboard locked")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(theme.text)
                    .contentTransition(.opacity)
                    .padding(.top, 26)
                Text(done ? "Your keys work again." : "Wipe away. Keys won’t do a thing.")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.text2)
                    .contentTransition(.opacity)
                    .padding(.top, 6)
                HStack(spacing: 8) {
                    StatChip(
                        systemImage: "hand.raised.fill",
                        text: "\(session.keysCaught) \(session.keysCaught == 1 ? "key" : "keys") caught"
                    )
                    if !done {
                        TimelineView(.animation(minimumInterval: 0.5)) { context in
                            StatChip(systemImage: "timer", text: "Unlocks in \(remaining(at: context.date))")
                        }
                    }
                }
                .padding(.top, 18)
                DoneButton(action: session.finish)
                    .padding(.top, 26)
                    .opacity(done ? 0 : 1)
                    .disabled(done)
                Text("Click it with your trackpad or mouse.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text3)
                    .padding(.top, 10)
                    .opacity(done ? 0 : 1)
                if session.secureInputOn, !done {
                    Label("Another app has Secure Keyboard Entry on, so some keys may slip through.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.warn)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Theme.warn.opacity(0.14), in: Capsule())
                        .padding(.top, 16)
                }
            }
        }
        .ignoresSafeArea()
        .environment(\.theme, theme)
    }

    private func remaining(at date: Date) -> String {
        let seconds = max(0, Int(session.unlocksAt.timeIntervalSince(date).rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct StatChip: View {
    let systemImage: String
    let text: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(theme.text2)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.chip, in: Capsule())
    }
}

private struct DoneButton: View {
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text("Done cleaning")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: Critter.inkHex))
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color(hex: Critter.bodyHex), in: Capsule())
                .brightness(hovering ? 0.06 : 0)
        }
        .buttonStyle(PressScale())
        .onHover { hovering = $0 }
        .animation(Theme.snappy(0.18), value: hovering)
        .pointerCursor()
    }
}

private struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.snappy(0.18), value: configuration.isPressed)
    }
}

/// Soap bubbles drifting up the screen, positions derived from time and index
/// alone so there is no per-bubble state to keep.
private struct BubbleField: View {
    private static let count = 18

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<Self.count {
                    let seed = Double(i)
                    let radius = 6 + fraction(seed * 0.618) * 22
                    let speed = 28 + fraction(seed * 0.377) * 48
                    let travel = size.height + radius * 4
                    let rise = (t * speed + fraction(seed * 0.913) * travel).truncatingRemainder(dividingBy: travel)
                    let x = fraction(seed * 0.271 + 0.13) * size.width + sin(t * 1.1 + seed) * 14
                    let y = size.height + radius * 2 - rise
                    let bubble = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: bubble), with: .color(Color(hex: Critter.bodyHex, alpha: 0.08)))
                    ctx.stroke(Path(ellipseIn: bubble), with: .color(Color(hex: Critter.bodyHex, alpha: 0.45)), lineWidth: 1.5)
                    let shine = CGRect(x: x - radius * 0.55, y: y - radius * 0.6, width: radius * 0.4, height: radius * 0.4)
                    ctx.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.55)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func fraction(_ value: Double) -> Double {
        value - value.rounded(.down)
    }
}
