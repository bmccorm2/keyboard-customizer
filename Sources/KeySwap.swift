import Foundation

enum KeySwap {
    // HID usage page 0x07: Caps Lock 0x39, Backspace 0x2a.
    static let caps: UInt64 = 0x700000039
    static let backspace: UInt64 = 0x70000002a
    static let mapping = [
        ["HIDKeyboardModifierMappingSrc": caps, "HIDKeyboardModifierMappingDst": backspace],
        ["HIDKeyboardModifierMappingSrc": backspace, "HIDKeyboardModifierMappingDst": caps]
    ]

    enum State { case off, on, conflict, unavailable }

    static func state(from output: String) -> State {
        guard output.contains("UserKeyMapping") else { return .unavailable }
        let blocks = matches(#"UserKeyMapping\s+\((.*?)\)"#, in: output, options: [.dotMatchesLineSeparators])
        guard !blocks.isEmpty else { return .off }
        var found = false
        for block in blocks {
            let entries = matches(#"\{([^}]*)\}"#, in: block)
            if entries.isEmpty {
                if !["", "null"].contains(block.trimmingCharacters(in: .whitespacesAndNewlines)) { return .conflict }
                continue
            }
            found = true
            guard entries.count == 2 else { return .conflict }
            let pairs = entries.compactMap { entry -> [String: UInt64]? in
                let fields = matches(#"(HIDKeyboardModifierMapping(?:Src|Dst))\s*=\s*(0x[0-9a-fA-F]+|[0-9]+)"#, in: entry, capture: false)
                guard fields.count == 2 else { return nil }
                var result = [String: UInt64]()
                for field in fields {
                    let parts = field.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
                    let value = parts[1]
                    result[parts[0]] = value.hasPrefix("0x") ? UInt64(value.dropFirst(2), radix: 16) : UInt64(value)
                }
                return result
            }
            guard pairs.count == 2 && Set(pairs.map { $0["HIDKeyboardModifierMappingSrc"] }) == Set([caps, backspace]) &&
                    pairs.allSatisfy({ $0["HIDKeyboardModifierMappingDst"] == ($0["HIDKeyboardModifierMappingSrc"] == caps ? backspace : caps) }) else { return .conflict }
        }
        return found ? .on : .off
    }

    private static func matches(_ pattern: String, in text: String, options: NSRegularExpression.Options = [], capture: Bool = true) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: capture ? $0.numberOfRanges - 1 : 0), in: text).map { String(text[$0]) }
        }
    }

    private static func run(_ args: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        task.arguments = ["property"] + args
        let output = Pipe()
        task.standardOutput = output
        task.standardError = output
        try task.run()
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw NSError(domain: "hidutil", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: text]) }
        return text
    }

    static func state() -> State {
        guard let output = try? run(["--matching", "keyboard", "--get", "UserKeyMapping"]) else { return .unavailable }
        return state(from: output)
    }

    static func setEnabled(_ enabled: Bool) throws {
        let current = state()
        guard current == (enabled ? .off : .on) else {
            throw NSError(domain: "KeySwap", code: 1, userInfo: [NSLocalizedDescriptionKey: "Existing or unreadable keyboard remaps were found; no keys were changed."])
        }
        let json = try JSONSerialization.data(withJSONObject: ["UserKeyMapping": enabled ? mapping : []])
        _ = try run(["--set", String(decoding: json, as: UTF8.self)])
        guard state() == (enabled ? .on : .off) else {
            throw NSError(domain: "KeySwap", code: 2, userInfo: [NSLocalizedDescriptionKey: "hidutil ran, but the swap could not be confirmed. Check your keyboard before typing passwords."])
        }
    }
}
