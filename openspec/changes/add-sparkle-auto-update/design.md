## Context

Estado atual do BreezeFan (post-rename): `UpdateChecker` custom faz GET no GitHub Releases API a cada 6h, compara versão semantica, e quando há update, popula `AppState.availableUpdate` que dispara um banner em `MainView` com botão "Baixar" que **só abre o navegador**.

Problema: experiência de update é **manual** (download → mount → drag → quit → relaunch). Apps distribuidos diretamente usam Sparkle desde 2006.

[Sparkle 2.x](https://sparkle-project.org/documentation/) é canônico:
- MIT license
- Suporta sandbox via XPC services internas
- Assinatura EdDSA Ed25519 obrigatória (sem RSA legacy)
- SwiftUI-native via `SPUStandardUpdaterController`
- 100M+ apps macOS usam (1Password, Tweetbot, iStat Menus)

## Goals / Non-Goals

**Goals:**
- G1. Substituir `UpdateChecker` custom por Sparkle 2.x integrado
- G2. Auto-download + 1-click install + relaunch sem sair do app
- G3. Releases assinadas com EdDSA (segurança contra MITM)
- G4. Pipeline `./scripts/release.sh <versão>` totalmente automatizado
- G5. Zero infraestrutura adicional além do GitHub (usar GitHub Pages pra appcast.xml — gratuito, sob nosso controle)

**Non-Goals:**
- NG1. Auto-instalação de **updates beta** (Sparkle suporta canais — out of MVP)
- NG2. Update via diff/delta (Sparkle suporta — adiciona complexidade, MVP usa full DMG sempre)
- NG3. UI customizada de update (Sparkle vem com dialog padrão macOS bonito)
- NG4. Notarização (próximo passo separado quando tivermos Developer ID)
- NG5. Manter `UpdateChecker` antigo coexistindo — vai ser **removido**

## Decisions

### D1. Sparkle 2.x via SPM
- **Escolhido**: latest 2.6+ via `https://github.com/sparkle-project/Sparkle`
- **Razão**: SwiftUI-native, sandbox-compatible, EdDSA mandatory. 1.x é deprecated.

### D2. SPUStandardUpdaterController como SwiftUI ObservableObject
- **Escolhido**: `@StateObject var updaterController = SPUStandardUpdaterController(...)` no `BreezeFanApp`
- **Razão**: SwiftUI lifecycle. Pass via Environment pra views que precisam.

### D3. Appcast hosted on GitHub Pages do mesmo repo
- **Escolhido**: branch `gh-pages` com `appcast.xml` + `index.html`
  - URL: `https://jeversonmisaeldacruz.github.io/Macfancontrol/appcast.xml`
- **Razão**: GitHub Pages gratuito, controlado, HTTPS por default.

### D4. EdDSA private key persistida em Keychain
- **Escolhido**: `setup-sparkle.sh` chama `generate_keys` que armazena private em macOS Keychain (item "ed25519 sparkle"). Public key retornada pra `Info.plist`.
- **Razão**: Keychain é seguro por default, encrypted. `sign_update` lê automaticamente.
- **Trade-off**: se user perder o Mac sem backup, todos os clients existentes ficam stuck no último update assinado. Time Machine cobre Keychain.

### D5. Pipeline `release.sh` end-to-end
1. Bump `CFBundleShortVersionString` em `project.yml`
2. `xcodegen generate`
3. `./scripts/build-dmg.sh --version <v>` (gera `dist/BreezeFan-<v>.dmg`)
4. `sign_update dist/BreezeFan-<v>.dmg` → output: `sparkle:edSignature` + `length`
5. Atualiza `gh-pages/appcast.xml` com nova entry no topo
6. `gh release create <v> --title "BreezeFan <v>" dist/BreezeFan-<v>.dmg`
7. Commit + push `main` + `gh-pages`

### D6. Remover `UpdateChecker.swift` e código relacionado
- **Escolhido**: deletar arquivo, remover `availableUpdate` de AppState, banner JSX em MainView, menu items que chamam `UpdateChecker.shared`. Substituir tudo pelos do Sparkle.
- **Razão**: dois sistemas concorrendo é receita pra bugs.

### D7. Sparkle UI dialog standard
- **Escolhido**: usar default macOS look do Sparkle.
- **Razão**: dialog padrão é o que usuários macOS reconhecem.

### D8. Auto-check intervalo: 24h (Sparkle default)
- **Escolhido**: `SUScheduledCheckInterval = 86400`. User pode forçar via "Check for Updates…" (instant).

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| EdDSA private key em Keychain — se Mac do dev é wipe sem backup, perde controle | Documentar em RELEASING.md. Time Machine cobre. |
| Appcast.xml em GitHub Pages — se GH Pages cai, updates não funcionam | GH Pages tem 99.9% uptime. Aceitável. |
| Primeira release com Sparkle (0.3.0) precisa ter usuário em 0.2.0 baixar manualmente | Esperado em qualquer migração. |
| Sparkle ad-hoc signed app pode ter dificuldade pra atualizar (Gatekeeper) | Sparkle tem suporte explícito pra ad-hoc. EdDSA signature é independente do code signing. |
| SPM dependency adiciona ~5MB ao bundle | Aceito. Bundle vai de ~600KB → ~6MB. |

## Migration Plan

1. **Setup-sparkle.sh** rodado UMA VEZ pelo dev (gera EdDSA keys)
2. **Adiciona Sparkle SPM** em `project.yml`
3. **Implementa SPUStandardUpdaterController** integration
4. **Remove UpdateChecker** custom
5. **Cria appcast.xml** template em branch `gh-pages` (vazio inicial)
6. **Cria scripts/release.sh**
7. **Build local + smoke test**
8. **Primeira release real**: `./scripts/release.sh 0.3.0`

### Rollback

Se Sparkle der problema irrecuperável: `git revert <sparkle commits>`. Restore `UpdateChecker.swift` (pega do histórico). Rebuild + manual release.
