## ADDED Requirements

### Requirement: Janela principal de tamanho fixo 360x640 sem titlebar nativa

O app SHALL apresentar uma unica janela principal com largura `360pt` e altura `640pt`, **sem** a titlebar padrao do macOS, **sem** redimensionamento, e com `windowStyle(.hiddenTitleBar)` aplicado. A janela MUST ter cantos arredondados de `18pt` e sombra grande (`0 24px 60px rgba(0,0,0,0.55)`) compativel com o `FCWindow` definido em `FanControl/app/window-shell.jsx`.

#### Scenario: Abertura inicial da janela

- **WHEN** o usuario abre o app pela primeira vez
- **THEN** uma janela de exatamente `360x640` aparece centrada na tela primaria
- **AND** a janela nao mostra a barra de titulo padrao do macOS
- **AND** os 3 traffic lights desenhados aparecem no canto superior esquerdo

#### Scenario: Tentativa de redimensionamento

- **WHEN** o usuario tenta redimensionar a janela arrastando uma borda
- **THEN** a janela NAO redimensiona (mantem 360x640)

#### Scenario: Restauracao apos minimizar

- **WHEN** o usuario minimiza a janela e depois clica no Dock
- **THEN** a janela reaparece com as mesmas dimensoes 360x640
- **AND** mantem o estado anterior (preset selecionado, curva carregada)

### Requirement: Traffic lights desenhados (mock) com cores Tahoe

O app SHALL desenhar tres circulos `12pt` em vermelho `#ff5f57`, amarelo `#febc2e` e verde `#28c840` no canto superior esquerdo, replicando o `FCTrafficLights` do JSX. Estes lights MUST nao ter funcionalidade nativa — clicar nao fecha/minimiza/maximiza a janela. O fechar/minimizar e tratado pelo gesto de janela do SwiftUI ou pelo menu da app.

#### Scenario: Cliques nos traffic lights mock

- **WHEN** o usuario clica em qualquer um dos 3 traffic lights desenhados
- **THEN** nada acontece (sao decorativos)

#### Scenario: Cores e tamanhos exatos

- **WHEN** a janela renderiza
- **THEN** os 3 dots aparecem com `width=12, height=12, borderRadius=50%`
- **AND** as cores sao exatamente `#ff5f57`, `#febc2e`, `#28c840`
- **AND** ha um gap de `8pt` entre eles

### Requirement: Background graphite com glow do accent color

O app SHALL renderizar o background da janela com gradient duplo: `radial-gradient(120% 60% at 50% -10%, accent@18% 0%, transparent 55%)` sobre `linear-gradient(180deg, #1a1c20 0%, #0f1013 100%)`, replicando exatamente o `FCWindow` JSX. O glow do accent MUST atualizar em tempo real quando o accent muda (via setting), sem rebuild.

#### Scenario: Background com accent default (#3b82f6)

- **WHEN** o app abre com accent default
- **THEN** o topo da janela tem um glow azul `#3b82f6` com 18% de opacidade

#### Scenario: Troca de accent color

- **WHEN** o usuario muda o accent para `#a855f7` (roxo) via setting
- **THEN** o glow do topo da janela troca imediatamente para roxo
- **AND** o gradient base graphite permanece igual

### Requirement: Layout vertical com sections, dividers, header e footer

O app SHALL organizar o conteudo da main view em blocos verticais com componentes reutilizaveis: `FCSection(title:padding:action:)` para cada bloco, `FCDivider` para separacao (linha `0.5pt` em `rgba(255,255,255,0.06)`), header de janela `40pt` com title centralizado, footer com link "Edit fan curve" colado no bottom. Estrutura compativel com `FanControl/app/main-mvp.jsx`.

#### Scenario: Renderizacao da main view

- **WHEN** a main view renderiza
- **THEN** ela mostra na ordem vertical: header (40pt) -> temp readout -> divider -> Fans section -> divider -> Mode section -> espaco flexivel -> footer Edit fan curve
- **AND** cada section tem o titulo em uppercase com letter-spacing 1.4

#### Scenario: Action button em section header

- **WHEN** uma section recebe `action` (ex: botao "+ Add" no curve editor)
- **THEN** o botao aparece a direita do titulo, alinhado verticalmente

### Requirement: Sheet modal para curve editor com animacao bottom-up

O app SHALL apresentar o curve editor como sheet modal que cobre `inset 0` da janela com background `rgba(8,9,11,0.85)` + `backdrop-filter: blur(20px) saturate(150%)`. A entrada SHALL animar de `translateY(20px) opacity(0)` para `translateY(0) opacity(1)` em `260ms` com curva `cubic-bezier(.2,.8,.3,1)`. A saida (cancelar/salvar) reverte a animacao.

#### Scenario: Abertura do curve editor

- **WHEN** o usuario clica em "Edit fan curve" no footer
- **THEN** o sheet desliza de baixo pra cima em ~260ms
- **AND** o background atras fica blurred

#### Scenario: Fechamento via Cancel

- **WHEN** o usuario clica em "Cancel" no sheet
- **THEN** o sheet desliza para baixo e desaparece em ~260ms
- **AND** mudancas nao salvas SAO descartadas

#### Scenario: Fechamento via Save

- **WHEN** o usuario clica em "Save" no sheet
- **THEN** o sheet fecha com mesma animacao
- **AND** a curva editada e persistida em `state.json`

### Requirement: Persistencia de UI state (accent, tempUnit)

O app SHALL persistir o accent color (default `#3b82f6`) e a unidade de temperatura (`C` ou `F`, default `C`) em `~/Library/Application Support/FanControl/state.json`. Ao reabrir o app, esses valores SHALL ser restaurados antes da primeira renderizacao da janela.

#### Scenario: Mudanca de tempUnit persiste

- **WHEN** o usuario troca tempUnit para `F` via setting
- **AND** fecha o app
- **AND** reabre o app
- **THEN** o tempUnit ainda esta em `F`
- **AND** a UI exibe temperaturas convertidas (ex: 67°C -> 152.6°F)

#### Scenario: Conversao Celsius -> Fahrenheit

- **WHEN** tempUnit esta em `F`
- **AND** SMC retorna 67°C
- **THEN** o app exibe `153°F` (arredondado para inteiro)

### Requirement: Tipografia SF Pro com tabular-nums em todos os numeros

O app SHALL usar `-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro"` como font-family default. Todos os numericos exibidos (RPM, temp, duty, step values) SHALL usar `font-variant-numeric: tabular-nums` para alinhamento vertical em colunas.

#### Scenario: RPM com 4 e 5 digitos alinham verticalmente

- **WHEN** Left Fan = 4280 RPM e Right Fan = 5810 RPM aparecem na lista
- **THEN** os digitos alinham verticalmente (cada coluna ocupa mesma largura)

### Requirement: Acessibilidade basica

O app SHALL fornecer `accessibilityLabel` em todos os botoes interativos (presets, edit curve, cancel, save, traffic lights mock como decorativos). Acessibilidade plena (VoiceOver, Dynamic Type) e cobertura WCAG ficam fora do escopo MVP.

#### Scenario: Botoes de preset com label

- **WHEN** o usuario navega via VoiceOver
- **THEN** cada preset (Silent/Balanced/Performance/Max) anuncia o nome correto
- **AND** o estado ativo e anunciado ("Performance, selected")
