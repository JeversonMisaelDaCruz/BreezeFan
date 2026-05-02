## Why

O usuario tem um MacBook Pro 14" M1 Pro (`MacBookPro18,3`, 2 fans) e hoje depende do **Macs Fan Control da crystalidea** para controlar a velocidade dos fans, mas o app entrega apenas o basico: clique em **Max** (RPM maximo constante) ou **Min** (RPM minimo constante), modo **Auto** (sistema decide), ou um modo "sensor-based" linear simples. Nao ha **curva multi-step**, nao ha **presets nomeados**, nao ha **historico de comportamento**, e a UI Qt cross-platform destoa visualmente do macOS Tahoe / Liquid Glass que o resto do sistema usa. O design ja foi todo modelado em React/JSX (em `FanControl/`) com janela 360x640 dark + traffic lights proprios + glow do accent + leitura grande de temp + lista de fans com RPM/duty + 4 presets + editor de curva. O proposito desta change e **construir esse app nativo do zero em Swift/SwiftUI**, alvo unico **MacBook Pro 14" M1 Pro (2021, MacBookPro18,3)**, entregando em uma so investida o MVP funcional que substitui o Macs Fan Control para o uso do dia a dia.

## What Changes

- Novo projeto Xcode `FanControl.xcodeproj` na raiz de `/Users/jeversonmisael/Documents/codigos/Macfancontrol/`, com 2 targets: `FanControl.app` (UI sandbox) e `FanControlHelper` (daemon privilegiado).
- Janela principal **360x640** sem titlebar nativa, com traffic lights desenhados, background graphite com glow do accent, e fonte SF Pro — fidelidade visual ao design em `FanControl/app/window-shell.jsx` + `main-mvp.jsx` + `curve-mvp.jsx`.
- **Leitura de sensores** em tempo real (refresh ~1s): RPM real dos 2 fans (`F0Ac`/`F1Ac`), duty calculado em % de `F0Mx`, temperatura dos clusters CPU performance (`Tp01`, `Tp05`, `Tp09`) com fallback para o maior valor.
- **Controle de fans** com 3 modos:
  - **Auto** — `F0Md=0` / `F1Md=0`, sistema decide (paridade com Macs Fan Control)
  - **Forced constant** — `F0Md=1`, `F0Tg=<rpm fixo>` (Min, Max, ou Custom RPM)
  - **Curve** — control loop le temp a cada ~1.5s, interpola na curva ativa, escreve `F0Tg`/`F1Tg` resultante; aplica histerese de 3°C para evitar oscilacao
- **4 presets do MVP** mapeando para configuracoes pre-definidas: `Silent` (target = 35% de max constante), `Balanced` (= Auto), `Performance` (target = 70% de max constante), `Max` (target = `F0Mx`/`F1Mx`).
- **Editor de curva** multi-step (2 a 6 pontos: 40°/20%, 60°/50%, 75°/80%, 90°/100% como default), graph SVG, tabela de steps com NumStepper +/-, salvar/cancelar — UI fielmente portada do `curve-mvp.jsx`.
- **Helper privilegiado** instalado via `SMAppService` (API moderna, deprecou `SMJobBless`); comunica com o app via **XPC** (NSXPCConnection com protocol type-safe). Helper roda como root em `~/Library/LaunchDaemons/com.fancontrol.helper.plist`, mantem o control loop, e re-escreve `F0Md=1` periodicamente para garantir que o sistema nao retome controle.
- **Persistencia local** da curva ativa, preset selecionado e accent color em `~/Library/Application Support/FanControl/state.json` (UI app), com mirror das configs criticas em `/Library/Application Support/FanControl/control.json` (helper, lido quando o daemon inicia).
- **Code signing ad-hoc** para dev local — usuario aprova o helper na primeira instalacao via dialog do macOS. Notarization e Apple Developer ID ($99/ano) ficam **fora do escopo do MVP** (entram quando/se for distribuir).
- **Fora do escopo do MVP** (entram em changes futuras): historico/grafico de temp e RPM ao longo do tempo, presets nomeados pelo usuario com persistencia (alem dos 4 default), app binding (`NSWorkspace` observer trocando curva quando Final Cut/DaVinci abrem), bateria override, hardware diferente do `MacBookPro18,3`, build universal Intel+ARM, Mac App Store distribution.

## Capabilities

### New Capabilities

