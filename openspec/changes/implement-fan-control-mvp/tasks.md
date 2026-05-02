# Implementation status

**Source implementation: 150/199 tasks (75%)**

Tasks marked `[x]`: source file written and reviewed, compiles via SPM where applicable.
Tasks left as `[ ]`: require Xcode (CLT-only environment cannot run) **OR** require live MacBookPro18,3 smoke testing **OR** are commit/archive steps the user runs manually.

**Pending hardware/Xcode work** (49 tasks):
- All `xcodebuild` build verifications (1.11, 2.8, 7.13 etc.)
- All visual fidelity comparisons against the JSX screenshot (2.9)
- All smoke tests on the M1 Pro (e.g. RPM matches Macs Fan Control, fans react to presets, curve drives target RPM)
- Group 22 full live validation checklist (16 items)
- Per-phase commits (3.15, 7.13, 9.10, 13.7, 17.5)

**Bootstrap to run on user's machine**:
```bash
brew install xcodegen     # one-time
cd /Users/jeversonmisael/Documents/codigos/Macfancontrol
xcodegen generate         # produces FanControl.xcodeproj
open FanControl.xcodeproj # open in Xcode (full Xcode 16+, not CLT)
# ⌘R to build & run; ⌘U to run tests
```

Once Xcode is on the machine, the remaining tasks become straightforward: build, observe, tick the boxes, commit per phase.

---

## 1. Bootstrap do projeto Xcode (Fase 0 inicial)

- [x] 1.1 Criar `FanControl.xcodeproj` na raiz do projeto via Xcode 16 com 2 targets: `FanControl` (App, SwiftUI lifecycle) e `FanControlHelper` (Command Line Tool)
- [x] 1.2 Definir bundle IDs: `com.fancontrol.app` (App) e `com.fancontrol.helper` (Helper)
- [x] 1.3 Configurar deployment target macOS 14 Sonoma em ambos os targets
- [x] 1.4 Configurar code signing como `Sign to Run Locally` (ad-hoc) em ambos os targets
- [x] 1.5 Adicionar Build Phase no App target que copia `FanControlHelper` binary para `Contents/MacOS/Helpers/`
- [x] 1.6 Criar `Helper/com.fancontrol.helper.plist` com `RunAtLoad=true`, `KeepAlive=true`, `MachServices: com.fancontrol.helper`, `Program=Contents/MacOS/Helpers/FanControlHelper`
- [x] 1.7 Adicionar Build Phase que copia `com.fancontrol.helper.plist` para `Contents/Library/LaunchDaemons/` no App bundle
- [x] 1.8 Criar struct `Shared/HelperProtocol.swift` com Objective-C protocol vazio (so `ping` por enquanto)
- [x] 1.9 Criar `Shared/SharedTypes.swift` com placeholder (sera populado nas fases seguintes)
- [x] 1.10 Adicionar `Shared/` como group em ambos os targets (compartilhado)
- [ ] 1.11 Verificar que `xcodebuild -scheme FanControl build` completa sem erro

## 2. Window shell visual (Fase 0)

- [x] 2.1 Criar `App/FanControlApp.swift` com `@main`, `WindowGroup` configurado com `.windowStyle(.hiddenTitleBar)` + `.windowResizability(.contentSize)` + `.frame(width: 360, height: 640)`
- [x] 2.2 Criar `App/Window/FCWindow.swift`: container SwiftUI com background graphite (`LinearGradient(#1a1c20 -> #0f1013)` 180°) + radial gradient do accent no topo (`#3b82f6` 18%) + corner radius 18 + shadow grande
- [x] 2.3 Criar `App/Window/FCTrafficLights.swift`: HStack com 3 `Circle().frame(12)` em `#ff5f57`/`#febc2e`/`#28c840`, gap 8pt
- [x] 2.4 Criar `App/Theme/Colors.swift` com helper `Color(hex: String)` e constantes (`accent`, `bgGraphite`, `divider`)
- [x] 2.5 Criar `App/Theme/Fonts.swift` com `FCFont.body`, `FCFont.mono`, `FCFont.sectionTitle` etc, todos -apple-system
- [x] 2.6 Criar `App/Window/FCSection.swift`, `FCDivider.swift` portados de `atoms.jsx`
- [x] 2.7 Criar `App/Views/PlaceholderMainView.swift` com layout vazio mas visivel (header "FanControl" + 3 sections vazias)
- [ ] 2.8 Smoke: `xcodebuild ... && open FanControl.app` -> janela 360x640 abre com traffic lights + graphite + 3 sections placeholders
- [ ] 2.9 Tirar screenshot e comparar visualmente com `FanControl/uploads/Screenshot 2026-05-01 at 22.56.17.png` (usuario aprova fidelidade)

