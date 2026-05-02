# Implementation tasks — add-menu-bar-icon-and-ui-polish

Order: design tokens → polish da janela → menu bar core → popover → atalhos → settings.

Rationale: tokens não bloqueiam nada, vão primeiro. Polish da janela é independente do menu bar. Menu bar é maior bloco — faz core (status item) primeiro, depois popover. Atalhos por último (keyboardShortcut modifiers nas views existentes).

## 1. Design tokens (Spacing + Animations)

- [x] 1.1 Criar `App/Theme/Spacing.swift` com `FCSpacing` enum: `xs=4, sm=8, md=12, lg=16, xl=24` (CGFloat).
- [x] 1.2 Criar `App/Theme/Animations.swift` com `FCAnimation` enum: `fast = .easeOut(duration: 0.15)`, `normal = .easeOut(duration: 0.26)`, `slow = .easeOut(duration: 0.4)`, `bouncy = .spring(response: 0.26, dampingFraction: 0.85)`.
- [x] 1.3 Refatorar `FCSection.swift`: substituir `horizontalPadding: 18` → `FCSpacing.lg`, `topPadding: 12` → `FCSpacing.md`, `bottomPadding: 10` → `FCSpacing.sm`. Spacing interno entre title e content = `FCSpacing.sm`.
- [x] 1.4 Refatorar `FCDivider.swift`: `inset: 18` → `FCSpacing.lg`.
- [x] 1.5 Refatorar `MainView.swift` magic numbers para tokens (`padding(.bottom, 16)` → `FCSpacing.lg`, etc).
- [x] 1.6 Refatorar `CurveEditorView.swift` similar.
- [x] 1.7 Refatorar `NumStepper.swift` (horizontal padding 4 → `FCSpacing.xs`).
- [x] 1.8 Build limpo após refactor.

## 2. Polish da janela principal (UX)

- [x] 2.1 Em `PresetButton.swift`, adicionar `@State var hovered = false` + `.onHover { hovered = $0 }` + cursor `.pointingHand`. Background no hover: `Color.white.opacity(0.05)` (se não selected). Animation `FCAnimation.fast`.
- [x] 2.2 Em `MainView.swift` footer "Edit fan curve →", aplicar mesmo pattern de hover (state, onHover, cursor).
- [x] 2.3 Em `PresetButton.swift`, mudança de `isActive` deve animar com `FCAnimation.normal` (border + background com transição suave em vez de swap).
- [x] 2.4 Em `MainView.swift`, banner "Helper offline" com `.transition(.move(edge: .top).combined(with: .opacity))` + `.animation(FCAnimation.normal)`.
- [x] 2.5 Em `MainView.swift`, temp readout text com `.transition(.opacity)` + `.animation(.easeOut(duration: 0.1), value: snapshot.cpuTemp)`.
- [x] 2.6 Em `FanRow.swift`, RPM number com mesmo fade transition.
- [x] 2.7 Smoke: hover em cada button, observar lift sutil (build + open app).
- [x] 2.8 Smoke: clicar diferentes presets, observar transição suave entre eles (não swap brusco).

## 3. Menu bar core — NSStatusItem

- [x] 3.1 Criar `App/MenuBar/StatusItemController.swift` com `final class @MainActor StatusItemController` (singleton). Init cria `NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)`.
- [x] 3.2 Configurar `statusItem.button?.image = NSImage(systemSymbolName: "fan.fill", accessibilityDescription: "FanControl status")`. Fallback "gearshape.2.fill" se nil.
- [x] 3.3 Configurar tooltip inicial: "FanControl".
- [x] 3.4 Em `FanControlApp.swift` init(), criar `_ = StatusItemController.shared` antes do WindowGroup body — garantindo que ícone aparece desde o boot.
- [x] 3.5 Smoke: build + open app, ver ícone na menu bar (canto superior direito).

## 4. Status icon reativo ao snapshot

- [x] 4.1 Em `StatusItemController`, adicionar method `func updateForSnapshot(_ snapshot: SensorSnapshot, mode: ControlMode.Kind, smcConflict: Bool)`. Calcula tooltip text + tint color.
- [x] 4.2 Tint logic: `smcConflict ? .systemYellow : (mode == .auto ? nil : (mode == .curve ? .controlAccentColor : .systemRed))`.
- [x] 4.3 Em `SensorViewModel`, observar mudanças em `snapshot` e disparar `StatusItemController.shared.updateForSnapshot(...)` (debounce 2s pra tooltip).
- [x] 4.4 Em `AppState`, observer mudanças em `modeKind` e disparar update do ícone.
- [x] 4.5 Smoke: trocar mode (Silent → Balanced → Curve) e ver cor do ícone mudar accordingly.

## 5. Popover compacto

