# Implementation tasks — fix-mvp-runtime-bugs-on-m1pro

Order: BUG 1 (temp sanity) → BUG 3 (fan ceilings + clamp) → BUG 2 (animation) → diagnostic logs → live validation.

Rationale: temperatura é leitura, não tem efeito colateral. Fan ceilings + clamp habilita os botões. Animação é cosmética e independente. Logs ajudam o diagnóstico final. Live validation no MacBookPro18,3 confirma todos.

## 1. BUG 1 — Sanity range para temperatura

- [x] 1.1 [TEST] Adicionar suite `TempSanityTests.swift` em `Tests/SensorsTests/`: mock `SMCReading` retorna Tp01=200°C → esperado descartar; Tp01=-50°C → descartar; Tp01=45°C → aceitar; Tp01=108°C → aceitar (dentro do range expandido). Esperar 5 testes RED.
- [x] 1.2 Em `Helper/Sensors/TemperatureReader.swift`, adicionar constante `tempPlausibleRange = -20.0...120.0` e filtrar `values.append(v)` no `maxCPUTemp()` apenas se `tempPlausibleRange.contains(v)`. Caso contrário, `HelperLogger.sensors.warn("rejected out-of-range temp <key>=<v>°C")`.
- [x] 1.3 Refatorar para que `TemperatureReader.maxCPUTemp()` saiba o nome da key sendo lida (não só o valor) para o log mostrar `Tp01=200°C` em vez de só `200°C`. Pode ser via tuple `[(SMCKey, Double)]` retornado por uma helper privada.
- [x] 1.4 Verificar 5/5 testes verdes.
- [x] 1.5 Smoke: rebuild + reinstall helper + observar logs por 1 minuto: `log show --predicate 'subsystem == "com.fancontrol.helper"' --info --last 1m | grep "rejected"`. Expectativa: zero rejeições em hardware sano, ou rejeições isoladas e UI estável (cpuTemp muda mas não para valores absurdos).

## 2. BUG 3 — Fan ceilings reais via XPC

- [x] 2.1 [TEST] Adicionar `FanCeilingsValidityTests.swift` em `Tests/SensorsTests/`: cobre `f0Mn ∈ [500, 3000]`, `f0Mx ∈ [3500, 10000]`. Casos: válido (1300/6500), inválido f0Mx muito baixo (38), inválido f0Mn alto (5000), inválido f0Mx alto (50000).
- [x] 2.2 Em `Helper/Sensors/SnapshotBuilder.swift`, adicionar property `var ceilingsValid: Bool` (default false). Em `loadFanCeilings()`, validar cada read; setar `ceilingsValid = true` apenas se todos os 4 valores caem no range plausível. Se inválido, manter defaults `1300/6500` e logar warn `"loadFanCeilings: <key>=<v> out of plausible range"`.
- [x] 2.3 Verificar testes verdes (4/4).
- [x] 2.4 Adicionar struct `FanCeilings` em `Shared/SharedTypes.swift`: `Codable { f0Mn, f0Mx, f1Mn, f1Mx: Int; valid: Bool }`.
- [x] 2.5 Adicionar call em `HelperProtocol.swift`: `func getFanCeilings(reply: @escaping (Data?, Error?) -> Void)`.
- [x] 2.6 Implementar `HelperService.getFanCeilings` retornando JSON-encoded FanCeilings construído a partir do `SnapshotBuilder` (que precisa ser acessível via wire ou ref). Considerar passar `SnapshotBuilder` para `HelperService.wire(...)`.
- [x] 2.7 Atualizar `HelperService.wire(...)` para aceitar `snapshotBuilder: SnapshotBuilder` (ou um protocol `CeilingsProvider` com `var ceilings: FanCeilings`).
- [x] 2.8 Em `HelperMain.swift` no boot, passar `snapshotBuilder` para o `wire()`.
- [x] 2.9 [TEST] Adicionar `GetFanCeilingsXPCTests.swift` em `Tests/HelperProtocolTests/`: mock `CeilingsProvider` retorna ceilings; chamada XPC retorna JSON correto.
- [x] 2.10 Em `App/XPC/HelperClient.swift`, adicionar `func getFanCeilings() async throws -> FanCeilings` (com 2s timeout como as outras).
- [x] 2.11 Em `App/State/AppState.swift`, adicionar `var fanCeilings: FanCeilings?`. Default nil.
- [x] 2.12 Em `App/State/SensorViewModel.swift`, no `pollOnce()` quando primeira leitura sucessful, disparar `Task { try? await fetchCeilings() }`. Esse método chama `HelperClient.shared.getFanCeilings()` e atualiza `AppState.shared.fanCeilings` via MainActor.
- [x] 2.13 Em `App/Views/PresetGrid.swift`, modificar `apply(_ preset)` para usar `appState.fanCeilings` (não defaults hardcoded). Se `fanCeilings == nil`, button está disabled (já estava por `!helperReachable`, agora também por `fanCeilings == nil`).
- [x] 2.14 Atualizar `Preset.targetMode(f0Mx:f1Mx:)` para receber também `f0Mn` (precisa pra clamping no app side opcional). Ou: deixar app passar `f0Mx` e helper clampar. Optei por **app passar f0Mx, helper clamp** (D5).
- [x] 2.15 [TEST] Adicionar `ModeManagerClampTests.swift` em `Tests/ControlTests/`: setMode(.forced(99999)) com f0Mx=6500 → escreve 6500 + log; .forced(100) com f0Mn=1300 → escreve 1300 + log; .forced(4500) sem clamp; .forced(0) → 1300 + log.
- [x] 2.16 Em `Helper/Control/ModeManager.swift` `setMode`, no caso `.forced(rpm)`, fazer `let clampedRpm = min(max(rpm, f0Mn), f0Mx)`. Se diferente, logar warn. Persistir `clampedRpm` em `cfg.forcedTargetRPM`.
- [x] 2.17 ModeManager precisa receber `f0Mn` no init (já tem `f0Mx`). Atualizar HelperMain para passar.
- [x] 2.18 Verificar testes verdes (4/4 ModeManagerClampTests + 4/4 GetFanCeilings).
- [x] 2.19 Smoke local: rebuild + reinstall helper + relaunch app. Click Max → fans aceleram audivelmente até ~6500 RPM em ~3s. Click Silent → desaceleram para ~2275. Click Balanced → vão pro Auto. Confirmar via Macs Fan Control rodando paralelo.

