import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panel: PanelController

    init(session: CleaningSession) {
        panel = PanelController(session: session)
        super.init()
        guard let button = item.button else { return }
        button.image = Critter.image(mood: .happy, points: 16)
        button.imagePosition = .imageOnly
        button.toolTip = "Scrubby"
        button.setAccessibilityLabel("Scrubby")
        button.target = self
        button.action = #selector(clicked)
    }

    func openPanel() {
        if let button = item.button { panel.open(below: button) }
    }

    @objc private func clicked() {
        if let button = item.button { panel.toggle(below: button) }
    }
}
