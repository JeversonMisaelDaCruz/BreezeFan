## ADDED Requirements

### Requirement: Sparkle framework integrado via SPM

O app SHALL integrar Sparkle 2.x como dependência SPM em `project.yml`. O framework SHALL ser linkado e embedded no bundle do app, não no helper. Helper continua sem dependências externas.

#### Scenario: Build inclui Sparkle.framework

- **WHEN** xcodebuild compila BreezeFan target em Debug ou Release
- **THEN** `BreezeFan.app/Contents/Frameworks/Sparkle.framework/` existe
- **AND** binário tem `Sparkle` linkado (verificável via `otool -L`)
- **AND** helper binário NÃO depende de Sparkle

### Requirement: Info.plist tem keys do Sparkle obrigatórias

O `Info.plist` do app SHALL ter:
- `SUFeedURL`: `https://jeversonmisaeldacruz.github.io/Macfancontrol/appcast.xml`
- `SUPublicEDKey`: chave pública EdDSA Ed25519 (string base64, 44 chars)
- `SUEnableAutomaticChecks`: true
- `SUScheduledCheckInterval`: 86400 (24h)

#### Scenario: Info.plist válido

- **WHEN** PlistBuddy lê o Info.plist do app instalado
- **THEN** as 4 keys acima existem com valores válidos

#### Scenario: SUPublicEDKey não placeholder

- **WHEN** o app é distribuído (release build)
- **THEN** `SUPublicEDKey` contém uma chave EdDSA real (não string vazia ou "TODO")

### Requirement: SPUStandardUpdaterController instanciado no app

O app SHALL instanciar `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)` como `@StateObject` no `BreezeFanApp` (entry point). Isso dispara auto-check em background no boot conforme `SUScheduledCheckInterval`.

#### Scenario: Boot do app faz check em background

- **WHEN** app inicia pela primeira vez após release de versão nova no GitHub
- **AND** se passou >= 24h desde último check (ou primeira vez)
- **THEN** Sparkle faz HTTP GET no `SUFeedURL`
- **AND** detecta nova versão
- **AND** mostra dialog padrão Sparkle: "A new version of BreezeFan is available!"

### Requirement: "Check for Updates…" menu items chamam Sparkle

Os 2 menu items "Check for Updates…" (top bar app menu + status item right-click) SHALL chamar `SPUUpdater.checkForUpdates()` em vez do `UpdateChecker.shared.checkForUpdates()` antigo.

#### Scenario: Click em Check for Updates da top bar

- **WHEN** usuário clica `🍎 BreezeFan → Check for Updates…`
- **THEN** Sparkle dialog aparece imediatamente (force check)
- **AND** se há update, mostra "Install Update" / "Skip This Version" / "Remind Me Later"
- **AND** se não há, mostra "You're up to date"

#### Scenario: Click do menu bar status item

- **WHEN** usuário clica direito no ícone fan da menu bar → "Check for Updates…"
- **THEN** mesmo comportamento que cima (Sparkle handle)

### Requirement: appcast.xml hospedado em GitHub Pages

O repo SHALL ter branch `gh-pages` com:
- `appcast.xml` no root, formato XML padrão do Sparkle
- Opcional `index.html` página simples descritiva

GitHub Pages SHALL ser habilitado em Settings com source = `gh-pages` branch / `(root)`.

URL final: `https://jeversonmisaeldacruz.github.io/Macfancontrol/appcast.xml`

#### Scenario: appcast.xml acessível publicamente

- **WHEN** `curl https://jeversonmisaeldacruz.github.io/Macfancontrol/appcast.xml`
- **THEN** retorna HTTP 200
- **AND** Content-Type é `application/xml` ou similar
- **AND** parseável como Sparkle appcast

#### Scenario: appcast tem entry da última release

- **WHEN** appcast.xml é parseado
- **THEN** `<channel><item>` com `<sparkle:version>` matching última release
- **AND** `<enclosure>` aponta pro DMG hospedado em GitHub Releases
- **AND** `<enclosure sparkle:edSignature>` tem assinatura EdDSA válida

### Requirement: Pipeline release.sh end-to-end

O script `scripts/release.sh <version>` SHALL automatizar release completa:

1. Validar version arg (semver)
2. Bumpar `CFBundleShortVersionString` e `CFBundleVersion` em `project.yml`
3. `xcodegen generate`
4. `./scripts/build-dmg.sh --version <v>` (gera `dist/BreezeFan-<v>.dmg`)
5. Run `sign_update <dmg>` → captura `sparkle:edSignature` e file size
6. Append nova `<item>` no `gh-pages/appcast.xml` no topo do channel
7. Commit `main` (project.yml bump) + push
8. Commit `gh-pages` (appcast update) + push
9. `gh release create <v> --title "BreezeFan <v>" --notes-file <gen> dist/BreezeFan-<v>.dmg`

#### Scenario: Release feliz path

- **WHEN** dev roda `./scripts/release.sh 0.3.0`
- **THEN** todos os 9 passos executam em ordem
- **AND** versão 0.3.0 visível em GitHub Releases + appcast.xml + commit history
- **AND** apps existentes detectam upgrade dentro do `SUScheduledCheckInterval` ou via Check for Updates

#### Scenario: Erro no meio aborta sem corrupção

- **WHEN** algum passo falha (ex: `gh release create` sem auth)
- **THEN** script aborta com erro claro
- **AND** não deixa appcast.xml ou GitHub release em estado inconsistente

### Requirement: setup-sparkle.sh gera chaves uma vez

O script `scripts/setup-sparkle.sh` SHALL:
1. Detectar tools do Sparkle (após `swift package resolve` ou direct download)
2. Rodar `generate_keys` (Sparkle CLI) — armazena private key em Keychain
3. Output public key formatada pra colar em `project.yml`/`Info.plist`

#### Scenario: Primeira execução

- **WHEN** dev roda `./scripts/setup-sparkle.sh` pela primeira vez
- **THEN** chave EdDSA é gerada
- **AND** private key salva em Keychain (item "ed25519 sparkle")
- **AND** public key (44 chars base64) impressa no terminal
- **AND** dev cola public key em `project.yml` SUPublicEDKey

#### Scenario: Re-execução com chave existente

- **WHEN** dev roda setup-sparkle.sh de novo (já tem chave no Keychain)
- **THEN** script detecta key existente, mostra public key sem regenerar
- **AND** alerta sobre risco de regenerar (invalidaria releases existentes)

### Requirement: UpdateChecker custom removido

O arquivo `App/State/UpdateChecker.swift` SHALL ser deletado. `AppState.availableUpdate` SHALL ser removido. Banner update em `MainView.swift` SHALL ser removido. Menu items que chamavam `UpdateChecker.shared` SHALL chamar Sparkle.

#### Scenario: Após migração

- **WHEN** repo é grep por `UpdateChecker` ou `availableUpdate`
- **THEN** zero resultados (apenas em git history)

#### Scenario: Banner antigo não aparece mais

- **WHEN** app está rodando com versão atual da release no GitHub
- **THEN** nenhum banner azul "Nova versão disponível" aparece
- **AND** Sparkle só aparece via dialog modal quando há update real
