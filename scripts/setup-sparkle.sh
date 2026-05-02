#!/usr/bin/env bash
#
# setup-sparkle.sh — gera o par de chaves EdDSA Ed25519 que Sparkle usa pra
# verificar assinatura dos updates. Run once per machine.
#
# Output:
#   - Private key armazenada em macOS Keychain (item "ed25519 sparkle")
#   - Public key impressa no terminal (string base64 de 44 chars)
#
# Próximos passos depois de rodar:
#   1. Copiar a public key impressa
#   2. Colar em project.yml (info > properties > SUPublicEDKey)
#   3. Rodar xcodegen + xcodebuild
#
# Re-execução é safe: se já existe key no Keychain, mostra a public sem regenerar.
#
# Pre-requisitos:
#   - Sparkle SPM resolved (basta abrir o projeto no Xcode 1x ou rodar
#     xcodebuild -resolvePackageDependencies)
#   - Tools do Sparkle (generate_keys, sign_update) acessíveis

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ─── Localiza tools do Sparkle ───────────────────────────────────────────────

# Sparkle SPM-resolved checkout vai pra DerivedData. Procuramos os tools.
SPARKLE_BIN_DIR=""

# Caminho 1: DerivedData artifacts (Sparkle 2.x distribui tools como binary artifacts)
if [[ -z "$SPARKLE_BIN_DIR" ]]; then
  candidate=$(find ~/Library/Developer/Xcode/DerivedData \
    -type d -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin" 2>/dev/null \
    | head -1)
  if [[ -n "$candidate" ]]; then
    SPARKLE_BIN_DIR="$candidate"
  fi
fi

# Caminho 1b: DerivedData checkouts (fallback)
if [[ -z "$SPARKLE_BIN_DIR" ]]; then
  candidate=$(find ~/Library/Developer/Xcode/DerivedData \
    -type d -path "*/SourcePackages/checkouts/Sparkle/bin" 2>/dev/null \
    | head -1)
  if [[ -n "$candidate" ]]; then
    SPARKLE_BIN_DIR="$candidate"
  fi
fi

# Caminho 2: instalação manual em scripts/sparkle-tools/
if [[ -z "$SPARKLE_BIN_DIR" ]] && [[ -d "$PROJECT_DIR/scripts/sparkle-tools" ]]; then
  SPARKLE_BIN_DIR="$PROJECT_DIR/scripts/sparkle-tools"
fi

# Caminho 3: env override
if [[ -z "$SPARKLE_BIN_DIR" ]] && [[ -n "${SPARKLE_TOOLS_DIR:-}" ]]; then
  SPARKLE_BIN_DIR="$SPARKLE_TOOLS_DIR"
fi

if [[ -z "$SPARKLE_BIN_DIR" ]] || [[ ! -x "$SPARKLE_BIN_DIR/generate_keys" ]]; then
  cat >&2 << EOF
✗ Sparkle tools não encontrados.

Resolva uma das opções:

  Opção A — Build do projeto primeiro (recomendado):
    cd $PROJECT_DIR
    xcodegen generate
    xcodebuild -resolvePackageDependencies -project BreezeFan.xcodeproj
    # ou: open BreezeFan.xcodeproj e deixar o Xcode resolver SPM

  Opção B — Download manual dos tools:
    1. Download https://github.com/sparkle-project/Sparkle/releases/latest
       (arquivo Sparkle-2.x.x.tar.xz)
    2. tar -xJf Sparkle-2.x.x.tar.xz
    3. mkdir -p $PROJECT_DIR/scripts/sparkle-tools
    4. cp Sparkle/bin/generate_keys Sparkle/bin/sign_update $PROJECT_DIR/scripts/sparkle-tools/
    5. Re-rode este script

  Opção C — Env override:
    SPARKLE_TOOLS_DIR=/path/to/Sparkle/bin ./scripts/setup-sparkle.sh
EOF
  exit 1
fi

echo "▸ Sparkle tools: $SPARKLE_BIN_DIR"
echo

# ─── Gera (ou lê) chave EdDSA ────────────────────────────────────────────────

# generate_keys com -p mostra a public key do Keychain (existente ou recém-criada).
# Sem -p, gera nova só se não existe.
echo "▸ Gerando/lendo par EdDSA…"
PUBLIC_KEY=$("$SPARKLE_BIN_DIR/generate_keys" -p 2>/dev/null || true)

if [[ -z "$PUBLIC_KEY" ]]; then
  # Não tem key ainda — gera
  echo "▸ Sem chave existente — gerando nova (private key vai pra Keychain)…"
  "$SPARKLE_BIN_DIR/generate_keys"
  PUBLIC_KEY=$("$SPARKLE_BIN_DIR/generate_keys" -p)
else
  echo "▸ Já existe par no Keychain — usando o existente."
fi

# ─── Output ──────────────────────────────────────────────────────────────────

echo
echo "═══════════════════════════════════════════════════════════════════════"
echo "  ✓ EdDSA Ed25519 public key (cole em project.yml SUPublicEDKey)       "
echo "═══════════════════════════════════════════════════════════════════════"
echo
echo "  $PUBLIC_KEY"
echo
echo "═══════════════════════════════════════════════════════════════════════"
echo
echo "Próximos passos:"
echo "  1. Edita project.yml e adiciona em info > properties:"
echo "       SUPublicEDKey: \"$PUBLIC_KEY\""
echo "  2. xcodegen generate"
echo "  3. xcodebuild ..."
echo
echo "⚠  IMPORTANTE: a private key NÃO sai do Keychain. Backup do Keychain"
echo "   (Time Machine cobre). Se perder, todos os clients existentes ficam"
echo "   stuck no último update assinado com essa chave."
