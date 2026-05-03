## Context

Branch `gh-pages` atual:
```
appcast.xml         (Sparkle feed — preserve)
index.html          (placeholder mínimo do setup Sparkle — substituir)
```

Source da landing em `~/Downloads/FanControl/`:
```
site/
  index.html        (HTML shell com <div id="root">, carrega React via CDN)
  site.jsx          (588 linhas — landing page completa)
app/
  window-shell.jsx, atoms.jsx, main-mvp.jsx  (referenciados pelo index)
  curve-editor.jsx, curve-mvp.jsx, main-pulse.jsx, main-spectrum.jsx  (extras, design canvas)
screenshots/
  01-04-site-overview.png, frame-issue.png, glass-v1.png
uploads/
  Screenshot 2026-05-01 at 22.56.17.png
FanControl.html     (entry alt — provavelmente ignorável)
design-canvas.jsx, tweaks-panel.jsx (design playground — não pra produção)
```

O `site/index.html` referencia paths relativos:
```html
<script type="text/babel" src="../app/window-shell.jsx"></script>
<script type="text/babel" src="../app/atoms.jsx"></script>
<script type="text/babel" src="../app/main-mvp.jsx"></script>
<script type="text/babel" src="site.jsx"></script>
```

Esses paths assumem que `index.html` vive em `site/` (com `app/` no parent). Quando copiar pra gh-pages root, vamos achatar a estrutura — `app/` fica no mesmo nível do index.

## Goals / Non-Goals

**Goals:**
- G1. Landing page publicada em `https://jeversonmisaeldacruz.github.io/Macfancontrol/`
- G2. Preservar `appcast.xml` do Sparkle (não quebrar auto-update)
- G3. Zero build step — React in-browser via CDN
- G4. Estrutura limpa em gh-pages: `index.html`, `site.jsx`, `app/*.jsx`, `screenshots/*.png`, `appcast.xml`
- G5. Path references corretos depois do achatamento

**Non-Goals:**
- NG1. Build pipeline com Vite/esbuild (overkill pra single-page com React in-browser)
- NG2. Domínio customizado (`breezefan.com`) — out of scope, GitHub Pages default URL serve
- NG3. Pre-render / SSG — JSX transpilado no browser cliente é aceitável
- NG4. Stripe checkout funcional — `STRIPE_URL` placeholder fica como está, user configura depois
- NG5. Copiar `design-canvas.jsx`, `tweaks-panel.jsx`, `FanControl.html` — são playground, não pra produção
- NG6. Atualizar SwiftUI app pra refletir novos JSX em `app/` — escopo de change futura ("port-new-design-to-swiftui")

## Decisions

### D1. Achatar estrutura em gh-pages root

- **Escolhido**: copiar `site/index.html` pro root, e `site/site.jsx` pro root também. Copiar `app/*.jsx` pra `app/` no root, screenshots pra `screenshots/`.
- **Alternativa**: manter `site/` como subdir → URL `https://.../Macfancontrol/site/`
- **Razão**: URL canônica é mais limpa (`.../Macfancontrol/` direto), e GitHub Pages serve `index.html` na raiz por default sem config extra. Mudança nos paths relativos é trivial (`../app/` → `app/`).

### D2. Paths relativos: ajustar `index.html` durante copy

- **Escolhido**: ao copiar `site/index.html` pra `gh-pages/index.html`, fazer sed/replace de `src="../app/` → `src="app/`.
- **Alternativa**: mexer no source `~/Downloads/FanControl/site/index.html` pra usar `app/` direto (sem `../`).
- **Razão**: source vem do user, manter intocado preserva referência. Adaptação no destino é o pattern correto pra deploy.

### D3. Copiar pasta `app/` inteira (todos os 7 JSX), não só os 3 referenciados

- **Escolhido**: copiar `window-shell.jsx`, `atoms.jsx`, `main-mvp.jsx`, `curve-editor.jsx`, `curve-mvp.jsx`, `main-pulse.jsx`, `main-spectrum.jsx`.
- **Razão**: tamanho desprezível (~50KB total), e caso o `site.jsx` evolua e referencie outros (curve editor demo, pulse meter, etc), tudo está pronto. Idempotente.

### D4. Screenshots: copiar todas

- **Escolhido**: `01-site-overview.png`, `02-site-overview.png`, `03-site-overview.png`, `04-site-overview.png`, `frame-issue.png`, `glass-v1.png`
- **Razão**: o `site.jsx` provavelmente referencia algumas. Imagens são pequenas, copiar todas é safer.

### D5. Preservar `appcast.xml` durante copy

- **Escolhido**: o script de deploy faz `git checkout gh-pages`, copia novos arquivos por cima de tudo (substituindo o `index.html` mínimo), mas explicitamente NÃO toca em `appcast.xml`.
- **Validação pós-deploy**: `git log -p gh-pages -- appcast.xml` mostra zero changes nesta change.

### D6. Sem build offline; React + Babel via CDN

- **Escolhido**: continuar com `<script src="https://unpkg.com/...">` pra React 18.3 + Babel standalone. ~500KB extra na primeira carga (cacheado por unpkg).
- **Alternativa**: Vite build estático pra ~50KB JS bundle.
- **Razão**: zero build pipeline. User pode setup Vite no follow-up se virar pain. Pra single-page de marketing com tráfego limitado, CDN é OK.

### D7. Sem copiar `FanControl.html`, `design-canvas.jsx`, `tweaks-panel.jsx`

- **Escolhido**: esses são playground / entry alt. `index.html` da `site/` é o canônico.
- **Razão**: mantém gh-pages limpa.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| index.html paths quebram em produção | Validar com `curl` que `app/window-shell.jsx` retorna 200 |
| Babel standalone pesado | Aceitável pra MVP; otimizar com Vite em follow-up |
| Sparkle quebra se appcast for sobrescrito | Script de deploy explicitamente preserva (não copia por cima) |
| GitHub Pages cache stale | Esperar 30-60s, hard reload (⌘⇧R) |

## Migration Plan

1. **Stash main** se houver mudanças não-commitadas
2. **Switch para gh-pages**
3. **rm placeholder `index.html`**
4. **cp** com sed:
   - `~/Downloads/FanControl/site/index.html` → `index.html` (com `../app/` → `app/`)
   - `~/Downloads/FanControl/site/site.jsx` → `site.jsx`
   - `~/Downloads/FanControl/app/*.jsx` → `app/`
   - `~/Downloads/FanControl/screenshots/*.png` → `screenshots/`
5. **Verificar appcast.xml intacto** (`git status` não deve mostrar changes em appcast.xml)
6. **Commit + push** branch gh-pages
7. **Switch back** main, restore stash se houver
8. **Live validation** ao acessar URL no browser

### Rollback

`git revert <commit>` na branch gh-pages e force-push (ou simplesmente novo commit revertendo arquivos).
