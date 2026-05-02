## ADDED Requirements

### Requirement: NSStatusItem com ícone fan na menu bar do macOS

O app SHALL instalar um `NSStatusItem` na menu bar via `NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)` no boot do app. O ícone SHALL ser o SF Symbol `"fan.fill"` (fallback `"gearshape.2.fill"` se indisponível). O ícone SHALL ser instalado **antes** da janela principal abrir, garantindo que está sempre visível desde o launch.

#### Scenario: Boot inicial do app

- **WHEN** o usuário abre o app pela primeira vez
- **THEN** dentro de 500ms aparece um ícone de fan na menu bar
- **AND** o tooltip do ícone diz "FanControl" inicialmente
- **AND** a janela principal aparece simultaneamente (a menos que `menuBarOnly` esteja ativo)

#### Scenario: Reaberto via Dock

- **WHEN** o app já estava rodando em background e usuário clica no ícone do Dock
- **THEN** a janela principal aparece
- **AND** o ícone na menu bar continua visível (não é re-instanciado)

#### Scenario: SF Symbol não disponível

- **WHEN** o app inicia em macOS futuro onde "fan.fill" não existe
- **THEN** usa fallback "gearshape.2.fill"
- **AND** loga warn `"Status icon: fan.fill unavailable, using fallback"`

### Requirement: Tooltip dinâmico no ícone reflete temp + RPM

O tooltip do `NSStatusItem.button` SHALL ser atualizado a cada 2 segundos com formato `"<int(cpuTemp)>°C · <leftRPM> RPM"`. Se cpuTemp ou leftRPM forem nil, mostrar `"—"` no lugar.

#### Scenario: Tooltip com leitura válida

- **WHEN** snapshot tem cpuTemp=49.5 e leftRPM=2300
- **AND** 2 segundos se passam desde última atualização
- **THEN** tooltip exibe "50°C · 2300 RPM"

#### Scenario: Tooltip com leitura indisponível

- **WHEN** snapshot.cpuTemp=nil e snapshot.leftRPM=nil
- **THEN** tooltip exibe "— · — RPM"

#### Scenario: Tooltip durante hover

- **WHEN** o usuário paira o cursor sobre o ícone na menu bar
- **THEN** o tooltip aparece após o delay padrão do macOS (~1s)
- **AND** mostra valores atualizados (não cacheados de quando o ícone foi clicado pela última vez)

### Requirement: Cor do ícone reflete o modo ativo

A cor de tint do ícone (`statusItem.button.contentTintColor`) SHALL refletir o modo ativo:
- **Auto**: `nil` (default systemGray, segue light/dark)
- **Curve**: `NSColor.controlAccentColor` (accent do user)
- **Forced** ou preset Max: `NSColor.systemRed`
- **smcConflict** (banner amarelo): `NSColor.systemYellow` (overrides cor do mode)

#### Scenario: Modo Auto

- **WHEN** mode=auto e smcConflict=false
- **THEN** ícone aparece em cor neutra padrão do sistema

#### Scenario: Modo Curve ativo

- **WHEN** mode=curve
- **THEN** ícone fica colorido com `NSColor.controlAccentColor` (azul ou cor escolhida pelo user)

#### Scenario: SMC Conflict

- **WHEN** smcConflict=true (outro app controla fans)
- **AND** mode=forced
- **THEN** ícone fica amarelo (warn override) — conflict tem prioridade visual

### Requirement: Click esquerdo abre popover com controles compactos

O `NSStatusItem` SHALL detectar click esquerdo e abrir um `NSPopover` (transient behavior) ancorado no botão. O popover SHALL ter dimensões `320×180pt` e conter:

1. Header compacto com temperatura grande (font 32pt, tabular-nums) + unidade
2. Subtext com "Running cool · 2 fans active" (mesmo formato da janela principal)
3. Grid 2×2 com 4 preset buttons (mesmo estilo da janela)
4. Botão "Open FanControl →" no rodapé que traz janela principal pra frente

Click fora do popover SHALL fechá-lo.

#### Scenario: Click no ícone abre popover

- **WHEN** o usuário clica esquerdo no ícone
- **THEN** o popover desliza pra fora abaixo do ícone com animação padrão macOS
- **AND** mostra temp atual + 4 presets

#### Scenario: Click em preset dentro do popover

- **WHEN** popover está aberto e usuário clica em "Silent"
- **THEN** XPC `applyPreset(.silent)` é chamado (mesmo do botão da janela)
- **AND** o botão fica visualmente selecionado
- **AND** o popover NÃO fecha automaticamente (usuário pode trocar de preset)

