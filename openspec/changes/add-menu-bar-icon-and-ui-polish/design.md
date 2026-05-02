## Context

App MVP funcional em MacBookPro18,3: janela 360×640 com temp readout, fan list, 4 presets, curve editor. SMC reads/writes via helper privilegiado XPC validados. Bugs de runtime (sanity, ceilings, animation) resolvidos.

Padrão macOS para apps de monitoramento de hardware é **menu bar utility**:
- Macs Fan Control da crystalidea: ícone na top bar + popover com presets
- iStat Menus: temp/CPU/network sempre visíveis na menu bar
- stats.app: vários sensors customizáveis na menu bar
- TG Pro: combo Dock + menu bar

Nosso app já tem helper rodando 24/7 — só falta visibilidade contínua. Adicionar menu bar não muda arquitetura; apenas adiciona client view alternativa.

JSX em `FanControl/app/main-mvp.jsx` foi modelado pra janela 360×640 (não popover). O popover terá layout simplificado mas reusando primitivos (FCDial-like temp display, preset buttons).

**Restrições**:
- macOS 14+ (já target). NSStatusItem API estável desde 10.10.
- App sandbox: `LSUIElement` é build setting + runtime call `NSApp.setActivationPolicy(.accessory)`.
- Popover NSPopover: tamanho mínimo 200pt, max ~600pt. SwiftUI hostable via `NSHostingView`.

## Goals / Non-Goals

**Goals:**
- G1. Ícone fan na menu bar sempre visível com tooltip dinâmico mostrando `<temp>°C · <leftRPM> RPM`.
- G2. Click esquerdo abre popover compacto (320×180 max) com temp + 4 preset buttons + link "Open FanControl".
- G3. Click direito abre menu nativo: Show Window / Quit / Toggle "Menu bar only".
- G4. Toggle "Menu bar only" em Preferences. Quando ativo, app roda como `accessory` (sem Dock icon). Default: false.
- G5. Status icon reflete modo: auto=cinza neutro, curve=accent, forced/max=danger red, conflict=warn amarelo.
- G6. Polish da janela principal: hover states, espaçamentos consistentes, animações de transição.
- G7. Atalhos de teclado: ⌘1-4 presets, ⌘E edit curve, ⌘W close window (mantém helper rodando).
- G8. Acessibilidade básica: VoiceOver labels em popover items.

**Non-Goals:**
- NG1. Popover com fan curve editor inline (overflow demais — abre janela full).
- NG2. Múltiplos ícones na menu bar (1 só por app — temp + fan combinado).
- NG3. Customização de qual sensor mostrar no tooltip (sempre cpuTemp).
- NG4. Notification Center widgets — change futura.
- NG5. Touch Bar support (deprecated hardware).
- NG6. Apple Silicon menu bar fan icon como SF Symbol custom — usar SF Symbol nativo.
- NG7. Dark/light mode adaptive icon — sempre semitransparent neutral.

## Decisions

### D1. NSStatusItem via classe AppKit, não SwiftUI MenuBarExtra

- **Escolhido**: `NSStatusItem` direto via `NSStatusBar.system.statusItem(withLength:)`, com `NSPopover` hostando uma `NSHostingView` da SwiftUI.
- **Alternativa**: SwiftUI 14+ `MenuBarExtra` scene — mais idiomática.
- **Razão**: `MenuBarExtra` tem limitações (não suporta detached popover, ícone reativo é mais difícil, escolha entre menu/window é estática). `NSStatusItem` dá controle total sobre click handlers (esquerdo vs direito), tooltip dinâmico, ícone reativo, e popover detachable. JSX referência mostra popover style, não menu nativo.

### D2. Popover detached: `NSPopover` com `behavior = .transient`

- **Escolhido**: NSPopover transient (fecha ao clicar fora). Tamanho 320×180. Hosta SwiftUI `MenuBarPopoverView`.
- **Alternativa**: NSPanel custom (mais customizável mas mais código).
- **Razão**: NSPopover tem chrome nativo macOS (seta apontando pro statusItem, blur, sombra), comportamento de fechar automático. Suficiente para nossas 4 preset buttons + temp display.

### D3. Status icon: SF Symbol "fan.fill" com tint reativo

- **Escolhido**: `Image(systemName: "fan.fill")` + dynamic `tintColor` via `NSStatusItem.button.contentTintColor`.
  - mode=auto → `nil` (default systemGray, segue light/dark mode)
  - mode=curve → `NSColor.controlAccentColor` (azul/accent do user)
  - mode=forced ou .max → `NSColor.systemRed`
  - smcConflict → `NSColor.systemYellow`
- **Alternativa**: 4 ícones diferentes (gear-fill, fan-fill, exclamation, etc).
- **Razão**: 1 ícone só (fan) é mais reconhecível; cor comunica estado sem ambiguidade. Padrão usado por iStat e Macs Fan Control.

### D4. Tooltip dinâmico atualizado a cada snapshot

- **Escolhido**: `statusItem.button?.toolTip = "<temp>°C · <leftRPM> RPM"` atualizado no `onChange` do snapshot.
- **Alternativa**: tooltip estático "FanControl".
- **Razão**: feedback contínuo sem precisar abrir popover. UX padrão de status apps.

### D5. Toggle "Menu bar only" controla `NSApp.activationPolicy`

- **Escolhido**: setting `menuBarOnly: Bool` em AppState. Quando muda:
  - true → `NSApp.setActivationPolicy(.accessory)` + esconde Dock icon
  - false → `NSApp.setActivationPolicy(.regular)` + mostra Dock icon
  - Persiste em state.json. Aplica no boot via init().
