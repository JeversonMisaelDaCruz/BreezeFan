# BreezeFan 0.7.0 — branded installer + multi-Mac + perf + bug fixes

Consolidates three releases (0.5.0 → 0.6.0 → 0.7.0) into a single drop. 20 commits, ~1700 line diff.

## 0.7.0 — branded DMG installer

- 🎨 Dark-graphite drag-to-Applications window with custom volume icon (Finder sidebar).
- `scripts/generate-dmg-background.swift` renders `Resources/dmg-background.png` (1200×760 sRGB) via Core Graphics. Embeds `CFBundleShortVersionString` as a watermark so the DMG is self-identifying.
- `scripts/build-dmg-volume-icon.sh` derives `dmg-volume.icns` from `AppIcon.icns` via `iconutil` round-trip.
- `scripts/build-dmg.sh --pretty --regenerate-assets` runs the full branded build; pre-flights enforce asset presence + dimensions (1200×760) before invoking `create-dmg`.
- Final output echoes SHA256 and Gatekeeper assessment for release-note copy-paste.
- `scripts/release.sh` defaults to the branded build (`--pretty --regenerate-assets`).

## 0.6.0 — multi-MacBook profiles + crash hardening

- `ModelProfile` registry maps `IOPlatformExpertDevice/model` → SMC topology (fan count, CPU temp keys, control policy).
- Ships profiles for:
  - **Full control** — MacBook Pro 14"/16" M1 Pro/Max (`MacBookPro18,1` through `18,4`)
  - **Read-only (monitoring only)** — MacBook Air M1/M2/M3 (`MacBookAir10,1`, `Mac14,2`, `Mac14,15`, `Mac15,12`, `Mac15,13`)
  - **Defensive read-only** — every other model, with banner explaining "fan control not yet supported on `<model>`"
- UI adapts to `fanCount`: right-fan row hidden on 1-fan Macs, "Passive cooling — temperature monitoring only" badge on Air.
- Preset grid disabled when `controlSupported == false`.
- 5 crash surfaces hardened: `HelperClient.proxy` no longer force-casts, `StateStore.defaultPath` falls back to `temporaryDirectory`, new non-trapping `SMCKey(validating:)`.

## 0.5.0 — perf pass + menu-bar fix

- 🐛 **Critical bug fix** — Menu-bar tooltip + SMC-conflict warning indicator were frozen pre-0.5.0 (`AppState.snapshot` was read by `StatusItemController` but nothing wrote to it). Wired end-to-end across window-open, popover-open, and menu-bar-only modes.
- 🐛 `ControlLoop.writeLock` closes the tick-vs-`setMode(.auto)` race that could leave fans stuck in manual mode after a mode switch.
- ⚡ SMC IOConnectCalls halved (~22/sec → ~11/sec in curve mode) via per-key info cache + zero-allocation decode (removed `Mirror` reflection from the hot path).
- ⚡ Zero disk IO on the control-loop tick path — `ControlConfigStore` keeps the config in memory.
- ⚡ Shared `JSONEncoder` / `JSONDecoder` across XPC (App + Helper).
- ⚡ UI hot paths: static `NumberFormatter`, `Font`, `Color(hex:)` byte-walking parser; idle `FanGlyph` stops `TimelineView` redraws at display refresh rate.

## Tests

5 test suites / ~19 tests, all green via `xcodebuild test`:

| Suite | Coverage |
|---|---|
| `ControlConfigStoreCacheTests` | Cache lifecycle, hot-cache vs disk, concurrent reads |
| `ControlLoopRaceTests` | The writeLock fix (direct cancel, sequential, concurrent) |
| `HardwareCapabilitiesTests` | `.unknown` defaults, Codable round-trip |
| `ModelProfileResolutionTests` | Known Pro/Max, Air, unknown, empty identifier |
| `SensorSnapshotTests` | `activeFanCount` edge cases |

## DMG checksum

```
sha256: 3077db057d58c78ded02915eb95185b01fa95b7e938c6283caad719c013f42e5
size:   4.4 MB
```

Verify with:

```bash
shasum -a 256 BreezeFan-0.7.0.dmg
```

## Smoke test plan (for the maintainer running 0.4.0 → 0.7.0)

- [ ] Open `dist/BreezeFan-0.7.0.dmg` — branded window, custom volume icon
- [ ] Drag `BreezeFan.app` to `/Applications`
- [ ] First launch: helper prompts for password (Login Items approval)
- [ ] Menu-bar tooltip shows °C / RPM within ~5s (was frozen pre-0.5.0)
- [ ] Mode switch Balanced → Performance → Balanced doesn't leave a fan stuck
- [ ] Curve editor: edit a step, no visual reorder while typing
- [ ] Close window — tooltip continues updating (menu-bar-only polling)
- [ ] `launchctl list | grep breezefan` reports the helper running
- [ ] `log stream --predicate 'subsystem == "com.breezefan.helper"' --info` shows no sustained warnings
