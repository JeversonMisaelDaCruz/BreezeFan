## ADDED Requirements

### Requirement: Helper instalado via SMAppService.daemon

O app SHALL instalar o helper privilegiado via `SMAppService.daemon(plistName: "com.fancontrol.helper.plist").register()`. O `.plist` do helper SHALL viver em `Contents/Library/LaunchDaemons/com.fancontrol.helper.plist` dentro do app bundle (NAO em `/Library/LaunchDaemons/` — SMAppService gerencia copia automaticamente). O helper SHALL ser invocado pelo `launchd` em `/Library/LaunchDaemons/com.fancontrol.helper.plist` (caminho final apos register).

#### Scenario: Primeira instalacao

- **WHEN** o usuario abre o app pela primeira vez
- **AND** o helper ainda nao esta instalado
- **THEN** o app chama `SMAppService.daemon.register()`
- **AND** o macOS exibe dialog de aprovacao admin (pedindo senha do usuario)
- **AND** apos aprovacao, helper aparece em `launchctl list | grep fancontrol`

#### Scenario: App ja com helper instalado

- **WHEN** o usuario abre o app pela segunda vez (helper ja instalado)
- **THEN** o app NAO chama register de novo (verifica `SMAppService.daemon.status == .enabled` antes)
- **AND** o XPC `ping` confirma que helper esta vivo em <500ms

#### Scenario: Recusa da aprovacao admin

- **WHEN** o usuario clica "Cancelar" no dialog de admin do macOS
- **THEN** `register()` retorna `SMAppService.Status.notFound`
- **AND** UI exibe banner "Helper precisa ser instalado para controlar fans" com botao "Tentar novamente"

### Requirement: Comunicacao app <-> helper via NSXPCConnection com protocol typed

O sistema SHALL usar `NSXPCConnection` com um `HelperProtocol` Swift compartilhado entre app e helper. Todos os tipos passados via XPC SHALL ser `Codable`. Calls publicos do `HelperProtocol`:

```swift
@objc protocol HelperProtocol {
    func ping(reply: @escaping (Date) -> Void)
    func getSnapshot(reply: @escaping (SensorSnapshot) -> Void)
    func setMode(_ mode: ControlMode, reply: @escaping (Result<Void, HelperError>) -> Void)
    func setCurve(_ curve: Curve, reply: @escaping (Result<Void, HelperError>) -> Void)
    func applyPreset(_ preset: Preset, reply: @escaping (Result<Void, HelperError>) -> Void)
    func uninstall(reply: @escaping (Result<Void, HelperError>) -> Void)
}
```

Versao Swift moderna pode usar async/await wrapping desse protocolo Objective-C. Sem string dispatch, sem path forwarding — so enums + structs Codable.

#### Scenario: Ping bem-sucedido

- **WHEN** app conecta XPC e chama `ping()`
- **THEN** helper responde com `Date()` em < 50ms
- **AND** app pode prosseguir com outras chamadas

#### Scenario: Helper crashed durante chamada

- **WHEN** app chama `setMode(.curve)` mas helper crashou
- **THEN** XPC connection invalidates
- **AND** app exibe "Helper offline" e tenta `register` novamente
- **AND** helper restartado pelo launchd em <2s

#### Scenario: Mensagem com payload invalido

- **WHEN** app envia `setMode` com enum desconhecido (corrupcao bizarra)
- **THEN** Codable falha em decodificar
- **AND** helper retorna `Result.failure(.invalidPayload)`
- **AND** nao executa nenhuma escrita SMC

### Requirement: Validacao do caller via code signing

O helper SHALL validar todo caller XPC antes de aceitar a conexao. Validacao SHALL extrair `audit_token` do `NSXPCConnection`, derivar `SecCode` via `SecCodeCopyGuestWithAttributes`, e verificar:

1. Code signing valido (`SecCodeCheckValidity`)
2. Team identifier ou bundle ID matching o esperado (no MVP: bundle ID = `com.fancontrol.app`)

Conexoes que falharem validacao SHALL ser invalidadas imediatamente.

#### Scenario: App legitimo conecta

- **WHEN** `FanControl.app` (com bundle ID `com.fancontrol.app` e signing valido) conecta XPC
- **THEN** helper aceita a conexao
- **AND** chamadas subsequentes funcionam

#### Scenario: Outro processo tenta conectar

- **WHEN** um processo arbitrario (`/usr/bin/curl` ou outro app) tenta conectar XPC ao helper
- **THEN** helper invalida a conexao em `shouldAcceptNewConnection`
- **AND** nenhuma chamada e processada
- **AND** helper loga warning `"Rejected XPC connection from <pid>: invalid bundle ID"`

#### Scenario: App com signing invalido

- **WHEN** o app foi modificado pos-signing (binario alterado)
- **AND** tenta conectar XPC
- **THEN** `SecCodeCheckValidity` retorna erro
- **AND** helper rejeita a conexao

### Requirement: Helper roda como root e persiste entre logouts

O helper SHALL ter `RunAtLoad=true` e `KeepAlive=true` no `.plist`, garantindo que o launchd reinicia o helper se ele crashar. O helper SHALL ser executado como `root` (`UserName` nao especificado — default LaunchDaemon). A presenca persiste entre logouts e reboots ate ser explicitly desinstalado via `SMAppService.daemon.unregister()`.

#### Scenario: Reboot do Mac

- **WHEN** o usuario faz reboot do Mac
- **AND** loga novamente
- **THEN** o helper ja esta rodando antes mesmo do app abrir
- **AND** modo Curve (se estava ativo) continua aplicando a curva imediatamente

