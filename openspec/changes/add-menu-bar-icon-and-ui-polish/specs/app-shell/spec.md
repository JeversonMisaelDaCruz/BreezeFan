## ADDED Requirements

### Requirement: Design tokens para spacing centralizados

O app SHALL definir tokens de spacing em `App/Theme/Spacing.swift`:
- `FCSpacing.xs = 4`
- `FCSpacing.sm = 8`
- `FCSpacing.md = 12`
- `FCSpacing.lg = 16`
- `FCSpacing.xl = 24`

Todos os `padding`, `spacing` (HStack/VStack), e gaps internos de section SHALL usar esses tokens — eliminando magic numbers (12, 14, 18, etc) espalhados pelas views.

#### Scenario: Section interna com tokens

- **WHEN** FCSection renderiza com title + content
- **THEN** `padding(.horizontal, FCSpacing.lg)` no container
- **AND** `padding(.top, FCSpacing.md)`
- **AND** `padding(.bottom, FCSpacing.sm)`
- **AND** spacing entre title e content = `FCSpacing.sm`

#### Scenario: Inconsistências resolvidas

- **WHEN** code review futuro ler qualquer view do app
- **THEN** nenhum literal `padding(.horizontal, 18)` ou similar deve aparecer
- **AND** todos referem `FCSpacing.<token>`

### Requirement: Design tokens para animações centralizados

O app SHALL definir em `App/Theme/Animations.swift`:
- `FCAnimation.fast: Animation = .easeOut(duration: 0.15)`
- `FCAnimation.normal: Animation = .easeOut(duration: 0.26)`
- `FCAnimation.slow: Animation = .easeOut(duration: 0.4)`
- `FCAnimation.bouncy: Animation = .spring(response: 0.26, dampingFraction: 0.85)`

Todas as animações de hover, transition, mode change SHALL usar esses tokens em vez de literais.

#### Scenario: Hover state usa fast token

- **WHEN** usuário paira mouse sobre PresetButton
- **THEN** background lift acontece com `FCAnimation.fast` (~150ms)

#### Scenario: Curve editor sheet abre com bouncy

- **WHEN** usuário clica "Edit fan curve →"
- **THEN** sheet desliza com `FCAnimation.bouncy`

### Requirement: Hover state visual em todos os botões interativos

Cada button interativo (PresetButton, "Edit fan curve" footer, popover items, header buttons) SHALL ter um hover state visual sutil:
- Background lift: `Color.white.opacity(0.05)` adicionado no hover
- Cursor automatic .pointingHand (default macOS button behavior)
- Animação com `FCAnimation.fast`

Botões disabled NÃO mostram hover state.

#### Scenario: Hover em PresetButton inativo

- **WHEN** usuário paira mouse sobre "Performance" (não selected)
- **THEN** background muda de `white@3%` para `white@5%` em ~150ms
- **AND** cursor mostra .pointingHand

#### Scenario: Hover em PresetButton ativo

- **WHEN** usuário paira mouse sobre "Silent" (currently selected)
- **THEN** background NÃO muda significativamente (já é `accent@15%`)
- **AND** cursor mostra .pointingHand

#### Scenario: Hover em botão disabled

- **WHEN** PresetButton está disabled (helper offline)
- **AND** usuário paira mouse sobre ele
- **THEN** background NÃO muda
- **AND** cursor mostra .arrow padrão

### Requirement: Transição suave ao mudar modo ativo

Quando o `activePreset` muda (após click de preset), a transição visual SHALL durar `FCAnimation.normal` (~260ms) com easing — não ser um swap instantâneo de bordas.

#### Scenario: Transição de Auto para Performance

- **WHEN** usuário clica em Performance vindo de Balanced (auto)
- **THEN** o border do Performance acende em accent ao longo de ~260ms
- **AND** simultaneamente o border de Balanced perde o accent (decai)

### Requirement: Banner de erro/loading com slide-in

