# FanControl 🇧🇷

<p align="center">
  <a href="../README.md">🏠 Home</a> ·
  <a href="README.en.md">🇺🇸 English</a> ·
  <a href="README.es.md">🇪🇸 Español</a>
</p>

---

Controle nativo de fans para **MacBook Pro 14" M1 Pro (2021, `MacBookPro18,3`)**.

Substitui o [Macs Fan Control da crystalidea](https://github.com/crystalidea/macs-fan-control), com 5 funcionalidades que ele não tem: **curvas multi-step com histerese**, **4 presets nomeados** (Silent / Balanced / Performance / Max), **ícone de menu bar** com popover compacto, **editor de curva protegido por chave de ativação**, e UI **nativa macOS Liquid Glass** (não Qt).

> ⚠️ **Trava de hardware.** Roda apenas em `MacBookPro18,3`. Outros modelos entram em modo read-only.

## Funcionalidades

- 📊 **Leitura em tempo real** de RPM, duty cycle e temperatura CPU (atualização 1Hz)
- 🎛️ **4 presets** clicáveis (Silent 35%, Balanced=Auto, Performance 70%, Max 100%)
- 📈 **Editor de curva** com 2-6 steps (temp → duty), gráfico SVG com hover labels e zona de perigo
- 🌡️ **Modo Curve** com control loop a 1.5s aplicando histerese de 3°C
- 🛡️ **Safety override** força fans no máximo se CPU passar 95°C por 3 ticks consecutivos
- 🎯 **Watchdog** reverte para Auto se o control loop travar mais que 5s
- 📍 **Ícone de menu bar** com tooltip dinâmico `<temp>°C · <RPM>`
- 🪟 **Popover compacto** ao clicar no ícone (presets sem abrir janela completa)
- 🔒 **Chave de ativação** para liberar editor de curva
- ⌨️ **Atalhos de teclado**: ⌘1=Silent, ⌘2=Balanced, ⌘3=Performance, ⌘4=Max, ⌘E=editor

## Arquitetura

```
FanControl.app  ──── NSXPCConnection ────→  FanControlHelper (root LaunchDaemon)
   (sandbox)            (validado)             │
                                                ├─ SMCReader/Writer (IOKit)
                                                ├─ TemperatureReader (SMC + IOHID fallback)
                                                ├─ ControlLoop (tick 1.5s)
                                                ├─ Hysteresis (3°C bidirecional)
                                                ├─ SafetyOverride (>95°C × 3 ticks → Mx)
                                                └─ Watchdog (5s travada → reverte para Auto)
```

| Componente            | Path                          | O que faz                                                              |
| --------------------- | ----------------------------- | ---------------------------------------------------------------------- |
| `FanControl.app`      | `App/`                        | Janela SwiftUI 360×640 + menu bar item, sandbox, fala via XPC          |
| `FanControlHelper`    | `Helper/`                     | LaunchDaemon root, dono de SMC reads/writes + control loop + watchdog  |
| `Shared/`             | `Shared/`                     | Tipos Codable + algoritmos puros (`Curve`, `CurveInterpolator`)         |

## Pré-requisitos

- macOS 14 Sonoma ou superior
- **Xcode 16+** (full IDE — Command Line Tools sozinho não roda XCTest nem `xcodebuild`)
- `xcodegen` via Homebrew

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
brew install xcodegen
```

## Build & run

```bash
# 1. Gera Xcode project do project.yml
cd /Users/jeversonmisael/Documents/codigos/Macfancontrol
xcodegen generate

# 2. Abre no Xcode
open FanControl.xcodeproj

# 3. Build & run (⌘R) — alvo FanControl
#    Primeira execução: macOS pede senha admin para instalar o helper privilegiado.

# Ou via linha de comando:
xcodebuild -scheme FanControl -destination 'platform=macOS' build
```

## Gerar instalador .dmg

Existe um script pronto em `scripts/build-dmg.sh` que faz build em Release, embeda o helper privilegiado, e empacota tudo num `.dmg` arrastável pra `/Applications`:

```bash
# Versão simples (usa hdiutil nativo)
./scripts/build-dmg.sh

# Versão "bonita" com background + ícone posicionado
brew install create-dmg
./scripts/build-dmg.sh --pretty

# Versão customizada
./scripts/build-dmg.sh --version 0.2.0
```

Output em `dist/FanControl-<versão>.dmg` (~600KB).

### Como instalar o .dmg em outra máquina

1. Abrir o `.dmg` (duplo-clique)
2. Arrastar **FanControl.app** pra **Applications** (atalho mostrado dentro do .dmg)
3. Abrir o app — primeira execução pede senha admin pra instalar o helper privilegiado

### ⚠️ Aviso sobre Gatekeeper

O `.dmg` é gerado com **assinatura ad-hoc** (sem Apple Developer ID). Em outras máquinas, o macOS vai bloquear na primeira abertura com mensagem do tipo:

> "FanControl não pode ser aberto porque o desenvolvedor não pode ser verificado."

**Workaround**: clique direito no app → **Abrir** → **Abrir mesmo assim**. Faz isso uma vez, macOS lembra.

Pra distribuir publicamente sem esse aviso, precisa de uma conta Apple Developer ($99/ano), assinar com `Developer ID Application` e rodar `notarytool`. Out of scope deste projeto.

## Como destravar o editor de curva

O editor de curva é protegido por uma chave de ativação:

1. Abre o app
2. No rodapé da janela, clica em **🔒 Unlock fan curve**
3. Insira a chave de ativação fornecida
4. Após validação, o editor fica permanentemente liberado (persiste em `~/Library/Application Support/FanControl/state.json`)

> **Observação**: a chave fica armazenada em `state.json` como flag boolean. Para travar de novo, delete o arquivo.

## Atalhos de teclado

| Atalho | Ação |
|--------|------|
| `⌘1` | Preset Silent |
| `⌘2` | Preset Balanced |
| `⌘3` | Preset Performance |
| `⌘4` | Preset Max |
| `⌘E` | Editor de curva (ou unlock se trancado) |
| `⌘0` | Mostrar janela principal |
| `⌘W` | Fechar janela (helper continua rodando) |
| `⌘Q` | Encerrar app (helper continua) |

## Menu bar

Clique **esquerdo** no ícone da menu bar abre o popover compacto. Clique **direito** abre menu nativo:

- **Show Window** — traz a janela principal
- **Edit fan curve…** — abre o editor (ou unlock sheet se trancado)
- **Menu bar only** — toggle pra esconder o ícone do Dock
- **Open System Settings…** — abre Login Items
- **Quit FanControl** — encerra o app

## Desinstalação manual (último recurso)

```bash
sudo launchctl unload /Library/LaunchDaemons/com.fancontrol.helper.plist
sudo rm /Library/LaunchDaemons/com.fancontrol.helper.plist
sudo rm -rf /Library/Application\ Support/FanControl
sudo rm /Library/PrivilegedHelperTools/com.fancontrol.helper
rm -rf ~/Library/Application\ Support/FanControl
trash /Applications/FanControl.app
```

Depois do unload, os fans voltam para o controle do macOS Auto em ~5 segundos.

## Logs

```bash
log stream --predicate 'subsystem == "com.fancontrol.helper"' --info
# Ou no app menu → "Open logs in Console…"
```

## Créditos

- Tabela de chaves SMC reverse-engineered por [crystalidea/macs-fan-control](https://github.com/crystalidea/macs-fan-control) (LGPL).
- Padrões de sensor de temperatura Apple Silicon documentados por [exelban/stats](https://github.com/exelban/stats) (MIT).

## Status do projeto

**MVP funcional em hardware real.** Curva ativa, presets funcionam, ícone na menu bar, gate de licença operacional. Code está em `main`. Testes (XCTest) são locais (não incluídos no repositório).