- `app-shell`: janela custom 360x640 sem titlebar nativa, traffic lights desenhados, layout principal (header, sections, divider, footer), design tokens (cores, fontes SF Pro, accents), navegacao para o curve editor como sheet modal animado, tema dark com glow do accent. Tudo o que e UI chrome compartilhada — incluindo a montagem do `FCWindow` portado do `window-shell.jsx`.
- `sensor-monitoring`: leitura periodica e exibicao em tempo real de RPM por fan, duty calculado, temperatura representativa (max dos clusters CPU performance) e estado dos fans (ativo/parado). Inclui o pipeline de IPC (helper le SMC/IOHID -> envia snapshot via XPC -> UI renderiza).
- `fan-control`: controle dos fans via SMC com 3 modos (Auto, Forced constant, Curve), 4 presets MVP (Silent/Balanced/Performance/Max), control loop que tickeia ~1.5s aplicando a curva ativa com histerese 3°C, persistencia da configuracao escolhida, e re-escrita periodica de `F0Md=1` para manter o controle.
- `curve-editor`: editor modal de curva temperatura -> duty com 2 a 6 steps, grafico SVG renderizado em SwiftUI Canvas, tabela de steps com NumStepper (+/- buttons clamp em min/max), botoes Cancel/Save, animacao de entrada (`fc-sheet-in`), validacao (steps ordenados por temp, sem duplicatas).
- `privileged-helper`: daemon privilegiado instalado via `SMAppService.daemon`, XPC protocol bidirecional com app sandbox, calls publicas (`getSnapshot`, `setMode`, `setCurve`, `applyPreset`), control loop e watchdog rodando como root, leitura/escrita de SMC keys (F0/F1 family), leitura de IOHID sensors quando SMC nao expoe, mecanismo de instalacao on-first-launch + dialog de aprovacao Gatekeeper.

### Modified Capabilities

<!-- Nenhuma — projeto novo, sem specs existentes para modificar. -->

## Impact

- **Codigo**: cria projeto Xcode novo (`FanControl.xcodeproj`) com ~6 grupos (`App/`, `App/Window/`, `App/Views/`, `App/Views/CurveEditor/`, `App/State/`, `App/XPC/`), helper em `Helper/` (`SMC/`, `Sensors/`, `Control/`, `XPC/`), e protocolos compartilhados em `Shared/`. Mantem `FanControl/` (JSX existente) como referencia de design.
- **Dependencias** (todas Apple, sem terceiros no MVP): `SwiftUI`, `AppKit`, `IOKit`, `IOKit.hid`, `ServiceManagement` (SMAppService), `Foundation` (XPC). Nenhum SPM/CocoaPods.
- **APIs / Frameworks privados**: `IOServiceOpen` em `AppleSMC` e `IOHIDEventSystemClient` (Apple Silicon). Sao APIs publicas-mas-pouco-documentadas; as keys SMC para fan vem do reverse engineering do `crystalidea/macs-fan-control` (LGPL — compativel com reuso da tabela de keys).
- **Permissoes root**: helper precisa rodar como root para escrever no SMC. Instalacao via `SMAppService.daemon.register()` dispara prompt de admin do macOS; usuario aprova uma vez. Helper instalado em `/Library/LaunchDaemons/com.fancontrol.helper.plist`.
- **Hardware lock**: MVP roda **somente em `MacBookPro18,3`**. Se rodado em outro modelo, app exibe banner "Modelo nao suportado nesta versao" e desabilita controle (mantem leitura quando possivel).
- **SIP / Gatekeeper**: nao requer SIP off, nao requer kext. Code signing ad-hoc para dev; usuario clica "Open Anyway" em System Settings -> Privacy & Security na primeira execucao.
- **Risco de termico**: control loop pode definir target RPM baixo demais sob carga — implementa **safety override** que ignora curva e seta target = max se qualquer temperatura cluster CPU passar de **95°C** por mais de 3 ticks consecutivos. Documentado em `design.md`.
- **Reversibilidade**: ao desinstalar o helper (via menu da app ou comando manual `sudo launchctl unload /Library/LaunchDaemons/com.fancontrol.helper.plist && sudo rm /Library/LaunchDaemons/com.fancontrol.helper.plist`), os fans voltam imediatamente ao controle do macOS — `F0Md` sem ninguem reescrevendo retorna a `0` no proximo ciclo do sistema.
