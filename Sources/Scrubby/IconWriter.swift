import AppKit

/// `Scrubby --write-iconset <dir>` renders the app icon from the critter art,
/// so the icon and the menu bar critter can never drift apart. bundle.sh feeds
/// the result to iconutil.
enum IconWriter {
    private static let sizes: [(name: String, pixels: Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]

    private struct RenderFailed: Error {}

    static func write(to path: String) -> Bool {
        let dir = URL(fileURLWithPath: path)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for size in sizes {
                try png(pixels: size.pixels).write(to: dir.appendingPathComponent("\(size.name).png"))
            }
            return true
        } catch {
            FileHandle.standardError.write(Data("Scrubby: could not write the iconset: \(error)\n".utf8))
            return false
        }
    }

    private static func png(pixels: Int) throws -> Data {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { throw RenderFailed() }
        let s = CGFloat(pixels)
        // Apple's icon grid: 824/1024 artwork, 185/1024 corner radius.
        let inset = s * 100 / 1024
        let tile = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let radius = s * 185 / 1024
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.clip()
        let colors = [Critter.cgColor(0xB8EAF1), Critter.cgColor(0xEDFBFD)] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])
        }
        ctx.restoreGState()
        ctx.setShouldAntialias(false)
        let side = (tile.width * 0.8).rounded()
        let critter = CGRect(x: (s - side) / 2, y: (s - side) / 2 - s * 0.01, width: side, height: side)
        Critter.draw(mood: .happy, in: critter, context: ctx)
        guard let image = ctx.makeImage(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw RenderFailed() }
        return data
    }
}