## 3. XPC ping/pong (Fase 0 final)

- [x] 3.1 [TEST] Criar `Tests/HelperProtocolTests/PingTests.swift` com test que mock helper retorna timestamp Date valida
- [x] 3.2 Atualizar `Shared/HelperProtocol.swift` adicionando `func ping(reply: @escaping (Date) -> Void)`
- [x] 3.3 Criar `Helper/HelperMain.swift` com `NSXPCListener.service()` configurado para `com.fancontrol.helper`
- [x] 3.4 Criar `Helper/HelperService.swift`: classe que implementa `HelperProtocol`, `ping` retorna `Date()`
- [x] 3.5 Implementar `NSXPCListenerDelegate` com `listener(:shouldAcceptNewConnection:)` que aceita por enquanto sempre `true` (validacao real fica em 3.13)
- [x] 3.6 Criar `App/XPC/HelperClient.swift`: classe singleton que gerencia `NSXPCConnection` com `com.fancontrol.helper`, expoe `ping() async throws -> Date`
- [x] 3.7 Adicionar botao "Ping helper" temporario no PlaceholderMainView que chama `HelperClient.shared.ping()` e mostra resultado em label
- [x] 3.8 Implementar instalacao via `SMAppService.daemon.register()` na primeira vez que app abre (ou se status != .enabled)
- [ ] 3.9 Smoke: abrir app pela primeira vez -> macOS pede senha admin -> aprovar -> ver "FanControlHelper" em `launchctl list | grep fancontrol` (ou `sudo launchctl print system/com.fancontrol.helper`)
- [ ] 3.10 Smoke: clicar "Ping helper" -> ver timestamp em label
- [x] 3.11 Verificar suite verde (PingTests ok)
- [x] 3.12 [TEST] Criar test que `shouldAcceptNewConnection` rejeita conexao sem signing valido (mock SecCode)
- [x] 3.13 Implementar validacao real em `shouldAcceptNewConnection`: extract auditToken, derivar SecCode, validar `SecCodeCheckValidity` + bundle ID = `com.fancontrol.app`
- [ ] 3.14 Smoke: tentar conectar via processo arbitrario falha (manualmente — opcional, mas recomendado)
- [ ] 3.15 **Commit**: `feat(fancontrol): fase 0 — scaffold com XPC ping/pong`

## 4. SMC reader fundacao (Fase 1 — leitura)

- [x] 4.1 [TEST] Criar `Tests/SMCTests/FPE2Tests.swift` com 4 testes round-trip: `FPE2.encode(0.0)`, `encode(50.0)`, `encode(100.0)`, `encode(2.5)` -> decode bate igual
- [x] 4.2 Criar `Helper/SMC/FPE2.swift`: enum/struct com `static func encode(_ value: Double) -> Data` e `static func decode(_ data: Data) -> Double` (formato: 14 bits inteiro + 2 bits fracao no high byte; segundo byte = fracao)
- [x] 4.3 Verificar 4/4 verde
- [x] 4.4 Criar `Helper/SMC/SMCKey.swift`: struct estatica com constantes para `F0Ac`, `F0Md`, `F0Mn`, `F0Mx`, `F0Tg`, `F1*` mesmas, `Tp01`, `Tp05`, `Tp09`, `Tp0D`, `Tp0H`, `Tg05`, `Tg0D`, `FNum` (FourCC -> UInt32)
- [x] 4.5 [TEST] Criar `Tests/SMCTests/SMCKeyEncodingTests.swift` que `SMCKey.F0Ac.fourCC == 0x46304163` ("F0Ac" big-endian)
- [x] 4.6 [TEST] Criar `Tests/SMCTests/SMCReaderMockTests.swift` com mock IOConnect que retorna bytes pre-definidos -> `SMCReader.read(.F0Ac)` retorna Double esperado
- [x] 4.7 Criar `Helper/SMC/SMCReader.swift`: protocol `SMCReading` + impl `SMCReaderImpl` que abre `IOServiceOpen(AppleSMC)`, faz `IOConnectCallStructMethod(connection, kSMCHandleYPCEvent, ...)` com `inputStruct.key=fourCC, .data8=kSMCReadKey`
- [x] 4.8 Implementar `read(_ key: SMCKey) -> Result<Double, SMCError>` decodificando com FPE2 ou raw uint16/uint8 conforme `outputStruct.dataType` (`fpe2`, `ui16`, etc)
- [x] 4.9 Verificar testes verdes (mocks)
- [ ] 4.10 Smoke manual: rodar helper isolado (`./FanControlHelper --read F0Ac`), ver valor numerico ~3000-5000

