## ADDED Requirements

### Requirement: Tres modos de controle: Auto, Forced, Curve

O sistema SHALL suportar exatamente 3 modos de controle, mutuamente exclusivos:

- **Auto** — `F0Md=0, F1Md=0`. Sistema macOS controla. Helper apenas le sensores, NAO escreve targets.
- **Forced** — `F0Md=1, F1Md=1, F0Tg=<rpm>, F1Tg=<rpm>`. RPM constante definido pelo usuario. Helper re-escreve `F0Md=1` a cada tick para manter o controle.
- **Curve** — `F0Md=1, F1Md=1`. Helper executa control loop que le temp, interpola na curva ativa, e escreve `F0Tg`/`F1Tg` resultante a cada tick.

O modo ativo SHALL ser persistido em `/Library/Application Support/FanControl/control.json` no campo `mode: "auto" | "forced" | "curve"`.

#### Scenario: Transicao Auto -> Forced (Max)

- **WHEN** o usuario clica no preset "Max" estando em modo Auto
- **THEN** o helper escreve `F0Md=1, F1Md=1, F0Tg=F0Mx, F1Tg=F1Mx`
- **AND** mode em `control.json` = `"forced"`
- **AND** RPM dos 2 fans atinge max em ~3s

#### Scenario: Transicao Forced -> Auto (Balanced)

- **WHEN** o usuario clica no preset "Balanced" estando em modo Forced
- **THEN** o helper escreve `F0Md=0, F1Md=0`
- **AND** PARA de re-escrever F0Md a cada tick
- **AND** mode em `control.json` = `"auto"`
- **AND** os fans voltam ao controle do macOS em ~5s (1 tick do scheduler de fans)

#### Scenario: Transicao Forced -> Curve (Edit fan curve + Save)

- **WHEN** o usuario clica em "Edit fan curve", edita uma curva, e clica em Save
- **AND** estava em modo Forced
- **THEN** o helper carrega a curva salva e troca mode para `"curve"`
- **AND** o control loop comeca a tickar com a curva ativa
- **AND** F0Md/F1Md continuam em 1 (forced bit precisa estar setado para o helper escrever F0Tg)

### Requirement: Quatro presets MVP com mapeamento exato

O app SHALL apresentar 4 botoes de preset na main view com mapeamento exato:

| Preset | Mode | Target RPM (% de F0Mx) |
|---|---|---|
| `Silent` | Forced | 35% |
| `Balanced` | Auto | n/a |
| `Performance` | Forced | 70% |
| `Max` | Forced | 100% |

`F0Mx` e `F1Mx` SHALL ser lidos no boot do helper e cacheados. O target RPM e calculado independente para cada fan.

#### Scenario: Preset Silent

- **WHEN** o usuario clica em "Silent"
- **AND** F0Mx=6500, F1Mx=6500
- **THEN** F0Tg=2275, F1Tg=2275 (35% de 6500)
- **AND** o usuario percebe os fans desacelerarem em ~3s

#### Scenario: Preset Performance

- **WHEN** o usuario clica em "Performance"
- **AND** F0Mx=6500, F1Mx=6500
- **THEN** F0Tg=4550, F1Tg=4550 (70% de 6500)

#### Scenario: Preset com clamp em F0Mn

- **WHEN** o usuario clica em "Silent"
- **AND** F0Mx=6500, F0Mn=2500 (M1 Pro tem floor alto)
- **THEN** target calculado seria 2275 mas e clamped em F0Mn=2500
- **AND** F0Tg=2500 (respeita o floor do hardware)

### Requirement: Modo Curve com control loop a cada 1.5s

O helper SHALL rodar um timer (`Task.sleep(for: .milliseconds(1500))` em loop async) que a cada tick:

1. Le `cpuTemp` do snapshot fresh
2. Aplica histerese (D9 do design) para decidir target temp
3. Interpola linearmente na curva ativa para obter `targetDuty: 0...100`
4. Calcula `targetRPM = F0Mn + targetDuty/100 * (F0Mx - F0Mn)` para cada fan
5. Escreve `F0Md=1, F0Tg=targetRPM, F1Md=1, F1Tg=targetRPM` (idempotente)

