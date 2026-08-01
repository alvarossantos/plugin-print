> **STATUS: CONCLUÍDO (2026-08-01).** Todas as APIs foram confirmadas e o
> plugin está **instalado e habilitado** no sistema:
> `~/.local/share/noctalia/plugins/print-toolkit/` (id `alvaro/print-toolkit`,
> lint 0 errors, widget `toolkit` na barra, panel `tools` funcional via
> `noctalia msg panel-toggle alvaro/print-toolkit:tools`). Este documento é o
> histórico do pedido original — veja o `README.md` para o estado atual.
>
> **v0.1.1 — correções (2026-08-01):** painel não aparecia no screenshot
> (espera de 0.35s após `panel.close()` para a animação de 200ms terminar);
> OCR/pesquisa quebravam com `SCREENSHOT_DIR="~/Pictures"` (expansão de tilde
> agora via `noctalia.expandPath` no painel + normalização `${VAR/#\~/$HOME}`
> nos scripts); gravação abria o portal XDG (agora usa payload `focused` no
> IPC do `screen_recorder`, nova setting `record_source`). Todas verificadas
> ao vivo (screenshot sem painel via OCR, OCR no cliphist, gsr `-w HDMI-A-1`
> sem portal). Adicionado `onIpc` no painel para disparar ações por IPC/atalho.

Você vai me ajudar a finalizar um plugin para o Noctalia v5 (shell de desktop
nativo em C++/Wayland, https://github.com/noctalia-dev/noctalia). Tenho um
rascunho funcional em partes, mas algumas chamadas de API não foram
confirmadas contra a documentação atual porque o sistema de plugins está em
beta e a API muda. Preciso que você:

1. Busque e leia estas páginas antes de mexer em qualquer código:
   - https://docs.noctalia.dev/v5/plugins/development/manifest/
   - https://docs.noctalia.dev/v5/plugins/development/entries/
   - https://docs.noctalia.dev/v5/plugins/development/declarative-ui/
   - https://docs.noctalia.dev/v5/plugins/development/runtime-api/
   - https://docs.noctalia.dev/v5/plugins/development/plugin-api/
   - https://docs.noctalia.dev/v5/plugins/development/workflow/
   - Código-fonte real de um plugin oficial completo como referência de
     "código que de fato roda":
     https://github.com/noctalia-dev/official-plugins/tree/main/screen_recorder
     e também o plugin "example" no mesmo repo (usa widget + service +
     shortcut + launcher provider + panel, é o mais completo como exemplo).
   - https://docs.noctalia.dev/v5/bar/widgets/screenshot/ (comportamento e
     comandos do screenshot nativo que eu quero acionar, não reimplementar)
   - https://docs.noctalia.dev/v5/plugins/official-plugins/ (para confirmar
     o alvo IPC exato do plugin oficial screen_recorder)

2. Contexto do que estou construindo — um plugin chamado "Print Toolkit"
   que junta em um só painel, como um "Region Tools" ao estilo do shell
   iNiR (https://github.com/snowarch/iNiR), estas 5 ações:
   - Print de região da tela (aciona o comando nativo do Noctalia, não
     reimplementa captura)
   - Print de tela cheia (idem)
   - OCR na captura mais recente (script bash próprio, já pronto, chama
     `tesseract`)
   - Pesquisa reversa por imagem (script bash próprio, já pronto, sobe a
     imagem pro uguu.se e abre o Google Lens)
   - Iniciar/parar gravação de tela (aciona o plugin oficial
     `noctalia/screen_recorder` via IPC, não reimplementa gravação)

3. Estrutura atual do plugin (vou colar os arquivos abaixo — ou você pode
   pedir pra eu colar cada um se preferir revisar por partes):
   - `plugin.toml` — manifesto com um `[[widget]]` (ícone da barra) e um
     `[[panel]]` (o painel com os 5 botões). Marcado com TODO porque não
     confirmei se `[[panel]]` é mesmo a seção certa no manifesto.
   - `widget.luau` — usa `barWidget.setGlyph`, `noctalia.notify`,
     `update()`/`onClick()`, que são API confirmada (veio do exemplo
     mínimo oficial da doc). O `onClick()` só tem um TODO: a chamada certa
     pra abrir o painel do próprio plugin a partir do Luau.
   - `panel.luau` — RASCUNHO NÃO CONFIRMADO. Usa `ui.button(...)` e uma
     função inventada `noctalia.exec(...)` como placeholder pra "rodar
     comando externo e ler variável pluginDir" — os nomes reais dessas
     coisas (como declarar botões de verdade, como disparar um processo
     externo, como pegar o diretório do plugin) precisam ser corrigidos
     com base na doc real.
   - `scripts/ocr.sh` e `scripts/reverse-search.sh` — bash puro,
     independente do framework, já testável fora do Noctalia. Só ajuste se
     encontrar bug real.

4. O que eu quero que você entregue:
   - `plugin.toml`, `widget.luau` e `panel.luau` corrigidos e funcionais,
     usando os nomes reais de função/seção confirmados na doc (cite de
     onde tirou cada API que usar).
   - Se a forma de declarar um painel com múltiplos botões for diferente
     do que assumi (por exemplo, se painéis nascem de dentro do próprio
     widget via `panel.*`, e não como uma seção separada no manifesto),
     me explique a diferença antes de reescrever.
   - Instruções de instalação local pra testar: onde colocar a pasta
     (`~/.local/share/noctalia/plugins/print-toolkit/` ou o caminho
     correto conforme a doc de Workflow), como habilitar em
     Settings → Plugins, e como testar cada ação isoladamente via
     `noctalia msg plugin ...` pelo terminal antes de confiar no clique
     do botão.
   - Se algo que eu pedi não for possível hoje na API v5 beta (por
     exemplo, se plugin não conseguir de fato rodar processo externo
     arbitrário), me diga isso claramente em vez de forçar um workaround
     frágil.

5. Ambiente: Arch Linux (CachyOS), compositor Niri, Noctalia v5 instalado
   via AUR. Dependências que já assumi disponíveis: tesseract, curl,
   wl-clipboard, xdg-utils, libnotify.

Comece lendo as páginas da doc e o código do plugin `screen_recorder`
antes de tocar nos arquivos.
