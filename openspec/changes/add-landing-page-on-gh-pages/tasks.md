# Implementation tasks — add-landing-page-on-gh-pages

## 1. Preparar deploy

- [ ] 1.1 Verificar working tree clean em main (stash se necessário)
- [ ] 1.2 Switch para branch `gh-pages`
- [ ] 1.3 Confirmar `appcast.xml` existe e tem release 0.3.0 (não tocar)

## 2. Copiar assets

- [ ] 2.1 `cp ~/Downloads/FanControl/site/site.jsx ./site.jsx`
- [ ] 2.2 Copy `~/Downloads/FanControl/site/index.html` → `./index.html` com sed `s|"../app/|"app/|g` (achata path)
- [ ] 2.3 `mkdir -p app && cp ~/Downloads/FanControl/app/*.jsx app/`
- [ ] 2.4 `mkdir -p screenshots && cp ~/Downloads/FanControl/screenshots/*.png screenshots/`
- [ ] 2.5 Validar `appcast.xml` ainda existe e não foi modificado (`git diff appcast.xml` vazio)

## 3. Verificar antes de commit

- [ ] 3.1 Inspecionar `index.html`: paths `src="app/..."` (sem `../`)
- [ ] 3.2 Listar `app/` e `screenshots/` — todos arquivos copiados
- [ ] 3.3 `git status` mostra adição limpa (sem appcast modificado)

## 4. Commit + push gh-pages

- [ ] 4.1 `git add index.html site.jsx app/ screenshots/`
- [ ] 4.2 `git commit -m "feat: deploy landing page (preserves Sparkle appcast)"`
- [ ] 4.3 `git push origin gh-pages`

## 5. Voltar pra main

- [ ] 5.1 `git switch main`
- [ ] 5.2 Pop stash se houver
- [ ] 5.3 Verificar working tree main intacto

## 6. Live validation

- [ ] 6.1 Aguardar ~30-60s pro GitHub Pages rebuildar
- [ ] 6.2 `curl -I https://jeversonmisaeldacruz.github.io/Macfancontrol/` retorna 200
- [ ] 6.3 Abrir URL no browser — landing renderiza
- [ ] 6.4 `curl -I https://jeversonmisaeldacruz.github.io/Macfancontrol/appcast.xml` ainda retorna 200 (Sparkle não quebrou)
- [ ] 6.5 Verificar imagens carregam (Network tab no DevTools)
- [ ] 6.6 Toggle linguagem pra PT (navegador BR) — texto traduz

## 7. Commit em main

- [ ] 7.1 Commit OpenSpec change directory + qualquer reference doc no main
- [ ] 7.2 Push main
