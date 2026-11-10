import AppKit

/// Launch flags for QA and the build script; none exist for end users.
enum LaunchFlags {
    private static let args = CommandLine.arguments

    static let selftest = args.contains("--selftest")
    static let startCleaning = args.contains("--clean")
    static let light = args.contains("--light")
    static let iconsetPath = value(after: "--write-iconset")
    static let unlockAfter = value(after: "--unlock-after").flatMap(TimeInterval.init)

    private static func value(after flag: String) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var session: CleaningSession!
    private var statusItem: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if LaunchFlags.light { NSApp.appearance = NSAppearance(named: .aqua) }
        session = CleaningSession()
        statusItem = StatusItemController(session: session)
        if LaunchFlags.startCleaning, session.start() { return }
        // Wait for the status item to be laid out so the panel can hang under it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.statusItem.openPanel()
        }
    }

    /// Launching it again from Spotlight or Raycast is the way back in when the
    /// menu bar is too full to show the critter.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem.openPanel()
        return false
    }
}

if LaunchFlags.selftest { exit(SelfTest.run() ? 0 : 1) }
if let path = LaunchFlags.iconsetPath { exit(IconWriter.write(to: path) ? 0 : 1) }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
