# FanControl 🇺🇸

<p align="center">
  <a href="../README.md">🏠 Home</a> ·
  <a href="README.pt-BR.md">🇧🇷 Português</a> ·
  <a href="README.es.md">🇪🇸 Español</a>
</p>

---

Native fan control for **MacBook Pro 14" M1 Pro (2021, `MacBookPro18,3`)**.

A replacement for [crystalidea's Macs Fan Control](https://github.com/crystalidea/macs-fan-control), with 5 features it doesn't have: **multi-step curves with hysteresis**, **4 named presets** (Silent / Balanced / Performance / Max), **menu bar icon** with compact popover, **license-key gated curve editor**, and a **native macOS Liquid Glass UI** (not Qt).

> ⚠️ **Hardware-locked.** Runs only on `MacBookPro18,3`. Other models boot in read-only mode.

## Features

- 📊 **Real-time readings** of RPM, duty cycle, and CPU temperature (1Hz refresh)
- 🎛️ **4 presets** clickable (Silent 35%, Balanced=Auto, Performance 70%, Max 100%)
- 📈 **Curve editor** with 2-6 steps (temp → duty), SVG graph with hover labels and danger zone
- 🌡️ **Curve mode** with 1.5s control loop applying 3°C hysteresis
- 🛡️ **Safety override** forces fans to max if CPU exceeds 95°C for 3 consecutive ticks
- 🎯 **Watchdog** reverts to Auto if the control loop stalls for more than 5s
- 📍 **Menu bar icon** with dynamic tooltip `<temp>°C · <RPM>`
- 🪟 **Compact popover** on click (presets without opening the full window)
- 🔒 **Activation key** to unlock the curve editor
- ⌨️ **Keyboard shortcuts**: ⌘1=Silent, ⌘2=Balanced, ⌘3=Performance, ⌘4=Max, ⌘E=editor

## Architecture

```
FanControl.app  ──── NSXPCConnection ────→  FanControlHelper (root LaunchDaemon)
   (sandbox)            (validated)            │
                                                ├─ SMCReader/Writer (IOKit)
                                                ├─ TemperatureReader (SMC + IOHID fallback)
                                                ├─ ControlLoop (1.5s tick)
                                                ├─ Hysteresis (3°C bidirectional)
                                                ├─ SafetyOverride (>95°C × 3 ticks → Mx)
                                                └─ Watchdog (5s stall → revert to Auto)
```

| Component             | Path                          | What                                                                  |
| --------------------- | ----------------------------- | --------------------------------------------------------------------- |
| `FanControl.app`      | `App/`                        | SwiftUI window 360×640 + menu bar item, sandbox, talks via XPC        |
| `FanControlHelper`    | `Helper/`                     | LaunchDaemon root, owns SMC reads/writes + control loop + watchdog    |
| `Shared/`             | `Shared/`                     | Codable types + pure-logic algorithms (`Curve`, `CurveInterpolator`)  |

## Prerequisites

- macOS 14 Sonoma or higher
- **Xcode 16+** (full IDE — Command Line Tools alone cannot run XCTest or `xcodebuild`)
- `xcodegen` via Homebrew

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
brew install xcodegen
```

## Build & run

```bash
# 1. Generate Xcode project from project.yml
cd /Users/jeversonmisael/Documents/codigos/Macfancontrol
xcodegen generate

# 2. Open in Xcode
open FanControl.xcodeproj

# 3. Build & run (⌘R) — target FanControl
#    First run: macOS will ask for admin password to install the privileged helper.

# Or via command line:
xcodebuild -scheme FanControl -destination 'platform=macOS' build
```

## Unlocking the curve editor

The curve editor is protected by an activation key:

1. Open the app
2. At the bottom of the window, click **🔒 Unlock fan curve**
3. Enter the provided activation key
4. After validation, the editor stays permanently unlocked (persists in `~/Library/Application Support/FanControl/state.json`)

> **Note**: the unlock state is stored in `state.json` as a boolean flag. To re-lock, delete the file.

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘1` | Silent preset |
| `⌘2` | Balanced preset |
| `⌘3` | Performance preset |
| `⌘4` | Max preset |
| `⌘E` | Curve editor (or unlock if locked) |
| `⌘0` | Show main window |
| `⌘W` | Close window (helper keeps running) |
| `⌘Q` | Quit app (helper keeps running) |

## Menu bar

**Left-click** on the menu bar icon opens the compact popover. **Right-click** opens the native menu:

- **Show Window** — brings the main window forward
- **Edit fan curve…** — opens the editor (or unlock sheet if locked)
- **Menu bar only** — toggle to hide the Dock icon
- **Open System Settings…** — opens Login Items
- **Quit FanControl** — quits the app

## Manual uninstallation (last resort)

```bash
sudo launchctl unload /Library/LaunchDaemons/com.fancontrol.helper.plist
sudo rm /Library/LaunchDaemons/com.fancontrol.helper.plist
sudo rm -rf /Library/Application\ Support/FanControl
sudo rm /Library/PrivilegedHelperTools/com.fancontrol.helper
rm -rf ~/Library/Application\ Support/FanControl
trash /Applications/FanControl.app
```

After unload, the fans return to macOS Auto control within ~5 seconds.

## Logs

```bash
log stream --predicate 'subsystem == "com.fancontrol.helper"' --info
# Or via app menu → "Open logs in Console…"
```

## Credits

- SMC key table reverse-engineered by [crystalidea/macs-fan-control](https://github.com/crystalidea/macs-fan-control) (LGPL).
- Apple Silicon temperature sensor patterns documented by [exelban/stats](https://github.com/exelban/stats) (MIT).

## Project status

**MVP working on real hardware.** Curves apply, presets work, menu bar icon is alive, license gate is operational. Code is on `main`. Tests (XCTest) live locally (not included in the repository).