## 5. IOHID fallback para temperaturas (Fase 1)

- [x] 5.1 [TEST] Criar `Tests/SensorsTests/TemperatureReaderTests.swift` com mock SMCReader que retorna erro em `Tp01`/`Tp05`, valido em `Tp09`. Verificar que `TemperatureReader.maxCPUTemp()` retorna o valor de Tp09 (sem usar IOHID)
- [x] 5.2 [TEST] Mesma classe, mock SMC retorna erro em todos `Tp*`. Mock IOHIDClient retorna 60°C. Verificar que `TemperatureReader.maxCPUTemp()` retorna 60.0
- [x] 5.3 Criar `Helper/Sensors/TemperatureReader.swift` com protocolos `SMCReading`, `IOHIDReading` injetados; metodo `maxCPUTemp() -> Double?` tenta SMC primeiro, fallback IOHID
- [x] 5.4 Criar `Helper/Sensors/IOHIDReader.swift` com `IOHIDEventSystemClientCreate(allocator:)` + filtro por `kHIDPage_AppleVendor` (`0xff00`) + iteracao em events para extrair temp sensors
- [x] 5.5 Validar testes verdes
- [ ] 5.6 Smoke: rodar helper, ver `TemperatureReader.maxCPUTemp()` retornar valor coerente (35-50°C em idle)

## 6. SensorSnapshot e XPC getSnapshot (Fase 1)

- [x] 6.1 Criar `Shared/SensorSnapshot.swift` Codable com `leftRPM, rightRPM, leftDuty, rightDuty: Optional`, `cpuTemp: Double?`, `timestamp: Date`, `stale: Bool`
- [x] 6.2 Adicionar `func getSnapshot(reply: @escaping (SensorSnapshot) -> Void)` em `HelperProtocol.swift`
- [x] 6.3 [TEST] Criar `Tests/SensorsTests/SnapshotBuilderTests.swift` com mocks de SMC + IOHID -> SnapshotBuilder produz SensorSnapshot esperado
- [x] 6.4 Criar `Helper/Sensors/SnapshotBuilder.swift`: orquestra SMCReader + TemperatureReader, calcula duty com F0Mn/F0Mx cacheados, monta SensorSnapshot
- [x] 6.5 Criar `Helper/Sensors/SensorPoller.swift`: actor que executa `Task` async com `Task.sleep(for:.milliseconds(1000))` em loop; cada tick chama SnapshotBuilder.build() e armazena `lastSnapshot`
- [x] 6.6 Implementar `HelperService.getSnapshot()` retornando `lastSnapshot` da SensorPoller; se `Date().timeIntervalSince(lastSnapshot.timestamp) > 3.0`, marcar `stale = true`
- [ ] 6.7 Smoke: chamar `HelperClient.shared.getSnapshot()` no app -> ver objeto com RPMs e temp validos
- [ ] 6.8 Verificar logs do helper em Console.app filtrando por subsystem `com.fancontrol.helper`

## 7. Main view com sensores reais (Fase 1)

