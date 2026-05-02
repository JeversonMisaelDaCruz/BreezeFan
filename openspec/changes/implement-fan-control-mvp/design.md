## Context

**Hardware alvo**: MacBook Pro 14" M1 Pro (2021), identificador `MacBookPro18,3`, com **2 fans** (Left/Right) e cluster de CPU performance + efficiency + GPU clusters acessiveis via SMC e IOHID. Confirmado pelo `system_profiler SPHardwareDataType` do usuario.

**Estado atual**: usuario depende do **Macs Fan Control da crystalidea** (Qt/C++, LGPL, repo `crystalidea/macs-fan-control`). Esse app roda em M1 e controla fans, mas oferece somente: modo Auto, modo Forced (Min/Max constante), e um modo "sensor-based" linear simples. Nao tem curve multi-step, nao tem presets nomeados, e a UI Qt destoa do macOS Tahoe.

**Design pronto**: a UI esta inteiramente modelada em React/JSX em `FanControl/` (criada em sessao anterior). Os arquivos sao referencia visual viva — janela 360x640 com `window-shell.jsx` (traffic lights, glow do accent, grain noise SVG), tela principal `main-mvp.jsx` (temp readout 64px, lista de fans com RPM/duty + ícone girando, 4 presets, footer Edit fan curve), e modal de curva `curve-mvp.jsx` (graph SVG temp x duty, tabela de steps com NumStepper). O `atoms.jsx` define os primitivos (`FCDial`, `FCMeter`, `FCFanRow`, `FCSection`, `FCDivider`).

**Restricoes Apple**:
1. App sandbox NAO tem permissao para escrever em SMC. Solucao: helper privilegiado separado.
2. SMJobBless (legacy) deprecated em macOS 13. Substituto oficial: `SMAppService` (Ventura+).
3. Sem distribuicao na MAS no MVP — code signing ad-hoc, usuario aprova manualmente.
4. SMC keys de Apple Silicon foram parcialmente reverse-engineered por crystalidea (LGPL permite reuso da tabela). Sensores de temp em M1 usam nomes diferentes do Intel (`Tp01`/`Tp09`/`Tg05` em vez de `TC0P`/`TG0P`).

**Stakeholder unico**: o proprio usuario (jeverson@). Sem revisao externa, sem requisitos de outros usuarios. Prioridades: (1) entregar MVP em uma investida, (2) UI fiel ao JSX, (3) seguranca termica.

**Memoria do projeto** (vide CLAUDE.md raiz): TDD obrigatorio em todas as changes, commitar direto na main sem PR, confirmar antes de qualquer reset/destruicao.

## Goals / Non-Goals

**Goals:**

- G1. Substituir o **Macs Fan Control** no uso diario do usuario, com paridade nas funcoes basicas (Auto, Min/Max constante, leitura de RPM/temp).
- G2. Adicionar **3 capacidades novas** que o app atual nao tem: (a) curva multi-step com histerese, (b) 4 presets MVP nomeados (Silent/Balanced/Performance/Max), (c) UI nativa Liquid Glass.
- G3. Fidelidade visual com o design JSX existente — janela 360x640, traffic lights desenhados, fonte SF Pro, tipografia tabular-nums, animacoes de sheet.
- G4. **Seguranca termica**: control loop com safety override que ignora curva e seta target = max se temp passar 95°C.
- G5. **Reversibilidade total**: desinstalar o helper devolve controle de fans ao macOS em < 2s, sem deixar lixo no sistema.
- G6. **TDD em toda logica testavel**: curve interpolation, hysteresis, FPE2 encoding, mode transitions, safety override — todos com unit tests passando antes de integrar.

**Non-Goals:**

- NG1. **Cross-hardware**: nao roda em Intel Mac, nao roda em M1 base 13" (1 fan), nao roda em M2/M3. App detecta `MacBookPro18,3` e desabilita controle gracefully em outros modelos.
- NG2. **App binding** (Final Cut abre -> troca pra Performance): vai pra change futura.
- NG3. **Curvas nomeadas multiplas**: MVP guarda **1 curva ativa**. Salvar/listar curvas nomeadas vai pra change futura.
- NG4. **Bateria override** (cap em 60% quando desplugado): change futura.
- NG5. **Historico/grafico** de RPM/temp ao longo do tempo: change futura.
- NG6. **Notarization + distribuicao**: code signing ad-hoc para dev. Apple Developer ID ($99/ano) e notarytool entram quando/se for distribuir.
- NG7. **Mac App Store**: helpers privilegiados nao sao permitidos na MAS. App ficara em distribuicao direta.
- NG8. **Localizacao**: UI em ingles apenas (igual ao JSX). i18n vai pra change futura.
- NG9. **Acessibilidade plena (VoiceOver, Dynamic Type)**: cobertura basica do SwiftUI default. Auditoria de a11y vai pra change futura.

