## Why

O MVP funciona em hardware real (MacBookPro18,3): helper instalado, presets aplicam, curva edita, RPM/temp em tempo real. Próximo passo é tornar o app **utilitário de menu bar** (NSStatusItem) — padrão macOS para apps de monitoramento (stats.app, iStat Menus, Macs Fan Control próprio) — e elevar a estética da janela principal pra ficar à altura do design Tahoe/Liquid Glass que o JSX especifica.

Hoje o usuário precisa abrir a janela toda vez que quer trocar preset ou checar temperatura. Com ícone de menu bar:
1. Status sempre visível (temp + fan ativo) sem ocupar Dock
2. Click rápido abre popover compacto OU traz janela principal
3. App pode rodar em background sem janela aberta (control loop continua via helper)

Sobre estética: o atual já está alinhado com o JSX, mas tem detalhes que destoam — espaçamentos inconsistentes em sections, hover states visuais ausentes em buttons, animações de mode change sem easing, separadores às vezes muito sutis ou muito grossos, e nenhum feedback visual quando preset está in-flight (só ProgressView pequeno).

## What Changes

- **Menu bar icon (NSStatusItem) sempre visível** com ícone de fan SF Symbol e tooltip "<temp>°C · <fan>RPM". Click esquerdo: abre popover de 320×180 com leitura compacta (temp big + 4 preset buttons + "Open FanControl" link). Click direito: menu nativo com "Show window", "Show in Dock", "Quit".
- **Popover compacto**: subset da janela principal — 1 linha de temp, 4 botões de preset, link pra abrir janela completa. Reusa AppState e helper client.
- **App configurável como `LSUIElement`** (background app sem ícone Dock) via toggle nas Preferences. Default: ícone no Dock + menu bar (ambos). Toggle para "menu bar only" esconde Dock icon ao reabrir.
- **Polish da janela principal**:
  - Espaçamento padronizado entre sections (16pt vertical consistente)
  - Hover state em todos os botões (background lift sutil)
  - Active preset com transição easing `0.2s ease-out` no border + background
  - "Edit fan curve" footer mais destacado (subtle accent border quando hovered)
  - Banner de erro/loading com slide animation
  - Snapshot atualiza com fade transition curto ao invés de instant swap
- **Status na menu bar reflete modo ativo**: ícone normal em Auto, accent (azul) em Curve, vermelho em Forced/Max, amarelo se SMC conflict.
- **Atalhos de teclado** nas Preferences: ⌘1=Silent, ⌘2=Balanced, ⌘3=Performance, ⌘4=Max, ⌘E=Edit curve.
- **Acessibilidade**: VoiceOver labels em todos os elementos do popover; menu bar tooltip dinâmico.
- **Sem mudança no helper**: tudo é UI-side. Helper continua intocado.

## Capabilities

### New Capabilities

- `menu-bar-app`: NSStatusItem + popover, ícone de status reativo ao mode, click handlers, integração com cabeçalho da app.

### Modified Capabilities

- `app-shell`: polish dos espaçamentos, hover states, transições, e suporte a `LSUIElement` toggle.

## Impact

- **Código**:
  - `App/MenuBar/StatusItemController.swift` (novo): NSStatusItem singleton com ícone reativo + popover (NSPopover ou NSPanel).
  - `App/MenuBar/MenuBarPopoverView.swift` (novo): SwiftUI popover view.
  - `App/MenuBar/StatusIcon.swift` (novo): helper para gerar SF Symbol composto com tint reativo ao mode.
  - `App/FanControlApp.swift`: instancia `StatusItemController` no init, configura LSUIElement opt-in.
  - `App/Window/FCWindow.swift` + `App/Views/MainView.swift`: ajustes de spacing/hover/transition.
  - `App/Theme/Animations.swift` (novo): tokens de animation timing (`.fast=0.15s`, `.normal=0.26s`, `.slow=0.4s`).
  - `App/Views/PresetButton.swift`: hover scale 1.02 + accent glow no hover.
  - `App/Info.plist`: opt-in `LSUIElement` via build setting controlado por Preferences.
  - `App/State/AppState.swift`: adicionar `menuBarOnly: Bool` setting + sync com NSApp activation policy.
- **Sem mudança no Helper**.
- **Sem mudança no XPC protocol** — UI lê snapshot existente e renderiza no menu bar.
- **Sem migration de schema**: state.json ganha campos novos opcionais (Codable backward-compat).
- **Risco**: baixo. Mudanças são aditivas; janela principal continua funcionando se LSUIElement=false.
- **Validação**: 
  - Ícone aparece na menu bar com temp atualizando a cada 1s
  - Click abre popover, presets dentro do popover funcionam
  - Toggle "menu bar only" em Preferences esconde Dock icon
  - Atalhos de teclado funcionam mesmo com janela fechada
  - Hover states visíveis em todos os botões