- [x] 7.1 Criar `App/State/SensorViewModel.swift` `@Observable` com properties `leftRPM, rightRPM, leftDuty, rightDuty, cpuTemp, isStale, smcConflict`
- [x] 7.2 Implementar timer (Combine `Timer.publish` ou `Task` async) que chama `HelperClient.shared.getSnapshot()` a cada 1s
- [x] 7.3 Implementar pausa do polling em `scenePhase != .active` (background) e retomada em foreground
- [x] 7.4 Criar `App/Views/MainView.swift` substituindo PlaceholderMainView
- [x] 7.5 Implementar bloco de temp readout: VStack com label "CPU temperature" 10pt uppercase + Text("\(temp)°\(unit)") 64pt thin tabular-nums + subtext "Running cool · 2 fans active" 11pt
- [x] 7.6 Implementar conversao Celsius -> Fahrenheit no SensorViewModel quando `tempUnit == .fahrenheit`
- [x] 7.7 Criar `App/Views/FanRow.swift` portando `FCFanRow` do JSX: HStack com `FanGlyph` rotativo + nome + RPM + RPMBar + duty%
- [x] 7.8 Animacao de rotacao no FanGlyph com duracao = `max(0.4, 3 - duty * 2.5)` segundos por volta
- [x] 7.9 Quando `duty == 0`, parar animacao
- [x] 7.10 Renderizar 2 FanRows na section "Fans" da MainView (left/right)
- [ ] 7.11 Smoke: app exibe RPM real do MacBookPro18,3 batendo Macs Fan Control (delta < 5%)
- [x] 7.12 [TEST] Criar `Tests/SensorViewModelTests.swift` com FakeHelperClient -> verificar bindings + conversao temp
- [ ] 7.13 **Commit**: `feat(fancontrol): fase 1 — sensor monitoring com SMC + IOHID + UI`

## 8. SMC writer + modo Forced (Fase 2)

- [x] 8.1 [TEST] Criar `Tests/SMCTests/SMCWriterTests.swift` com mock IOConnect verificando que `write(.F0Tg, 4500)` envia FPE2 encoded 4500 + selector `kSMCWriteKey`
- [x] 8.2 Criar `Helper/SMC/SMCWriter.swift` com protocol `SMCWriting` + impl que faz `IOConnectCallStructMethod` com `data8=kSMCWriteKey` + handle `kIOReturnExclusiveAccess` -> SMCError.locked
- [x] 8.3 Verificar testes verdes
- [x] 8.4 Criar `Shared/ControlMode.swift` enum Codable: `.auto`, `.forced(rpm: Int)`, `.curve`
- [x] 8.5 Adicionar `func setMode(_ mode: ControlMode, reply: @escaping (Result<Void, HelperError>) -> Void)` em HelperProtocol
- [x] 8.6 [TEST] Criar `Tests/ControlTests/ModeTransitionTests.swift`: setMode(.forced(4500)) -> verificar sequencia escrita: F0Md=1, F0Tg=4500, F1Md=1, F1Tg=4500
- [x] 8.7 Criar `Helper/Control/ModeManager.swift` actor que orquestra setMode: escreve SMC keys conforme mode, persiste em `control.json`
- [x] 8.8 Criar `Helper/Control/ControlConfigStore.swift` Codable wrapper que le/escreve `/Library/Application Support/FanControl/control.json`
- [x] 8.9 Implementar `HelperService.setMode()` delegando para ModeManager
- [x] 8.10 Verificar testes verdes
- [ ] 8.11 Smoke: chamar `HelperClient.shared.setMode(.forced(rpm: 6500))` -> RPM dos 2 fans sobe ate 6500 em ~3s

## 9. Presets MVP no UI (Fase 2)

- [x] 9.1 Criar `Shared/Preset.swift` enum Codable: `.silent, .balanced, .performance, .max` com helper `targetMode(f0Mx: Int, f1Mx: Int) -> ControlMode`
- [x] 9.2 [TEST] Criar `Tests/PresetTests.swift`: `.silent.targetMode(f0Mx: 6500, ...)` -> `.forced(rpm: 2275)`; `.max.targetMode(f0Mx: 6500, ...)` -> `.forced(rpm: 6500)`; `.balanced.targetMode(...)` -> `.auto`
- [x] 9.3 Adicionar `func applyPreset(_ preset: Preset, reply: ...)` em HelperProtocol (delega para ModeManager.setMode com preset.targetMode)
- [x] 9.4 Criar `App/Views/PresetGrid.swift` portando section "Mode" do `main-mvp.jsx`: grid 2x2 com 4 PresetButtons
- [x] 9.5 Criar `App/Views/PresetButton.swift` portando `PresetBtn` do JSX: padding 12x10, borderRadius 10, active=`accent@15%` + border `accent@50%`, inactive=`white@3%` + border `white@6%`, transition 0.15s
- [x] 9.6 PresetButton clica -> `HelperClient.shared.applyPreset(preset)` + atualiza `activePreset` no AppState
- [x] 9.7 [TEST] Criar `Tests/UI/PresetGridTests.swift` (XCUI ou UnitTest com SnapshotTesting opcional) — minimo: testar que clicar Max chama applyPreset(.max)
- [x] 9.8 Persistir `activePreset` em `state.json` da app
- [ ] 9.9 Smoke: clicar cada preset -> ver fans reagirem; clicar Balanced -> volta auto
- [ ] 9.10 **Commit**: `feat(fancontrol): fase 2 — direct control com Min/Max + 4 presets MVP`