## Decisions

### D1. Linguagem: Swift + SwiftUI

- **Escolhido**: Swift 5.10 + SwiftUI + AppKit (Xcode 16+, deployment target macOS 14 Sonoma)
- **Alternativas consideradas**:
  - **Go via cgo**: viraria FFI manual para IOKit/SMAppService/XPC; SwiftUI nao tem equivalente em Go (Wails/Fyne nao chega no Liquid Glass); RAM idle 60-150MB vs 5-15MB do Swift.
  - **Objective-C++ + AppKit**: funcional, mas overhead de bridging desnecessario num greenfield e custo de manutencao maior.
  - **Rust + Tauri**: similar ao Go — IOKit via FFI manual, UI via webview nao chega na fidelidade.
- **Razao**: SwiftUI mapeia 1:1 com o JSX (`Section`/`Divider`/`Button` em vez de `<div>`); IOKit e nativo via `IOServiceOpen`; `ServiceManagement.SMAppService` e API moderna; `NSXPCConnection` type-safe com Codable; comunidade ativa de exemplos M1 (`exelban/stats` MIT, `MonitorControl`, `SMCKit`).

### D2. Arquitetura: app sandbox + helper privilegiado (2 binarios)

- **Escolhido**: `FanControl.app` (UI sandboxed, sem entitlements de root) + `FanControlHelper` (LaunchDaemon root)
- **Alternativa**: 1 binario rodando como root via `authopen` ou setuid.
- **Razao**: Apple proibe app GUI rodando como root desde Mojave; futura distribuicao na MAS exige app sandboxed; pattern oficial Apple e split via `SMAppService` + XPC; permite revogar privilegios do helper sem desinstalar o app.

### D3. Instalacao do helper: SMAppService.daemon

- **Escolhido**: `SMAppService.daemon(plistName: "com.fancontrol.helper.plist").register()`
- **Alternativa**: `SMJobBless` (legacy, deprecated macOS 13).
- **Razao**: SMJobBless da warnings em compilers modernos; SMAppService e a API recomendada Apple desde Ventura. Plist do helper vive em `Contents/Library/LaunchDaemons/com.fancontrol.helper.plist` **dentro do app bundle** (nao em `/Library/LaunchDaemons/` como antes — SMAppService gerencia copia).
- **Trade-off**: minimo macOS 14 (excluindo Monterey/Big Sur). Aceitavel — usuario esta em Sonoma+.

### D4. Comunicacao app <-> helper: NSXPCConnection com protocol typed

- **Escolhido**: `NSXPCConnection` com `NSXPCInterface(with: HelperProtocol.self)` em Swift, todos os args/returns `Codable` Swift.
- **Alternativas**: Mach ports raw, UNIX domain socket.
- **Razao**: type-safe, async/await em Swift moderno (`continuation`), reconnect automatico, suporta Codable. Mach/UNIX exigiriam serializacao manual e tratamento de invalidation.

### D5. SMC keys: derivar de onde

- **Escolhido**: portar a tabela de `crystalidea/macs-fan-control/osx/smc.h` + `osx/smc_keys.h` para Swift como struct estatica `SMCKey`. Validar cada key no boot do helper (`SMCReadKey` retorna sucesso ou nao).
- **Alternativa**: reverse engineering via `ioreg -lr` no MacBookPro18,3 — levaria semanas e duplicaria trabalho.
- **Razao**: licenca LGPL do crystalidea permite reusar a tabela (constantes, nao codigo). Validacao no boot detecta se Apple mudou nomes em macOS futuro.
- **Keys core que precisam funcionar em `MacBookPro18,3`**:
  ```
  Fans:  F0Ac, F0Md, F0Mn, F0Mx, F0Tg, F1Ac, F1Md, F1Mn, F1Mx, F1Tg, FNum
  Temp:  Tp01, Tp05, Tp09, Tp0D, Tp0H (CPU performance clusters)
         Tg05, Tg0D (GPU clusters) — fallback IOHID se SMC nao expor
  ```

### D6. Leitura de temperatura: SMC primeiro, IOHID fallback