- **Alternativa**: build setting `LSUIElement` fixo (no toggle).
- **Razão**: usuário escolhe. Default = .regular pra primeiro contato visível. Toggle off "Menu bar only" pra modo "always available" sem Dock icon.

### D6. Popover reusa SwiftUI views existentes

- **Escolhido**: `MenuBarPopoverView` reusa `PresetGrid` + um temp display compacto (não o de 64pt). Helper client é o mesmo singleton.
- **Alternativa**: View 100% nova.
- **Razão**: DRY. Mudanças no helper protocol/state propagam automaticamente.

### D7. Polish: padronização de espaçamento via DesignTokens

- **Escolhido**: novo arquivo `App/Theme/Spacing.swift` com tokens:
  - `.xs = 4`, `.sm = 8`, `.md = 12`, `.lg = 16`, `.xl = 24`
- Aplicar em todos os `padding`, `spacing`, etc. JSX usa estes valores; replicar fielmente.
- **Razão**: hardcoded magic numbers (12, 18, 14...) tornam manutenção difícil.

### D8. Hover states via SwiftUI `.onHover` + `@State hovered`

- **Escolhido**: cada button interativo (PresetButton, "Edit fan curve", popover items) tem `@State var hovered = false` + `.onHover { hovered = $0 }`. Background muda com `.animation(.easeOut(duration: 0.15))`.
- **Alternativa**: NSTrackingArea (NSView level).
- **Razão**: SwiftUI native, declarative. Compatível com macOS 14+ sem hacks.

### D9. Transitions: tokens de timing em `App/Theme/Animations.swift`

- **Escolhido**:
  - `.fast = 0.15s` (hover, micro-interactions)
  - `.normal = 0.26s` (sheet open/close, mode change)
  - `.slow = 0.4s` (banner slide-in)
- Tudo `.easeOut`. Curve `cubic-bezier(.2,.8,.3,1)` que o JSX usa.

### D10. Atalhos de teclado via `.keyboardShortcut` modifier

- **Escolhido**: cada `PresetButton` recebe `.keyboardShortcut(...)` baseado no preset:
  - `.silent` → `.init("1", modifiers: .command)`
  - `.balanced` → `.init("2", modifiers: .command)`
  - `.performance` → `.init("3", modifiers: .command)`
  - `.max` → `.init("4", modifiers: .command)`
- "Edit fan curve" → `⌘E`
- Funciona quando janela está focada. Pra funcionar com janela fechada (menu bar only mode), implementar via `NSEvent.addGlobalMonitorForEvents` (out of MVP — change futura).

### D11. Sem reescrever JSX como referência — guideline texto only

- **Escolhido**: design.md guia spacing/animations/hover. Não criar novo JSX no `FanControl/`.
- **Razão**: JSX foi entregável de design phase. Implementação vai além sem dirty design source.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| **R1**. Popover transient fecha quando user move cursor para outra app | Comportamento padrão; aceitável. Se virar pain, adicionar opção "pin popover" (out of MVP). |
| **R2**. SF Symbol `fan.fill` pode não estar disponível em todas as versões macOS | macOS 14+ tem. Fallback: usar `gearshape.2.fill`. |
| **R3**. NSStatusItem em background app pode não receber events em todos os contextos | Standard pattern; testar em fullscreen mode. |
| **R4**. Toggle de Activation Policy em runtime pode causar glitch visual | Aceitável pra um setting raramente mudado. Pode pedir relaunch se necessário. |
| **R5**. Hover states em SwiftUI podem ter delay perceptível em alguns macOS | `.animation(.easeOut(duration: 0.15))` mascara isso. |
| **R6**. Tooltip dinâmico pode causar flicker se snapshot atualiza muito rápido | Atualizar tooltip apenas a cada 2s (não a cada 1s do polling). |
| **R7**. Atalhos ⌘1-4 podem conflitar com other apps em focus | Funcionam apenas quando FanControl é foreground. Aceitável MVP. |

## Migration Plan

### Sequência

1. **Polish da janela existente** primeiro (Spacing tokens, Animations tokens, hover states) — não bloqueia menu bar.
2. **Menu bar core** (StatusItem + popover básico com temp).
3. **Popover funcional** (preset buttons + link).
4. **LSUIElement toggle** + Preferences.
5. **Atalhos teclado**.
6. **Smoke live**.

### Rollback

Tudo é aditivo. Reverter commits restaura janela como está hoje. Toggle "Menu bar only" pode ser removido sem afetar app principal.

### Validação live

- [ ] Boot do app: ícone aparece na menu bar com tooltip "<temp>°C · <leftRPM> RPM"
- [ ] Click esquerdo no ícone abre popover; click fora fecha
- [ ] Click em "Silent" no popover muda preset (visualmente reflete na janela tb)
- [ ] Click em "Open FanControl" no popover traz janela à frente
- [ ] Click direito no ícone abre menu com "Show Window" / "Quit" / "Menu bar only"
- [ ] Toggle "Menu bar only" → Dock icon some; reabrir aplica
- [ ] ⌘1 com janela focada aplica Silent
- [ ] Hover em qualquer button mostra mudança visual sutil
- [ ] Trocar mode (Balanced→Curve) tem transição visual suave

## Open Questions

**OQ1**. Devemos persistir o estado do popover (último view, etc.) entre sessões? **Resposta**: não — popover sempre abre limpo no estado padrão (presets, sem curve editor).

**OQ2**. O ícone na menu bar deve mostrar texto além do ícone (ex: "65°C")? **Resposta**: out of MVP. Apenas tooltip. Se virar request, adicionar `statusItem.button?.title` em change futura.

**OQ3**. Atalhos globais (funcionar fora da janela)? **Resposta**: out of MVP. Requer permissão extra (Accessibility) que adiciona fricção.