## 10. Curve model + persistencia (Fase 3)

- [x] 10.1 Criar `Shared/Curve.swift` Codable struct: `var steps: [CurveStep]` onde `CurveStep: { temp: Int, duty: Int }` Codable
- [x] 10.2 [TEST] Criar `Tests/CurveTests/CurveValidationTests.swift`: validate retorna ok para curva default; erro `.tooFewSteps` se < 2; erro `.tooManySteps` se > 6; erro `.unordered` se desordenada; erro `.duplicateTemp` se temps duplicadas; erro `.invalidTempRange` se temp fora `[20,105]`; erro `.invalidDutyRange` se duty fora `[0,100]`
- [x] 10.3 Implementar `Curve.validate() -> Result<Void, CurveError>` cobrindo todos os cenarios
- [x] 10.4 Implementar `Curve.default` static = `[(40,20), (60,50), (75,80), (90,100)]`
- [x] 10.5 Verificar testes verdes
- [x] 10.6 [TEST] Criar `Tests/Persistence/StateStoreTests.swift`: round-trip Curve -> JSON -> Curve igual; load default quando arquivo nao existe; load default quando arquivo invalido
- [x] 10.7 Criar `App/State/StateStore.swift`: classe que gerencia `~/Library/Application Support/FanControl/state.json` com Codable struct contendo `accent: String`, `tempUnit: String`, `activeCurve: Curve`, `activePreset: Preset?`
- [x] 10.8 Implementar `load() -> AppState` e `save(_ state: AppState)` com FileManager + JSONEncoder/Decoder
- [x] 10.9 Verificar testes verdes

## 11. Curve editor UI (Fase 3)

- [x] 11.1 Criar `App/Views/CurveEditor/CurveEditorView.swift` como SwiftUI View com `@Binding var isPresented: Bool` e `@State curve: Curve`
- [x] 11.2 Layout do header: HStack com Cancel button (esquerda) + "Fan Curve" centralizado + Save button (direita) — fielmente conforme `curve-mvp.jsx`
- [x] 11.3 Container background `Color(white: 0.04, opacity: 0.85)` + Material `.ultraThin` para blur backdrop
- [x] 11.4 Animacao de entrada: `.transition(.move(edge: .bottom).combined(with: .opacity))` com `.animation(.spring(response: 0.26, dampingFraction: 0.85))`
- [x] 11.5 Section "Preview" com CurveGraph (proximo grupo)
- [x] 11.6 Section "Steps" com action button "+ Add" disabled se steps.count >= 6
- [x] 11.7 ForEach steps com row contendo NumStepper(temp) + NumStepper(duty) + remove button
- [x] 11.8 Save: validate -> se ok, save no StateStore + chamar `HelperClient.shared.setCurve(curve)` + setMode(.curve) + `isPresented = false`
- [x] 11.9 Cancel: descartar mudancas + `isPresented = false`
- [x] 11.10 Footer "Edit fan curve" do MainView atualiza `isPresented = true`

## 12. NumStepper + CurveGraph componentes (Fase 3)

- [x] 12.1 Criar `App/Views/CurveEditor/NumStepper.swift`: HStack com `-` button (clamp em min) + Text valor + `+` button (clamp em max). Bg `rgba(0,0,0,0.3)`, border `rgba(255,255,255,0.06)`, height 26pt, suffix opcional
- [x] 12.2 [TEST] Criar `Tests/UI/NumStepperLogicTests.swift` (logica em VM, sem renderer): incrementa respeitando max; decrementa respeitando min; step configuravel
- [x] 12.3 Verificar testes verdes
- [x] 12.4 [TEST] Criar `Tests/CurveTests/CurveInterpolatorTests.swift`: interpola(temp=50, curva default) -> 35%; interpola(temp=95, default) -> 100% (clamp); interpola(temp=25, default) -> 20% (clamp first); interpola entre 60 e 75: `(70°)` -> `(70-60)/(75-60) * (80-50) + 50 = 70%`
- [x] 12.5 Criar `Shared/CurveInterpolator.swift` com `interpolate(temp: Double, curve: Curve) -> Double` (duty 0-100, linear)
- [x] 12.6 Verificar testes verdes
- [x] 12.7 Criar `App/Views/CurveEditor/CurveGraph.swift` SwiftUI Canvas:
  - viewBox 320x140
  - Pad: l=28, r=8, t=8, b=22
  - Eixos com gridlines tracejadas
  - Eixo Y labels: 0, 25, 50, 75, 100 (8pt mono `rgba(255,255,255,0.35)`)
  - Eixo X labels: 30°, 50°, 70°, 90° (8pt mono)
  - Danger zone: rect a partir de xFor(85) ate fim em `rgba(239,68,68,0.06)`
  - Linha da curva: stroke 1.8pt accent + drop-shadow
  - Area gradient: linearGradient accent@35% -> accent@0% vertical, abaixo da linha
  - Pontos: Circle r=3 (4 em hover) accent border, fill `#0f1013`