- **Escolhido**: tentar ler `Tp01..Tp0H` via SMC; se qualquer chave retornar erro, fallback para `IOHIDEventSystemClient` lendo `kHIDPage_AppleVendorTemperatureSensor`.
- **Alternativa A**: so SMC (frágil — algumas keys nem sempre existem).
- **Alternativa B**: so IOHID (incompleto — alguns sensores so via SMC).
- **Razao**: hibrido cobre 100% dos casos validados em apps reais (stats.app, TG Pro). MVP usa **max(Tp01, Tp05, Tp09)** como temp representativa para a curva.

### D7. Onde roda o control loop: helper, NAO app

- **Escolhido**: control loop (timer 1.5s) roda no `FanControlHelper` daemon, sempre.
- **Alternativa**: loop na UI app, helper so executa comandos discretos.
- **Razao**: app sandbox pode ser suspenso pelo macOS quando minimizado/inativo (App Nap); LaunchDaemon roda 24/7 ate ser explicitly unloaded; fechar a UI nao deve parar o controle de fans (regra: usuario que ativou modo Curve espera que continue mesmo sem janela aberta).

### D8. Frequencia do control loop: 1.5s

- **Escolhido**: tick a cada **1.5 segundos**
- **Alternativas**: 1s (mais reativo, mais custo CPU), 2s (mais leve, mais lag termico)
- **Razao**: read SMC + IOHID + write F0Tg/F1Tg = ~5ms por tick; 1.5s da margem para o sistema termal sem custar CPU. Validado em apps similares (TG Pro: 1s, Macs Fan Control: 5s default).

### D9. Histerese: 3°C bidirecional

- **Escolhido**: ao subir RPM, usa temp atual para escolher o step da curva. Ao **descer**, exige que temp atual esteja **3°C abaixo** do threshold do step para acionar o step inferior.
- **Alternativas**: sem histerese (oscila); histerese assimetrica (1°C subir, 5°C descer); histerese percentual.
- **Razao**: 3°C e o valor usado pelo Macs Fan Control e em manuais de termal management. Previne oscilacao na fronteira (60°C com curva 60°→50% sem histerese ficaria pulando entre 49% e 51%).

### D10. Interpolacao da curva: linear (nao spline)

- **Escolhido**: interpolacao linear entre os pontos `(temp, duty)`. Acima do ultimo ponto, clamp em 100%. Abaixo do primeiro, clamp em duty do primeiro ponto.
- **Alternativa**: spline cubica.
- **Razao**: spline causa overshoot indesejado nos extremos (90°→100% pode estourar 100% antes de chegar ao ponto). Linear e previsivel, debugavel, suficiente para 4-6 pontos. Macs Fan Control usa linear.

### D11. Safety override: max RPM se T > 95°C

- **Escolhido**: se `max(Tp01, Tp05, Tp09) > 95°C` por **>= 3 ticks consecutivos** (4.5s), helper ignora a curva e escreve `F0Tg = F0Mx, F1Tg = F1Mx`. Volta ao normal quando temp `< 92°C` (histerese de 3°C).
- **Alternativa**: limite mais alto (100°C) ou mais baixo (90°C); aplicar imediatamente sem 3 ticks.
- **Razao**: M1 Pro tem TJmax ~105°C; 95°C com 3 ticks da margem para spikes transientes mas reage rapido em sustained load. Curva mal configurada pelo usuario nao pode causar throttle agressivo do silicio.

### D12. Persistencia: arquivos JSON

- **Escolhido**: 2 arquivos JSON Codable:
  - **App** (UI state): `~/Library/Application Support/FanControl/state.json` — accent color, tempUnit, ultima curva editada, preset selecionado
  - **Helper** (control config): `/Library/Application Support/FanControl/control.json` — modo ativo (auto/forced/curve), curva ativa em uso, target RPM forced. Helper le no boot, app envia updates via XPC `setMode`/`setCurve`.
- **Alternativas**: UserDefaults (nao compartilha entre sandbox/root facilmente), CoreData (overkill).
- **Razao**: JSON e debugavel manualmente (`cat control.json`), versionavel se schema mudar (`version` key), e suficiente para < 1KB de dados.

### D13. TDD obrigatorio

- **Escolhido**: Swift Testing (framework novo Swift 5.10) + XCTest para casos legacy. Cobertura focada em logica pura:
  - `CurveInterpolator` (lookup linear, clamp extremos, vazio)
  - `Hysteresis` (state machine subir/descer, threshold)
  - `FPE2` (encode/decode SMC fixed-point 2 bytes)
  - `ControlLoop` (mock SMC: dados sinteticos in -> target esperado out)
  - `SafetyOverride` (3 ticks acima 95° aciona; volta < 92° desaciona; spike unico ignorado)
  - `ModeTransition` (auto -> forced -> curve sem deadlock)
