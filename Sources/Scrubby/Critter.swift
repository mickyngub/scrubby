import AppKit
import SwiftUI

enum Mood: CaseIterable {
    case happy, scrubbing, sparkly, worried
}

/// Scrubby's 16×16 pixel critter, built the way Merly's are: body art, an
/// outline pass, then a mood face stamped on top.
enum Critter {
    static let bodyHex: UInt32 = 0x5CCAD6
    static let inkHex: UInt32 = 0x14292C

    /// B body, D shade, L belly, O outline, E eye, M mouth, C blush, S sweat, A foam.
    private static let palette: [Character: UInt32] = [
        "B": bodyHex, "D": 0x34A3B3, "L": 0xC9F1F5, "O": 0x1D5F68,
        "E": inkHex, "M": 0x1D5F68, "C": 0xFF9DB5, "S": 0x8FBFFF, "A": 0xF5FDFF,
    ]

    /// Before the outline pass. The "A" foam cap is the car-wash nod.
    static let art = [
        "................",
        "................",
        "................",
        ".....AA..AA.....",
        "....AAAAAAAA....",
        "...AAAAAAAAAA...",
        "...BBBBBBBBBB...",
        "...BBBBBBBBBB...",
        "...BBBBBBBBBB...",
        "...BBBBBBBBBB...",
        "...BBBLLLLBBB...",
        "...BBBLLLLBBB...",
        "...BBBLLLLBBB...",
        "....BBBBBBBB....",
        ".....DD..DD.....",
        "................",
    ]

    private static let solid: Set<Character> = ["B", "D", "L", "A"]

    static func grid(mood: Mood, blink: Bool) -> [[Character]] {
        var g = art.map(Array.init)
        outline(&g)
        stampFace(&g, mood: mood, blink: blink)
        return g
    }

    static func forEachCell(mood: Mood, blink: Bool, _ body: (Int, Int, UInt32) -> Void) {
        let g = grid(mood: mood, blink: blink)
        for y in 0..<16 {
            for x in 0..<16 {
                if let hex = palette[g[y][x]] { body(x, y, hex) }
            }
        }
    }

    /// Draws into a y-up Core Graphics rect.
    static func draw(mood: Mood, blink: Bool = false, in rect: CGRect, context: CGContext) {
        let cell = rect.width / 16
        forEachCell(mood: mood, blink: blink) { x, y, hex in
            context.setFillColor(cgColor(hex))
            context.fill(CGRect(
                x: rect.minX + CGFloat(x) * cell,
                y: rect.maxY - CGFloat(y + 1) * cell,
                width: cell, height: cell
            ))
        }
    }

    static func image(mood: Mood, points: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: points, height: points), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(mood: mood, in: rect, context: context)
            return true
        }
    }

    static func cgColor(_ hex: UInt32) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func outline(_ g: inout [[Character]]) {
        var edges: [(Int, Int)] = []
        for y in 0..<16 {
            for x in 0..<16 where g[y][x] == "." {
                let touches = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
                    let nx = x + dx, ny = y + dy
                    return (0..<16).contains(nx) && (0..<16).contains(ny) && solid.contains(g[ny][nx])
                }
                if touches { edges.append((x, y)) }
            }
        }
        for (x, y) in edges { g[y][x] = "O" }
    }

    private static func stampFace(_ g: inout [[Character]], mood: Mood, blink: Bool) {
        func set(_ x: Int, _ y: Int, _ ch: Character) { g[y][x] = ch }
        switch mood {
        case .happy:
            set(6, 8, "E"); set(9, 8, "E")
            set(5, 9, "C"); set(10, 9, "C")
            set(6, 11, "M"); set(9, 11, "M"); set(7, 12, "M"); set(8, 12, "M")
        case .scrubbing:
            set(4, 8, "E"); set(5, 7, "E"); set(6, 8, "E")
            set(9, 8, "E"); set(10, 7, "E"); set(11, 8, "E")
            set(5, 9, "C"); set(10, 9, "C")
            set(6, 11, "M"); set(9, 11, "M"); set(7, 12, "M"); set(8, 12, "M")
        case .sparkly:
            set(6, 8, "E"); set(9, 8, "E")
            set(4, 9, "C"); set(5, 9, "C"); set(10, 9, "C"); set(11, 9, "C")
            set(6, 11, "M"); set(9, 11, "M"); set(7, 12, "M"); set(8, 12, "M")
        case .worried:
            set(6, 8, "E"); set(9, 8, "E")
            set(5, 7, "D"); set(6, 7, "D"); set(9, 7, "D"); set(10, 7, "D")
            set(7, 12, "M"); set(8, 12, "M")
            set(12, 7, "S"); set(12, 8, "S")
        }
        if blink, mood != .scrubbing {
            set(5, 8, "D"); set(6, 8, "D"); set(9, 8, "D"); set(10, 8, "D")
        }
    }
}

/// Idle bob, random blink, and a squash-and-stretch hop (Merly's keyframes),
/// fired on hover or whenever `hopTrigger` changes.
struct CritterView: View {
    let mood: Mood
    var px: CGFloat = 26
    var hopTrigger = 0
    var hopsOnHover = true

    @State private var blink = false
    @State private var bobUp = false
    @State private var hoverHops = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Hop {
        var y: CGFloat = 0
        var sx: CGFloat = 1
        var sy: CGFloat = 1
    }

    var body: some View {
        let height = px * 0.3
        Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
            let cell = size.width / 16
            Critter.forEachCell(mood: mood, blink: blink) { x, y, hex in
                let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell + 0.01, height: cell + 0.01)
                ctx.fill(Path(rect), with: .color(Color(hex: hex)))
            }
        }
        .frame(width: px, height: px)
        .keyframeAnimator(initialValue: Hop(), trigger: reduceMotion ? 0 : hopTrigger + hoverHops) { view, hop in
            view
                .scaleEffect(x: hop.sx, y: hop.sy, anchor: UnitPoint(x: 0.5, y: 0.9))
                .offset(y: hop.y)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                CubicKeyframe(-height, duration: 0.125)
                CubicKeyframe(0, duration: 0.15)
                CubicKeyframe(-height * 0.22, duration: 0.10)
                CubicKeyframe(0, duration: 0.125)
            }
            KeyframeTrack(\.sx) {
                CubicKeyframe(0.94, duration: 0.125)
                CubicKeyframe(1.08, duration: 0.15)
                CubicKeyframe(0.98, duration: 0.10)
                CubicKeyframe(1.0, duration: 0.125)
            }
            KeyframeTrack(\.sy) {
                CubicKeyframe(1.08, duration: 0.125)
                CubicKeyframe(0.92, duration: 0.15)
                CubicKeyframe(1.02, duration: 0.10)
                CubicKeyframe(1.0, duration: 0.125)
            }
        }
        .offset(y: bobUp ? -px * 0.08 : 0)
        .animation(reduceMotion ? .default : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: bobUp)
        .onAppear { if !reduceMotion { bobUp = true } }
        .onHover { inside in
            if inside, hopsOnHover, !reduceMotion { hoverHops += 1 }
        }
        .task(id: mood) {
            guard mood != .scrubbing else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.2...5.0)))
                guard !Task.isCancelled else { return }
                blink = true
                try? await Task.sleep(for: .milliseconds(140))
                blink = false
            }
        }
    }
}
