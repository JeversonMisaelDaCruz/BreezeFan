## Why

Hoje a branch `gh-pages` serve apenas o `appcast.xml` do Sparkle (auto-update) com um placeholder `index.html` mínimo. O usuário projetou uma **landing page completa** pra BreezeFan em `~/Downloads/FanControl/site/` (React in-browser via Babel standalone, design dark com grain texture, hero + 6 features + pricing $3 one-time, i18n PT/EN auto-detect). Ela referencia componentes JSX do app real (`window-shell.jsx`, `atoms.jsx`, `main-mvp.jsx`) e screenshots reais em `screenshots/`.

Esta change publica essa landing page em `https://jeversonmisaeldacruz.github.io/Macfancontrol/` preservando o `appcast.xml` do Sparkle.

## What Changes

- **Copiar conteúdo de `~/Downloads/FanControl/site/`** (HTML + JSX) para o root da branch `gh-pages`
- **Copiar `~/Downloads/FanControl/app/`** (window-shell.jsx, atoms.jsx, main-mvp.jsx + outros novos: curve-editor.jsx, curve-mvp.jsx, main-pulse.jsx, main-spectrum.jsx) para `gh-pages/app/`
- **Copiar `~/Downloads/FanControl/screenshots/`** (PNGs) para `gh-pages/screenshots/`
- **Ajustar referência relativa em `index.html`** (`../app/*.jsx` → `app/*.jsx` — o site original assume estrutura `site/index.html` com `app/` no parent, mas no gh-pages tudo fica plano na raiz)
- **Manter `appcast.xml`** intacto (Sparkle continua funcionando)
- **Substituir placeholder index.html** atual da branch
- Push gh-pages → GitHub Pages serve em ~30s

## Capabilities

### New Capabilities

- `landing-page`: GitHub Pages site servindo a landing page de produto (HTML + React in-browser + JSX assets) em `https://jeversonmisaeldacruz.github.io/Macfancontrol/`. Coexiste com o `appcast.xml` do Sparkle no mesmo branch.

### Modified Capabilities

- Nenhuma. `auto-update` (Sparkle) continua intacta — appcast.xml preservado.

## Impact

- **Branch `gh-pages`**: ganha ~10 arquivos novos (1 HTML + ~7 JSX + ~6 PNGs screenshots) + adapta caminhos relativos
- **Sem impacto no app code**: 0 arquivos do `App/`, `Helper/`, `Shared/` mudam
- **Sem impacto no Sparkle**: `appcast.xml` preservado
- **GitHub Pages já habilitado** (do setup Sparkle anterior); deploy automático em ~30s após push
- **URL final**: `https://jeversonmisaeldacruz.github.io/Macfancontrol/` mostra landing; `https://.../appcast.xml` continua servindo Sparkle feed
- **Sem build step**: page é static — React é via CDN (unpkg.com/react@18 + babel/standalone), JSX transpila no browser
- **Performance OK pra MVP**: babel/standalone é ~500KB extra por load, mas single-page de marketing é tolerável. Otimizar (build offline pra static JS) é follow-up.
- **Risco**: nenhum — change reversível via `git revert` na branch gh-pages
- **Validação**:
  - `curl -I` retorna 200 na URL raiz
  - Browser renderiza hero + features + pricing
  - Imagens (screenshots) carregam
  - i18n PT/EN funciona (testar com `Accept-Language` ou navegador BR)
  - `appcast.xml` ainda retorna 200 (não foi quebrado)