#### Scenario: Helper crash

- **WHEN** o helper crashou por bug
- **THEN** launchd restarta em <2s
- **AND** helper carrega `control.json` e restaura ultimo modo

### Requirement: Watchdog interno do helper

O helper SHALL rodar um watchdog separado da thread do control loop. O watchdog SHALL verificar a cada `2.0s` se o `lastTickTimestamp` do control loop foi atualizado nos ultimos `5.0s`. Se nao, watchdog SHALL:

1. Logar erro `"WATCHDOG: control loop stalled for >5s, recovering"`
2. Escrever `F0Md=0, F1Md=0` para devolver controle ao macOS
3. Cancelar a Task atual do control loop e iniciar uma nova

#### Scenario: Loop saudavel

- **WHEN** control loop tickea normal a cada 1.5s
- **THEN** watchdog NUNCA dispara
- **AND** lastTickTimestamp e sempre <= 1.6s no passado

#### Scenario: Loop trava

- **WHEN** control loop trava por bug em SMCWriter (ex: deadlock numa lock)
- **AND** passa 6 segundos sem tick
- **THEN** watchdog detecta no proximo check (em <2s apos os 5s)
- **AND** F0Md=0 escrito (sistema retoma controle)
- **AND** novo control loop iniciado

### Requirement: Reverter para Auto ao desinstalar

Antes de desinstalar via `SMAppService.daemon.unregister()`, o helper SHALL escrever `F0Md=0, F1Md=0`, parar o control loop, e remover `control.json`. Apos `unregister()`, o launchd para o processo e remove o `.plist` de `/Library/LaunchDaemons/`.

#### Scenario: Uninstall via menu

- **WHEN** o usuario seleciona "Uninstall helper" no menu da app
- **AND** confirma o dialog
- **THEN** app envia XPC `uninstall()` ao helper
- **AND** helper: (1) escreve F0Md=0, (2) para control loop, (3) deleta control.json, (4) responde `Result.success`
- **AND** app: (5) chama `SMAppService.daemon.unregister()`, (6) recebe success
- **AND** fans voltam ao Auto do macOS em <2s

#### Scenario: Uninstall com helper offline

- **WHEN** helper esta offline (crash) e usuario clica Uninstall
- **THEN** app pula a chamada XPC (ou timeout 1s)
- **AND** prossegue para `SMAppService.daemon.unregister()`
- **AND** macOS limpa o helper morto

### Requirement: Fallback manual de uninstall via CLI

Para casos onde a UI nao funciona, o usuario SHALL poder desinstalar manualmente via:

```bash
sudo launchctl unload /Library/LaunchDaemons/com.fancontrol.helper.plist
sudo rm /Library/LaunchDaemons/com.fancontrol.helper.plist
sudo rm -rf /Library/Application\ Support/FanControl
rm -rf ~/Library/Application\ Support/FanControl
```

Esses comandos SHALL ser documentados em `README.md` do projeto.

#### Scenario: Uninstall manual

- **WHEN** usuario executa os 4 comandos do bloco acima
- **THEN** helper para imediatamente
- **AND** F0Md retorna a 0 no proximo tick do scheduler de fans (~5s)
- **AND** sem residuos no filesystem

### Requirement: Logs em `~/Library/Logs/FanControl/`

O helper SHALL escrever logs em `~/Library/Logs/FanControl/control.log` (rotacionado a 10MB, mantendo 3 arquivos historicos). Niveis: `info`, `warn`, `error`. Toda escrita SMC, troca de modo, e erro de IO SHALL ser logado.

Note: como helper roda como root, `~/Library/Logs/` aponta para `/var/root/Library/Logs/`. Para o usuario ver logs de forma conveniente, adicionar comando "Open logs in Console" no menu da app que abre `/var/log/FanControl/control.log` (symlink) ou usa `os_log` para integracao com Console.app.

#### Scenario: Log de troca de modo

- **WHEN** helper recebe `setMode(.curve)`
- **THEN** log entry: `"INFO 2026-05-01T23:45:00Z mode=auto -> curve, curve=4 steps"`

#### Scenario: Log de safety override

- **WHEN** safety override aciona em 96°C
- **THEN** log entry: `"WARN 2026-05-01T23:46:30Z SAFETY: cpuTemp=96.2°C, forcing F0Tg=F0Mx=6500"`

### Requirement: Hardware lock — degradar gracefully em modelos diferentes

No boot, o helper SHALL ler `IOPlatformExpertDevice` -> `model` e verificar se e exatamente `MacBookPro18,3`. Se nao, helper SHALL:

1. Logar `"WARN: Unsupported model <X>, entering read-only mode"`
2. Aceitar XPC `getSnapshot()` (read funciona em qualquer Mac com SMC/IOHID)
3. Rejeitar `setMode`/`setCurve`/`applyPreset` com `HelperError.unsupportedModel`

App SHALL exibir banner "Modelo nao suportado nesta versao (suporte: MacBook Pro 14" M1 Pro)" no topo da janela.

#### Scenario: Roda em MacBookPro18,3

- **WHEN** helper detecta `MacBookPro18,3`
- **THEN** modo full ativo (read + write)
- **AND** UI sem banner de modelo

#### Scenario: Roda em outro modelo

- **WHEN** helper detecta `MacBookPro18,1` (16" M1 Pro)
- **THEN** modo read-only ativo
- **AND** UI exibe banner de modelo nao suportado
- **AND** clicar em presets retorna erro
