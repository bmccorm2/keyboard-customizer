import Foundation

@main
struct KeySwapTests {
    static func main() {
        let empty = "RegistryID  Key  Value\n1000   UserKeyMapping   (\n)\n1001   UserKeyMapping   (null)"
        precondition(KeySwap.state(from: empty) == .off)
        let active = """
        RegistryID  Key  Value
        1000   UserKeyMapping   (
            {
                HIDKeyboardModifierMappingDst = 30064771114;
                HIDKeyboardModifierMappingSrc = 30064771129;
            },
            {
                HIDKeyboardModifierMappingDst = 30064771129;
                HIDKeyboardModifierMappingSrc = 30064771114;
            }
        )
        """
        precondition(KeySwap.state(from: active) == .on)
        precondition(KeySwap.state(from: active.replacingOccurrences(of: "30064771114;", with: "30064771115;")) == .conflict)
        precondition(KeySwap.state(from: active + "\n1001   UserKeyMapping   (\n    { HIDKeyboardModifierMappingSrc = 42; HIDKeyboardModifierMappingDst = 43; }\n)") == .conflict)
        precondition(KeySwap.state(from: "garbled") == .unavailable)
        precondition(KeySwap.mapping.count == 2)
        print("Key swap checks passed")
    }
}