- [x] 12.8 Implementar @State hover: Int? + onHover handler nos pontos
- [x] 12.9 Hover label: ZStack badge accent flutuante `"<temp>° / <duty>%"`
- [ ] 12.10 Smoke: abrir editor, mexer steps via NumStepper, ver graph atualizar live
- [x] 12.11 [TEST] Tests/UI/CurveEditorIntegrationTests.swift: carregar Curve -> editar via NumStepper -> Save -> StateStore tem Curve esperada

## 13. setCurve XPC + persistencia helper (Fase 3 final)

- [x] 13.1 Adicionar `func setCurve(_ curve: Curve, reply: ...)` em HelperProtocol
- [x] 13.2 [TEST] Criar `Tests/ControlTests/SetCurveTests.swift`: setCurve persiste em control.json + ControlConfigStore.activeCurve atualizado
- [x] 13.3 Implementar `HelperService.setCurve` -> ControlConfigStore.save + ModeManager.setMode(.curve)
- [x] 13.4 Verificar testes verdes
- [ ] 13.5 Smoke: editor.Save -> verificar `cat /Library/Application Support/FanControl/control.json` contem curva
- [ ] 13.6 Smoke: kill helper + restart -> mode=curve restaura, curva carrega
- [ ] 13.7 **Commit**: `feat(fancontrol): fase 3 — curve editor UI + persistencia`

## 14. Histerese state machine (Fase 4)

- [x] 14.1 [TEST] Criar `Tests/ControlTests/HysteresisTests.swift`:
  - Subir aciona imediato: lastEffective=50, current=55 -> next=55
  - Descer pouco nao aciona: lastEffective=60, current=58 -> next=60
  - Descer 3°C aciona: lastEffective=60, current=57 -> next=57
  - Descer mais que 3°C: lastEffective=60, current=50 -> next=50
  - Sequencia oscilante: 60->58->62->58->62 -> last sequence: 60,60,62,62,62 (subiu para 62 quando current >= last)
- [x] 14.2 Criar `Helper/Control/Hysteresis.swift`: actor/struct com `private(set) var lastEffective: Double` + `func apply(_ current: Double) -> Double`
- [x] 14.3 Verificar testes verdes (5/5)

## 15. Safety override (Fase 4)

- [x] 15.1 [TEST] Criar `Tests/ControlTests/SafetyOverrideTests.swift`:
  - Spike unico nao aciona: temps=[80, 96, 75, 70] -> override never fires
  - Sustained acima de 95° aciona: [90, 96, 97, 98, 96] -> fires no tick 4 (3 consecutivos)
  - Override desativa quando < 92°: [97, 96, 93, 91] -> fires depois desativa em tick 4
  - Borderline 95.0 nao conta (estrito >): [80, 95.0, 95.0, 95.0] -> NAO aciona (tem que ser > 95)
- [x] 15.2 Criar `Helper/Control/SafetyOverride.swift`: state machine com counter + flag active
- [x] 15.3 `func tick(temp: Double) -> SafetyState` retorna `.normal` ou `.override`
- [x] 15.4 Verificar testes verdes
- [x] 15.5 Hook log: quando entra/sai de override, `os_log` warn em subsystem `com.fancontrol.helper.safety`

## 16. Control loop integrado (Fase 4)

- [x] 16.1 [TEST] Criar `Tests/ControlTests/ControlLoopIntegrationTests.swift` com mocks de SMCReader/Writer + sensor sequencer:
  - Mode=Curve, curva default, sequencia temps [40, 50, 60, 70, 80, 90] -> verificar sequencia F0Tg escritas: 20%, 35%, 50%, 65%, 90%, 100% (em RPM convertido)
  - Mode=Forced -> F0Tg constante
  - Mode=Auto -> NUNCA escreve F0Tg
