## ADDED Requirements

### Requirement: Leitura periodica de RPM dos 2 fans via SMC

O helper SHALL ler a cada `1.0 segundo` os SMC keys `F0Ac` (Left fan RPM atual) e `F1Ac` (Right fan RPM atual) usando `IOConnectCallStructMethod` em `AppleSMC` IOService. Os valores SHALL ser decodificados como `FPE2` (fixed-point 2 bytes, formato SMC padrao) e expostos a UI via XPC `getSnapshot()` retornando `SensorSnapshot` Codable com `leftRPM: Int, rightRPM: Int`.

#### Scenario: Leitura bem-sucedida em hardware MacBookPro18,3

- **WHEN** o helper esta rodando e o SMC esta acessivel
- **AND** o app chama `getSnapshot()`
- **THEN** o snapshot retorna `leftRPM` e `rightRPM` com valores entre `0` e `6500`
- **AND** os valores batem (delta < 5%) com o que `Macs Fan Control` exibe no mesmo instante

#### Scenario: SMC inacessivel (outro app trava o lock)

- **WHEN** outro app (TG Pro, Macs Fan Control) ja tem o SMC com lock exclusivo
- **AND** o helper tenta ler `F0Ac`
- **THEN** a chamada retorna `kIOReturnExclusiveAccess`
- **AND** o snapshot retorna RPMs como `nil` (Optional) ou ultimo valor cacheado com flag `stale: true`
- **AND** a UI mostra banner "Outro app esta controlando os fans"

### Requirement: Calculo de duty cycle por fan

O helper SHALL calcular `duty = (currentRPM - F0Mn) / (F0Mx - F0Mn)` clampeado em `[0.0, 1.0]` para cada fan, lendo `F0Mn`/`F0Mx` apenas no boot do helper (cacheados). O snapshot exposto SHALL incluir `leftDuty: Double, rightDuty: Double` no range 0.0-1.0.

#### Scenario: Duty cycle em fan parado

- **WHEN** `F0Ac = 0`, `F0Mn = 1300`, `F0Mx = 6500`
- **THEN** `leftDuty = 0.0`

#### Scenario: Duty cycle em fan a velocidade media

- **WHEN** `F0Ac = 3900`, `F0Mn = 1300`, `F0Mx = 6500`
- **THEN** `leftDuty = (3900 - 1300) / (6500 - 1300) = 0.5`

#### Scenario: Duty cycle clampeado quando RPM excede F0Mx

- **WHEN** `F0Ac = 7000`, `F0Mx = 6500` (caso raro de overshoot)
- **THEN** `leftDuty = 1.0` (clamp em 1.0, nao 1.077)

### Requirement: Leitura de temperatura via SMC com fallback IOHID

O helper SHALL tentar ler os SMC keys `Tp01`, `Tp05`, `Tp09`, `Tp0D`, `Tp0H` (CPU performance clusters M1 Pro) a cada `1.5 segundos`. Para qualquer key que retornar erro, o helper SHALL fazer fallback para `IOHIDEventSystemClient` com filtro `kHIDPage_AppleVendorTemperatureSensor`. O snapshot SHALL incluir `cpuTemp: Double` (em °C) calculado como `max(temp_per_cluster)` sobre as keys disponiveis.

#### Scenario: Todas as 5 keys SMC retornam valor

- **WHEN** Tp01=55, Tp05=58, Tp09=62, Tp0D=51, Tp0H=49 (em °C)
- **THEN** `cpuTemp = 62` (max dos clusters)

#### Scenario: Tp01 e Tp05 retornam erro, demais OK

- **WHEN** Tp01 e Tp05 retornam `kIOReturnNotReadable`
- **AND** Tp09=62, Tp0D=51, Tp0H=49 funcionam
- **THEN** o helper usa max dos disponiveis = 62
- **AND** loga warning "Tp01, Tp05 unavailable — degraded sensor coverage"

#### Scenario: Todas as keys SMC falham, fallback IOHID funciona

- **WHEN** todas as `Tp*` keys retornam erro
- **AND** `IOHIDEventSystemClient` expoe sensor `pACC MTR Temp Sensor1` = 60°C
- **THEN** `cpuTemp = 60` (do IOHID)
- **AND** loga info "Using IOHID fallback for CPU temp"

#### Scenario: Tudo falha (hardware bizarro)

- **WHEN** SMC e IOHID retornam erro em todos os caminhos
- **THEN** `cpuTemp` no snapshot e `nil` (Optional)
- **AND** UI exibe "—" no temp readout
- **AND** modo Curve e bloqueado (nao da pra interpolar sem temp)

### Requirement: XPC `getSnapshot()` retorna estrutura completa

O helper SHALL expor uma call XPC `getSnapshot() async -> SensorSnapshot` onde `SensorSnapshot: Codable` contem:

```swift
struct SensorSnapshot: Codable {
    let leftRPM: Int?       // nil quando SMC bloqueado
    let rightRPM: Int?
    let leftDuty: Double?   // 0.0...1.0
    let rightDuty: Double?
    let cpuTemp: Double?    // °C, nil quando indisponivel
    let timestamp: Date     // quando o snapshot foi capturado
    let stale: Bool         // true se for ultimo cache (helper falhou em re-ler)
}
```

