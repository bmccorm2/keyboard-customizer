import Foundation

enum SavedSettings {
    static func restore(defaults: UserDefaults, layoutEnabled: Bool, swapState: KeySwap.State,
                        applyLayout: (Bool) -> Void, applySwap: (Bool) -> Void) {
        if let enabled = defaults.object(forKey: "layoutEnabled") as? Bool {
            if enabled != layoutEnabled { applyLayout(enabled) }
        } else {
            defaults.set(layoutEnabled, forKey: "layoutEnabled")
        }
        // Never alter unknown remaps, or erase a saved preference when a keyboard is unavailable.
        guard swapState == .on || swapState == .off else { return }
        let swapEnabled = swapState == .on
        if let enabled = defaults.object(forKey: "swapEnabled") as? Bool {
            if enabled != swapEnabled { applySwap(enabled) }
        } else {
            defaults.set(swapEnabled, forKey: "swapEnabled")
        }
    }
}