- **Alternativa**: testar so manual via fluxo na UI.
- **Razao**: regra explicita do usuario (memoria `feedback_always_tdd.md`). Logica testavel separada de IO via protocols (`SMCReader`/`SMCWriter` mockaveis).

### D14. Localizacao do projeto Xcode

- **Escolhido**: `FanControl.xcodeproj` na **raiz** de `/Users/jeversonmisael/Documents/codigos/Macfancontrol/`. JSX existente em `FanControl/` permanece intocado como referencia visual.
- **Alternativa**: criar subpasta `app/` ou mover JSX para `Resources/Design/`.
- **Razao**: estrutura plana facilita navegacao no Xcode. JSX nao quer ser linkado no bundle (e referencia, nao asset). Manter no lugar atual nao quebra nada.

### D15. Janela: SwiftUI Scene com hidden titlebar

- **Escolhido**: `WindowGroup` com `.windowStyle(.hiddenTitleBar)` e `.windowResizability(.contentSize)`, frame fixo `360x640`. Traffic lights desenhados como `Circle().fill(Color)` em `FCTrafficLights`.
- **Alternativa**: `NSWindow` custom com `styleMask = .borderless`.
- **Razao**: SwiftUI nativa lida com hidden titlebar limpo; design ja desenha proprios traffic lights. NSWindow custom traz controle a mais que nao e necessario no MVP.

### D16. Animacoes do JSX: portar como SwiftUI animations

- **Escolhido**: `fc-spin` (icone do fan girando) -> `Angle` animado infinito. `fc-sheet-in` -> `.transition(.move(edge: .bottom))` com `.animation(.spring())`. `fc-pulse` -> `.opacity` infinito.
- **Razao**: SwiftUI tem animation modifiers nativos equivalentes. Velocidade do spin proporcional a duty (`spinDur = max(0.4, 3 - duty * 2.5)`s) replicado em Swift.

## Risks / Trade-offs

| Risco | Mitigacao |
|---|---|
| **R1**. SMC keys mudam entre versoes macOS | Validar cada key no boot do helper via `SMCReadKey`; se ausente, log + fallback graceful (modo read-only); test suite roda contra mock para nao depender de hardware live em CI |
| **R2**. Helper privilegiado tem superficie de seguranca | (a) protocolo XPC com whitelist enum-based de calls (sem string dispatch), (b) validar caller via `audit_token_to_pid` + `SecCodeCheckValidity` matching team ID, (c) sem aceitar paths/comandos de UI — so structs Codable de tipos primitivos |
| **R3**. Apple pode remover write SMC em macOS futuro | Out of scope MVP. Se quebrar, app degrada para read-only e usuario continua com Macs Fan Control ate atualizarmos |
| **R4**. Bug no control loop pode aquecer Mac | Safety override 95°C (D11); watchdog que reverte para Auto se loop trava > 5s sem tick; telemetry de temp logada em `~/Library/Logs/FanControl/control.log` |
| **R5**. Code signing ad-hoc nao persiste entre rebuilds | Cada `xcodebuild` novo invalida assinatura -> Gatekeeper pede aprovacao. Aceitavel para dev local; usuario clica Open Anyway uma vez por build |
| **R6**. Helper nao desinstala limpo | Comando "Uninstall helper" no menu da app -> chama `SMAppService.daemon.unregister()` + remove `control.json`; documentar fallback manual via `sudo launchctl unload` |
| **R7**. Hardware lock ao MacBookPro18,3 quebra em outro Mac | Detect model identifier no boot do helper; se diferente, banner "Modelo nao suportado nesta versao" + read-only |
| **R8**. Test coverage real depende de hardware fisico | Tests CI rodam em GitHub macOS-14 runners (sao M1 Apple Silicon); locally usuario roda no proprio MacBookPro18,3; testes de logica pura nao precisam hardware |
| **R9**. SMC pode ser locked durante outros processos (TG Pro, iStat rodando junto) | Helper detecta erro `kIOReturnExclusiveAccess` e log clear ("Outro app ja controla os fans"); UI exibe banner "Feche TG Pro/Macs Fan Control para tomar controle" |
| **R10**. App nao testado fora de SwiftUI hidden-titlebar pode ter glitches em fullscreen / Mission Control | Testar manualmente em Fase 0; se problema, fallback para NSWindow custom |
| **R11**. Usuario esquece o helper rodando e sai do app -> fans ficam "presos" no modo manual | Adicionar dialog "Manter controle ativo ao fechar?" na primeira saida; menu da app sempre tem "Stop control & quit helper" |

