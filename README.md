# Colemak-DH + key swap for macOS

A small native app with two independent switches: **Colemak-DH ANSI** as the current input source, and **Caps Lock ↔ Backspace** on all input sources. The layout is the official Colemak-DH macOS bundle, not a background key interceptor; it also includes ISO, Matrix, and extended variants with Shift/Option and dead-key layers.

## Build and use

Requires macOS 13+ and Apple's Command Line Tools (`xcode-select --install`).

```fish
./build.sh
open .build/Colemak-DH-Installer.app
```

Click **Install Colemak-DH for my account**, log out and back in, then turn on the Colemak-DH switch. The app enables and selects the ANSI layout; turning it off restores the input source that was active before you turned it on. Keep another input source enabled. For ISO or Matrix keyboards, add the matching bundled layout from **System Settings → Keyboard → Text Input → Edit → + → English** instead (the app's layout switch selects ANSI only).

The separate key-swap switch uses macOS `hidutil` to swap the physical Caps Lock and Backspace keys. The mapping is intended to take effect immediately for all keyboards and layouts, including password inputs; turning it off clears the swap configuration. Test both physical keys in TextEdit before relying on it: reading the saved HID property does not prove that macOS delivers the remapped key events. **macOS clears the swap on reboot**, but this app remembers your last successfully applied layout and swap settings and restores them whenever it opens. On first launch it adopts the current settings instead of forcing anything on. Failed restores keep the saved preference for the next launch. If other HID key remaps are present or cannot be read, the app refuses to modify them. It does not request Accessibility access. Recent macOS versions may require **Input Monitoring** permission for `hidutil`; this is separate from Accessibility.

### Start at login

Copy the built app into `~/Applications` or `/Applications`, open that copy, and enable **Start at login**. This uses macOS's native login-item support; approve it in **System Settings → General → Login Items & Extensions** if prompted. Turn the switch off to remove the login item. If you move the app afterward, turn the option off before moving it and back on from the new location.

The app opens after you sign in and restores your saved layout and swap settings. It does not remap keys before login. Closing its window quits the app but leaves the applied keyboard settings and login item in place. Actual launch-at-login behavior and physical key behavior require a real sign-out/sign-in test; the automated checks do not register a login item or change your keyboard.

**Password dialogs / login screen:** macOS can fall back to another layout for sensitive inputs when a layout is installed only for one user. To install system-wide instead, click **Show layout in Finder**, copy `Colemak DH.bundle` into `/Library/Keyboard Layouts` (Finder will ask for administrator approval), then log out and back in and add the layout as above. Don't install the same bundle in both locations. This installer does not alter existing layouts.

## If typing or the swap does not work

- **Layout added but still QWERTY:** adding a layout enables it; it does not necessarily select it. Select **Colemak DH ANSI** from the macOS input menu or turn on the app's layout switch. Test in a normal TextEdit document (not a password field). Physical QWERTY `asdf` should type `arst`.
- **Backspace toggles Caps Lock but Caps Lock does not delete:** check **System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys**, select the affected keyboard, and make sure Caps Lock is not set to **No Action** or another modifier. Check Logi Options+ and Karabiner for overlapping remaps; use only one tool for the swap. Do not delete their existing configurations.
- If that does not help, open **System Settings → Privacy & Security → Input Monitoring**, use **+** and Finder's **Go to Folder** (`Command-Shift-G`) to add `/usr/bin/hidutil`. If the installer is listed, allow it too. Quit/reopen the installer and switch the swap off, then on. Permission and effective behavior must be checked on your macOS version; a successful `hidutil` write alone is not sufficient.

Run the checks (fish):

```fish
python3 -m unittest discover -s tests -v
swiftc -assert-config Debug Sources/KeySwap.swift tests/KeySwapTests.swift -o .build/key-swap-tests; and .build/key-swap-tests
swiftc -assert-config Debug Sources/InputSource.swift tests/InputSourceTests.swift -framework Carbon -o .build/input-source-tests; and .build/input-source-tests
swiftc Sources/KeySwap.swift Sources/SavedSettings.swift tests/SavedSettingsTests.swift -o .build/saved-settings-tests; and .build/saved-settings-tests
swiftc Sources/Installer.swift Sources/KeySwap.swift Sources/InputSource.swift Sources/SavedSettings.swift tests/StartupTests.swift -framework AppKit -framework Carbon -framework ServiceManagement -o .build/startup-tests; and .build/startup-tests
```

These verify the layout mapping, remap parsing, real macOS input-source property reads, saved-setting restoration decisions (including conflicting/unreadable remaps), and startup-switch state refresh without modifying your keyboard or login items. The UI check saves a preview to `.build/startup-ui.png`. Physical key behavior still requires the TextEdit check above.

The input-menu icon is a white keyboard outline on a transparent background, with native 16px and Retina 32px versions for every layout variant. Regenerate it with `swift tools/generate-menu-icon.swift`, then rebuild. If an older bundle is already installed, replace only its `.icns` files with the new ones from `Vendor/Colemak DH.bundle/Contents/Resources/`; the installer intentionally does not overwrite existing bundles. macOS stores the icon artwork inside `com.apple.IntlDataCache.le.kbdx` in the directory reported by `getconf DARWIN_USER_CACHE_DIR`. This cache can survive a restart, so replacing the `.icns` files or restarting `TextInputMenuAgent` alone may leave the old icon visible. If it persists, back up and remove only `com.apple.IntlDataCache.le` and `com.apple.IntlDataCache.le.kbdx` from that cache directory, then restart `TextInputMenuAgent` to rebuild them. Do not remove keyboard preferences or layout files. The icon is fixed white, so it is intended for a dark menu bar.

The keyboard layout bundle (with locally replaced icons) is from [ColemakMods/mod-dh](https://github.com/ColemakMods/mod-dh), commit `d9398d57695089658841f3dc62827ae814aef8c4`, under CC0 (see `Vendor/LICENSE`). The installer itself is built locally and ad-hoc signed, not notarized or distributed as a prebuilt download.
