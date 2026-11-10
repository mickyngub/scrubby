import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class CleaningSession: ObservableObject {
    enum Phase { case idle, cleaning, finished }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var keysCaught = 0
    @Published private(set) var startedAt = Date()
    @Published private(set) var hasPermission = AXIsProcessTrusted()
    @Published private(set) var secureInputOn = false

    /// A failsafe for a Mac whose only pointer stops responding mid-clean.
    let autoUnlockAfter: TimeInterval = LaunchFlags.unlockAfter ?? 5 * 60
    var unlocksAt: Date { startedAt.addingTimeInterval(autoUnlockAfter) }

    private let blocker = KeyBlocker()
    private lazy var overlay = OverlayController(session: self)
    private var autoUnlock: Timer?
    private var previousApp: NSRunningApplication?
    private var hasPrompted = false

    init() {
        blocker.onKeyPressed = { [weak self] in
            MainActor.assumeIsolated { self?.keysCaught += 1 }
        }
    }

    func refreshPermission() {
        hasPermission = AXIsProcessTrusted()
    }

    /// The system prompt only ever shows once per app, so later asks go straight
    /// to the Accessibility pane.
    func requestPermission() {
        if !hasPrompted {
            hasPrompted = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            hasPermission = AXIsProcessTrustedWithOptions(options)
            return
        }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @discardableResult
    func start() -> Bool {
        guard phase == .idle else { return false }
        guard blocker.start() else {
            hasPermission = false
            return false
        }
        hasPermission = true
        keysCaught = 0
        startedAt = Date()
        secureInputOn = false
        phase = .cleaning
        previousApp = NSWorkspace.shared.frontmostApplication
        // Frontmost, so another app's password field drops Secure Event Input,
        // which would otherwise let keys past the tap.
        NSApp.activate()
        overlay.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.phase == .cleaning else { return }
            self.secureInputOn = IsSecureEventInputEnabled()
        }
        autoUnlock = Timer.scheduledTimer(withTimeInterval: autoUnlockAfter, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
        return true
    }

    func finish() {
        guard phase == .cleaning else { return }
        blocker.stop()
        autoUnlock?.invalidate()
        autoUnlock = nil
        NSLog("Scrubby: caught %d keys", keysCaught)
        withAnimation(Theme.snappy(0.35)) { phase = .finished }
        overlay.releasePointer()
        previousApp?.activate()
        previousApp = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self, self.phase == .finished else { return }
            self.overlay.hide { [weak self] in
                MainActor.assumeIsolated { self?.phase = .idle }
            }
        }
    }
}
