import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class CleaningSession: ObservableObject {
    enum Phase { case idle, cleaning, finished }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var keysCaught = 0
    @Published private(set) var startedAt = Date()
    @Published private(set) var hasPermission: Bool
    @Published private(set) var secureInputOn = false

    /// A failsafe for a Mac whose only pointer stops responding mid-clean.
    let autoUnlockAfter: TimeInterval = LaunchFlags.unlockAfter ?? 5 * 60
    var unlocksAt: Date { startedAt.addingTimeInterval(autoUnlockAfter) }

    private let effects: CleaningEffects
    private var autoUnlock: Timer?
    private var hasPrompted = false

    init(effects: CleaningEffects) {
        self.effects = effects
        hasPermission = effects.isTrusted
    }

    func refreshPermission() {
        hasPermission = effects.isTrusted
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
        let locked = effects.lockKeys { [weak self] in
            MainActor.assumeIsolated { self?.keysCaught += 1 }
        }
        guard locked else {
            hasPermission = false
            return false
        }
        hasPermission = true
        keysCaught = 0
        startedAt = Date()
        secureInputOn = false
        phase = .cleaning
        effects.showOverlay(for: self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.phase == .cleaning else { return }
            self.secureInputOn = self.effects.secureInputOn
        }
        autoUnlock = Timer.scheduledTimer(withTimeInterval: autoUnlockAfter, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
        return true
    }

    func finish() {
        guard phase == .cleaning else { return }
        effects.unlockKeys()
        autoUnlock?.invalidate()
        autoUnlock = nil
        NSLog("Scrubby: caught %d keys", keysCaught)
        withAnimation(Theme.snappy(0.35)) { phase = .finished }
        effects.releaseOverlay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self, self.phase == .finished else { return }
            self.effects.hideOverlay { [weak self] in
                MainActor.assumeIsolated { self?.phase = .idle }
            }
        }
    }
}

/// What a cleaning session does to the Mac. `LiveCleaningEffects` locks the
/// keyboard and covers every display; the demo stage only plays the views.
@MainActor
protocol CleaningEffects: AnyObject {
    var isTrusted: Bool { get }
    var secureInputOn: Bool { get }
    /// False when macOS refuses the key tap.
    func lockKeys(onKeyPress: @escaping () -> Void) -> Bool
    func unlockKeys()
    func showOverlay(for session: CleaningSession)
    func releaseOverlay()
    func hideOverlay(completion: @escaping () -> Void)
}

@MainActor
final class LiveCleaningEffects: CleaningEffects {
    private let blocker = KeyBlocker()
    private var overlay: OverlayController?
    private var previousApp: NSRunningApplication?

    var isTrusted: Bool { AXIsProcessTrusted() }
    var secureInputOn: Bool { IsSecureEventInputEnabled() }

    func lockKeys(onKeyPress: @escaping () -> Void) -> Bool {
        blocker.onKeyPressed = onKeyPress
        return blocker.start()
    }

    func unlockKeys() {
        blocker.stop()
    }

    func showOverlay(for session: CleaningSession) {
        previousApp = NSWorkspace.shared.frontmostApplication
        // Frontmost, so another app's password field drops Secure Event Input,
        // which would otherwise let keys past the tap.
        NSApp.activate()
        if overlay == nil { overlay = OverlayController(session: session) }
        overlay?.show()
    }

    func releaseOverlay() {
        overlay?.releasePointer()
        previousApp?.activate()
        previousApp = nil
    }

    func hideOverlay(completion: @escaping () -> Void) {
        guard let overlay else { return completion() }
        overlay.hide(completion: completion)
    }
}