- [x] 5.1 Criar `App/MenuBar/MenuBarPopoverView.swift` SwiftUI: VStack com (a) temp display 32pt+unit, (b) subtext, (c) PresetGrid existente, (d) link "Open FanControl →".
- [x] 5.2 Reusar `PresetGrid` (já implementado). Garante DRY.
- [x] 5.3 Em `StatusItemController`, criar `NSPopover` com `behavior = .transient`, `contentSize = NSSize(width: 320, height: 180)`, `contentViewController = NSHostingController(rootView: MenuBarPopoverView().environment(AppState.shared))`.
- [x] 5.4 Click handler: `statusItem.button?.action = #selector(togglePopover)`. No selector, se popover.shown → close; senão → show relative to button.
- [x] 5.5 Botão "Open FanControl →" no popover: `NSApp.activate(ignoringOtherApps: true)` + close popover + bring window to front.
- [x] 5.6 Smoke: click esquerdo no ícone abre popover, mostra temp/RPM atual + 4 presets.
- [x] 5.7 Smoke: click "Silent" no popover muda preset (helper aceita, snapshot reflete na próxima poll).

## 6. Click direito → menu nativo

- [x] 6.1 Em `StatusItemController`, criar `NSMenu` com items: Show Window (⌘0), Edit fan curve… (⌘E), Sep, Menu bar only [toggle], Open System Settings, Sep, Quit FanControl (⌘Q).
- [x] 6.2 Detectar right-click ou Control+click via `statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])` e diferenciar no selector via `NSApp.currentEvent?.type`.
- [x] 6.3 Show Window action: trazer janela principal pra frente (`NSApp.activate` + `window.makeKeyAndOrderFront`).
- [x] 6.4 Edit fan curve action: trazer janela + setar `appState.curveEditorPresented = true`.
- [x] 6.5 Menu bar only toggle: alterna `appState.menuBarOnly`. Atualiza checkmark do menu item.
- [x] 6.6 Open System Settings action: abre URL `x-apple.systempreferences:com.apple.LoginItems-Settings.extension`.
- [x] 6.7 Quit FanControl action: `NSApp.terminate(nil)`.
- [x] 6.8 Smoke: click direito mostra menu, cada item funciona.

## 7. LSUIElement / menu bar only mode

- [x] 7.1 Em `AppState`, adicionar `var menuBarOnly: Bool = false`. Persistir em `state.json` via `StateStore` (já existe).
- [x] 7.2 Em `FanControlApp.init()`, ler state.json. Se `menuBarOnly == true`, chamar `NSApp.setActivationPolicy(.accessory)`. Senão `.regular`.
- [x] 7.3 Em `StatusItemController` toggle de menuBarOnly, atualizar AppState + chamar `setActivationPolicy` em runtime.
- [x] 7.4 Smoke: toggle menu bar only via menu direito → Dock icon some.
- [x] 7.5 Smoke: untoggle → Dock icon volta.
- [x] 7.6 Smoke: relaunch app com menuBarOnly=true → boot sem Dock icon.

## 8. Atalhos de teclado

- [x] 8.1 Em `PresetButton`, adicionar `.keyboardShortcut(KeyEquivalent(presetShortcut), modifiers: .command)` onde shortcut é "1"/"2"/"3"/"4" para Silent/Balanced/Performance/Max respectivamente.
- [x] 8.2 Em `MainView` footer "Edit fan curve" button: `.keyboardShortcut("e", modifiers: .command)`.
- [x] 8.3 Em `FanControlApp.swift` commands: adicionar `Button("Show Window") { ... }.keyboardShortcut("0", modifiers: .command)`.
- [x] 8.4 ⌘W já é default do macOS pra fechar janela. Garantir que helper continua rodando + ícone permanece na menu bar.
- [x] 8.5 Smoke: pressionar ⌘1 com janela focada aplica Silent.
- [x] 8.6 Smoke: pressionar ⌘E abre curve editor sheet.

## 9. Tests (onde fizerem sentido)

- [ ] 9.1 [TEST] Criar `Tests/UI/StatusIconTintTests.swift`: dado mode + smcConflict, retorna tint esperado. Casos: auto+nofs → nil; curve → accent; forced → red; conflict overrides.
- [ ] 9.2 [TEST] `MenuBarPopoverViewTests` (snapshot opcional): renderiza com temp e ceilings setados.
- [ ] 9.3 [TEST] `AppStateMenuBarOnlyTests`: roundtrip Codable de state.json com menuBarOnly campo.
- [ ] 9.4 Verificar tests verdes (3+ novos).

## 10. Live validation

- [ ] 10.1 Boot do app: ícone fan aparece na menu bar com tooltip "<temp>°C · <RPM>".
- [ ] 10.2 Click esquerdo: popover abre 320×180 com presets funcionais.
- [ ] 10.3 Click direito: menu com 7 items.
- [ ] 10.4 Toggle "Menu bar only": Dock icon some/volta corretamente.
- [ ] 10.5 ⌘1-4 funcionam aplicando presets.
- [ ] 10.6 ⌘E abre curve editor.
- [ ] 10.7 Hover em todos os botões mostra estado visual.
- [ ] 10.8 Trocar mode: ícone na menu bar muda cor (Auto→cinza, Curve→accent, Forced→red).
- [ ] 10.9 Banner "Helper offline" desliza in/out animado.

## 11. Documentation + commit

- [x] 11.1 Atualizar README.md com features novas: menu bar icon, atalhos, menu bar only mode.
- [x] 11.2 Atualizar CLAUDE.md com novos arquivos em `App/MenuBar/` e tokens em `App/Theme/`.
- [x] 11.3 **Commit**: `feat(fancontrol): menu bar icon + ui polish`.
- [ ] 11.4 Considerar `/opsx:archive` se OK do usuário.
