## Why

O MVP do FanControl roda no MacBookPro18,3 com helper como root, XPC conectado e modo Auto restaurado — mas o smoke test live revelou 3 bugs que impedem uso real:

1. **Temperatura da CPU varia para valores absurdos intermitentemente** — algumas das chaves SMC `Tp01..Tp0H` são decodificadas como `sp78` (signed fixed-point Intel) mas no Apple Silicon retornam `flt ` (float 32-bit). Quando a chave tem 4 bytes em vez de 2, a leitura como `sp78` produz valor lixo (~1500°C ou negativo).
2. **Ícones dos fans não giram** — a animação SwiftUI `withAnimation(.linear.repeatForever)` aplicada num `rotationEffect` só dispara uma vez no `onAppear`, e o `onChange(of:)` chamando `withAnimation` de novo enquanto outra está in-flight cancela ambas. O ícone fica imóvel mesmo com `duty > 0`.
3. **Botões Balanced/Max não têm efeito** — os logs mostram `setMode -> forced(38)` (preset Max calcula 38 RPM porque F0Mx é lido como 38), o helper escreve F0Tg=38 com sucesso mas o fan não acelera porque 38 RPM é abaixo do mínimo do hardware (F0Mn ≈ 1300). E `forced(13)` para Silent. Causa raiz: F0Mx/F0Mn lidos com formato errado pré-fix do reader (já corrigido em commit anterior, mas os defaults no `SnapshotBuilder` ficam com 1300/6500 quando read falha — e o write usa esses defaults na hora do preset, gerando target absurdo).

Esses 3 bugs são o gap entre "compila e conecta" e "funciona como o Macs Fan Control". Sem fix, o app é apenas um visualizador inerte. Os bugs foram detectados pelo usuário no live smoke testing depois do helper subir corretamente em `/Library/PrivilegedHelperTools/`.

## What Changes

- **BUG 1 (Temperature decoding)**: Adicionar suporte robusto a múltiplos formatos de chave SMC para temperaturas em Apple Silicon. Filtrar valores fora de range plausível (`-20°C..120°C`) antes de aceitar como leitura válida. Loggar warning quando uma chave esperada como `sp78` retorna `flt` (e vice-versa).
- **BUG 2 (Fan icon spin)**: Reescrever animação de rotação. Usar `TimelineView` SwiftUI ou `Date().timeIntervalSince` mapeado em ângulo, em vez de `withAnimation.repeatForever`. Trocar quando `duty` muda, sem cancelar Task existente.
- **BUG 3 (Preset write effectiveness)**: 
  - Garantir que `Preset.targetMode(f0Mx:f1Mx:)` recebe `f0Mx`/`f1Mx` reais lidos pelo helper (via XPC `getFanCeilings()` ou via snapshot expandido), nunca defaults hardcoded do app.
  - Helper recusa `setMode(.forced(rpm))` se `rpm < F0Mn || rpm > F0Mx` (clamp + log).
  - Adicionar uma chamada XPC `getFanCeilings()` que devolve `(f0Mn, f0Mx, f1Mn, f1Mx)` reais para o app calcular targets.
  - **App lado**: cachear ceilings recebidos no boot do helper e usar nos `Preset.targetMode()` em vez do hardcoded 6500.

- **Diagnóstico observável**: Helper loga em `os_log` toda leitura SMC com chave + dataType FourCC + valor decodificado nos primeiros 5 ticks após boot, pra facilitar debug em hardware diferente.

- **Sem mudança de UX**: a janela continua com mesmo layout. Bugs são consertados sob o capô.

## Capabilities

### New Capabilities

<!-- Sem capability nova. Os 3 bugs caem em capabilities existentes. -->

### Modified Capabilities

- `sensor-monitoring`: temperaturas devem ser robustas a múltiplos formatos SMC, com sanity range. Animação de fan icon proporcional ao duty deve funcionar em SwiftUI continuamente, não só no primeiro frame.
- `fan-control`: presets devem usar ceilings reais lidos do hardware, com clamp validado pelo helper. App expõe `getFanCeilings()` via XPC.

## Impact

- **Codigo**:
  - `Helper/SMC/SMCReader.swift` — `decodeDynamic` ganha sanity range para temperaturas; logs de diagnóstico nos primeiros ticks.
  - `Helper/Sensors/SnapshotBuilder.swift` — `loadFanCeilings()` valida que valores lidos são plausíveis (mn=500..3000, mx=3500..10000); se falhar, marca `ceilingsValid=false` e helper loga error.
  - `Helper/Sensors/TemperatureReader.swift` — sanity filter `cpuTemp ∈ [-20°C, 120°C]` antes de aceitar; cai em fallback se fora.
  - `Helper/HelperService.swift` + `HelperProtocol.swift` — nova call `getFanCeilings(reply:)`.
  - `Helper/Control/ModeManager.swift` — `setMode(.forced(rpm))` clampa rpm em `[f0Mn, f0Mx]`.
  - `App/XPC/HelperClient.swift` — wrapper `getFanCeilings() async throws -> FanCeilings` Codable.
  - `App/State/AppState.swift` — campo `fanCeilings: FanCeilings?` cacheado, populado no primeiro snapshot fresh.
  - `App/Views/PresetGrid.swift` — usa `appState.fanCeilings` no `targetMode()`.
  - `App/Views/FanRow.swift` — animação reescrita usando `TimelineView` ou `.angularGradient` derivado de `Date().timeIntervalSince(reference) / spinDuration`.
- **Specs deltas**: `sensor-monitoring` (temperatura sanity + animação spin) + `fan-control` (preset clamp + getFanCeilings).
- **Sem migration**: control.json schema inalterado.
- **Risco**: baixo. Bugs são localizados, fixes não tocam control loop / hysteresis / safety override.
- **Validation**: smoke test live no MacBookPro18,3 — clique em Max acelera fans até ~6500 RPM (audível); ícone gira proporcional ao duty; CPU temp fica em [-20, 120] sem jumps.