## 3. BUG 2 — Fan icon spin com TimelineView

- [x] 3.1 Em `App/Views/FanRow.swift`, reescrever `FanGlyph` para usar `TimelineView(.animation)`:
  ```swift
  TimelineView(.animation) { context in
      let elapsed = context.date.timeIntervalSinceReferenceDate
      let angle = (spinDuration ?? 0) > 0 ? (elapsed * 360.0 / spinDuration!).truncatingRemainder(dividingBy: 360.0) : 0
      Image(systemName: "fan.fill")
          .resizable()
          .scaledToFit()
          .foregroundStyle(FCTheme.textMuted)
          .rotationEffect(.degrees(angle))
  }
  ```
- [x] 3.2 Remover `@State rotation` e o `withAnimation` antigo do FanGlyph.
- [x] 3.3 Smoke: rebuild + relaunch app. Em modo Auto com fans em ~2000 RPM (duty ~0.15), ícones giram lentamente. Click Max, ícones aceleram. Click Balanced, voltam ao gradual.
- [x] 3.4 [TEST] (opcional, fora do MVP) Snapshot test renderiza FanGlyph com diferentes spin durations.

## 4. Logging diagnóstico nos primeiros 5 ticks

- [x] 4.1 Em `Helper/Sensors/SnapshotBuilder.swift`, adicionar `var tickCount: Int = 0`. Incrementar em `build()`.
- [x] 4.2 Adicionar method privado `logSMCRead(key: SMCKey, dataType: UInt32, bytes: [UInt8], decoded: Double)` que apenas loga se `tickCount <= 5`. Format: `"smc tick=<n> key=<code> dataType=0x<hex> (<fourcc-ascii>) bytes=<hex> -> <decoded>"`.
- [x] 4.3 Modificar `SMCReader.read()` para também retornar `dataType` raw (`UInt32`) e `bytes` ([UInt8]) no `Result.success`, ou expor um método `readWithDiagnostics(_ key) -> Result<(value: Double, dataType: UInt32, bytes: [UInt8]), SMCError>`.
- [x] 4.4 Em `SnapshotBuilder.build()`, ao ler cada chave, chamar `logSMCRead` se `tickCount <= 5`.
- [x] 4.5 Smoke: rebuild + reinstall + boot helper. Ver os primeiros 5 entries no Console.app, identificar dataType de cada chave (Tp01..Tp0H, F0*, F1*).
- [x] 4.6 Documentar em `CLAUDE.md` os dataTypes observados em MacBookPro18,3 (referência futura para novos modelos).

## 5. Live validation final

- [x] 5.1 Validar que após boot, `AppState.fanCeilings` é populado com valores plausíveis (não defaults).
- [x] 5.2 CPU temp idle (~30-50°C) sem jumps absurdos por 5 minutos.
- [x] 5.3 Stress: `yes > /dev/null & yes > /dev/null & yes > /dev/null &` por 1 minuto. Temp sobe gradualmente, fans aceleram (em modo Curve com curva agressiva ou Performance preset).
- [x] 5.4 Click Max → fans atingem ~F0Mx em ~3s. Click Silent → desaceleram para ~35% F0Mx. Click Balanced → vão pro Auto, F0Md=0.
- [x] 5.5 Ícones giram durante todos os modos com `duty > 0`.
- [x] 5.6 Helper logs limpos depois do tick #5 (sem ruído).

## 6. Documentation + commit

- [x] 6.1 Atualizar `README.md` se ceilings real diferem do esperado MacBookPro18,3 (ex: F0Mx=5400 em vez de 6500).
- [x] 6.2 Atualizar status no `tasks.md` da change `implement-fan-control-mvp` (marcar smoke tests da Group 22 que agora passam).
- [x] 6.3 **Commit**: `fix(fancontrol): MVP runtime bugs on MacBookPro18,3 — temp sanity, fan ceilings, icon spin`.
- [ ] 6.4 Marcar todos os tasks completos. Considerar `/opsx:archive` se OK do usuário.
