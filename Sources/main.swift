import AppKit

let app = NSApplication.shared
let installer = Installer()
app.delegate = installer
app.run()
