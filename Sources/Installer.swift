import AppKit
import Carbon
import ServiceManagement

final class Installer: NSObject, NSApplicationDelegate {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

    private var window: NSWindow!
    private let status = NSTextField(wrappingLabelWithString: "")
    private let layoutSwitch = NSSwitch()
    private let swapSwitch = NSSwitch()
    private let startupSwitch = NSSwitch()
    private let colemakID = "io.github.colemakmods.keyboardlayout.colemakdh.keylayout.ColemakDHANSI"
    private var layout: URL {
        Bundle.main.resourceURL!.appendingPathComponent("Colemak DH.bundle")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        let title = NSTextField(labelWithString: "Colemak-DH")
        title.font = .boldSystemFont(ofSize: 28)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "Two independent switches. Colemak-DH is a native macOS input source; the Caps Lock / Backspace swap works with any layout."))
        layoutSwitch.target = self
        layoutSwitch.action = #selector(toggleLayout)
        stack.addArrangedSubview(row("Colemak-DH layout (ANSI)", layoutSwitch))
        swapSwitch.target = self
        swapSwitch.action = #selector(toggleSwap)
        stack.addArrangedSubview(row("Swap Caps Lock and Backspace", swapSwitch))
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "Your last settings are restored whenever this app opens. The key swap affects all keyboards and input sources, including passwords. It will not replace existing HID remaps."))
        startupSwitch.target = self
        startupSwitch.action = #selector(toggleStartup)
        stack.addArrangedSubview(row("Start at login", startupSwitch))
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "Opens this app and restores your last settings when you sign in. Move the app to Applications before enabling this. macOS may require approval in Login Items settings."))
        stack.addArrangedSubview(NSButton(title: "Install Colemak-DH for my account", target: self, action: #selector(install)))
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "After installing, log out and back in. Then turn on the Colemak-DH switch. Keep another input source enabled to switch back."))
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "For password dialogs and the login screen, install system-wide instead: reveal the bundle below, then copy it in Finder to /Library/Keyboard Layouts (administrator approval required). Log out and back in afterward."))
        stack.addArrangedSubview(NSButton(title: "Show layout in Finder", target: self, action: #selector(reveal)))
        stack.addArrangedSubview(status)

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 550, height: 620), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Colemak-DH Installer"
        stack.frame = window.contentView!.bounds
        stack.autoresizingMask = [.width, .height]
        window.contentView = stack
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        layoutSwitch.state = InputSource.id(TISCopyCurrentKeyboardInputSource().takeRetainedValue()) == colemakID ? .on : .off
        startupSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let swapState = KeySwap.state()
        swapSwitch.state = swapState == .on ? .on : .off
        if swapState == .conflict || swapState == .unavailable {
            swapSwitch.isEnabled = false
            status.stringValue = "Existing HID remaps or an unreadable keyboard were found. The swap is unavailable; no remaps were changed."
        }
        var messages = status.stringValue.isEmpty ? [] : [status.stringValue]
        SavedSettings.restore(defaults: defaults, layoutEnabled: layoutSwitch.state == .on, swapState: swapState,
                              applyLayout: { enabled in
            self.layoutSwitch.state = enabled ? .on : .off
            self.toggleLayout()
            messages.append(self.status.stringValue)
        }, applySwap: { enabled in
            self.swapSwitch.state = enabled ? .on : .off
            self.toggleSwap()
            messages.append(self.status.stringValue)
        })
        status.stringValue = messages.joined(separator: "\n")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        startupSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleStartup() {
        let service = SMAppService.mainApp
        let enable = startupSwitch.state == .on
        do {
            if enable {
                if service.status != .enabled && service.status != .requiresApproval {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
            status.stringValue = enable ? "Start at login requested." : "Start at login disabled."
        } catch {
            status.stringValue = "Could not change start at login: \(error.localizedDescription)"
        }
        startupSwitch.state = service.status == .enabled ? .on : .off
        if enable && service.status == .requiresApproval {
            status.stringValue = "Approve Colemak-DH Installer in System Settings → General → Login Items & Extensions."
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func row(_ label: String, _ toggle: NSSwitch) -> NSStackView {
        let row = NSStackView(views: [NSTextField(labelWithString: label), toggle])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    @objc private func toggleLayout() {
        let sources = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        if layoutSwitch.state == .on {
            guard let colemak = sources.first(where: { InputSource.id($0) == colemakID }) else {
                status.stringValue = "Install the layout, log out and back in, then try again."
                layoutSwitch.state = .off
                return
            }
            if !InputSource.isEnabled(colemak) && TISEnableInputSource(colemak) != noErr {
                status.stringValue = "Could not enable Colemak-DH in Keyboard settings."
                layoutSwitch.state = .off
                return
            }
            guard TISSelectInputSource(colemak) == noErr else {
                status.stringValue = "Could not select Colemak-DH. Try adding it in Keyboard settings."
                layoutSwitch.state = .off
                return
            }
            defaults.set(InputSource.id(current), forKey: "previousInputSource")
            status.stringValue = "Colemak-DH selected."
        } else {
            let previous = defaults.string(forKey: "previousInputSource")
            guard let target = sources.first(where: { InputSource.id($0) == previous }), TISSelectInputSource(target) == noErr else {
                status.stringValue = "Select another input source from the macOS input menu to turn Colemak-DH off."
                layoutSwitch.state = .on
                return
            }
            status.stringValue = "Previous input source restored."
        }
        defaults.set(layoutSwitch.state == .on, forKey: "layoutEnabled")
    }

    @objc private func toggleSwap() {
        do {
            try KeySwap.setEnabled(swapSwitch.state == .on)
            defaults.set(swapSwitch.state == .on, forKey: "swapEnabled")
            status.stringValue = swapSwitch.state == .on ? "Swap enabled and remembered. Test both keys in TextEdit before typing passwords." : "Caps Lock and Backspace swap disabled and remembered."
        } catch {
            swapSwitch.state = KeySwap.state() == .on ? .on : .off
            status.stringValue = error.localizedDescription
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([layout])
    }

    @objc private func install() {
        guard FileManager.default.fileExists(atPath: layout.path) else {
            status.stringValue = "The layout is missing from the app. Rebuild and try again."
            return
        }
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Keyboard Layouts", isDirectory: true)
        let destination = directory.appendingPathComponent(layout.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            status.stringValue = "Colemak DH is already installed for this account. Nothing was overwritten."
            return
        }
        let temporary = directory.appendingPathComponent(".Colemak DH-\(UUID().uuidString).bundle")
        defer { try? FileManager.default.removeItem(at: temporary) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: layout, to: temporary)
            try FileManager.default.moveItem(at: temporary, to: destination)
            status.stringValue = "Installed. Log out and back in, then add Colemak DH in Keyboard settings."
        } catch {
            status.stringValue = "Installation failed: \(error.localizedDescription)"
        }
    }
}

