## Why

Hoje o `UpdateChecker.swift` detecta nova versão via GitHub Releases API e mostra banner com botão "Baixar" — mas só abre o navegador. Usuário precisa baixar manualmente, abrir `.dmg`, arrastar pra Applications, fechar app, reabrir. **3+ cliques fora do app + reinício**.

Apps Mac de distribuição direta (1Password, Tweetbot, iStat Menus, Macs Fan Control da crystalidea) usam o **[Sparkle framework](https://sparkle-project.org/)** — auto-download em background, verificação de assinatura EdDSA, install + relaunch silencioso. **1 clique, ~5 segundos, dentro do app**.

Esta change substitui o checker custom do BreezeFan por Sparkle 2.x e estabelece pipeline de release assinado.

## What Changes

- **Adicionar Sparkle 2.x via SPM** (`https://github.com/sparkle-project/Sparkle`)
- **Substituir `UpdateChecker.swift` por `SPUStandardUpdaterController`** (SwiftUI-friendly via Environment)
- **Remover banner custom em MainView** (Sparkle traz UI nativa de update — dialog macOS padrão)
- **Adicionar `Info.plist` keys**: `SUFeedURL` (URL do appcast.xml), `SUPublicEDKey` (chave EdDSA pública), `SUEnableAutomaticChecks=true`, `SUScheduledCheckInterval=86400`
- **Adicionar entitlement** `com.apple.security.network.client` pra Sparkle baixar updates
- **Criar `appcast.xml`** hospedado em **GitHub Pages** do próprio repo (gratuito, branch `gh-pages`)
- **Criar `scripts/setup-sparkle.sh`**: gera par de chaves EdDSA via `generate_keys` (Sparkle CLI), guarda private em Keychain, output public pra Info.plist
- **Criar `scripts/release.sh`**: end-to-end release — bumpa versão, build DMG, assina via `sign_update`, atualiza `appcast.xml`, commit branch `gh-pages`, cria GitHub Release com asset
- **`Check for Updates…`** continua existindo no menu (top bar e status item) mas agora chama `SPUUpdater.checkForUpdates()` em vez do nosso checker
- **Remover** `UpdateChecker.swift`, `availableUpdate` em AppState, banner em `MainView` — Sparkle gerencia tudo
- **Atualizar docs** (PT-BR/EN/ES) com fluxo de release e instruções pra usuários (já é automático — só mencionar)

## Capabilities

### New Capabilities

- `auto-update`: Sparkle integration — automatic background check, EdDSA-signed download, in-place install + relaunch via SPUStandardUpdaterController.

### Modified Capabilities

- Nenhuma — o "update check" anterior era custom (não documentado em spec); agora vira capability nova com Sparkle.

## Impact

- **Dependências novas**: Sparkle 2.x (SPM, MIT-licensed). Adiciona ~5MB ao bundle (framework).
- **Código removido**: `App/State/UpdateChecker.swift` (~150 linhas), banner update no `MainView`, `AppState.availableUpdate`, menu items custom.
- **Código novo**: `App/Updater/UpdaterController.swift` (~50 linhas wrapping SPUStandardUpdaterController), `App/Updater/CheckForUpdatesView.swift` (~30 linhas SwiftUI Button bind).
- **Plumbing**: `Info.plist` ganha 4 keys, entitlements ganha 1 entry, `project.yml` ganha SPM dependency.
- **Repo structure**:
  - Branch `gh-pages` criada com `appcast.xml` + `index.html` simples
  - GitHub Pages habilitado em `Settings → Pages → Source: gh-pages branch`
- **Release process**: passa a ter 1 comando: `./scripts/release.sh 0.3.0`. Tudo automático (assina, atualiza appcast, push, cria GitHub release).
- **Trade-off**: pra primeira release com Sparkle, user precisa **rodar `./scripts/setup-sparkle.sh` UMA VEZ** pra gerar a chave EdDSA. Depois é só rodar `release.sh`.
- **Risco**: zero pra usuários atuais — eles continuam vendo o banner antigo do `UpdateChecker` até instalarem a primeira versão Sparkle (a 0.3.0, primeira com Sparkle integrado). A partir dali, updates são automáticos.
- **Validação**:
  - Build limpo no Xcode com Sparkle linkado
  - Bumpar local pra 0.2.0 → release 0.3.0 com Sparkle no GitHub → app local pega update via Sparkle, instala automaticamente, relança como 0.3.0
