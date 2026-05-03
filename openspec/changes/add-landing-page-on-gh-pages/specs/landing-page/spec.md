## ADDED Requirements

### Requirement: Landing page deployada em GitHub Pages root

A branch `gh-pages` SHALL servir uma landing page completa em `https://jeversonmisaeldacruz.github.io/Macfancontrol/`. A página SHALL renderizar:
- Hero com título "Take control of your Mac's fans" + tagline + CTA "Download for Mac" / "Unlock Pro — $3"
- 6 cards de features (Live temperature, Four built-in modes, Custom fan curves, Native and lightweight, Privacy first, Apple Silicon ready)
- Pricing: Free vs Pro $3 (one-time)
- Stats: 0 background CPU · <1MB memory · $3 pro
- i18n PT/EN auto-detect via `navigator.language`

#### Scenario: URL raiz retorna landing page

- **WHEN** `curl -I https://jeversonmisaeldacruz.github.io/Macfancontrol/`
- **THEN** retorna HTTP 200
- **AND** Content-Type é `text/html`
- **AND** body contém `<title>BreezeFan — Mac fan control</title>`

#### Scenario: Browser renderiza landing

- **WHEN** usuário abre URL raiz no Safari/Chrome
- **THEN** vê hero com título + CTAs
- **AND** após ~1s (babel/standalone transpila JSX), vê features grid + pricing
- **AND** background dark com grain noise sutil

#### Scenario: Imagens carregam

- **WHEN** browser carrega screenshots referenciados pelo `site.jsx`
- **THEN** todos os PNGs em `screenshots/` retornam 200

### Requirement: appcast.xml preservado

A branch `gh-pages` SHALL preservar `appcast.xml` na raiz, intocado durante deploy da landing. Sparkle continua resolvendo updates corretamente.

#### Scenario: appcast.xml continua acessível

- **WHEN** após deploy da landing
- **AND** `curl -I https://jeversonmisaeldacruz.github.io/Macfancontrol/appcast.xml`
- **THEN** retorna HTTP 200
- **AND** Content-Type é `application/xml` ou `text/xml`
- **AND** XML parseável com entry da última release

#### Scenario: Git history mostra appcast.xml unchanged neste commit

- **WHEN** `git log -p gh-pages -- appcast.xml` mostra histórico
- **THEN** o commit "deploy landing page" NÃO modifica appcast.xml

### Requirement: Estrutura de arquivos plana em gh-pages

A branch `gh-pages` SHALL ter a seguinte estrutura no root:
```
gh-pages/
├── index.html              (landing page entry)
├── site.jsx                (componente React principal da landing, ~588 linhas)
├── app/                    (componentes JSX reutilizados do design do app)
│   ├── window-shell.jsx
│   ├── atoms.jsx
│   ├── main-mvp.jsx
│   ├── curve-editor.jsx
│   ├── curve-mvp.jsx
│   ├── main-pulse.jsx
│   └── main-spectrum.jsx
├── screenshots/            (PNGs do app)
│   ├── 01-site-overview.png
│   ├── 02-site-overview.png
│   ├── 03-site-overview.png
│   ├── 04-site-overview.png
│   ├── frame-issue.png
│   └── glass-v1.png
└── appcast.xml             (Sparkle feed — preserve)
```

#### Scenario: Paths relativos funcionam

- **WHEN** browser carrega `index.html` e processa `<script src="app/window-shell.jsx">`
- **THEN** request retorna 200 (path `app/window-shell.jsx` existe)
- **AND** mesmo pra atoms.jsx e main-mvp.jsx

#### Scenario: Site.jsx referencia screenshots corretamente

- **WHEN** `site.jsx` faz `<img src="screenshots/01-site-overview.png">`
- **THEN** browser resolve em `https://.../Macfancontrol/screenshots/01-site-overview.png`
- **AND** retorna 200

### Requirement: index.html ajustado pra paths relativos sem `../`

Ao copiar `site/index.html` (source) pra `gh-pages/index.html` (deploy), o script de deploy SHALL substituir `src="../app/` por `src="app/`. Outros paths (CDN unpkg.com/react etc., `site.jsx` relativo) ficam inalterados.

#### Scenario: index.html no destino tem paths corretos

- **WHEN** inspeciona `gh-pages/index.html` após deploy
- **THEN** todos `<script type="text/babel" src="...">` apontam pra `app/<file>.jsx` ou `site.jsx` (sem `../`)

### Requirement: README do gh-pages aponta pra repo

O `gh-pages` SHALL manter (ou criar) um link discreto no rodapé da landing apontando pro repositório `https://github.com/JeversonMisaelDaCruz/Macfancontrol` para usuários técnicos curiosos. Este link já está provavelmente no `site.jsx` original — preservar.

#### Scenario: Footer da landing tem link pro source

- **WHEN** usuário scrolla até o final da landing
- **THEN** vê link "GitHub" ou ícone que abre `https://github.com/JeversonMisaelDaCruz/Macfancontrol`
