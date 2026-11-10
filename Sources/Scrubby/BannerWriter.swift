import AppKit
import SwiftUI

/// `Scrubby --write-banner <path>`: the README banner, laid out like Merly's
/// and drawn from the same critter art as the app.
enum BannerWriter {
    @MainActor
    static func write(to path: String) -> Bool {
        let renderer = ImageRenderer(content: Banner())
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { return false }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            FileHandle.standardError.write(Data("Scrubby: could not write the banner: \(error)\n".utf8))
            return false
        }
    }
}

private struct Banner: View {
    private static let cell: CGFloat = 15

    var body: some View {
        HStack(spacing: 40) {
            art
            VStack(alignment: .leading, spacing: 0) {
                Text("Scrubby")
                    .font(.custom("AvenirNext-Bold", size: 64))
                    .foregroundStyle(Color(hex: 0xF5F5F7))
                Text("for macOS")
                    .font(.custom("AvenirNext-DemiBold", size: 30))
                    .foregroundStyle(Color(hex: 0xC9CDD6))
                    .padding(.top, -6)
                Text("By Pichaya Puttekulangkura")
                    .font(.custom("AvenirNext-DemiBold", size: 16))
                    .foregroundStyle(Color(hex: 0x9AA0AC))
                    .padding(.top, 22)
                Rectangle()
                    .fill(Color(hex: Critter.bodyHex))
                    .frame(width: 212, height: 2)
                    .padding(.top, 10)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 50)
        .frame(width: 880, height: 294)
        .background(Color(hex: 0x1E2029))
    }

    /// The critter with pixel soap bubbles drifting off its foam cap.
    private var art: some View {
        Canvas { ctx, _ in
            func fill(_ x: Int, _ y: Int, _ hex: UInt32, originX: CGFloat = 0, originY: CGFloat = 0) {
                let rect = CGRect(x: originX + CGFloat(x) * Self.cell, y: originY + CGFloat(y) * Self.cell, width: Self.cell + 0.01, height: Self.cell + 0.01)
                ctx.fill(Path(rect), with: .color(Color(hex: hex)))
            }
            Critter.forEachCell(mood: .happy, blink: false) { x, y, hex in
                fill(x, y, hex, originY: Self.cell * 2)
            }
            for bubble in [(x: 15, y: 1, big: true), (x: 18, y: 6, big: false)] {
                let ring: [(Int, Int)] = bubble.big
                    ? [(1, 0), (2, 0), (0, 1), (3, 1), (0, 2), (3, 2), (1, 3), (2, 3)]
                    : [(1, 0), (0, 1), (2, 1), (1, 2)]
                for (dx, dy) in ring { fill(bubble.x + dx, bubble.y + dy, 0x8FE3EC) }
                fill(bubble.x + 1, bubble.y + 1, 0xF5FDFF)
            }
        }
        .frame(width: Self.cell * 21, height: Self.cell * 18)
    }
}
