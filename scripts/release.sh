#!/usr/bin/env bash
#
# release.sh — release end-to-end automatizada do BreezeFan via Sparkle.
#
# Uso:
#   ./scripts/release.sh 0.3.0
#   ./scripts/release.sh 0.3.0 --notes "Release notes aqui"
#   ./scripts/release.sh 0.3.0 --dry-run         # NÃO faz commit/push/release
#
# Pre-requisitos (one-time):
#   - ./scripts/setup-sparkle.sh rodado (chave EdDSA no Keychain)
#   - SUPublicEDKey definido em project.yml
#   - Branch gh-pages criada e GitHub Pages habilitado
#   - gh CLI instalado e autenticado: `brew install gh && gh auth login`
#
# Pipeline:
#   1. Valida argumentos + git clean
#   2. Bumpa versão em project.yml
#   3. xcodegen generate
#   4. ./scripts/build-dmg.sh --version <v>
#   5. sign_update <dmg> -> assinatura EdDSA + size
#   6. Atualiza appcast.xml em branch gh-pages com nova entry
#   7. Commit + push main (versão bump)
#   8. Commit + push gh-pages (appcast)
#   9. gh release create com asset

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="BreezeFan"
GH_USER="JeversonMisaelDaCruz"
GH_REPO="Macfancontrol"
APPCAST_URL="https://jeversonmisaeldacruz.github.io/$GH_REPO/appcast.xml"
DOWNLOAD_BASE="https://github.com/$GH_USER/$GH_REPO/releases/download"

# ─── Args ────────────────────────────────────────────────────────────────────

VERSION=""
NOTES=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes) NOTES="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) sed -n '4,20p' "$0" | sed 's/^# //; s/^#$//'; exit 0 ;;
    [0-9]*) VERSION="$1"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "✗ Versão não fornecida. Uso: ./scripts/release.sh 0.3.0" >&2
  exit 2
fi

# Valida formato semver simples
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "✗ Versão deve ser semver X.Y.Z (recebido: $VERSION)" >&2
  exit 2
fi

# Valida ferramentas
for tool in xcodegen xcodebuild gh git; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "✗ $tool não encontrado. Instale antes de rodar." >&2
    exit 1
  fi
done