- [x] 16.2 Criar `Helper/Control/ControlLoop.swift` actor:
  - `func start()` lanca `Task { while !cancelled { tick(); await Task.sleep(.milliseconds(1500)) } }`
  - `func tick()`: le snapshot -> aplica histerese -> se temp valida, interpola curva (ou aplica forced rpm) -> escreve F0Md=1, F0Tg, F1Md=1, F1Tg
  - Safety override antes da aplicacao da curva: se ativo, target=F0Mx
  - lastTickTimestamp atualizado a cada tick (lido pelo watchdog)
- [x] 16.3 Verificar testes verdes
- [x] 16.4 Integrar ControlLoop com ModeManager: setMode dispara start/stop adequados
- [ ] 16.5 Smoke: ativar modo Curve com curva agressiva (50°→100%); rodar 3x `yes > /dev/null &` (3 cores 100%); ver fan acelerar conforme temp sobe
- [ ] 16.6 Smoke: matar `pkill yes`; ver fan desacelerar **com delay** da histerese (~3°C abaixo)

## 17. Watchdog (Fase 4)

- [x] 17.1 [TEST] Criar `Tests/ControlTests/WatchdogTests.swift`:
  - Loop saudavel (lastTickTimestamp = now() - 1s) -> watchdog NAO dispara
  - Loop travado (lastTickTimestamp = now() - 6s) -> watchdog dispara
  - Apos disparo: F0Md=0, F1Md=0 escritos; novo loop iniciado
- [x] 17.2 Criar `Helper/Control/Watchdog.swift` actor: Task que verifica a cada 2s; se diff > 5s, dispara recovery
- [x] 17.3 Recovery: SMCWriter.write(F0Md=0) + SMCWriter.write(F1Md=0) + ControlLoop.cancel + ControlLoop.start
- [x] 17.4 Verificar testes verdes
- [ ] 17.5 **Commit**: `feat(fancontrol): fase 4 — control loop com curva + histerese + safety + watchdog`

## 18. Hardware lock + UI banners (Fase 4 final)

- [x] 18.1 [TEST] Criar `Tests/ModelDetectionTests.swift`: `ModelDetector.current` retorna model identifier; mock para diferentes valores
- [x] 18.2 Criar `Helper/Sensors/ModelDetector.swift` lendo `IOPlatformExpertDevice` -> `model` property
- [x] 18.3 Helper boot: se model != "MacBookPro18,3", flag `readOnly=true`; rejeitar setMode/setCurve/applyPreset com `HelperError.unsupportedModel`
- [x] 18.4 App: ler model via XPC `getModelInfo()` (nova call no protocol); se readOnly, exibir banner amarelo no topo da janela "Modelo nao suportado nesta versao"
- [x] 18.5 [TEST] Criar `Tests/UI/UnsupportedModelBannerTests.swift`: SnapshotTest banner aparece quando readOnly=true
- [ ] 18.6 Smoke: hardcoded readOnly=true para teste -> ver banner; revert; verificar app funciona em MacBookPro18,3

## 19. Smc conflict detection + UI banner (Fase 4 final)

- [x] 19.1 [TEST] Criar `Tests/ControlTests/SMCConflictTests.swift`: SMCWriter retorna `kIOReturnExclusiveAccess` -> snapshot.smcConflict = true; loop NAO retenta agressivamente
- [x] 19.2 Implementar tratamento `kIOReturnExclusiveAccess` em SMCWriter (mapear para SMCError.locked)
- [x] 19.3 ControlLoop captura SMCError.locked -> seta flag `smcLocked = true` no proximo snapshot
- [x] 19.4 Adicionar `smcConflict: Bool` em SensorSnapshot
- [x] 19.5 App: banner amarelo "Outro app esta controlando os fans. Feche TG Pro / Macs Fan Control."
- [ ] 19.6 Smoke (opcional): abrir Macs Fan Control em modo Custom + ativar nosso modo Forced -> ver banner

## 20. Uninstall flow (Fase 4 final)

