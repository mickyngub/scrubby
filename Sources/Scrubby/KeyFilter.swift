import AppKit
import CoreGraphics

/// Which events the tap holds back. Pure, so `--selftest` can check it without
/// a live tap or any permission.
enum KeyFilter {
    /// NX_SYSDEFINED: CGEventType has no case for it.
    static let systemDefined: UInt32 = 14

    /// IOLLEvent.h subtypes: power key (1), volume/brightness/media keys (8),
    /// eject (10). Extra mouse buttons (7) stay live: the mouse is the way out.
    static let keyboardSubtypes: Set<Int16> = [1, 8, 10]

    static let swallowedTypes: Set<UInt32> = [
        CGEventType.keyDown.rawValue,
        CGEventType.keyUp.rawValue,
        CGEventType.flagsChanged.rawValue,
    ]

    static var eventMask: CGEventMask {
        (swallowedTypes.union([systemDefined])).reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1) }
    }

    static func shouldSwallow(type: UInt32, subtype: Int16?) -> Bool {
        if swallowedTypes.contains(type) { return true }
        if type == systemDefined, let subtype { return keyboardSubtypes.contains(subtype) }
        return false
    }

    /// NSEvent raises when `subtype` is read off an event that has none, so only
    /// system-defined events are asked.
    static func subtype(of event: CGEvent) -> Int16? {
        guard event.type.rawValue == systemDefined else { return nil }
        return NSEvent(cgEvent: event)?.subtype.rawValue
    }
}