#### Scenario: Click em "Open FanControl"

- **WHEN** popover aberto, usuário clica no link "Open FanControl →"
- **THEN** janela principal vem pra frente (`NSApp.activate(ignoringOtherApps: true)`)
- **AND** popover fecha
- **AND** se janela estava minimizada/fechada, é mostrada

#### Scenario: Click fora fecha popover

- **WHEN** popover aberto, usuário clica em outra app ou outro lugar
- **THEN** popover fecha em ~150ms

### Requirement: Click direito abre menu nativo com opções

O `NSStatusItem` SHALL detectar click direito (ou Control+click) e mostrar `NSMenu` nativo com items:
1. **Show Window** (⌘0) — traz janela principal à frente
2. **Edit fan curve…** (⌘E) — abre janela com sheet de curve editor já aberto
3. *Separator*
4. **Menu bar only** (toggle, ✓ se ativo) — alterna `menuBarOnly` setting
5. **Open System Settings** — abre Login Items pra aprovar helper se necessário
6. *Separator*
7. **Quit FanControl** (⌘Q) — encerra app (helper continua rodando)

#### Scenario: Click direito no ícone

- **WHEN** o usuário clica direito ou Control+click no ícone
- **THEN** menu nativo aparece com 7 items
- **AND** "Menu bar only" tem checkmark ✓ se setting estiver true

#### Scenario: Selecionar Show Window

- **WHEN** menu aberto, usuário clica "Show Window"
- **THEN** janela principal vem à frente
- **AND** menu fecha

#### Scenario: Toggle Menu bar only

- **WHEN** menu aberto e setting menuBarOnly=false
- **AND** usuário clica "Menu bar only"
- **THEN** setting muda para true
- **AND** Dock icon some (NSApp.setActivationPolicy(.accessory))
- **AND** janela principal NÃO fecha (continua visível se estava aberta)
- **AND** próximo boot mantém menu bar only ativo

#### Scenario: Quit do menu

- **WHEN** usuário clica "Quit FanControl"
- **THEN** o app encerra
- **AND** o ícone some da menu bar
- **AND** o helper continua rodando como root daemon (separado)

### Requirement: Menu bar only mode esconde Dock icon

Quando `AppState.menuBarOnly == true`, o app SHALL chamar `NSApp.setActivationPolicy(.accessory)` que remove o ícone do Dock. Quando muda para false, SHALL chamar `NSApp.setActivationPolicy(.regular)`. A mudança SHALL ser persistida em `state.json`. Setting é aplicado no boot via init de AppState.

#### Scenario: Boot com menuBarOnly=true

- **WHEN** state.json contém `"menuBarOnly": true`
- **AND** app inicia
- **THEN** Dock icon NÃO aparece
- **AND** ícone da menu bar aparece normalmente
- **AND** janela principal NÃO abre automaticamente (seria estranho sem Dock)

#### Scenario: Toggle ativando menuBarOnly em runtime

- **WHEN** menuBarOnly=false e janela aberta
- **AND** usuário toggles via menu (⌘ direito → Menu bar only)
- **THEN** Dock icon some imediatamente
- **AND** janela continua visível (não fecha)
- **AND** state.json é atualizado com menuBarOnly=true

### Requirement: Atalhos de teclado para presets quando janela focada

Quando a janela principal está focada (key window), os atalhos SHALL funcionar:
- `⌘1` → Silent
- `⌘2` → Balanced
- `⌘3` → Performance
- `⌘4` → Max
- `⌘E` → Edit fan curve
- `⌘W` → Close window (mas mantém helper + menu bar item)
- `⌘Q` → Quit (encerra app, helper continua)

#### Scenario: ⌘3 com janela focada

- **WHEN** janela principal está focada
- **AND** usuário pressiona ⌘3
- **THEN** preset Performance é aplicado (XPC applyPreset(.performance))
- **AND** botão Performance fica visualmente selecionado

#### Scenario: ⌘1 com janela em background

- **WHEN** janela está em background (outra app focada)
- **AND** usuário pressiona ⌘1
- **THEN** atalho NÃO dispara (FanControl não é focused app)

#### Scenario: ⌘W fecha janela mas mantém app

- **WHEN** janela aberta e focada
- **AND** usuário pressiona ⌘W
- **THEN** janela fecha
- **AND** ícone na menu bar permanece visível
- **AND** helper continua rodando
- **AND** clicar no Dock (ou no ícone da menu bar) reabre a janela