#### Scenario: Snapshot fresh

- **WHEN** o helper acabou de ler todos os sensores com sucesso 0.5s atras
- **AND** o app chama `getSnapshot()`
- **THEN** o snapshot tem `stale = false`
- **AND** `timestamp` e ~0.5s no passado

#### Scenario: Snapshot stale apos falha de leitura

- **WHEN** o helper falhou em ler nos ultimos 3 ticks (~4.5s)
- **AND** o app chama `getSnapshot()`
- **THEN** o snapshot tem `stale = true`
- **AND** valores correspondem a ultima leitura bem-sucedida

### Requirement: UI faz polling do snapshot a cada 1 segundo

O app (UI) SHALL fazer polling do `getSnapshot()` via XPC a cada `1.0 segundo` enquanto a janela esta visivel. Quando a janela e minimizada ou app vai pra background, o polling SHALL pausar para economizar CPU. O polling SHALL retomar imediatamente quando o app voltar a foreground.

#### Scenario: Polling ativo com janela visivel

- **WHEN** a janela esta visivel
- **THEN** ha exatamente 1 chamada `getSnapshot()` por segundo
- **AND** os valores na UI atualizam em ~1s

#### Scenario: Polling pausado em background

- **WHEN** o usuario minimiza a janela (clica no minimize do dock ou cmd+M)
- **THEN** o polling para em <500ms
- **AND** nenhuma chamada `getSnapshot()` ocorre

#### Scenario: Retomada ao voltar foreground

- **WHEN** o usuario clica no Dock ou cmd+tab para o app
- **THEN** uma chamada `getSnapshot()` ocorre imediatamente (sem esperar 1s)
- **AND** o polling de 1s retoma

### Requirement: Exibicao de RPM com unidades e formatting

A UI SHALL exibir cada fan na lista com formato `"<RPM>".toLocaleString() + " RPM"` (ex: `4,280 RPM`), font tabular-nums, label do fan ("Left Fan"/"Right Fan") a esquerda, e duty `Math.round(duty * 100)%` em cinza a direita (ex: `66%`).

#### Scenario: Fan com RPM de 4 digitos

- **WHEN** leftRPM=4280, leftDuty=0.66
- **THEN** UI exibe `"Left Fan"` + `"4,280 RPM"` + `"66%"`

#### Scenario: Fan parado

- **WHEN** leftRPM=0
- **THEN** UI exibe `"Left Fan"` + `"0 RPM"` + `"0%"`
- **AND** o icone do fan NAO gira (animacao parada)

#### Scenario: RPM nil (SMC bloqueado)

- **WHEN** leftRPM=nil
- **THEN** UI exibe `"Left Fan"` + `"—"` + `"—"`
- **AND** o icone do fan NAO gira

### Requirement: Exibicao de temperatura com unit toggle

A UI SHALL exibir `cpuTemp` no topo da janela em font 64pt thin, label `"CPU temperature"` em uppercase 10pt, com sufixo `"°C"` ou `"°F"` conforme `tempUnit` setting. Conversao MUST aplicar `F = C * 9/5 + 32` arredondado para inteiro.

#### Scenario: Display em Celsius

- **WHEN** cpuTemp=67, tempUnit=C
- **THEN** UI exibe `67` + `°C`

#### Scenario: Display em Fahrenheit

- **WHEN** cpuTemp=67, tempUnit=F
- **THEN** UI exibe `153` + `°F` (67*9/5+32 = 152.6 -> arredondado 153)

#### Scenario: Temp unavailable

- **WHEN** cpuTemp=nil
- **THEN** UI exibe `"—"` + `°C/F`
- **AND** o subtext muda de "Running cool" para "Sensor unavailable"

### Requirement: Subtext informativo abaixo da temperatura

A UI SHALL exibir um subtext de 11pt em cinza abaixo da temp readout com formato `"<status> · <fan_count> fans active"`:
- `<status>` = `"Running cool"` se temp < 60°C, `"Warming up"` se 60-80°C, `"Hot"` se >= 80°C, `"Sensor unavailable"` se nil
- `<fan_count>` = numero de fans com RPM > 0

#### Scenario: 2 fans ativos, temp baixa

- **WHEN** cpuTemp=45, leftRPM=2100, rightRPM=2350
- **THEN** subtext mostra `"Running cool · 2 fans active"`

#### Scenario: 1 fan parado, temp alta

- **WHEN** cpuTemp=85, leftRPM=6200, rightRPM=0
- **THEN** subtext mostra `"Hot · 1 fans active"`

### Requirement: Animacao de fan icon proporcional ao duty

Cada fan icon na lista SHALL girar com duracao da rotacao calculada como `spinDuration = max(0.4, 3.0 - duty * 2.5)` segundos por volta. Em duty=0.0 a animacao para. Em duty=1.0 spin = 0.5s/volta. Em duty=0.5 spin = 1.75s/volta.

#### Scenario: Fan rapido

- **WHEN** duty=1.0
- **THEN** o icone gira a 0.5s por volta

#### Scenario: Fan parado

- **WHEN** duty=0.0
- **THEN** o icone NAO gira (animacao stopped)