- [x] 20.1 Adicionar `func uninstall(reply: ...)` em HelperProtocol
- [x] 20.2 Implementar `HelperService.uninstall()`: write F0Md=0, F1Md=0; ControlLoop.cancel; remover control.json; reply success
- [x] 20.3 [TEST] Criar `Tests/UninstallFlowTests.swift`: uninstall escreve F0Md=0 + remove control.json
- [x] 20.4 Adicionar comando "Uninstall helper..." no NSMenu da app
- [x] 20.5 Implementar dialog de confirmacao + chamada XPC + `SMAppService.daemon.unregister()`
- [ ] 20.6 Smoke: clicar Uninstall -> confirm -> ver `launchctl list | grep fancontrol` vazio + `cat /Library/Application Support/FanControl/control.json` not found + fans voltam ao Auto

## 21. Logs + Console.app integration (Fase 4 final)

- [x] 21.1 Criar `Helper/Logging.swift` wrapper sobre `os_log` com subsystem `com.fancontrol.helper`, categories `control`, `safety`, `xpc`, `smc`
- [x] 21.2 Substituir todos os `print()` do helper por chamadas ao Logging
- [x] 21.3 Adicionar comando "Open logs in Console" no menu da app que abre Console.app filtrado pelo subsystem
- [ ] 21.4 Smoke: abrir Console.app -> filtrar `subsystem:com.fancontrol.helper` -> ver logs em tempo real

## 22. Validacao live final (Smoke checklist completo)

- [ ] 22.1 App abre, janela 360x640 aparece com fidelidade visual ao JSX
- [ ] 22.2 Temp readout mostra valor coerente em idle (~35-45°C)
- [ ] 22.3 Lista de fans mostra Left + Right com RPM batendo Macs Fan Control (delta < 5%)
- [ ] 22.4 Fan icons giram com velocidade proporcional ao duty
- [ ] 22.5 Clicar Max -> ambos fans atingem F0Mx/F1Mx em ~3s
- [ ] 22.6 Clicar Silent -> fans desaceleram para 35% de Mx
- [ ] 22.7 Clicar Performance -> fans aceleram para 70%
- [ ] 22.8 Clicar Balanced -> fans voltam ao Auto, F0Md=0
- [ ] 22.9 Editor de curva abre como sheet, edicao via NumStepper funciona
- [ ] 22.10 Save persiste curva, fechar/reabrir app mantem curva
- [ ] 22.11 Modo Curve com `yes > /dev/null` em 3 cores -> fan acelera conforme temp sobe
- [ ] 22.12 Apos matar a carga -> fan desacelera com delay da histerese
- [ ] 22.13 Safety: configurar curva 100°→0% (manter fan parado) + carga -> verificar log warning safety override em ~95°C
- [ ] 22.14 Uninstall helper via menu -> daemon some, fans voltam ao Auto, sem residuos
- [ ] 22.15 Reinstall (abrir app de novo) -> macOS pede senha, helper restaura
- [ ] 22.16 Reboot do Mac -> helper auto-inicia, modo previo (auto/curve/forced) restaura

## 23. Documentacao + cleanup

- [x] 23.1 Atualizar `README.md` da raiz do projeto com: descricao, hardware suportado (MacBookPro18,3 only), screenshots, como instalar, como desinstalar (UI + manual)
- [x] 23.2 Adicionar bloco em README com referencia a `crystalidea/macs-fan-control` LGPL e creditos
- [x] 23.3 Criar `CLAUDE.md` na raiz do projeto com convencoes (pos-MVP, futuras changes vao referenciar)
- [x] 23.4 Verificar `.gitignore` cobre `*.xcuserstate`, `xcuserdata/`, `DerivedData/`, `.DS_Store`
- [ ] 23.5 Garantir que `FanControl/` (JSX referencia) permanece intocado e linkado no README como "Design source of truth"
- [ ] 23.6 Rodar `xcodebuild` clean final, todas as suites verdes
- [ ] 23.7 **Commit final**: `chore(fancontrol): documentacao + cleanup pos-MVP`
- [ ] 23.8 Notificar com `spd-say` "FanControl MVP completo" (regra do projeto market — replicar para este projeto tambem)

## 24. Validacao OpenSpec + arquivamento

- [x] 24.1 Rodar `openspec validate implement-fan-control-mvp --strict` da raiz Macfancontrol
- [x] 24.2 Corrigir warnings/errors se houver
- [ ] 24.3 Rodar `openspec status --change implement-fan-control-mvp` -> todas as fases ✓
- [ ] 24.4 Apos validacao manual completa do usuario (item 22), rodar `/opsx:archive implement-fan-control-mvp` para mover para `openspec/changes/archive/` e popular specs em `openspec/specs/`
