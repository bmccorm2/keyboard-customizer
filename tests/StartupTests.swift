import AppKit
import ServiceManagement

@main
struct StartupTests {
    static func main() throws {
        let app = NSApplication.shared
        let suite = "StartupTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let installer = Installer(defaults: defaults)
        installer.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        let window = app.windows.first { $0.title == "Colemak-DH Installer" }!
        let stack = window.contentView as! NSStackView
        let row = stack.arrangedSubviews.compactMap { $0 as? NSStackView }.first {
            ($0.arrangedSubviews.first as? NSTextField)?.stringValue == "Start at login"
        }!
        let toggle = row.arrangedSubviews.last as! NSSwitch
        precondition(toggle.target === installer)
        precondition(toggle.action == NSSelectorFromString("toggleStartup"))
        let state = SMAppService.mainApp.status == .enabled ? NSControl.StateValue.on : .off
        precondition(toggle.state == state)
        toggle.state = state == .on ? .off : .on
        installer.applicationDidBecomeActive(Notification(name: NSApplication.didBecomeActiveNotification))
        precondition(toggle.state == state, "Refresh the switch after returning from System Settings")

        // Exercise the already-set state without registering or removing a login item.
        if SMAppService.mainApp.status == .notRegistered || SMAppService.mainApp.status == .enabled {
            precondition(app.sendAction(toggle.action!, to: installer, from: toggle))
            precondition(toggle.state == state)
        }
        stack.layoutSubtreeIfNeeded()
        let bitmap = stack.bitmapImageRepForCachingDisplay(in: stack.bounds)!
        stack.cacheDisplay(in: stack.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: ".build/startup-ui.png"))
        print("Startup UI/state checks passed; screenshot: .build/startup-ui.png (no login settings changed)")
    }
}
