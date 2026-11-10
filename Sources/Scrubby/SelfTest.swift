import AppKit
import CoreGraphics

/// `Scrubby --selftest`: needs no permission and no UI. Exit code 1 on any failure.
enum SelfTest {
    static func run() -> Bool {
        var failures = 0
        func check(_ passed: Bool, _ name: String) {
            print(passed ? "ok    \(name)" : "FAIL  \(name)")
            if !passed { failures += 1 }
        }

        for type in [CGEventType.keyDown, .keyUp, .flagsChanged] {
            check(KeyFilter.shouldSwallow(type: type.rawValue, subtype: nil), "swallows event type \(type.rawValue)")
            check(KeyFilter.eventMask & (CGEventMask(1) << type.rawValue) != 0, "taps event type \(type.rawValue)")
        }
        for type in [CGEventType.leftMouseDown, .leftMouseUp, .rightMouseDown, .mouseMoved, .scrollWheel, .otherMouseDown] {
            check(!KeyFilter.shouldSwallow(type: type.rawValue, subtype: nil), "lets pointer event \(type.rawValue) through")
            check(KeyFilter.eventMask & (CGEventMask(1) << type.rawValue) == 0, "never taps pointer event \(type.rawValue)")
        }
        check(KeyFilter.shouldSwallow(type: KeyFilter.systemDefined, subtype: 8), "swallows volume, brightness and media keys")
        check(KeyFilter.shouldSwallow(type: KeyFilter.systemDefined, subtype: 1), "swallows the power key")
        check(KeyFilter.shouldSwallow(type: KeyFilter.systemDefined, subtype: 10), "swallows eject")
        check(!KeyFilter.shouldSwallow(type: KeyFilter.systemDefined, subtype: 7), "lets extra mouse buttons through")
        check(!KeyFilter.shouldSwallow(type: KeyFilter.systemDefined, subtype: nil), "lets unreadable system events through")

        let media = NSEvent.otherEvent(
            with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, subtype: 8, data1: 0, data2: 0
        )?.cgEvent
        check(media.flatMap(KeyFilter.subtype) == 8, "reads the media-key subtype off a real event")
        let key = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        check(key.map { KeyFilter.subtype(of: $0) == nil } ?? false, "skips the subtype on key events")

        check(Critter.art.count == 16 && Critter.art.allSatisfy { $0.count == 16 }, "critter art is 16×16")
        for mood in Mood.allCases {
            let grid = Critter.grid(mood: mood, blink: true)
            check(grid.count == 16 && grid.allSatisfy { $0.count == 16 }, "builds the \(mood) critter")
        }

        print(failures == 0 ? "selftest passed" : "selftest FAILED (\(failures))")
        return failures == 0
    }
}
