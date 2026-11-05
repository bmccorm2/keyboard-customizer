import Carbon
import Foundation

@main
struct InputSourceTests {
    static func main() {
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        precondition(InputSource.id(current)?.isEmpty == false)
        precondition(InputSource.isEnabled(current))
        let filter = [kTISPropertyInputSourceID as String: "com.apple.keylayout.US"] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as! [TISInputSource]
        precondition(!sources.isEmpty)
        for source in sources {
            precondition(InputSource.id(source) == "com.apple.keylayout.US")
            let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled)!
            let enabled = Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue()
            precondition(InputSource.isEnabled(source) == CFBooleanGetValue(enabled))
        }
        print("Input source checks passed (no settings changed)")
    }
}