O loop SHALL parar imediatamente quando mode muda para Auto ou Forced.

#### Scenario: Curva 40°/20% -> 60°/50% -> 75°/80% -> 90°/100%, temp = 50°C

- **WHEN** mode=curve, curva ativa = `[(40,20), (60,50), (75,80), (90,100)]`, cpuTemp=50
- **THEN** interpolacao linear entre (40,20) e (60,50): `duty = 20 + (50-40)/(60-40) * (50-20) = 35%`
- **AND** F0Tg ~= F0Mn + 0.35 * (F0Mx - F0Mn) ~= 1300 + 0.35 * 5200 = 3120 RPM
- **AND** o helper escreve F0Tg=3120

#### Scenario: Temp acima do ultimo ponto

- **WHEN** curva = `[(40,20), (60,50), (75,80), (90,100)]`, cpuTemp=95
- **THEN** duty = 100% (clamp no ultimo ponto)
- **AND** F0Tg = F0Mx

#### Scenario: Temp abaixo do primeiro ponto

- **WHEN** curva = `[(40,20), (60,50), (75,80), (90,100)]`, cpuTemp=25
- **THEN** duty = 20% (clamp no primeiro ponto, NAO interpola para 0)
- **AND** F0Tg = F0Mn + 0.20 * (F0Mx - F0Mn)

#### Scenario: cpuTemp=nil

- **WHEN** mode=curve mas cpuTemp do snapshot e nil
- **THEN** o control loop NAO escreve F0Tg neste tick
- **AND** loga warning "Skipping tick — temp unavailable"
- **AND** mantem F0Md=1 (nao deixa o sistema retomar)

### Requirement: Histerese 3°C bidirecional

O helper SHALL aplicar histerese para evitar oscilacao quando temp varia perto de uma fronteira de step. A histerese SHALL ser implementada via state machine `Hysteresis`:

- Estado: `lastEffectiveTemp: Double`
- Transicao SUBIR: se `currentTemp >= lastEffectiveTemp`, aceita imediato
- Transicao DESCER: so atualiza `lastEffectiveTemp` se `currentTemp <= lastEffectiveTemp - 3.0`

A interpolacao da curva sempre usa `lastEffectiveTemp`, NAO `currentTemp` raw.

#### Scenario: Subir temp aciona imediato

- **WHEN** lastEffectiveTemp=50, currentTemp=55
- **THEN** lastEffectiveTemp atualiza para 55 imediatamente
- **AND** curva e interpolada com 55°C

#### Scenario: Descer pouco NAO aciona

- **WHEN** lastEffectiveTemp=60, currentTemp=58
- **THEN** lastEffectiveTemp permanece em 60 (nao baixou 3°C)
- **AND** curva e interpolada com 60°C
- **AND** o fan NAO desacelera ainda

#### Scenario: Descer 3°C aciona

- **WHEN** lastEffectiveTemp=60, currentTemp=57
- **THEN** lastEffectiveTemp atualiza para 57
- **AND** curva e interpolada com 57°C

### Requirement: Safety override em temp critica

O helper SHALL monitorar `cpuTemp` em todo tick. Se `cpuTemp > 95.0°C` em **3 ticks consecutivos** (4.5s), o control loop SHALL ignorar a curva ativa e escrever `F0Tg=F0Mx, F1Tg=F1Mx`. O override SHALL ser desativado quando `cpuTemp < 92.0°C` (histerese de 3°C). Enquanto override ativo, helper SHALL logar `"SAFETY: temp <X>°C exceeded threshold, forcing max RPM"` em `~/Library/Logs/FanControl/control.log`.

#### Scenario: Spike unico nao aciona override

- **WHEN** sequence de cpuTemp = `[80, 96, 75, 70]` em 4 ticks
- **THEN** override NAO aciona (so 1 tick acima de 95°)
- **AND** curva continua sendo aplicada normalmente

#### Scenario: Sustained alto aciona override

- **WHEN** sequence = `[90, 96, 97, 98, 96]` em 5 ticks
- **THEN** override aciona no tick 4 (3 consecutivos > 95°)
- **AND** F0Tg=F0Mx, F1Tg=F1Mx
- **AND** log warning aparece

