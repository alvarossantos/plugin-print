# Print Toolkit — plugin Noctalia v5

Junta print de região/tela cheia, OCR, pesquisa reversa por imagem e
gravação de tela em um só painel, inspirado no "Region tools" do iNiR.

## Status

**Instalado e habilitado** no sistema:

- Source: `local` (`~/.local/share/noctalia/plugins/print-toolkit/`)
- ID: `alvaro/print-toolkit` · versão `0.1.1` · `plugin_api = 9`
- Lint: **0 errors, 0 warnings**
- Widget de barra: `alvaro/print-toolkit:toolkit` (adicionado ao `center` da barra)
- Panel principal: `alvaro/print-toolkit:tools` (420×420, floating, open-near-click)
- **Toolbar de captura**: `alvaro/print-toolkit:capture` (620×68, floating, **bottom_center**)

## Funcionalidades

### Toolbar de Captura (tecla `Print` / widget da barra)
Barra horizontal compacta na base da tela com 5 ações:

| Botão | Tecla/Click | Comportamento |
|-------|-------------|---------------|
| **Tela cheia** | Click | Captura nativa fullscreen → fecha toolbar |
| **Região** | Click | Seleção interativa (slurp/grim) → reabre toolbar |
| **OCR** | Click | Seleção → OCR (tesseract) → **texto no clipboard** → reabre toolbar |
| **Pesquisa por Imagem** | Click | Seleção → upload (uguu.se) → abre Google Lens/Bing/Yandex → reabre toolbar |
| **Gravar** | Click | Toggle gravação monitor focado (screen_recorder) → fecha toolbar |

**Design:**
- Posição: **bottom_center** (base da tela)
- Nenhum modo ativo por padrão — usuário escolhe
- Botão ativo destacado com variant `primary` (tema)
- Variantes nativas do Noctalia: `primary`/`secondary`/`destructive`
- Separadores verticais entre grupos
- Segue tema ativo (Catppuccin, Dracula, etc.)

### Painel Principal (`tools`)
Painel flutuante 420×420 com as mesmas ações + configurações visuais.

### Widget da Barra
Ícone `screenshot` na barra → click abre a **toolbar de captura** (`capture`).

## Arquivos

| Arquivo | Função |
|---|---|
| `plugin.toml` | Manifesto: id, `plugin_api = 9`, deps (`tesseract`, `grim`, `slurp`, `curl`), settings (`screenshot_dir`, `ocr_language`, `search_engine`, `record_source`), `[[widget]] toolkit` + `[[panel]] tools` + `[[panel]] capture` (bottom_center) |
| `widget.luau` | Widget da barra — abre `alvaro/print-toolkit:capture` |
| `capture.luau` | Toolbar compacta (bottom_center): 5 botões, estados ativos, auto-reopen |
| `panel.luau` | Painel principal 420×420: UI declarativa completa |
| `scripts/ocr.sh` | OCR na captura mais recente + copia texto para clipboard |
| `scripts/ocr-region.sh` | OCR em arquivo de região específico (usado pela toolbar) |
| `scripts/reverse-search.sh` | Upload captura mais recente → pesquisa reversa |
| `scripts/search-region.sh` | Upload arquivo de região → pesquisa reversa (toolbar) |
| `translations/en.json`, `translations/pt-BR.json` | Traduções widget, panels, settings, notificações |

## Decisões de Implementação

- Screenshot usa comandos nativos Noctalia (`screenshot-region`, `screenshot-fullscreen`) via `noctalia.runAsync`
- Toolbar fecha antes de capturar (`panel.close()` + `sleep 0.35`): animação ~200ms
- **OCR/Pesquisa/Região mantêm toolbar**: fecham → slurp → processam → **reabrem** toolbar (0.2s)
- Tela Cheia / Gravar **fecham** toolbar permanentemente
- Gravação delega ao plugin oficial `noctalia/screen_recorder` via IPC payload `focused` (monitor focado, sem portal XDG). Configurável via setting `record_source` (`focused` | `portal`)
- Diretório capturas default = `~/Pictures` (nativo Noctalia). Sobrescritível por env `SCREENSHOT_DIR`. Painel usa `noctalia.expandPath`; scripts normalizam `~`
- Settings passadas por env aos scripts (`SCREENSHOT_DIR`, `OCR_LANG`, `SEARCH_ENGINE`)
- Panels expõem `onIpc(event, payload)` — disparo por IPC/atalhos:
  ```
  noctalia msg plugin alvaro/print-toolkit:capture all <screenshot-fullscreen|screenshot-region|ocr|reverse-search|record>
  noctalia msg plugin alvaro/print-toolkit:tools all <screenshot-region|screenshot-fullscreen|ocr|reverse-search|record>
  ```

## Glyphs (Tabler)
`crop` · `screen-share` · `scan-eye` · `search` · `square`/`video` · `close`

## Dependências (Arch/CachyOS)

```bash
sudo pacman -S tesseract tesseract-data-por tesseract-data-eng \
               grim slurp curl wl-clipboard libnotify \
               gpu-screen-recorder  # para gravação (plugin oficial screen_recorder)
```

## Keybindings (Niri)
Migração completa iNiR → Noctalia em `~/.config/niri/config.d/70-binds.kdl`:

```kdl
# Print → Toolbar captura
Print      { spawn "noctalia" "msg" "panel-toggle" "alvaro/print-toolkit:capture"; }
Ctrl+Print { screenshot-screen; }
Alt+Print  { screenshot-window; }

# Região/OCR/Pesquisa
Mod+Shift+S { spawn "noctalia" "msg" "screenshot-region"; }
Mod+Shift+X { spawn "noctalia" "msg" "plugin" "alvaro/print-toolkit:capture" "all" "ocr"; }
Mod+Shift+A { spawn "noctalia" "msg" "plugin" "alvaro/print-toolkit:capture" "all" "reverse-search"; }
Ctrl+Shift+S { spawn "noctalia" "msg" "panel-toggle" "alvaro/print-toolkit:capture"; }

# Gravação
Mod+Shift+R { spawn "noctalia" "msg" "plugin" "noctalia/screen_recorder:service" "all" "toggle" "focused"; }
```

## Teste Manual dos Scripts

```bash
chmod +x scripts/*.sh
SCREENSHOT_DIR="$HOME/Pictures" OCR_LANG="por+eng" ./scripts/ocr.sh
SCREENSHOT_DIR="$HOME/Pictures" SEARCH_ENGINE="google" ./scripts/reverse-search.sh
```

## Instalação / Reinstalação

```bash
DEST="$HOME/.local/share/noctalia/plugins/print-toolkit"
mkdir -p "$DEST"
cp -r plugin.toml widget.luau capture.luau panel.luau scripts translations "$DEST"
chmod +x "$DEST"/scripts/*.sh
noctalia msg plugins disable alvaro/print-toolkit
noctalia msg plugins enable alvaro/print-toolkit
# ou
noctalia msg config-reload
```

## Estrutura do Repositório

```
print-toolkit/
├── plugin.toml
├── widget.luau
├── capture.luau      # Toolbar (bottom_center)
├── panel.luau        # Painel principal
├── scripts/
│   ├── ocr.sh
│   ├── ocr-region.sh
│   ├── reverse-search.sh
│   └── search-region.sh
├── translations/
│   ├── en.json
│   └── pt-BR.json
└── README.md
```

## Licença
MIT