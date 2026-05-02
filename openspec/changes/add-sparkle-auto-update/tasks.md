# Implementation tasks — add-sparkle-auto-update

Order: setup tools → SPM dep → Swift integration → remove old → scripts → docs → ship.

## 1. Setup-sparkle.sh + tools

- [ ] 1.1 Criar `scripts/setup-sparkle.sh`: detecta tools, roda `generate_keys`, output public key
- [ ] 1.2 Rodar setup-sparkle.sh — gera chave EdDSA + captura public key
- [ ] 1.3 Documentar public key obtida (vai pro Info.plist)

## 2. Sparkle SPM + project.yml

- [ ] 2.1 Adicionar Sparkle como SPM package em `project.yml` (`https://github.com/sparkle-project/Sparkle`, branch 2.x)
- [ ] 2.2 Linkar Sparkle ao target `BreezeFan` (não Helper)
- [ ] 2.3 Adicionar Info.plist keys: `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`, `SUScheduledCheckInterval`
- [ ] 2.4 Adicionar entitlement `com.apple.security.network.client` em `App/BreezeFan.entitlements`
- [ ] 2.5 Regenerar projeto + verificar Sparkle.framework no bundle

## 3. SwiftUI integration

- [ ] 3.1 Criar `App/Updater/UpdaterController.swift`: wrapper SPUStandardUpdaterController
- [ ] 3.2 Criar `App/Updater/CheckForUpdatesView.swift`: SwiftUI Button bind to updater
- [ ] 3.3 Atualizar `BreezeFanApp.swift`: `@StateObject` do controller, passar via Environment
- [ ] 3.4 Substituir menu items "Check for Updates…" pra usar Sparkle (top bar + status item)
- [ ] 3.5 Build verifica Sparkle linkado sem erro

## 4. Remover UpdateChecker antigo

- [ ] 4.1 Deletar `App/State/UpdateChecker.swift`
- [ ] 4.2 Remover `availableUpdate: ReleaseInfo?` de `AppState`
- [ ] 4.3 Remover banner `updateBanner(_:)` em `MainView.swift`
- [ ] 4.4 Remover `Task.sleep(30s)` boot-time check em `BreezeFanApp.init()`
- [ ] 4.5 Build limpo (zero referências a `UpdateChecker` ou `ReleaseInfo`)

## 5. appcast.xml + GitHub Pages

- [ ] 5.1 Criar branch `gh-pages` localmente com `appcast.xml` template + `index.html`
- [ ] 5.2 Push branch `gh-pages`
- [ ] 5.3 (Manual user) Habilitar GitHub Pages em Settings → Pages → Source: `gh-pages` branch
- [ ] 5.4 Verificar `https://jeversonmisaeldacruz.github.io/Macfancontrol/appcast.xml` retorna 200

## 6. release.sh pipeline

- [ ] 6.1 Criar `scripts/release.sh <version>`: 9 passos do design D5
- [ ] 6.2 Validação semver + git status clean check
- [ ] 6.3 Smoke test: rodar `release.sh 0.3.0` (dry-run mode primeiro)

## 7. Documentação

- [ ] 7.1 Criar `docs/RELEASING.md` com fluxo de release + setup instructions
- [ ] 7.2 Atualizar README home + 3 idiomas com nota "auto-update via Sparkle"
- [ ] 7.3 Atualizar CLAUDE.md mencionando pasta `App/Updater/`

## 8. Live validation

- [ ] 8.1 Boot do app: confirmar Sparkle inicializa sem crash
- [ ] 8.2 Click "Check for Updates…" → Sparkle dialog aparece
- [ ] 8.3 Bumpar local pra 0.2.0 → release real 0.3.0 → ver Sparkle detectar e oferecer install
- [ ] 8.4 Click "Install Update" → app baixa, instala, relança como 0.3.0

## 9. Commit + push

- [ ] 9.1 Commit principal: feat sparkle integration
- [ ] 9.2 Commit appcast on gh-pages branch
- [ ] 9.3 Push main + gh-pages