#### Scenario: Override desativa quando temp baixa

- **WHEN** override ativo, sequence = `[97, 96, 93, 91]`
- **THEN** no tick 91°C, override desativa (< 92°)
- **AND** curva volta a ser aplicada

### Requirement: Persistencia de modo + curva ativa

O helper SHALL persistir em `/Library/Application Support/FanControl/control.json`:

```json
{
  "version": 1,
  "mode": "auto" | "forced" | "curve",
  "forcedTargetRPM": 4550 | null,
  "activeCurve": {
    "steps": [
      {"temp": 40, "duty": 20},
      {"temp": 60, "duty": 50},
      ...
    ]
  } | null,
  "updatedAt": "2026-05-01T23:30:00Z"
}
```

Ao reiniciar o helper, SHALL carregar o JSON e restaurar o ultimo modo. Default no primeiro boot: `mode = "auto"`, `activeCurve = null`.

#### Scenario: Helper reinicia em modo Curve

- **WHEN** helper estava em mode=curve com curva X
- **AND** helper e killed e relauncado pelo launchd
- **THEN** helper carrega `control.json`, mode=curve persiste
- **AND** control loop retoma com curva X
- **AND** fans NAO ficam parados durante o reboot do helper (~1-2s gap)

#### Scenario: Primeiro boot (control.json nao existe)

- **WHEN** helper inicia e `control.json` nao existe
- **THEN** mode = "auto" default
- **AND** helper NAO escreve em F0Md/F0Tg (deixa sistema controlar)
- **AND** cria control.json vazio com defaults

### Requirement: Re-escrita periodica de F0Md em modos Forced e Curve

Em modos Forced e Curve, o helper SHALL escrever `F0Md=1, F1Md=1` em **todo tick** do control loop, mesmo quando F0Tg nao muda. Isso e idempotente — se o sistema macOS retomar controle (zera F0Md), o proximo tick re-impoe F0Md=1.

#### Scenario: Sistema retoma controle entre ticks

- **WHEN** mode=forced e helper escreveu F0Md=1 no tick T
- **AND** sistema macOS por alguma razao zera F0Md durante T+0.5s
- **AND** helper executa tick T+1 (1.5s depois)
- **THEN** helper escreve F0Md=1 novamente
- **AND** controle de fans permanece com o helper

### Requirement: Detecao de outro app controlando os fans

Quando o helper tenta escrever `F0Md` ou `F0Tg` e recebe `kIOReturnExclusiveAccess`, SHALL:

1. Logar warning `"SMC locked — likely conflicting app (TG Pro / Macs Fan Control / iStat)"`
2. Expor flag `smcConflict: true` no proximo `getSnapshot()`
3. NAO retentar agressivamente (1 retry por tick maximo)

A UI SHALL exibir banner "Outro app esta controlando os fans. Feche-o para tomar controle." quando `smcConflict=true`.

#### Scenario: Macs Fan Control rodando junto

- **WHEN** Macs Fan Control esta aberto e em modo Custom
- **AND** o usuario clica em "Max" no nosso app
- **THEN** helper recebe `kIOReturnExclusiveAccess`
- **AND** snapshot.smcConflict = true
- **AND** UI exibe banner amarelo
- **AND** preset "Max" NAO fica visualmente selected (operacao falhou)

### Requirement: Watchdog reverte para Auto se control loop trava

O helper SHALL ter um watchdog separado que monitora `lastTickTimestamp`. Se passou `> 5.0 segundos` desde o ultimo tick (provavelmente o loop principal travou), o watchdog SHALL:

1. Logar erro `"WATCHDOG: control loop stalled, reverting to auto"`
2. Escrever `F0Md=0, F1Md=0` (devolve ao sistema)
3. Tentar reiniciar o control loop

#### Scenario: Loop trava por bug

- **WHEN** o control loop nao escreve por 6 segundos (simulado em teste)
- **THEN** watchdog dispara em ~5s
- **AND** F0Md=0 escrito
- **AND** log erro aparece

#### Scenario: Loop saudavel

- **WHEN** loop tickea normal a cada 1.5s
- **THEN** watchdog NUNCA dispara
- **AND** lastTickTimestamp e sempre <= 1.6s no passado