Quando o banner "Helper offline" ou "Aguardando dados do helper…" aparece, SHALL fazer slide-in vertical (de cima pra baixo) com `FCAnimation.normal`. Quando some, SHALL fazer slide-out reverso.

#### Scenario: Banner aparece quando helper desconecta

- **WHEN** helper crash, snapshot fail
- **THEN** banner amarelo "Helper offline" desliza de cima pra baixo em ~260ms
- **AND** ocupa espaço acima do header sem empurrar conteúdo bruscamente (animado)

#### Scenario: Banner some quando helper reconecta

- **WHEN** helper reconecta, snapshot OK
- **THEN** banner desliza de volta pra cima em ~260ms

### Requirement: Snapshot updates com fade transition curto

Mudanças de valores numéricos no snapshot (cpuTemp, leftRPM, rightRPM) SHALL ser renderizadas com `.transition(.opacity)` + `.animation(.easeOut(duration: 0.1))`. Evita "flash" de números mudando bruscamente quando snapshot pula.

#### Scenario: Temp muda de 50°C para 51°C

- **WHEN** snapshot atualiza cpuTemp de 50 para 51
- **THEN** o "50" fade out e "51" fade in em ~100ms (não swap instantâneo)

#### Scenario: RPM muda discretamente

- **WHEN** leftRPM vai de 4280 para 4290
- **THEN** transição com fade curto similar

## MODIFIED Requirements

### Requirement: Layout vertical com sections, dividers, header e footer

O app SHALL organizar o conteudo da main view em blocos verticais com componentes reutilizaveis: `FCSection(title:padding:action:)` para cada bloco, `FCDivider` para separacao (linha `0.5pt` em `rgba(255,255,255,0.06)`), header de janela `40pt` com title centralizado, footer com link "Edit fan curve" colado no bottom. Estrutura compativel com `FanControl/app/main-mvp.jsx`.

**Espaçamentos padronizados via FCSpacing tokens** (não mais magic numbers):
- Header height = `FCSpacing.xl + FCSpacing.lg` (40pt = 24+16)
- Section horizontal padding = `FCSpacing.lg` (16pt — antes era 18)
- Section vertical padding (top) = `FCSpacing.md` (12pt)
- Section vertical padding (bottom) = `FCSpacing.sm` (8pt — antes era 10)
- Spacing entre title e first child = `FCSpacing.sm` (8pt)

#### Scenario: Renderizacao da main view

- **WHEN** a main view renderiza
- **THEN** ela mostra na ordem vertical: header (40pt) -> temp readout -> divider -> Fans section -> divider -> Mode section -> espaco flexivel -> footer Edit fan curve
- **AND** cada section tem o titulo em uppercase com letter-spacing 1.4

#### Scenario: Action button em section header

- **WHEN** uma section recebe `action` (ex: botao "+ Add" no curve editor)
- **THEN** o botao aparece a direita do titulo, alinhado verticalmente

#### Scenario: Espaçamento consistente entre todas as sections

- **WHEN** code inspection lê qualquer FCSection ou padding em MainView
- **THEN** valores são `FCSpacing.<token>`, sem magic numbers
- **AND** mudar `FCSpacing.lg` propaga uniformemente

### Requirement: Footer "Edit fan curve" com hover state

O footer com botão "Edit fan curve →" SHALL ter:
- Background base `Color.white.opacity(0.02)`
- No hover: `Color.white.opacity(0.05)` com `FCAnimation.fast`
- Border top sutil `FCDivider`
- Padding vertical `FCSpacing.md`
- Texto em `FCFont.body` `FCTheme.textGhost`
- No hover: texto em `FCTheme.textMuted` (mais legível)
- Cursor `.pointingHand`

#### Scenario: Hover no footer

- **WHEN** usuário paira mouse sobre "Edit fan curve →"
- **THEN** background fica mais claro
- **AND** texto fica mais legível
- **AND** cursor é .pointingHand

#### Scenario: Click no footer

- **WHEN** usuário clica
- **THEN** sheet do curve editor abre (sem mudança no comportamento)
