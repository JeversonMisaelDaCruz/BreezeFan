## Context

**Estado atual** (após smoke test live em MacBookPro18,3): app abre, helper roda como root via `/Library/PrivilegedHelperTools/com.fancontrol.helper`, conexão XPC validada, modo Auto restaurado. Já com fix de tipo dinâmico no `SMCReader.decodeDynamic` (commit anterior) — chaves agora são decodificadas pelo FourCC retornado pelo SMC em vez do tipo declarado em `SMCKey`.

Mas no smoke test live o usuário relatou:

1. **CPU temp salta para valores absurdos intermitentemente** — alguns ticks mostram temperatura coerente (45°C), outros mostram lixo. Os logs do helper não foram inspecionados pra confirmar quais Tp* keys estão sendo problemáticas. Hipótese: algumas Tp* clusters reportam `flt ` no Apple Silicon, não `sp78` como assumi. Quando 4 bytes são interpretados como 2-byte sp78, o resultado depende de qual bytes prefix são lidos.
2. **Fan icons não giram visualmente** — animação SwiftUI `withAnimation(.linear(duration:).repeatForever(autoreverses:false)) { rotation = 360 }` aplicada uma vez em `onAppear`. Quando `duty` muda em `onChange`, faço `withAnimation { rotation = 360 }` novamente, mas como `rotation` já está em 360, SwiftUI pula. Precisa-se incrementar fora do bloco animation, ou usar abordagem decoupled (TimelineView).
3. **Botões Balanced/Max não fazem nada** — clique XPC chega ao helper. Helper escreve F0Md=1, F0Tg=<rpm>. Mas `<rpm>` é calculado no app via `preset.targetMode(f0Mx: 6500, f1Mx: 6500)` usando hardcoded 6500. **Como o real F0Mx pode ser diferente** (ex: 5400 num modelo, ou após o fix de float reader chegar valor diferente), o target enviado é divergente do que o hardware aceita. Pior: se F0Mx no app for hardcoded 6500 mas o helper lê 38 (read errado pré-fix) e `setMode(.forced)` mandar 4500, helper escreve 4500 que está dentro de [F0Mn=1300, F0Mx=lido_38] — clamp é > F0Mx, então clampa pra 38. Result: fan target = 38 RPM, não acelera.

**Constraints arquiteturais**:
- Helper é única source of truth para hardware. App nunca lê SMC direto.
- Toda mudança não pode quebrar o XPC protocol existente (apps já têm `getSnapshot` cacheado).
- TDD obrigatório (regra do projeto Macfancontrol).
- Mudanças cross-target (App + Helper + Shared).

## Goals / Non-Goals

**Goals:**
- G1. Temperatura da CPU lida sempre dentro de range plausível `[-20°C, 120°C]`. Spike único de leitura corrompida descartado, não exibido na UI.
- G2. Ícone do fan gira continuamente quando `duty > 0`, com velocidade proporcional. Stop quando `duty == 0` ou `nil`.
- G3. Botões de preset (Silent/Balanced/Performance/Max) produzem efeito audível e visível: fans aceleram/desaceleram em ~3s. App calcula targets a partir dos ceilings reais lidos pelo helper, não defaults hardcoded.
- G4. Helper loga em `os_log` toda leitura SMC nos primeiros 5 ticks após boot (chave + dataType FourCC + bytes hex + valor decodificado), facilitando diagnóstico em hardware diferente.
- G5. Helper rejeita `setMode(.forced(rpm))` com `rpm < F0Mn || rpm > F0Mx` (clampa + warn log).

**Non-Goals:**
- NG1. Fix para outros modelos além de MacBookPro18,3. Changes futuros tratam.
- NG2. Mudança de UX. Mesmo layout, mesmas animações de sheet.
- NG3. IOHID temperature fallback completo (já anotado como follow-up).
- NG4. Controle por GPU temp (Tg05/Tg0D) — apenas CPU clusters Tp*.

## Decisions

### D1. Sanity range para temperatura: `[-20°C, 120°C]`

