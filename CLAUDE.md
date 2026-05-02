# Macfancontrol Project — Conventions for Claude Code

This project is a native macOS fan control app for `MacBookPro18,3`, written in Swift + SwiftUI with a privileged helper LaunchDaemon. The full design specification lives under `openspec/changes/implement-fan-control-mvp/`.

## Project layout

```
Macfancontrol/
├── App/                 SwiftUI app (sandboxed UI, talks to helper via XPC)
│   ├── FanControlApp.swift     @main entry point
│   ├── Window/                 FCWindow, FCSection, FCDivider, FCTrafficLights
│   ├── Theme/                  Colors, Fonts (mirrors atoms.jsx tokens)
│   ├── Views/                  MainView, FanRow, PresetGrid, PresetButton
│   ├── Views/CurveEditor/      CurveEditorView, CurveGraph, NumStepper
│   ├── State/                  AppState (@Observable), SensorViewModel, StateStore, LogConsole
│   └── XPC/                    HelperClient (NSXPCConnection wrapper)
├── Helper/              Root LaunchDaemon (owns SMC + control loop)
│   ├── HelperMain.swift        @main, boots subsystems + listener
│   ├── HelperService.swift     Implements HelperProtocol (XPC interface)
│   ├── HelperLogger.swift      os.Logger wrappers
│   ├── SMC/                    FPE2, SMCKey, SMCReader, SMCWriter, SMCError
│   ├── Sensors/                TemperatureReader, SnapshotBuilder, SensorPoller, ModelDetector
│   ├── Control/                ControlLoop, Hysteresis, SafetyOverride, ModeManager, ConfigStore, Watchdog
│   ├── XPC/                    XPCConnectionValidator (signature + bundle ID validation)
│   └── com.fancontrol.helper.plist  LaunchDaemon plist
├── Shared/              Pure-logic types (Codable). Compiled into both targets and SPM.
│   ├── HelperProtocol.swift    @objc protocol shared between app and helper
│   ├── SharedTypes.swift       SensorSnapshot, ControlMode, Curve, CurveStep, Preset, HelperError, ControlConfig
│   ├── CurveValidator.swift    Pure validation logic
│   └── CurveInterpolator.swift Pure linear interpolation + duty→RPM
├── Tests/               XCTest. SPM cannot run these (CLT lacks XCTest). Use Xcode ⌘U.
│   ├── HelperProtocolTests/    Ping + signing validator
│   ├── SMCTests/               FPE2, SMCKey encoding, mock reader
│   ├── SensorsTests/           TemperatureReader, SnapshotBuilder
│   ├── ControlTests/           Hysteresis, SafetyOverride, ControlLoop integration
│   ├── CurveTests/             CurveValidator, CurveInterpolator, Preset
│   ├── UI/                     SwiftUI snapshot tests (later phase)
│   └── Persistence/            StateStore, ControlConfigStore (later phase)
├── FanControl/          REFERENCE-ONLY React/JSX design. Do NOT modify or link as bundle resource.
├── openspec/            Spec-driven workflow artifacts.
├── project.yml          xcodegen project specification (generates FanControl.xcodeproj)
├── Package.swift        SPM manifest (Shared module only)
└── README.md            User-facing docs
```

## Conventions

### Use OpenSpec for non-trivial changes
Any change beyond a typo/comment/single-file fix should go through `/opsx:propose` → `/opsx:apply` → `/opsx:archive`. The `openspec/AGENTS.md` file documents the workflow.

### TDD is mandatory
Every algorithm in `Shared/` and `Helper/Control/` ships with unit tests. Pattern: write test first (RED), implement (GREEN), then refactor. Tests live in `Tests/` and run via Xcode (XCTest needs Xcode, not CLT).

### Pure-logic split
Anything that can be tested without IO lives in `Shared/`. SMC/IOKit/IOHID code stays in `Helper/`. `App/` only renders + calls XPC.

### XPC payloads are JSON-Codable
The `@objc HelperProtocol` passes `Data` for any non-primitive (snapshot, mode, curve). The `HelperClient` and `HelperService` encode/decode at the boundary. This avoids Apple's NSSecureCoding hassles and keeps types Swift-Codable-clean.

### Visual fidelity to FanControl/*.jsx
`FanControl/app/window-shell.jsx` + `main-mvp.jsx` + `curve-mvp.jsx` are the **design source of truth**. SwiftUI views should mirror them as closely as possible: colors (`#1a1c20`, `#3b82f6`, `#ff5f57`), spacing, fonts (SF Pro 11pt body, 64pt thin display, 8pt mono badges), animations (260ms sheet bottom-up).

### Hardware lock
The MVP only supports `MacBookPro18,3`. `ModelDetector` reads `IOPlatformExpertDevice` → `model` and the helper enters read-only mode on any other identifier. Don't relax this without a follow-up change.

### Safety first
The `SafetyOverride` is non-negotiable. Any change to the control loop must keep: (a) `> 95°C × 3 consecutive ticks` activates max RPM, (b) `< 92°C` deactivates, (c) watchdog reverts to Auto if loop stalls > 5s.

### Helper communication
- App → Helper: `HelperClient.shared.<method>()` async wrappers
- Helper exports: implements `HelperProtocol` (objc protocol), returns Data for complex types
- Validation: `XPCConnectionValidator` checks `SecCodeCheckValidity` + bundle ID = `com.fancontrol.app` BEFORE accepting any connection

### File system layout in production
- `~/Library/Application Support/FanControl/state.json` — App-side UI state (accent, tempUnit, last curve)
- `/Library/Application Support/FanControl/control.json` — Helper-side control config (mode, curve, forced RPM)
- `/Library/LaunchDaemons/com.fancontrol.helper.plist` — managed by `SMAppService`
- `/var/log/FanControl/helper.{log,err}` — helper stdout/stderr (rotated by launchd)

## Open questions / future changes (out of MVP scope)

- App binding (Final Cut → Performance preset auto-switch)
- Multiple named curves saved by user
- Battery override (cap at 60% RPM unplugged)
- Historical RPM/temp graph
- Apple Developer ID + notarization for distribution
- Cross-hardware support (M1 base 13", M2/M3, Intel)
- Mac App Store distribution (helper privileges blocked there)

See `openspec/changes/implement-fan-control-mvp/proposal.md` Non-Goals section for full list.

## Useful commands

```bash
# Generate Xcode project after editing project.yml
xcodegen generate

# Build via Xcode CLI
xcodebuild -scheme FanControl -destination 'platform=macOS' build
xcodebuild -scheme FanControl -destination 'platform=macOS' test

# Build pure-logic Shared module via SPM (no Xcode required)
swift build

# Live helper logs
log stream --predicate 'subsystem == "com.fancontrol.helper"' --info

# Check helper status
launchctl list | grep fancontrol
sudo launchctl print system/com.fancontrol.helper

# Manually unregister (when uninstall flow is broken)
sudo launchctl unload /Library/LaunchDaemons/com.fancontrol.helper.plist
sudo rm -rf /Library/Application\ Support/FanControl
```
