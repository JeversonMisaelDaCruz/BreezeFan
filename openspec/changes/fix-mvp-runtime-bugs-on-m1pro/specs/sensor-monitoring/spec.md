## MODIFIED Requirements

### Requirement: Leitura de temperatura via SMC com fallback IOHID

O helper SHALL tentar ler os SMC keys `Tp01`, `Tp05`, `Tp09`, `Tp0D`, `Tp0H` (CPU performance clusters M1 Pro) a cada `1.5 segundos`. Para qualquer key que retornar erro, o helper SHALL fazer fallback para `IOHIDEventSystemClient` com filtro `kHIDPage_AppleVendorTemperatureSensor`. O snapshot SHALL incluir `cpuTemp: Double` (em °C) calculado como `max(temp_per_cluster)` sobre as keys disponiveis.

**Sanity range obrigatório**: cada valor decodificado SHALL ser validado em `[-20.0°C, 120.0°C]`. Valores fora desse range SHALL ser descartados (tratados como leitura corrompida) e a key correspondente SHALL ser ignorada para esse tick. Helper SHALL logar `"sensor: rejected out-of-range temp <key>=<value>°C"` em `os_log warn`.

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

#### Scenario: Valor decodificado fora do range plausível

- **WHEN** Tp01 decodifica como `1500.5°C` (lixo de bytes interpretados como wrong format)
- **THEN** o helper descarta esse valor
- **AND** loga warn `"sensor: rejected out-of-range temp Tp01=1500.5°C"`
- **AND** se outras keys retornam valores válidos, usa o max delas
- **AND** se todas as keys retornam fora-de-range, `cpuTemp = nil`

#### Scenario: Valor negativo extremo

- **WHEN** Tp05 decodifica como `-450.0°C` (Int16 max negative interpretado como sp78)
- **THEN** o helper descarta
- **AND** loga warn similar
- **AND** outras keys são consideradas

#### Scenario: Valor levemente acima do range, mas plausível physical

- **WHEN** Tp09 decodifica como `108.0°C` (próximo do TJmax mas ainda físico)
- **THEN** valor aceito (range é -20..120, dá margem)
- **AND** SafetyOverride deve disparar separadamente em `> 95°C × 3 ticks`

### Requirement: Animacao de fan icon proporcional ao duty

Cada fan icon na lista SHALL girar continuamente com duracao da rotacao calculada como `spinDuration = max(0.4, 3.0 - duty * 2.5)` segundos por volta. Em `duty = 0.0` ou `duty = nil` a animacao SHALL parar. Em `duty = 1.0` spin = 0.5s/volta. Em `duty = 0.5` spin = 1.75s/volta.

A animação SHALL usar `TimelineView(.animation)` do SwiftUI (ou equivalente baseado em tempo absoluto via `Date().timeIntervalSinceReferenceDate`), em vez de `withAnimation.repeatForever` aplicado a um state property. Mudança de `duty` em runtime (snapshot atualizado) SHALL ajustar a velocidade imediatamente sem cancelar/recriar a animação anterior.

#### Scenario: Fan rapido

- **WHEN** duty=1.0
- **THEN** o icone gira continuamente a 0.5s por volta
- **AND** após 5 segundos o ícone completou exatamente 10 voltas

#### Scenario: Fan parado

- **WHEN** duty=0.0
- **THEN** o icone NAO gira (rotação fixa em ângulo arbitrário)

#### Scenario: Duty muda durante runtime

- **WHEN** ícone está girando com duty=0.3 (spin = 2.25s/volta)
- **AND** snapshot atualiza para duty=0.8 (spin = 1.0s/volta)
- **THEN** ícone acelera suavemente sem interrupção visual
- **AND** continua girando indefinidamente

#### Scenario: Duty volta a zero

- **WHEN** ícone está girando com duty=0.5
- **AND** snapshot atualiza para duty=0.0
- **THEN** ícone para imediatamente (frame seguinte)

#### Scenario: Duty é nil (SMC bloqueado)

- **WHEN** snapshot tem leftDuty=nil (smcConflict)
- **THEN** ícone NAO gira (mesma renderização que duty=0.0)

## ADDED Requirements

### Requirement: Logging diagnóstico das primeiras 5 leituras SMC após boot

O helper SHALL logar em `os_log info` (subsystem `com.fancontrol.helper`, category `smc`) toda leitura SMC nos primeiros 5 ticks após boot. Cada log entry SHALL incluir: nome da chave (4 chars), dataType retornado pelo SMC (FourCC hex), bytes raw em hex, e valor decodificado em formato humano.

Após o tick #5, o logging volta ao normal (apenas erros e warnings). Esse logging facilita diagnóstico em hardware diferente do MacBookPro18,3 (modelo futuro, M2 Pro, etc).

#### Scenario: Primeiro tick após boot

- **WHEN** helper acabou de bootar e completa o tick #1
- **AND** lê F0Mx via SMC retornando 4 bytes `[0x00, 0xC0, 0xCB, 0x45]` como dataType `flt`
- **THEN** log entry: `"smc tick=1 key=F0Mx dataType=0x666c7420 (flt ) bytes=00 c0 cb 45 -> 6520.0 RPM"`

#### Scenario: Tick #6 (após período de diagnóstico)

- **WHEN** helper completa o tick #6 com sucesso
- **THEN** NÃO há log entry de cada chave individual
- **AND** apenas erros/warnings (se houver) são logados

#### Scenario: Erro SMC durante diagnóstico

- **WHEN** durante tick #2, lendo F1Ac retorna `kIOReturnExclusiveAccess`
- **THEN** log entry warn: `"smc tick=2 key=F1Ac error=locked (kIOReturnExclusiveAccess)"`
- **AND** continua logando outras chaves no mesmo tick