- **Escolhido**: Após decodificar uma key Tp*, validar `value >= -20 && value <= 120`. Se fora, descartar e tentar próxima key. Se todas fora, retornar `nil` (UI mostra `—`).
- **Alternativa A**: aceitar e renderizar (app exibe temperaturas absurdas).
- **Alternativa B**: cap em [-20, 120] (mascarar valores corruptos com extremos do range).
- **Razão**: M1 Pro CPU tem TJmax ~105°C, idle ~30°C. Qualquer valor fora desse range ampliado é certo lixo de decoding. Descartar é honest — UI mostra "—" e usuário sabe que sensor falhou.

### D2. Logging diagnóstico nos primeiros 5 ticks

- **Escolhido**: `SnapshotBuilder` mantém `tickCount: Int` que incrementa a cada `build()`. Quando `tickCount <= 5`, helper loga em `os_log info`: `key=Tp01 dataType=0x666c7420 (flt ) bytes=12 34 56 78 -> 50.234375°C`. Mesmo para fan keys (F0Mx etc).
- **Alternativa A**: log permanente (verbose pra produção).
- **Alternativa B**: log via env var `FANCONTROL_DEBUG`.
- **Razão**: 5 ticks = ~5s de boot. Captura a primeira leitura de cada key + 4 follow-ups, suficiente pra identificar formato em hardware diferente. Após isso, helper fica silencioso por padrão (logs preservados em Console.app).

### D3. Animação do fan icon: `TimelineView` em vez de `withAnimation.repeatForever`

- **Escolhido**: usar `TimelineView(.animation)` que dá callbacks de cada frame; calcular ângulo via `Date().timeIntervalSince(reference) * 360.0 / spinDuration`. Pula automaticamente para 0 quando `duty == 0`.
- **Alternativa A**: continuar com `withAnimation.repeatForever` mas alternar `rotation += 360` em vez de set absoluto.
- **Alternativa B**: usar `Timer.publish(every: 0.016)` Combine + `@State angle: Double`.
- **Razão**: `TimelineView` é a API SwiftUI nativa pra animações contínuas baseadas em tempo. Não tem state interno corrompido como `withAnimation.repeatForever` que SwiftUI re-cria a cada update do parent. Funciona limpo quando duty muda dinamicamente.

### D4. App pega ceilings via XPC `getFanCeilings()` no boot e cacheia

- **Escolhido**: nova call XPC retorna `FanCeilings { f0Mn, f0Mx, f1Mn, f1Mx }` Codable. Chamada uma vez quando app conecta ao helper (no primeiro `getSnapshot` bem-sucedido). Cacheada em `AppState.fanCeilings`. Presets usam essa cache.
- **Alternativa A**: Embutir ceilings no `SensorSnapshot`. Pro: 1 round-trip XPC. Contra: ceilings nunca mudam após boot, payload extra a cada 1s.
- **Alternativa B**: Helper calcular targets server-side (`applyPreset(.max)` aplica F0Mx automaticamente).
- **Razão**: Alternativa B é a mais limpa, mas requer mudança maior no contrato (presets viram comandos atômicos). D4 simples preserva o contrato `setMode(.forced(rpm))` existente. Segue padrão do `getModelInfo()` que também é uma call one-shot.
- **Trade-off**: Se ceilings mudarem em runtime (não acontece em hardware real), cache fica stale. Aceitável.

### D5. Helper clampa target RPM em `setMode(.forced)` e loga warn quando fora

- **Escolhido**: `ModeManager.setMode(.forced(rpm))` faz `clampedRpm = min(max(rpm, f0Mn), f0Mx)`. Se `clampedRpm != rpm`, loga warn `"setMode forced clamp: requested=4800 clamped=4500 (mn=1300 mx=4500)"`. Persiste `clampedRpm` em `control.json`.
- **Alternativa A**: rejeitar com erro (volta pro app pra mostrar dialog).
- **Razão**: Clamp é silencioso para o usuário, mas log preserva auditoria. Rejeitar com erro complica fluxo: app teria que re-tentar com valor ajustado. App envia o que sabe, helper aplica seguro.

### D6. Sanity range para fan ceilings em `loadFanCeilings()`

- **Escolhido**: validar `f0Mn ∈ [500, 3000]` e `f0Mx ∈ [3500, 10000]`. Se fora, mantém defaults `1300/6500` e marca `ceilingsValid = false`. Helper loga warn.
- **Razão**: Defende contra a mesma regressão que causou bug 3 (F0Mx lido como 38). Defaults são plausíveis para MacBookPro18,3 baseado em data sheet do M1 Pro.