## Migration Plan

### Estrategia: 5 fases sequenciais com TDD

```
Fase 0 — Scaffold              (1 sessao)   ┐
Fase 1 — Sensor monitoring     (1-2 sessoes) │
Fase 2 — Direct control        (1 sessao)   │ MVP entregavel
Fase 3 — Curve editor (UI)     (1-2 sessoes) │
Fase 4 — Curve control loop    (1 sessao)   ┘
```

**Cada fase fecha com:**
- Suite de testes verde (red-green-refactor)
- Build limpo no Xcode (sem warnings)
- Smoke test manual no MacBookPro18,3
- Commit direto na main com mensagem `feat(fancontrol): <fase X> - <resumo>`

### Detalhamento por fase

**Fase 0 — Scaffold (~3-4h)**
1. Criar `FanControl.xcodeproj` com 2 targets (App SwiftUI + Helper command-line)
2. Definir bundle IDs (`com.fancontrol.app`, `com.fancontrol.helper`)
3. Configurar code signing ad-hoc, embed helper em `Contents/Library/LaunchDaemons/`
4. Implementar `HelperProtocol` Swift compartilhado (calls: `ping`, depois adicionar)
5. App: `FCWindow` SwiftUI 360x640 com background graphite + traffic lights desenhados
6. App-Helper: NSXPCConnection com `ping()` retornando timestamp
7. Test: HelperProtocol mock + app chama `ping` -> recebe timestamp valido
8. Smoke: instalar helper via `SMAppService.daemon.register()` + ver janela aparecer

**Fase 1 — Sensor monitoring (~5-7h)**
1. `SMCService` no helper com `IOServiceOpen(AppleSMC)` + `IOConnectCallStructMethod`
2. `FPE2` Codable para fixed-point 2 bytes (encode/decode com testes)
3. `SMCKey` table portada do crystalidea
4. `SMCReader.read(key: String) -> Result<Float, SMCError>` (testes mock)
5. Helper: ler `F0Ac`, `F1Ac`, `Tp01`, `Tp05`, `Tp09` a cada 1s, expor via XPC `getSnapshot()`
6. App: `@Observable` `SensorViewModel` que faz polling do snapshot
7. UI: temp readout 64px com max(Tp01..Tp09) + lista de fans com RPM real + duty calculado (`F0Ac/F0Mx`)
8. IOHID fallback se SMC retornar erro em alguma temp key
9. Tests: `CurveInterpolator` (logica que sera usada na Fase 4 ja vai sendo testada), `FPE2` round-trip, `SMCError` mapping
10. Smoke: ver na janela RPM batendo o que `Macs Fan Control` mostra (delta < 5%)

**Fase 2 — Direct control + presets (~3-4h)**
1. `SMCWriter.write(key: String, value: Float)` com retry + lock detection
2. Helper: novas calls XPC `setMode(.auto)` / `setMode(.forced(rpm: Int))`
3. UI: 4 preset buttons (`Silent`, `Balanced`, `Performance`, `Max`) ligados ao XPC
4. Tests: mode transitions (auto -> forced -> auto preserva consistencia)
5. Tests: SMCWriter mock + verificar sequencia `F0Md=1` antes de `F0Tg=<X>`
6. Smoke: clicar Max -> RPM sobe ate 6500 em ~3s; clicar Balanced -> volta auto

**Fase 3 — Curve editor UI (~5-7h)**
1. `Curve` model: `[(temp: Int, duty: Int)]` com validation (ordenado, 2-6 pontos)
2. `CurveStore` Codable persistido em `state.json`
3. `CurveEditorView` SwiftUI fielmente portada de `curve-mvp.jsx`:
   - Sheet animado (move from bottom + fade)
   - `CurveGraph` SwiftUI Canvas com gridlines, danger zone, area gradient, pontos hoverable
   - `NumStepper` SwiftUI custom com clamp + suffix
   - Toolbar Cancel/Save
4. Tests: `Curve.validate()` rejeita unordered, duplicates, < 2 ou > 6 pontos
5. Tests: `CurveStore.save/load` round-trip
6. Smoke: abrir editor, mexer steps, salvar, reabrir app -> curva persistida

