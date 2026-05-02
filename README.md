# FanControl

Native macOS fan control for **MacBook Pro 14" M1 Pro (2021, `MacBookPro18,3`)**.

Replacement for [crystalidea/macs-fan-control](https://github.com/crystalidea/macs-fan-control), with three things it doesn't have: multi-step fan curves with hysteresis, named MVP presets (Silent / Balanced / Performance / Max), and a native macOS Liquid Glass UI that doesn't look like Qt.

> ⚠️ **Hardware-locked.** Runs only on `MacBookPro18,3`. Other models boot in read-only mode.

## What's inside

| Component             | Path                          | What                                                                  |
| --------------------- | ----------------------------- | --------------------------------------------------------------------- |
| `FanControl.app`      | `App/`                        | SwiftUI window 360×640, sandboxed, talks to helper via XPC            |
| `FanControlHelper`    | `Helper/`                     | LaunchDaemon root, owns SMC reads/writes + control loop + watchdog    |
| `Shared/`             | `Shared/`                     | Codable types + pure-logic algorithms (`Curve`, `CurveInterpolator`)  |
| Design source         | `FanControl/`                 | React/JSX reference UI — DO NOT MODIFY, used for visual fidelity      |
| OpenSpec change       | `openspec/changes/.../`       | Spec-driven proposal + design + 5 capability specs + 199 tasks        |

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

## Status

**MVP scaffold complete; implementation underway.** See `openspec/changes/implement-fan-control-mvp/tasks.md` for the full 199-task checklist.

What's done:
- Full Swift source tree (App + Helper + Shared)
- All algorithms (curve interpolation, hysteresis, safety override, FPE2, model detection)
- XPC plumbing (HelperProtocol, NSXPCConnection client/server, signing validation)
- Curve editor SwiftUI views (graph, NumStepper, validation)
- Preset grid + window shell (FCWindow, traffic lights, sections, theme)
- Test bodies covering all pure-logic decisions

What's pending:
- Smoke testing on real hardware (requires Xcode + the M1 Pro)
- Visual fidelity tuning (compare to JSX reference, Screenshot pin)
- IOHID temperature fallback (currently SMC-only on MacBookPro18,3 — works fine)

## Build prerequisites

You need **full Xcode 16+** (not just Command Line Tools — XCTest and `xcodebuild` need the full IDE):

```bash
# Install Xcode from the Mac App Store, then:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept

# Install xcodegen (generates the .xcodeproj from project.yml):
brew install xcodegen
```

## Build & run

```bash
# 1. Generate Xcode project from project.yml
cd /Users/jeversonmisael/Documents/codigos/Macfancontrol
xcodegen generate

# 2. Open in Xcode
open FanControl.xcodeproj

# 3. Build & run (⌘R) — target FanControl scheme
#    First run: macOS will ask for admin password to install the helper.

# OR via command line:
xcodebuild -scheme FanControl -destination 'platform=macOS' build
xcodebuild -scheme FanControl -destination 'platform=macOS' test
```

## Headless TDD via SPM

The pure-logic Shared module compiles without Xcode (Command Line Tools is enough):

```bash
swift build   # compiles Shared/
# Tests need Xcode (XCTest is bundled there, not in CLT). Run via Xcode ⌘U.
```

## Manual uninstall (last resort)

```bash
sudo launchctl unload /Library/LaunchDaemons/com.fancontrol.helper.plist
sudo rm /Library/LaunchDaemons/com.fancontrol.helper.plist
sudo rm -rf /Library/Application\ Support/FanControl
rm -rf ~/Library/Application\ Support/FanControl
trash /Applications/FanControl.app  # or move via Finder
```

After unload, fans return to macOS-controlled Auto in ~5 seconds (the SMC scheduler reclaims `F0Md` once nobody is reasserting it).

## Logs

```bash
log stream --predicate 'subsystem == "com.fancontrol.helper"' --info
# Or use the app menu → "Open logs in Console…"
```

## Credits

- SMC key table reverse-engineered by [crystalidea/macs-fan-control](https://github.com/crystalidea/macs-fan-control) (LGPL — keys are constants, reuse permitted).
- Apple Silicon temperature sensor patterns documented by [exelban/stats](https://github.com/exelban/stats) (MIT).

## Spec source

Everything in this repo derives from `openspec/changes/implement-fan-control-mvp/`:

- `proposal.md` — why & what
- `design.md` — 16 architectural decisions with trade-offs
- `specs/{app-shell,sensor-monitoring,fan-control,curve-editor,privileged-helper}/spec.md` — testable requirements
- `tasks.md` — 199-task implementation checklist with TDD markers
