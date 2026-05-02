# BreezeFan 🇪🇸

<p align="center">
  <a href="../README.md">🏠 Home</a> ·
  <a href="README.pt-BR.md">🇧🇷 Português</a> ·
  <a href="README.en.md">🇺🇸 English</a>
</p>

---

Control nativo de ventiladores para **MacBook Pro 14" M1 Pro (2021, `MacBookPro18,3`)**.

Reemplazo del [Macs Fan Control de crystalidea](https://github.com/crystalidea/macs-fan-control), con 5 funciones que él no tiene: **curvas multi-punto con histéresis**, **4 presets nombrados** (Silent / Balanced / Performance / Max), **icono en la barra de menú** con popover compacto, **editor de curva protegido por clave de activación**, y UI **nativa macOS Liquid Glass** (no Qt).

> ⚠️ **Bloqueo de hardware.** Solo funciona en `MacBookPro18,3`. Otros modelos arrancan en modo solo-lectura.

## Funciones

- 📊 **Lecturas en tiempo real** de RPM, duty cycle y temperatura CPU (refresco 1Hz)
- 🎛️ **4 presets** clicables (Silent 35%, Balanced=Auto, Performance 70%, Max 100%)
- 📈 **Editor de curva** con 2-6 puntos (temp → duty), gráfico SVG con tooltips y zona de peligro
- 🌡️ **Modo Curva** con loop de control a 1.5s aplicando histéresis de 3°C
- 🛡️ **Protección térmica** fuerza ventiladores al máximo si CPU pasa 95°C por 3 ticks consecutivos
- 🎯 **Watchdog** revierte a Auto si el loop de control se cuelga más de 5s
- 📍 **Icono en barra de menú** con tooltip dinámico `<temp>°C · <RPM>`
- 🪟 **Popover compacto** al hacer clic en el icono (presets sin abrir ventana completa)
- 🔒 **Clave de activación** para desbloquear el editor de curva
- ⌨️ **Atajos de teclado**: ⌘1=Silent, ⌘2=Balanced, ⌘3=Performance, ⌘4=Max, ⌘E=editor

## Arquitectura

```
BreezeFan.app  ──── NSXPCConnection ────→  BreezeFanHelper (root LaunchDaemon)
   (sandbox)            (validado)             │
                                                ├─ SMCReader/Writer (IOKit)
                                                ├─ TemperatureReader (SMC + IOHID fallback)
                                                ├─ ControlLoop (tick 1.5s)
                                                ├─ Hysteresis (3°C bidireccional)
                                                ├─ SafetyOverride (>95°C × 3 ticks → Mx)
                                                └─ Watchdog (5s colgado → revierte a Auto)
```

## Prerrequisitos

- macOS 14 Sonoma o superior
- **Xcode 16+** (IDE completo — solo Command Line Tools no ejecuta XCTest ni `xcodebuild`)
- `xcodegen` vía Homebrew

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
brew install xcodegen
```

## Build & ejecución

```bash
cd /Users/jeversonmisael/Documents/codigos/Macfancontrol
xcodegen generate
open BreezeFan.xcodeproj
# ⌘R para compilar y ejecutar
```

## Generar instalador .dmg

Hay un script listo en `scripts/build-dmg.sh` que hace build en Release, integra el helper privilegiado, y empaqueta todo en un `.dmg` arrastrable a `/Applications`:

```bash
# Versión simple (hdiutil nativo)
./scripts/build-dmg.sh

# Versión "bonita" con fondo + iconos posicionados
brew install create-dmg
./scripts/build-dmg.sh --pretty

# Versión personalizada
./scripts/build-dmg.sh --version 0.2.0
```

Salida en `dist/BreezeFan-<version>.dmg` (~600KB).

### Cómo instalar el .dmg en otra máquina

1. Abre el `.dmg` (doble clic)
2. Arrastra **BreezeFan.app** a **Applications**
3. Abre la aplicación — el primer lanzamiento pide contraseña de administrador para instalar el helper privilegiado

### ⚠️ Aviso de Gatekeeper

El `.dmg` se genera con **firma ad-hoc** (sin Apple Developer ID). En otras máquinas, macOS bloqueará la primera apertura con un mensaje como:

> "BreezeFan no se puede abrir porque el desarrollador no se puede verificar."

**Solución**: clic derecho en la aplicación → **Abrir** → **Abrir de todas formas**. Hazlo una vez, macOS lo recuerda.

Para distribución pública sin este aviso, se necesita una cuenta Apple Developer ($99/año), firmar con `Developer ID Application` y ejecutar `notarytool`. Fuera del alcance de este proyecto.

## Desbloquear el editor de curva

El editor de curva está protegido por una clave de activación:

1. Abre la aplicación
2. En el pie de la ventana, haz clic en **🔒 Unlock fan curve**
3. Ingresa la clave de activación proporcionada
4. Tras la validación, el editor queda permanentemente desbloqueado

## Atajos de teclado

| Atajo | Acción |
|-------|--------|
| `⌘1` | Preset Silent |
| `⌘2` | Preset Balanced |
| `⌘3` | Preset Performance |
| `⌘4` | Preset Max |
| `⌘E` | Editor de curva (o unlock si está bloqueado) |
| `⌘0` | Mostrar ventana principal |
| `⌘W` | Cerrar ventana (helper sigue corriendo) |
| `⌘Q` | Salir de la aplicación |

## Desinstalación manual

```bash
sudo launchctl unload /Library/LaunchDaemons/com.breezefan.helper.plist
sudo rm /Library/LaunchDaemons/com.breezefan.helper.plist
sudo rm -rf /Library/Application\ Support/BreezeFan
sudo rm /Library/PrivilegedHelperTools/com.breezefan.helper
rm -rf ~/Library/Application\ Support/BreezeFan
trash /Applications/BreezeFan.app
```

## Créditos

- Tabla de claves SMC obtenida vía reverse engineering por [crystalidea/macs-fan-control](https://github.com/crystalidea/macs-fan-control) (LGPL).
- Patrones de sensores de temperatura Apple Silicon documentados por [exelban/stats](https://github.com/exelban/stats) (MIT).
