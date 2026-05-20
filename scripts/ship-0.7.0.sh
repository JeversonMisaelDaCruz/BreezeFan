#!/usr/bin/env bash
#
# ship-0.7.0.sh — one-shot ship of 0.7.0 from the worktree branch.
#
# The Claude Code permissions classifier blocks Git pushes to the default
# branch from agent context. This script gives the maintainer a single
# copy-paste line to run the same sequence locally.
#
# Run:  ./scripts/ship-0.7.0.sh
#
# What it does:
#   1. Updates `origin` to the new repo name (Macfancontrol → BreezeFan)
#   2. Fast-forwards local main to worktree-loop-perf-ux
#   3. Pushes main + v0.7.0 tag
#   4. Authenticates gh CLI if needed
#   5. Creates GH release with the prebuilt DMG + RELEASE_NOTES_0.7.0.md
#
# Safe to re-run: no-ops if main is already merged, tag already pushed,
# or release already created.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

NEW_REMOTE="git@github.com:JeversonMisaelDaCruz/BreezeFan.git"
DMG="dist/BreezeFan-0.7.0.dmg"
NOTES="RELEASE_NOTES_0.7.0.md"

# ─── 1. Update remote URL ─────────────────────────────────────────────────────

current_remote=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$current_remote" != "$NEW_REMOTE" ]]; then
  echo "▸ Updating origin → $NEW_REMOTE"
  git remote set-url origin "$NEW_REMOTE"
else
  echo "✓ origin already points to $NEW_REMOTE"
fi

# ─── 2. Fast-forward main ─────────────────────────────────────────────────────

if [[ ! -f "$DMG" ]]; then
  echo "✗ $DMG not found — run ./scripts/build-dmg.sh --pretty --regenerate-assets first" >&2
  exit 1
fi
if [[ ! -f "$NOTES" ]]; then
  echo "✗ $NOTES not found — should have been committed" >&2
  exit 1
fi

echo "▸ Switching to main"
git checkout main

echo "▸ Fast-forwarding main → worktree-loop-perf-ux"
git merge --ff-only worktree-loop-perf-ux

# ─── 3. Push ─────────────────────────────────────────────────────────────────

echo "▸ Pushing main"
git push origin main

echo "▸ Pushing v0.7.0 tag"
git push origin v0.7.0

# ─── 4. gh CLI auth ──────────────────────────────────────────────────────────

if ! gh auth status >/dev/null 2>&1; then
  echo "▸ gh CLI not authenticated — launching browser login…"
  gh auth login
fi

# ─── 5. GitHub release ───────────────────────────────────────────────────────

if gh release view v0.7.0 >/dev/null 2>&1; then
  echo "✓ Release v0.7.0 already exists"
else
  echo "▸ Creating GitHub release v0.7.0"
  gh release create v0.7.0 "$DMG" \
    --title "BreezeFan 0.7.0 — branded installer + multi-Mac + perf + bug fixes" \
    --notes-file "$NOTES"
fi

echo
echo "✓ Ship complete."
echo "  Release: https://github.com/JeversonMisaelDaCruz/BreezeFan/releases/tag/v0.7.0"