### D7. TDD via mocks

- **Escolhido**: testes unit puros (`SnapshotBuilder` com mock SMC) + e2e via fake `MockSMCReader` controlando bytes/dataType retornado.
- **Tests novos**:
  - `TempSanityTests`: cpuTemp=200°C → nil; cpuTemp=45 → 45.
  - `FanCeilingsValidityTests`: F0Mx=38 → invalid, defaults; F0Mx=6500 → valid.
  - `FanRowAnimationTests`: smoke test de view (snapshot ou XCUI) — opcional.
  - `ModeManagerClampTests`: setMode(.forced(99999)) → clamps to F0Mx, logs warn.
  - `GetFanCeilingsXPCTests`: helper retorna ceilings via XPC quando consultado.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| **R1**. Sanity range em D1 pode mascarar bug futuro de leitura legítima fora desse range | Loggar warn quando descartado; range generoso (-20..120 cobre frio extremo até throttle) |
| **R2**. TimelineView pode causar re-render do MainView inteiro a cada frame de animação | Usar `.animation` schedule (60fps) só dentro do `FanGlyph`; resto da view não re-renderiza pq `TimelineView` é local. SwiftUI compiler garante isso. |
| **R3**. Cache de ceilings fica stale se helper restartar com hardware diferente (ex: hot-swap CPU) | Helper publica nova versão de ceilings via push se `loadFanCeilings()` rodar de novo. App refetch quando XPC connection é interrupted. |
| **R4**. Testes RTL/SwiftUI exigem snapshot framework. Snapshot framework não está integrado | Skipar testes UI; cobertura via TS/lógica pura. Smoke manual valida visualmente. |
| **R5**. `getFanCeilings()` é chamada extra no boot. Adiciona ~50ms de latência inicial | Aceitável — chamada paralela ao primeiro `getSnapshot`. UI já tem banner "Connecting…" durante esse tempo. |
| **R6**. Logging de 5 ticks pode poluir Console.app durante development | É escopo limitado (5×N keys ≈ 50 lines); usuário pode filtrar por subsystem; é só em boot |

## Migration Plan

### Sequência

1. **Rebuild e reinstall helper** após cada bug fix (com `sudo cp` + `launchctl bootstrap`).
2. **App rebuild** após mudanças no `HelperProtocol.swift` (recompila App + Helper).
3. **Smoke test live** após cada bug isolado, valida que outros não regrediram.

### Rollback

Em caso de regressão, basta `git revert` do commit + reinstall helper. Schema do `control.json` não muda. App continua funcionando contra helper antigo (calls XPC novas falham com timeout, banner "Helper offline").

### Validação live ao final

- [ ] Boot da app: `getFanCeilings()` retorna `f0Mx ∈ [3500, 10000]`. Confirmar via log.
- [ ] CPU temp: idle 30-50°C, sem jumps. Stress (yes > /dev/null × 3): sobe gradualmente.
- [ ] Fan icons giram com `duty > 0`. Param em `duty == 0`.
- [ ] Click "Max": ambos fans aceleram em ~3s para próximo de F0Mx (audível, dá pra ver mudança no Macs Fan Control rodando paralelo).
- [ ] Click "Silent": desaceleram para ~35% de F0Mx.
- [ ] Click "Balanced": helper escreve F0Md=0, fans voltam pro Auto do macOS.

## Open Questions

**OQ1**. Devemos cachear ceilings no `state.json` do app pra evitar XPC call no boot? **Resposta provável**: não — só ~50ms ganho mas adiciona stale risk. Resolver: descartar.

**OQ2**. SafetyOverride deveria também usar ceilings reais (não defaults 6500)? **Resposta**: sim, helper já tem ceilings cacheados via `SnapshotBuilder.f0Mx`. ControlLoop já usa eles. Não há gap aqui.

**OQ3**. Logs de diagnóstico devem ser persistidos em arquivo além do `os_log`? **Resposta**: não — `log show --predicate ...` cobre. Persistência em arquivo é follow-up se vira pain point.
