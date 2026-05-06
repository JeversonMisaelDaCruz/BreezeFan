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

## Troubleshooting

### BreezeFan crashes at login (Login Item crash — 0.4.0 only)

**Symptom:** BreezeFan added as a Login Item causes a crash at boot with `Library not loaded: @rpath/Sparkle.framework` in the crash report.

**Cause:** BreezeFan 0.4.0 was missing a code-signing entitlement (`com.apple.security.cs.disable-library-validation`) required for Hardened Runtime to allow bundled SPM frameworks (Sparkle) when launched by `launchd` (i.e. as a Login Item).

**Fix:** Install [BreezeFan 0.4.1](https://github.com/JeversonMisaelDaCruz/BreezeFan/releases/tag/0.4.1) — the entitlement is included and the build pipeline now runs `codesign --verify --strict` to prevent this class of regression.

## License

Personal-use project. SMC key table derived from [crystalidea/macs-fan-control](https://github.com/crystalidea/macs-fan-control) (LGPL).
