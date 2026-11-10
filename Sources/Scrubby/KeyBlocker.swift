import CoreGraphics
import Foundation

/// A HID-level event tap that drops keyboard events. HID level, not session
/// level, so ⌘Tab, Spotlight and the other system shortcuts are caught too.
///
/// If the app hangs, macOS disables the tap after a timeout; if it crashes, the
/// tap dies with it. Either way the keyboard comes back on its own.
final class KeyBlocker {
    var onKeyPressed: () -> Void = {}

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// False when macOS refuses the tap, which means no Accessibility grant.
    func start() -> Bool {
        if tap != nil { return true }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: KeyFilter.eventMask,
            callback: keyBlockerCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard KeyFilter.shouldSwallow(type: type.rawValue, subtype: KeyFilter.subtype(of: event)) else {
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            onKeyPressed()
        }
        return nil
    }
}

private func keyBlockerCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    return Unmanaged<KeyBlocker>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
}
