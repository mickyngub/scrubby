import AppKit
import ScreenCaptureKit
import SwiftUI

/// `Scrubby --demo [--record <file.mov>]`: the README demo. The real panel and
/// car-wash views play on a staged desktop with a scripted cursor and key
/// presses; the keyboard is never touched. `scripts/record-demo.sh` records it.
@MainActor
final class DemoStage {
    static let size = CGSize(width: 960, height: 600)
    static let menuBarHeight: CGFloat = 26
    private static let rest = CGPoint(x: 560, y: 390)

    private let model = DemoModel()
    private let effects: StageEffects
    private let session: CleaningSession
    private var windows: [NSWindow] = []
    private var captureRect = CGRect.zero

    private let keys: [(label: String, pause: Double)] = [
        ("S", 0.2), ("C", 0.18), ("R", 0.2), ("U", 0.18), ("B", 0.3), ("⌘ Tab", 0.45),
        ("Space", 0.35), ("A", 0.14), ("S", 0.14), ("D", 0.3), ("Esc", 0.4), ("⌥ ⌘ Esc", 0.5),
    ]

    init() {
        effects = StageEffects(model: model)
        session = CleaningSession(effects: effects)
    }

    func run() {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let screen = NSScreen.screens[0]
        let frame = NSRect(
            x: (screen.frame.midX - Self.size.width / 2).rounded(),
            y: (screen.frame.midY - Self.size.height / 2).rounded(),
            width: Self.size.width, height: Self.size.height
        )
        // The wallpaper is its own window underneath so the views' behind-window
        // blur frosts it, as it would a real desktop.
        windows = [
            Self.window(frame: frame, content: Wallpaper()),
            Self.window(frame: frame, content: StageView(model: model, session: session)),
        ]
        windows.forEach { $0.orderFrontRegardless() }
        // ScreenCaptureKit wants top-left-origin points.
        captureRect = CGRect(x: frame.minX, y: screen.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
        Task { await play() }
    }

    /// Recording starts and stops on the same idle frame, so the GIF loops cleanly.
    private func play() async {
        await pause(1.5)
        let recorder = await startRecording()
        await pause(0.6)

        await move(to: "critter", duration: 0.75)
        await click()
        withAnimation(.easeOut(duration: 0.16)) { model.panelOpen = true }
        await pause(0.7)

        await move(to: "start", duration: 0.6, hand: true)
        await pause(0.25)
        await click()
        model.panelOpen = false
        model.hand = false
        session.start()
        await pause(1.0)

        for (index, key) in keys.enumerated() {
            effects.pressKey()
            model.showKeycap(key.label, index: index)
            await pause(key.pause)
        }
        await pause(0.5)

        await move(to: "done", duration: 0.7, hand: true)
        await pause(0.25)
        await click()
        model.hand = false
        session.finish()
        await pause(1.6)

        await move(to: Self.rest, duration: 0.8)
        await pause(0.6)
        if #available(macOS 15, *), let recorder = recorder as? StageRecorder {
            await recorder.stop()
        }
        NSApp.terminate(nil)
    }

    private func startRecording() async -> AnyObject? {
        guard let path = LaunchFlags.recordPath else { return nil }
        guard #available(macOS 15, *) else { fail("recording the demo needs macOS 15") }
        let recorder = StageRecorder()
        do {
            try await recorder.start(rect: captureRect, to: URL(fileURLWithPath: path))
        } catch {
            fail("could not record the demo: \(error)")
        }
        return recorder
    }

    private func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("Scrubby: \(message)\n".utf8))
        exit(1)
    }

    private func move(to anchor: String, duration: Double, hand: Bool = false) async {
        guard let target = model.targets[anchor] else { return }
        await move(to: CGPoint(x: target.midX, y: target.midY), duration: duration, hand: hand)
    }

    private func move(to point: CGPoint, duration: Double, hand: Bool = false) async {
        withAnimation(.timingCurve(0.45, 0, 0.2, 1, duration: duration)) { model.cursor = point }
        await pause(duration)
        model.hand = hand
    }

    private func click() async {
        withAnimation(.easeOut(duration: 0.08)) { model.pressed = true }
        model.ripple()
        await pause(0.12)
        withAnimation(.easeOut(duration: 0.1)) { model.pressed = false }
        await pause(0.05)
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private static func window(frame: NSRect, content: some View) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.setFrame(frame, display: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: content)
        return window
    }
}

/// Records the stage's rectangle of the main display to a movie, cursor left out.
@available(macOS 15, *)
private final class StageRecorder: NSObject, SCRecordingOutputDelegate {
    private var stream: SCStream?
    private var finished: CheckedContinuation<Void, Never>?

    func start(rect: CGRect, to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
            throw CocoaError(.featureUnsupported)
        }
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width * 2)
        config.height = Int(rect.height * 2)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = false
        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = url
        recording.outputFileType = .mov
        recording.videoCodecType = .h264
        let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: nil)
        try stream.addRecordingOutput(SCRecordingOutput(configuration: recording, delegate: self))
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        guard let stream else { return }
        await withCheckedContinuation { continuation in
            finished = continuation
            Task { try? await stream.stopCapture() }
        }
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        finished?.resume()
        finished = nil
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        FileHandle.standardError.write(Data("Scrubby: recording failed: \(error)\n".utf8))
        finished?.resume()
        finished = nil
    }
}

@MainActor
private final class DemoModel: ObservableObject {
    struct Mark: Identifiable {
        let id = UUID()
        let label: String
        let point: CGPoint
    }