# Localiza tools do Sparkle
SPARKLE_BIN_DIR=""
SPARKLE_BIN_DIR=$(find ~/Library/Developer/Xcode/DerivedData \
  -type d -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin" 2>/dev/null \
  | head -1)
if [[ -z "$SPARKLE_BIN_DIR" ]] || [[ ! -x "$SPARKLE_BIN_DIR/sign_update" ]]; then
  echo "✗ Sparkle sign_update não encontrado. Build o projeto 1x antes de rodar release." >&2
  exit 1
fi

cd "$PROJECT_DIR"

# Valida git clean (a menos que dry-run)
if ! $DRY_RUN; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "✗ Working tree tem mudanças não commitadas. Commite ou stash antes." >&2
    git status -s
    exit 1
  fi
fi

echo "▸ Versão: $VERSION"
echo "▸ Dry-run: $DRY_RUN"
echo

# ─── 1. Bumpa versão em project.yml ──────────────────────────────────────────

CURRENT_BUILD=$(grep -E 'CFBundleVersion: "[0-9]+"' project.yml | head -1 | sed -E 's/.*"([0-9]+)".*/\1/')
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "▸ Bumpando project.yml: $VERSION (build $NEW_BUILD)"
# Edita as 2 linhas — cuidado pra pegar só a do app target (não Helper)
python3 - <<PY
import re
from pathlib import Path
p = Path("project.yml")
text = p.read_text()
# Substitui apenas o primeiro CFBundleShortVersionString (do app)
text = re.sub(r'(CFBundleShortVersionString:\s*)"[^"]*"',
              rf'\\1"$VERSION"', text, count=1)
text = re.sub(r'(CFBundleVersion:\s*)"[^"]*"',
              rf'\\1"$NEW_BUILD"', text, count=1)
p.write_text(text)
PY

# ─── 2. xcodegen ─────────────────────────────────────────────────────────────

echo "▸ Regenerando Xcode project…"
xcodegen generate

# ─── 3. Build DMG ────────────────────────────────────────────────────────────

echo "▸ Building branded DMG (--pretty --regenerate-assets)…"
./scripts/build-dmg.sh --pretty --regenerate-assets --version "$VERSION"
DMG_PATH="$PROJECT_DIR/dist/$APP_NAME-$VERSION.dmg"
if [[ ! -f "$DMG_PATH" ]]; then
  echo "✗ DMG não foi gerado em $DMG_PATH" >&2
  exit 1
fi

DMG_SIZE=$(stat -f %z "$DMG_PATH")
DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
echo "▸ DMG: $DMG_PATH ($DMG_SIZE bytes)"
echo "▸ SHA256: $DMG_SHA256"

# ─── 4. Sign DMG with Sparkle ────────────────────────────────────────────────

echo "▸ Assinando DMG com EdDSA via Sparkle…"
SIGN_OUTPUT=$("$SPARKLE_BIN_DIR/sign_update" "$DMG_PATH")
# Output exemplo:
#   sparkle:edSignature="abc123..." length="2048576"
SIG=$(echo "$SIGN_OUTPUT" | grep -oE 'edSignature="[^"]+"' | sed 's/edSignature="//;s/"//')
LEN=$(echo "$SIGN_OUTPUT" | grep -oE 'length="[^"]+"' | sed 's/length="//;s/"//')

if [[ -z "$SIG" ]] || [[ -z "$LEN" ]]; then
  echo "✗ sign_update output inesperado:" >&2
  echo "$SIGN_OUTPUT" >&2
  exit 1
fi

echo "▸ Signature: ${SIG:0:32}…"
echo "▸ Length: $LEN bytes"

# ─── 5. Update appcast.xml em branch gh-pages ────────────────────────────────

PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
DOWNLOAD_URL="$DOWNLOAD_BASE/$VERSION/$APP_NAME-$VERSION.dmg"
NOTES_HTML="${NOTES:-Release $VERSION. Veja https://github.com/$GH_USER/$GH_REPO/releases/tag/$VERSION para detalhes.}"

NEW_ITEM=$(cat <<EOF
        <item>
            <title>BreezeFan $VERSION</title>
            <link>https://github.com/$GH_USER/$GH_REPO/releases/tag/$VERSION</link>
            <sparkle:version>$NEW_BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <description><![CDATA[$NOTES_HTML]]></description>
            <pubDate>$PUB_DATE</pubDate>
            <enclosure
                url="$DOWNLOAD_URL"
                sparkle:version="$NEW_BUILD"
                sparkle:shortVersionString="$VERSION"
                sparkle:edSignature="$SIG"
                length="$LEN"
                type="application/octet-stream"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
EOF
)

echo "▸ Atualizando appcast.xml em branch gh-pages…"

# Salva mudanças do main em stash antes de switch (project.yml bump)
if ! $DRY_RUN; then
  git stash push -u -m "release-$VERSION-main-changes" || true
fi

# Checkout/cria gh-pages
if ! git rev-parse --verify gh-pages >/dev/null 2>&1; then
  echo "▸ Branch gh-pages não existe — criando orphan…"
  git switch --orphan gh-pages
  cat > appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>BreezeFan</title>
        <link>$APPCAST_URL</link>
        <description>BreezeFan release feed</description>
        <language>en</language>
$NEW_ITEM
    </channel>
</rss>
XML
  cat > index.html <<HTML
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>BreezeFan</title></head>
<body><h1>BreezeFan</h1>
<p>Sparkle appcast: <a href="appcast.xml">appcast.xml</a></p>
<p>GitHub: <a href="https://github.com/$GH_USER/$GH_REPO">$GH_USER/$GH_REPO</a></p>
</body></html>
HTML
else
  git switch gh-pages
  # Insere nova entry após `<channel>...<language>en</language>` (no topo do feed)
  python3 - <<PY
from pathlib import Path
p = Path("appcast.xml")
text = p.read_text()
new_item = """$NEW_ITEM
"""
# Insere logo após </language>
text = text.replace("</language>", "</language>\n" + new_item, 1)
p.write_text(text)
PY
fi

if ! $DRY_RUN; then
  git add appcast.xml index.html 2>/dev/null || true
  git commit -m "release: BreezeFan $VERSION (appcast)"
  git push origin gh-pages
fi

# Volta pra main
git switch main
if ! $DRY_RUN; then
  git stash pop || true
fi

# ─── 6. Commit version bump em main ──────────────────────────────────────────

if ! $DRY_RUN; then
  git add project.yml
  git commit -m "release: bump to $VERSION" || true
  git push origin main
fi

# ─── 7. GitHub Release ───────────────────────────────────────────────────────

if ! $DRY_RUN; then
  echo "▸ Criando GitHub Release $VERSION…"
  gh release create "$VERSION" \
    --title "BreezeFan $VERSION" \
    --notes "$NOTES_HTML" \
    "$DMG_PATH"
else
  echo "▸ [DRY-RUN] Skipping gh release create"
fi

echo
echo "✓ Release $VERSION concluída!"
echo "  Appcast: $APPCAST_URL"
echo "  Release: https://github.com/$GH_USER/$GH_REPO/releases/tag/$VERSION"
echo "  Apps existentes vão receber notificação na próxima checagem (até 24h),"
echo "  ou via 'Check for Updates…' menu (instantâneo)."
