import AppKit
import Combine
import SwiftUI

/// The dropdown under the menu bar critter: Merly's frosted panel, one card.
@MainActor
final class PanelController {
    static let width: CGFloat = 336

    private let session: CleaningSession
    private let panel: NSPanel
    private var outsideClicks: Any?
    private var permissionPoll: Timer?
    private var resize: AnyCancellable?

    init(session: CleaningSession) {
        self.session = session
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PanelRootView(
            session: session,
            onStart: { [weak self] in self?.startCleaning() }
        ))
        resize = session.$hasPermission.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.fitKeepingTop() }
        }
    }

    var isOpen: Bool { panel.isVisible }

    func toggle(below button: NSStatusBarButton) {
        isOpen ? close() : open(below: button)
    }

    func open(below button: NSStatusBarButton) {
        guard let host = panel.contentView else { return }
        session.refreshPermission()
        let size = host.fittingSize
        let frame: NSRect
        if let anchor = Self.visibleFrame(of: button), let screen = button.window?.screen {
            let visible = screen.visibleFrame
            let x = min(max(anchor.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
            frame = NSRect(x: x, y: anchor.minY - 6 - size.height, width: size.width, height: size.height)
        } else {
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? .zero
            frame = NSRect(x: visible.maxX - size.width - 10, y: visible.maxY - 6 - size.height, width: size.width, height: size.height)
        }
        panel.setFrame(frame, display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
        }
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.session.hasPermission else { return }
                self.session.refreshPermission()
            }
        }
    }

    func close() {
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
        permissionPoll?.invalidate()
        permissionPoll = nil
        panel.orderOut(nil)
    }

    /// Nil before the status item is laid out, and when a crowded menu bar hides
    /// it behind the notch.
    private static func visibleFrame(of button: NSStatusBarButton) -> NSRect? {
        guard let window = button.window, window.isVisible, window.frame.width > 0 else { return nil }
        let centre = NSPoint(x: window.frame.midX, y: window.frame.midY)
        return NSScreen.screens.contains { $0.frame.contains(centre) } ? window.frame : nil
    }

    private func startCleaning() {
        if session.start() { close() }
    }

    private func fitKeepingTop() {
        guard isOpen, let host = panel.contentView else { return }
        let height = host.fittingSize.height
        var frame = panel.frame
        frame.origin.y = frame.maxY - height
        frame.size.height = height
        panel.setFrame(frame, display: true, animate: false)
    }
}

struct PanelRootView: View {
    @ObservedObject var session: CleaningSession
    let onStart: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = Theme.resolve(scheme)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(mood: session.hasPermission ? .happy : .worried)
            StartCard(ready: session.hasPermission, onStart: onStart, onAllow: session.requestPermission)
                .padding(EdgeInsets(top: 2, leading: 10, bottom: 9, trailing: 10))
            Text("Your trackpad and mouse keep working, so you can click Done.")
                .font(.system(size: 10.5))
                .foregroundStyle(theme.text3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(EdgeInsets(top: 0, leading: 16, bottom: 13, trailing: 16))
        }
        .frame(width: PanelController.width)
        .background {
            ZStack {
                VisualEffect()
                theme.panelTint
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(theme.panelEdge, lineWidth: 0.5))
        .focusEffectDisabled()
        .environment(\.theme, theme)
    }
}

private struct PanelHeader: View {
    let mood: Mood

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            CritterView(mood: mood, px: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("Scrubby")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(theme.text)
                Text("Car wash mode for your keyboard")
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.text2)
            }
            Spacer()
            IconButton(systemName: "power") { NSApp.terminate(nil) }
                .help("Quit Scrubby")
        }
        .padding(EdgeInsets(top: 15, leading: 16, bottom: 11, trailing: 12))
    }
}

private struct StartCard: View {
    let ready: Bool
    let onStart: () -> Void
    let onAllow: () -> Void

    @State private var hovering = false
    @Environment(\.theme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        Button(action: ready ? onStart : onAllow) {
            HStack(spacing: 11) {
                Image(systemName: ready ? "bubbles.and.sparkles.fill" : "lock.shield")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ready ? Color(hex: Critter.bodyHex) : Theme.warn)
                    .frame(width: 40, height: 40)
                    .background(theme.chip, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ready ? "Start cleaning" : "Allow Accessibility")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text(ready
                         ? "Locks every key until you click Done."
                         : "Scrubby needs it to hold keys back. Already on? Toggle it off and on.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(theme.text3)
            }
            .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
            .background(hovering ? theme.cardBackgroundHover : theme.cardBackground, in: shape)
            .overlay(shape.strokeBorder(theme.cardBorder, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .demoAnchor("start")
        .onHover { hovering = $0 }
        .animation(Theme.snappy(0.2), value: hovering)
        .pointerCursor()
    }
}