    @Published var cursor = CGPoint(x: 560, y: 390)
    @Published var hand = false
    @Published var pressed = false
    @Published var panelOpen = false
    @Published var overlayVisible = false
    @Published var ripples: [Mark] = []
    @Published var keycaps: [Mark] = []
    /// Where each `demoAnchor` control sits on the stage. Not published: it is
    /// read by the script, never drawn.
    var targets: [String: CGRect] = [:]

    func ripple() {
        let mark = Mark(label: "", point: cursor)
        ripples.append(mark)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.ripples.removeAll { $0.id == mark.id }
        }
    }

    func showKeycap(_ label: String, index: Int) {
        let left = index.isMultiple(of: 2)
        let x = (left ? 190.0 : 770.0) + Double((index * 37) % 70) - 35
        let y = 380.0 + Double((index * 53) % 90)
        let mark = Mark(label: label, point: CGPoint(x: x, y: y))
        keycaps.append(mark)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.keycaps.removeAll { $0.id == mark.id }
        }
    }
}

@MainActor
private final class StageEffects: CleaningEffects {
    private let model: DemoModel
    private var onKeyPress: (() -> Void)?

    init(model: DemoModel) {
        self.model = model
    }

    var isTrusted: Bool { true }
    var secureInputOn: Bool { false }

    func pressKey() {
        onKeyPress?()
    }

    func lockKeys(onKeyPress: @escaping () -> Void) -> Bool {
        self.onKeyPress = onKeyPress
        return true
    }

    func unlockKeys() {
        onKeyPress = nil
    }

    func showOverlay(for session: CleaningSession) {
        withAnimation(.easeOut(duration: 0.25)) { model.overlayVisible = true }
    }

    func releaseOverlay() {}

    func hideOverlay(completion: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.3)) { model.overlayVisible = false }
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            completion()
        }
    }
}

private struct StageView: View {
    @ObservedObject var model: DemoModel
    let session: CleaningSession

    var body: some View {
        ZStack(alignment: .topLeading) {
            MenuBarStrip()
            if model.panelOpen {
                PanelRootView(session: session, onStart: {})
                    .padding(.top, DemoStage.menuBarHeight + 6)
                    .padding(.leading, DemoStage.size.width - PanelController.width - 10)
                    .transition(.opacity)
            }
            if model.overlayVisible {
                CleaningView(session: session)
                    .transition(.opacity)
            }
            ForEach(model.keycaps) { mark in
                KeycapView(label: mark.label).position(mark.point)
            }
            ForEach(model.ripples) { mark in
                RippleView().position(mark.point)
            }
            cursor
        }
        .frame(width: DemoStage.size.width, height: DemoStage.size.height, alignment: .topLeading)
        .backgroundPreferenceValue(DemoAnchorKey.self) { anchors in
            GeometryReader { geo in
                let rects = anchors.mapValues { geo[$0] }
                Color.clear
                    .onAppear { model.targets.merge(rects) { $1 } }
                    .onChange(of: rects) { _, new in model.targets.merge(new) { $1 } }
            }
        }
    }

    private var cursor: some View {
        let cursor = model.hand ? NSCursor.pointingHand : NSCursor.arrow
        let size = cursor.image.size
        let hotSpot = cursor.hotSpot
        return Image(nsImage: cursor.image)
            .scaleEffect(model.pressed ? 0.86 : 1, anchor: UnitPoint(x: hotSpot.x / size.width, y: hotSpot.y / size.height))
            .position(x: model.cursor.x - hotSpot.x + size.width / 2, y: model.cursor.y - hotSpot.y + size.height / 2)
    }
}

private struct MenuBarStrip: View {
    var body: some View {
        HStack(spacing: 18) {
            Text("Finder").fontWeight(.bold)
            ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) { Text($0) }
            Spacer()
            Image(nsImage: Critter.image(mood: .happy, points: 16))
                .demoAnchor("critter")
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("Wed 9:41")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 16)
        .frame(width: DemoStage.size.width, height: DemoStage.menuBarHeight)
        .background(Color.black.opacity(0.22))
    }
}

private struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0F1B2D), Color(hex: 0x16283F), Color(hex: 0x0E3138)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle().fill(Color(hex: 0x3FB8C6).opacity(0.55))
                .frame(width: 560, height: 560).blur(radius: 110).offset(x: -280, y: 170)
            Circle().fill(Color(hex: 0x7C5CF0).opacity(0.5))
                .frame(width: 480, height: 480).blur(radius: 110).offset(x: 300, y: -150)
            Circle().fill(Color(hex: 0xFF8FAF).opacity(0.3))
                .frame(width: 320, height: 320).blur(radius: 90).offset(x: 160, y: 230)
        }
        .frame(width: DemoStage.size.width, height: DemoStage.size.height)
        .clipped()
    }
}

/// A key the viewer "pressed", floating up and away like the bubbles.
private struct KeycapView: View {
    let label: String

    @State private var risen = false

    var body: some View {
        Text(label)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 13)
            .frame(minWidth: 46, minHeight: 46)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.24), lineWidth: 1))
            .scaleEffect(risen ? 1 : 0.7)
            .offset(y: risen ? -46 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { risen = true }
            }
    }
}

private struct RippleView: View {
    @State private var grown = false

    var body: some View {
        Circle()
            .strokeBorder(.white.opacity(grown ? 0 : 0.75), lineWidth: 2)
            .frame(width: grown ? 46 : 10, height: grown ? 46 : 10)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) { grown = true }
            }
    }
}

struct DemoAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Lets the demo stage aim its scripted cursor at this control.
    func demoAnchor(_ name: String) -> some View {
        anchorPreference(key: DemoAnchorKey.self, value: .bounds) { [name: $0] }
    }
}
