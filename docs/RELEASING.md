# Release Process — BreezeFan

Auto-update via [Sparkle 2](https://sparkle-project.org/) framework. Releases são assinadas com EdDSA Ed25519 e distribuídas via GitHub Releases + GitHub Pages appcast.

## One-time setup (primeira vez por máquina)

### 1. Gerar par de chaves EdDSA

```bash
./scripts/setup-sparkle.sh
```

Este script:
- Localiza os tools do Sparkle (em `DerivedData/.../Sparkle/bin/`)
- Roda `generate_keys` (private key vai pra macOS Keychain como item `ed25519 sparkle`)
- Imprime a public key (44 chars base64)

**Cole a public key impressa em `project.yml`** em `info.properties.SUPublicEDKey`.

### 2. Habilitar GitHub Pages

No GitHub:
1. **Settings** → **Pages**
2. **Source**: `Deploy from a branch`
3. **Branch**: `gh-pages` / `(root)` → **Save**

GitHub Pages serve `https://jeversonmisaeldacruz.github.io/Macfancontrol/appcast.xml` em ~1 minuto após primeiro push da branch `gh-pages`.

### 3. Instalar `gh` CLI (se ainda não tiver)

```bash
brew install gh
gh auth login
# escolhe GitHub.com → HTTPS → Yes → Login with web browser → autoriza
```

## Release de uma nova versão

```bash
./scripts/release.sh 0.3.0
# ou com release notes customizadas:
./scripts/release.sh 0.3.0 --notes "Adicionado suporte ao MacBook Pro 16 M1 Pro"
# ou dry-run pra validar tudo sem commit/push/release:
./scripts/release.sh 0.3.0 --dry-run
```

O script faz tudo:
1. Bumpa `CFBundleShortVersionString` e `CFBundleVersion` em `project.yml`
2. `xcodegen generate`
3. Build DMG (`./scripts/build-dmg.sh --version 0.3.0`)
4. Assina o DMG com `sign_update` → `sparkle:edSignature` + `length`
5. Adiciona nova `<item>` no `appcast.xml` (branch `gh-pages`)
6. Commit + push `main` (version bump) e `gh-pages` (appcast)
7. `gh release create 0.3.0 --title "BreezeFan 0.3.0" dist/BreezeFan-0.3.0.dmg`

Tempo total: ~2 minutos.

## Como usuários recebem o update

Apps em versão anterior (ex: 0.2.0):

1. **Auto**: Sparkle faz check em background a cada 24h (`SUScheduledCheckInterval=86400`)
2. **Manual**: usuário clica **🍎 BreezeFan → Check for Updates…** ou **right-click no ícone fan da menu bar → Check for Updates…**

Quando há update:
- Sparkle abre dialog modal nativo macOS: **"A new version of BreezeFan is available!"**
- Botões: **Install Update** / **Skip This Version** / **Remind Me Later**
- Click "Install Update" → Sparkle baixa em background, valida assinatura EdDSA, instala em `/Applications/`, mata o processo antigo, relança o novo
- **Total: ~5 segundos, sem sair do app**

## Troubleshooting

### "EdDSA signature verification failed"
- A private key no Keychain mudou desde a release. Não dá pra recuperar — os clients existentes ficam stuck. Solução: gerar nova key (`generate_keys -f`), atualizar `SUPublicEDKey` no project.yml, lançar versão nova. Usuários antigos vão precisar reinstalar manualmente.

### "Update download failed"
- Verifica que o `.dmg` está acessível em `https://github.com/.../releases/download/X.Y.Z/BreezeFan-X.Y.Z.dmg`
- Sparkle requer HTTPS (GitHub releases já são).

### Banner não aparece
- Sparkle só checa updates quando `canCheckForUpdates == true` (offline = pula).
- Verifica logs: `log stream --predicate 'subsystem == "org.sparkle-project.Sparkle"'`

### Quero forçar nova checagem
- **Click for Updates…** menu force, ignora cache de 24h.

## Arquivos relevantes

- `project.yml` — keys do Sparkle no Info.plist (SUFeedURL, SUPublicEDKey, etc)
- `App/Updater/UpdaterController.swift` — wrapper SPUStandardUpdaterController
- `App/Updater/CheckForUpdatesView.swift` — Button SwiftUI vinculado ao updater
- `scripts/setup-sparkle.sh` — gera EdDSA keys (one-time)
- `scripts/release.sh` — pipeline end-to-end de release
- `gh-pages` branch — appcast.xml + index.html

## Backup da private key (importante)

A private key EdDSA fica no **macOS Keychain** (item `ed25519 sparkle`, account `ed25519`). Se você perder o Mac sem backup, **todos os usuários existentes ficam stuck** (não conseguem mais validar assinaturas).

**Backup obrigatório**:
- Time Machine cobre Keychain por default
- Ou exporte via Keychain Access app: search "ed25519 sparkle" → File → Export

Para inspecionar a chave sem exportar:
```bash
security find-generic-password -a ed25519 -s "https://sparkle-project.org" -w
```
