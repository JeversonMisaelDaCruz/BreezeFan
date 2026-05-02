## ADDED Requirements

### Requirement: Editor de curva como modal sheet animado

A UI SHALL apresentar o editor de curva como modal sheet que ocupa toda a janela (`inset 0`) com background `rgba(8,9,11,0.85) + backdrop-filter blur(20px) saturate(150%)`. O sheet SHALL ser disparado pelo botao "Edit fan curve" no footer da main view e fechado por "Cancel" ou "Save". Implementacao SwiftUI usa `.sheet` ou `ZStack + transition(.move(edge:.bottom))`, fielmente equivalente a `FanControl/app/curve-mvp.jsx`.

#### Scenario: Abrir o editor

- **WHEN** o usuario clica "Edit fan curve" no footer da main view
- **THEN** o sheet aparece com animacao bottom-up em ~260ms
- **AND** o backdrop blur aplicado atras do sheet
- **AND** os steps default sao carregados (ou os do `state.json` se ja editou antes)

#### Scenario: Cancel descarta mudancas

- **WHEN** o usuario clica "Cancel" apos editar steps
- **THEN** sheet fecha sem persistir mudancas
- **AND** `state.json` NAO e atualizado
- **AND** ao reabrir o sheet, steps voltam ao ultimo valor salvo

#### Scenario: Save persiste e ativa modo Curve

- **WHEN** o usuario clica "Save" apos editar steps
- **THEN** sheet fecha
- **AND** `state.json` e atualizado com a nova curva
- **AND** helper recebe XPC `setCurve(steps)`
- **AND** helper troca mode para `"curve"` se ainda nao estava

### Requirement: Steps de curva entre 2 e 6 pontos

A curva SHALL ter no minimo `2` steps e no maximo `6` steps. Cada step SHALL ter `temp: Int` em `[20, 105]` (°C) e `duty: Int` em `[0, 100]` (%). Steps SHALL ser ordenados por `temp` ascendente. Defaults na primeira abertura: `[(40, 20), (60, 50), (75, 80), (90, 100)]`.

#### Scenario: Adicionar step quando ha menos de 6

- **WHEN** ha 4 steps e o usuario clica "+ Add"
- **THEN** um novo step aparece com `temp = lastTemp + 5, duty = lastDuty + 5` (clamp em 105/100)

#### Scenario: Tentar adicionar 7o step

- **WHEN** ha 6 steps e o usuario tenta clicar "+ Add"
- **THEN** o botao "+ Add" esta disabled visualmente (opacidade 0.25, cursor default)
- **AND** o clique nao adiciona nada

#### Scenario: Remover step quando ha 3 ou mais

- **WHEN** ha 4 steps e o usuario clica "X" no segundo step
- **THEN** o step e removido da lista
- **AND** restam 3 steps

#### Scenario: Tentar remover quando ha 2 steps

- **WHEN** ha 2 steps e o usuario tenta clicar "X"
- **THEN** o botao "X" esta disabled
- **AND** o clique nao remove

### Requirement: NumStepper para edicao de temp e duty

Cada step SHALL ser editado via componente `NumStepper` com botao `-` a esquerda, valor central, botao `+` a direita. Step de incremento: `temp` = 1°, `duty` = 5%. Min/max: `temp ∈ [20, 105]`, `duty ∈ [0, 100]`. Botoes `-`/`+` clampam no extremo. Componente fielmente portado de `curve-mvp.jsx`.

#### Scenario: Incrementar temp

- **WHEN** step.temp = 60 e o usuario clica `+`
- **THEN** step.temp = 61

#### Scenario: Decrementar temp no minimo

- **WHEN** step.temp = 20 e o usuario clica `-`
- **THEN** step.temp permanece 20 (clamp)

#### Scenario: Incrementar duty acima de 100%

- **WHEN** step.duty = 100 e o usuario clica `+`
- **THEN** step.duty permanece 100 (clamp)

#### Scenario: Decrementar duty em 5%

- **WHEN** step.duty = 50 e o usuario clica `-`
- **THEN** step.duty = 45

### Requirement: Graph SVG/Canvas com area gradient e pontos hoverable

A UI SHALL renderizar um grafico de `320x140` (escalavel via SwiftUI Canvas) com:

- Eixo X: temp `[20, 105]` (°C)
- Eixo Y: duty `[0, 100]` (%)
- Gridlines horizontais em duty `0, 25, 50, 75, 100` (linhas tracejadas `2 3` em `rgba(255,255,255,0.05)`)
- Gridlines verticais em temp `30, 50, 70, 90`
- Eixo Y labels em font 8pt mono em `rgba(255,255,255,0.35)` a esquerda
- Eixo X labels em font 8pt mono na base
- **Danger zone**: retangulo de `xFor(85)` ate o fim em `rgba(239,68,68,0.06)`
- **Linha da curva**: stroke 1.8pt em `accent` com `drop-shadow(0 0 4px accent88)`
- **Area gradient**: preenchimento abaixo da linha em `linearGradient(accent@35% -> accent@0%)` vertical
- **Pontos**: circulos de raio 3pt (4pt em hover) em `#0f1013` com border accent 1.5pt
- **Hover label**: badge accent flutuante mostrando `"<temp>° / <duty>%"` em mono branco 8pt

