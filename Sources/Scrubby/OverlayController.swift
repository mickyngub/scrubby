import AppKit
import SwiftUI

/// The car-wash screen: one frosted window per display, above the menu bar and
/// the Dock, for as long as the keyboard is locked.
@MainActor
final class OverlayController {
    private unowned let session: CleaningSession
    private var windows: [NSWindow] = []

    init(session: CleaningSession) {
        self.session = session
    }

    func show() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map(makeWindow)
        let pointerScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
        windows.forEach { $0.orderFrontRegardless() }
        (windows.first { $0.screen == pointerScreen } ?? windows.first)?.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    /// Clicks fall through to whatever is underneath while the "clean" beat plays.
    func releasePointer() {
        windows.forEach { $0.ignoresMouseEvents = true }
    }

    func hide(completion: @escaping () -> Void) {
        let closing = windows
        windows = []
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            closing.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: {
            closing.forEach { $0.orderOut(nil) }
            completion()
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = OverlayWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.setFrame(screen.frame, display: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: CleaningView(session: session))
        window.alphaValue = 0
        return window
    }
}

/// Borderless windows refuse key status by default. The overlay takes it so
/// keyboard focus leaves whatever app was in front.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
