## MODIFIED Requirements

### Requirement: Quatro presets MVP com mapeamento exato

O app SHALL apresentar 4 botoes de preset na main view com mapeamento exato:

| Preset | Mode | Target RPM (% de F0Mx) |
|---|---|---|
| `Silent` | Forced | 35% |
| `Balanced` | Auto | n/a |
| `Performance` | Forced | 70% |
| `Max` | Forced | 100% |

`F0Mx`, `F0Mn`, `F1Mx`, `F1Mn` SHALL ser lidos pelo helper no boot e validados em range plausível (`Mn ∈ [500, 3000]`, `Mx ∈ [3500, 10000]`). O app SHALL obter esses valores via XPC `getFanCeilings()` e cacheá-los em `AppState.fanCeilings` antes de calcular targets de preset. O target RPM SHALL ser calculado por fan usando os ceilings reais — **nunca** valores hardcoded no código do app.

Caso `getFanCeilings()` falhe ou `ceilingsValid = false`, o app SHALL desabilitar os botões de preset e exibir mensagem "Aguardando dados do helper…" no Mode section.

#### Scenario: Preset Silent

- **WHEN** o usuario clica em "Silent"
- **AND** AppState.fanCeilings = (f0Mn=1300, f0Mx=6500, f1Mn=1300, f1Mx=6500)
- **THEN** F0Tg=2275, F1Tg=2275 (35% de 6500)
- **AND** o usuario percebe os fans desacelerarem em ~3s

#### Scenario: Preset Performance

- **WHEN** o usuario clica em "Performance"
- **AND** AppState.fanCeilings = (1300, 6500, 1300, 6500)
- **THEN** F0Tg=4550, F1Tg=4550 (70% de 6500)

#### Scenario: Preset com clamp em F0Mn

- **WHEN** o usuario clica em "Silent"
- **AND** AppState.fanCeilings = (f0Mn=2500, f0Mx=6500, ...)  (M1 Pro tem floor alto)
- **THEN** target calculado seria 2275 mas e clamped em F0Mn=2500
- **AND** F0Tg=2500 (respeita o floor do hardware)

#### Scenario: Helper ainda não carregou ceilings (boot recente)

- **WHEN** app conectou ao helper há <1 segundo e `AppState.fanCeilings == nil`
- **THEN** botões de preset estão desabilitados (cinza)
- **AND** Mode section exibe "Aguardando dados do helper…"
- **AND** click em qualquer preset NÃO envia setMode

#### Scenario: Helper retorna ceilings inválidos

- **WHEN** helper retorna `getFanCeilings()` com f0Mx=38 (lixo)
- **THEN** helper interno marca `ceilingsValid=false` e usa defaults internos
- **AND** XPC call retorna `(f0Mn=1300, f0Mx=6500, ..., valid: false)`
- **AND** app exibe ainda os botões habilitados mas com tooltip warn "Sensor com valor suspeito; usando defaults"

#### Scenario: Após click em Max, helper clampa target absurdo

- **WHEN** app envia `setMode(.forced(rpm: 99999))` (input bizarro de teste)
- **AND** helper tem ceilings válidos f0Mx=6500
- **THEN** helper escreve F0Tg = clamp(99999, 1300, 6500) = 6500
- **AND** loga warn `"setMode forced clamp: requested=99999 clamped=6500 (mn=1300 mx=6500)"`
- **AND** retorna sucesso ao app (não erro)

## ADDED Requirements

### Requirement: XPC `getFanCeilings()` retorna ceilings reais validados

O helper SHALL expor uma chamada XPC `getFanCeilings(reply: @escaping (Data?, Error?) -> Void)` que devolve um payload Codable `FanCeilings { f0Mn: Int, f0Mx: Int, f1Mn: Int, f1Mx: Int, valid: Bool }`. O `valid` SHALL ser `true` apenas quando os 4 valores caem em range plausível (`Mn ∈ [500, 3000]`, `Mx ∈ [3500, 10000]`).

O helper SHALL ler esses 4 SMC keys uma única vez no boot (cacheando em `SnapshotBuilder.f0Mn` etc) e expor o cache. Se o read falha no boot, helper retorna defaults `1300/6500/1300/6500` com `valid=false` e loga warn.

#### Scenario: Helper retorna ceilings válidos

