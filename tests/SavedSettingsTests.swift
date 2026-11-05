import Foundation

@main
struct SavedSettingsTests {
    static func main() {
        let suite = "SavedSettingsTests.\(UUID().uuidString)"
        func defaults() -> UserDefaults { UserDefaults(suiteName: suite)! }
        defer { defaults().removePersistentDomain(forName: suite) }
        var layoutChanges: [Bool] = []
        var swapChanges: [Bool] = []
        func restore(layout: Bool, swap: KeySwap.State) {
            SavedSettings.restore(defaults: defaults(), layoutEnabled: layout, swapState: swap,
                                  applyLayout: { layoutChanges.append($0) }, applySwap: { swapChanges.append($0) })
        }
        restore(layout: true, swap: .on)
        precondition(layoutChanges.isEmpty && swapChanges.isEmpty, "First launch adopts current settings")
        precondition(defaults().bool(forKey: "layoutEnabled") && defaults().bool(forKey: "swapEnabled"))
        // A new defaults object models a relaunch after reboot clears the HID mapping.
        restore(layout: false, swap: .off)
        precondition(layoutChanges == [true] && swapChanges == [true])
        layoutChanges = []; swapChanges = []
        restore(layout: true, swap: .on)
        precondition(layoutChanges.isEmpty && swapChanges.isEmpty, "Already-applied settings need no writes")
        for state in [KeySwap.State.conflict, .unavailable] {
            restore(layout: true, swap: state)
            precondition(swapChanges.isEmpty && defaults().bool(forKey: "swapEnabled"))
        }
        // An unsuccessful apply must leave the desired setting intact for the next launch.
        restore(layout: false, swap: .off)
        precondition(defaults().bool(forKey: "layoutEnabled") && defaults().bool(forKey: "swapEnabled"))
        defaults().set(false, forKey: "layoutEnabled")
        defaults().set(false, forKey: "swapEnabled")
        layoutChanges = []; swapChanges = []
        restore(layout: true, swap: .on)
        precondition(layoutChanges == [false] && swapChanges == [false], "Remember disabled settings too")
        defaults().removePersistentDomain(forName: suite)
        swapChanges = []
        restore(layout: false, swap: .conflict)
        precondition(defaults().object(forKey: "swapEnabled") == nil && swapChanges.isEmpty)
        print("Saved settings checks passed (no keyboard or login settings changed)")
    }
}