**Fase 4 — Control loop com curva (~3-5h)**
1. `Hysteresis` state machine com testes (subir imediato, descer apos 3°C abaixo)
2. `ControlLoop`: a cada 1.5s le temp -> interpola curva -> aplica histerese -> escreve F0Tg/F1Tg
3. `SafetyOverride`: 3 ticks acima 95° forca max; volta < 92°
4. Tests: dados sinteticos (sequence de temps) -> verificar sequence de RPM esperado
5. Tests: safety override aciona/desaciona corretamente
6. Helper: integra ControlLoop + Hysteresis + SafetyOverride com SMCWriter real
7. UI: footer "Edit fan curve" do main-mvp aciona modo Curve no helper
8. Smoke: configurar curva agressiva (50°→100%), rodar carga de CPU (`yes > /dev/null`), ver fan acelerar conforme temp sobe; matar carga -> ver fan desacelerar **apos** delay da histerese

### Rollback strategy

Em caso de problema descoberto pos-deploy (que aqui significa "depois de instalar local"):

1. **Soft rollback** (mantem app instalado): menu da app -> "Stop control" -> XPC chama `setMode(.auto)` -> fans voltam ao macOS em 1 tick.
2. **Hard rollback** (desinstala tudo):
   ```bash
   # Via UI
   App menu -> "Uninstall helper" -> SMAppService.daemon.unregister()
   # Via CLI manual (caso UI quebre)
   sudo launchctl unload /Library/LaunchDaemons/com.fancontrol.helper.plist
   sudo rm /Library/LaunchDaemons/com.fancontrol.helper.plist
   sudo rm -rf /Library/Application\ Support/FanControl
   rm -rf ~/Library/Application\ Support/FanControl
   trash /Applications/FanControl.app  # ou Finder
   ```
3. **Escape thermico** (se app travar com fans em modo forced): kill -9 do helper -> `F0Md` sem reescrita retorna a `0` no proximo tick do scheduler de fans do macOS (~5s).

### Validacao live ao final

Apos Fase 4 completa, no MacBookPro18,3:
- [ ] App abre, janela 360x640 aparece
- [ ] Temp readout mostra valor coerente (CPU em idle ~35-45°C)
- [ ] Lista de fans mostra Left + Right com RPM batendo Macs Fan Control (delta < 5%)
- [ ] Clicar `Max` -> ambos fans atingem `F0Mx`/`F1Mx` em ~3s
- [ ] Clicar `Balanced` -> fans voltam ao Auto do macOS
- [ ] Editor de curva abre como sheet, salva, fecha — curva persiste apos reabrir
- [ ] Modo Curve ativo + carga `yes > /dev/null & yes > /dev/null & yes > /dev/null` (3 cores) -> temp sobe -> fan acelera conforme curva
- [ ] Safety: configurar curva 100°→0% (provoca aquecimento) -> temp passa 95° -> fan vai a max (override) -> log warning aparece em `~/Library/Logs/FanControl/control.log`
- [ ] "Uninstall helper" remove daemon, fans voltam ao Auto, sem residuos

## Open Questions

**OQ1**. `SMAppService.daemon` em macOS 14 vs 15: requer plist em `Contents/Library/LaunchDaemons/` no app bundle? Resposta provavel: sim, copy automatica via build phase. **Resolver na Fase 0** validando template Xcode.

**OQ2**. `IOHIDEventSystemClient` precisa de entitlement em macOS 14+? Stats.app nao tem, presumo que nao. **Resolver na Fase 1**.

**OQ3**. `F0Tg` aceita qualquer RPM ou e clamped pelo SMC para `[F0Mn, F0Mx]`? Provavelmente clamped (Macs Fan Control assume isso). **Resolver na Fase 2** com smoke test.

**OQ4**. Scheduler do macOS desativa `F0Md=1` se nao receber writes em N segundos? Crystalidea reescreve a cada loop tick. **Replicar comportamento na Fase 4** — control loop sempre escreve F0Md (idempotente).

**OQ5**. Quando o usuario fecha a app sem "Stop control", o helper continua rodando com a ultima curva ativa. Esse e o comportamento desejado? Default proposto: **sim**, helper persiste. Adicionar setting "Stop helper on quit" se virar problema. **Resolver via UX no smoke test pos-Fase 4**.

**OQ6**. Se duas instancias do app rodarem simultaneamente, o helper aceita comandos conflitantes? **Solucao MVP**: helper aceita ultima call, sem locking complex. Testar rapidamente; se virar problema, adicionar mutex no proximo iteration.
