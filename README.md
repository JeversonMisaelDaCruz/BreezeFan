# BreezeFan

<p align="center">
  <strong>Native macOS fan control for MacBook Pro 14" M1 Pro (2021)</strong>
</p>

<p align="center">
  <a href="docs/README.pt-BR.md">🇧🇷 Português</a> ·
  <a href="docs/README.en.md">🇺🇸 English</a> ·
  <a href="docs/README.es.md">🇪🇸 Español</a>
</p>

---

Replacement for [crystalidea/macs-fan-control](https://github.com/crystalidea/macs-fan-control) with multi-step fan curves, named MVP presets (Silent / Balanced / Performance / Max), menu bar integration, license-key gated curve editor, and a native macOS Liquid Glass UI.

> ⚠️ **Hardware-locked.** Runs only on `MacBookPro18,3`. Other models boot in read-only mode.

## Quick links

- 🇧🇷 [README em Português](docs/README.pt-BR.md)
- 🇺🇸 [README in English](docs/README.en.md)
- 🇪🇸 [README en Español](docs/README.es.md)

## Screenshots

<!-- Adicione screenshots em docs/img/ quando disponíveis -->

## Building a .dmg installer

```bash
./scripts/build-dmg.sh           # basic (hdiutil)
./scripts/build-dmg.sh --pretty  # with create-dmg (brew install create-dmg)
```

Output: `dist/BreezeFan-<version>.dmg`. See language-specific docs above for full instructions and Gatekeeper notes.

## What's new

### 0.6.0 — multi-MacBook profiles + crash hardening

- **Multi-Mac support.** `ModelProfile` registry maps each
  `IOPlatformExpertDevice/model` to its SMC topology (fan count, CPU temp
  keys, control policy). Known profiles ship for MacBook Pro 14"/16" M1
  Pro/Max (`MacBookPro18,1-4`) and MacBook Air M1/M2/M3 (read-only —
  passive cooling, temperature monitoring only). Unknown models fall back
  to a defensive read-only mode rather than pretending to control fans
  without a verified temperature source.
- **Hardware-aware UI.** Fan rows now respect `fanCount`: hidden on Air,
  single row on 1-fan Pros. Preset grid disables on unsupported hardware
  with an explanation line.
- **Safer XPC.** `HelperProtocol.getHardwareProfile` ships the capabilities
  snapshot to the App; the legacy `getModelInfo` stays for compat.
- **Crash surfaces hardened.** Force casts in `HelperClient.proxy` and the
  application-support path fallback in `StateStore` no longer trap; added
  a non-trapping `SMCKey(validating:)` for runtime-provided keys.

### 0.5.0 — perf pass + menu-bar fix

- **Bug fix — menu bar tooltip / warning indicator now update.** Pre-0.5.0 the
  status item read from an `AppState.snapshot` field that nothing wrote to;
  hovering the icon showed `BreezeFan · — · — RPM` permanently and the
  SMC-conflict yellow tint never appeared. Fixed end-to-end (window-open,
  popover-open, and menu-bar-only modes all stay accurate now).
- **Perf — SMC hot path halved.** Per-key `(dataSize, dataType)` cache in
  `SMCReader` / `SMCWriter` skips the `kSMCGetKeyInfo` round trip after first
  read. ~22 → ~11 `IOConnectCallStructMethod` calls/sec in steady-state curve
  mode.
- **Perf — zero-allocation SMC decode.** `SMCBytes` now exposes its 32-byte
  tuple via an unsafe pointer instead of `Mirror` reflection.
- **Perf — no disk IO on the tick path.** `ControlConfigStore` keeps the
  current config in memory; the control loop reads from the cache every 1.5 s
  instead of `fileExists` + `Data(contentsOf:)` + JSON decode.
- **Perf — shared `JSONEncoder` / `JSONDecoder` across XPC.** App and helper
  each reuse a single coder instance instead of allocating per call.
- **Perf — UI hot paths.** `NumberFormatter`, `Font`, `Color(hex:)`, and tick
  arrays moved out of SwiftUI `body` into static `let`s; `FanGlyph` stops
  ticking at display refresh rate when the fan isn't spinning;
  `Color(hex:)` rewritten as a `utf8`-bytes parser.
- **Bug fix — `setMode(.auto)` race.** Added a `writeLock` in `ControlLoop`
  so an in-flight tick can't undo `revertToAuto`'s `F0Md=0` writes with a
  trailing `F0Md=1`.
- **Tests.** Added smoke tests for the race fix, the config cache, and
  `SensorSnapshot.activeFanCount`. Run via `xcodebuild test`.

## Troubleshooting

### BreezeFan crashes at login (Login Item crash — 0.4.0 only)

**Symptom:** BreezeFan added as a Login Item causes a crash at boot with `Library not loaded: @rpath/Sparkle.framework` in the crash report.

**Cause:** BreezeFan 0.4.0 was missing a code-signing entitlement (`com.apple.security.cs.disable-library-validation`) required for Hardened Runtime to allow bundled SPM frameworks (Sparkle) when launched by `launchd` (i.e. as a Login Item).

**Fix:** Install [BreezeFan 0.4.1](https://github.com/JeversonMisaelDaCruz/BreezeFan/releases/tag/0.4.1) — the entitlement is included and the build pipeline now runs `codesign --verify --strict` to prevent this class of regression.

## License

Personal-use project. SMC key table derived from [crystalidea/macs-fan-control](https://github.com/crystalidea/macs-fan-control) (LGPL).