Renderizado fielmente conforme `CurveGraph` em `FanControl/app/curve-editor.jsx` (referencia mais detalhada que o `curve-mvp.jsx`).

#### Scenario: Renderizar curva default

- **WHEN** o sheet abre com steps `[(40,20), (60,50), (75,80), (90,100)]`
- **THEN** o graph mostra 4 pontos conectados por linha accent
- **AND** a area abaixo tem gradient accent
- **AND** danger zone (>= 85°) aparece avermelhada no canto direito

#### Scenario: Hover em um ponto

- **WHEN** o cursor passa sobre o ponto (60°, 50%)
- **THEN** o ponto aumenta de raio 3pt para 4pt
- **AND** uma badge `"60° / 50%"` aparece flutuando acima

#### Scenario: Atualizacao live ao editar step

- **WHEN** o usuario muda step[1].duty de 50 para 65 via NumStepper
- **THEN** o graph re-renderiza com a curva atualizada em <100ms
- **AND** o segundo ponto e a linha que o conecta movem para cima

### Requirement: Validacao de curva antes de salvar

Antes de chamar `setCurve(steps)` no helper, a UI SHALL validar:

1. `2 <= steps.count <= 6`
2. Cada step com `temp ∈ [20, 105]` e `duty ∈ [0, 100]`
3. Steps ordenados por temp ascendente
4. Sem duplicatas de temp (`Set(steps.map { $0.temp }).count == steps.count`)

Se validacao falhar, botao "Save" SHALL ficar disabled e UI SHALL mostrar mensagem de erro abaixo do graph.

#### Scenario: Curva valida

- **WHEN** steps = `[(40,20), (60,50), (75,80), (90,100)]`
- **THEN** validate() retorna sucesso
- **AND** botao Save esta enabled

#### Scenario: Steps com temps duplicados

- **WHEN** o usuario edita steps[1].temp = 40 (igual a steps[0].temp = 40)
- **THEN** validate() retorna erro `.duplicateTemp`
- **AND** botao Save fica disabled
- **AND** UI mostra "Cannot have two steps at the same temperature"

#### Scenario: Steps fora de ordem

- **WHEN** steps = `[(40,20), (90,100), (60,50)]` (segundo > terceiro)
- **THEN** validate() retorna erro `.unordered`
- **AND** botao Save disabled
- **AND** UI mostra "Steps must be in ascending temperature order"

#### Scenario: Auto-sort opcional ao salvar

- **WHEN** steps estao desordenados mas o usuario explicitamente pediu auto-sort (futuro setting)
- **THEN** UI ordena steps por temp ascendente antes de salvar
- **NOT IN MVP**: este auto-sort fica fora — MVP apenas valida e bloqueia Save

### Requirement: Persistencia da curva editada em state.json

Ao salvar, a UI SHALL escrever a curva atual em `~/Library/Application Support/FanControl/state.json` no campo `curve.steps`. Ao reabrir o sheet, a UI SHALL carregar `curve.steps` desse arquivo. Se o arquivo nao existe ou nao tem `curve`, usar defaults `[(40,20), (60,50), (75,80), (90,100)]`.

#### Scenario: Curva persiste apos reload do app

- **WHEN** usuario salva curva `[(45,30), (70,80), (90,100)]`
- **AND** fecha e reabre o app
- **AND** abre o curve editor
- **THEN** os 3 steps salvos aparecem (nao os defaults)

#### Scenario: First open (state.json sem curve)

- **WHEN** usuario abre o curve editor pela primeira vez
- **THEN** os defaults `[(40,20), (60,50), (75,80), (90,100)]` carregam
- **AND** salvar essa curva sem mudar nada cria o campo `curve` em state.json

### Requirement: Header do sheet com Cancel/title/Save

O sheet SHALL ter no topo um header de `~44pt` com:

- Botao **Cancel** a esquerda em `rgba(255,255,255,0.06)` background, label `"Cancel"` 11pt
- Title centralizado: `"Fan Curve"` em font 12pt fontWeight 600, cor `rgba(255,255,255,0.92)`
- Botao **Save** a direita em `accent@18%` background, border `accent@35%`, color accent, label `"Save"` 11pt fontWeight 600

#### Scenario: Layout do header

- **WHEN** o sheet abre
- **THEN** Cancel aparece a esquerda, title `"Fan Curve"` centralizado, Save a direita
- **AND** Save tem cor do accent (default azul)