- **WHEN** helper bootou normalmente, leu F0Mn=1300 F0Mx=6500 F1Mn=1300 F1Mx=6500
- **AND** app chama `getFanCeilings()`
- **THEN** retorna `FanCeilings(f0Mn=1300, f0Mx=6500, f1Mn=1300, f1Mx=6500, valid=true)`

#### Scenario: SMC retornou valores absurdos no boot

- **WHEN** boot do helper leu F0Mx=38 (lixo de decoding errado)
- **THEN** helper detecta `f0Mx < 3500`, marca `ceilingsValid=false`
- **AND** loga warn `"loadFanCeilings: F0Mx=38 out of plausible range [3500, 10000], using default 6500"`
- **AND** `getFanCeilings()` retorna `(1300, 6500, 1300, 6500, valid=false)`

#### Scenario: App reage ao boot do helper

- **WHEN** app boot e conecta XPC
- **AND** primeiro `getSnapshot()` retorna sucesso
- **THEN** app dispara `getFanCeilings()` em paralelo
- **AND** ao receber response, popula `AppState.fanCeilings`
- **AND** botões de preset ficam habilitados (estavam disabled enquanto fanCeilings == nil)

### Requirement: Helper clampa target RPM em setMode forced

Quando o helper recebe `setMode(.forced(rpm))` via XPC, ele SHALL aplicar `clampedRpm = min(max(rpm, f0Mn), f0Mx)` para o fan 0 (e equivalente para fan 1). O `clampedRpm` SHALL ser persistido em `control.json` e escrito no SMC. Se `clampedRpm != rpm`, helper SHALL logar warn `"setMode forced clamp: requested=<rpm> clamped=<clamped> (mn=<f0Mn> mx=<f0Mx>)"`.

#### Scenario: RPM válido dentro do range

- **WHEN** app envia `setMode(.forced(rpm: 4500))`
- **AND** ceilings = (1300, 6500)
- **THEN** helper escreve F0Tg=4500 (sem clamp)
- **AND** persiste `forcedTargetRPM=4500` em control.json
- **AND** NÃO loga warn de clamp

#### Scenario: RPM acima do max

- **WHEN** app envia `setMode(.forced(rpm: 7500))`
- **AND** f0Mx = 6500
- **THEN** helper escreve F0Tg=6500
- **AND** loga warn `"setMode forced clamp: requested=7500 clamped=6500"`
- **AND** persiste `forcedTargetRPM=6500` em control.json

#### Scenario: RPM abaixo do min

- **WHEN** app envia `setMode(.forced(rpm: 100))`
- **AND** f0Mn = 1300
- **THEN** helper escreve F0Tg=1300 (clamp para o floor do hardware)
- **AND** loga warn similar

#### Scenario: RPM zero (cancelar forced sem ir pra auto)

- **WHEN** app envia `setMode(.forced(rpm: 0))`
- **AND** f0Mn = 1300
- **THEN** helper clampa para 1300 (não permite turn off via forced=0; isso seria via setMode(.auto))
- **AND** loga warn

### Requirement: App cachea fanCeilings via getFanCeilings após boot do helper

O app SHALL chamar `HelperClient.getFanCeilings()` quando:
1. Primeiro `getSnapshot()` retornar sucesso (helper alcançável), E
2. `AppState.fanCeilings == nil`

Resultado SHALL ser armazenado em `AppState.fanCeilings: FanCeilings?`. Enquanto `nil`, presets SHALL estar disabled. App SHALL refetch ceilings se XPC connection for invalidated e re-estabelecida.

#### Scenario: Boot fresh do app

- **WHEN** app boot e XPC connection ainda não estabelecida
- **THEN** `AppState.fanCeilings == nil`
- **AND** PresetGrid renderiza botões disabled

#### Scenario: Helper conecta pela primeira vez

- **WHEN** app recebe primeiro snapshot bem-sucedido
- **AND** `AppState.fanCeilings == nil`
- **THEN** dispara `getFanCeilings()` em background
- **AND** popula `AppState.fanCeilings` ao receber response
- **AND** PresetGrid habilita os botões

#### Scenario: Helper crash + restart

- **WHEN** helper crash, conexão XPC é invalidated
- **AND** app detecta via invalidationHandler, marca `helperReachable = false`
- **AND** após launchd respawnar helper e XPC reconectar, app recebe snapshot
- **THEN** app refetch `getFanCeilings()` (cache vira nil temporariamente)
- **AND** PresetGrid mostra estado loading durante o refetch
