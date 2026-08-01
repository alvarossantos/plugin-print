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

## Instalação

### Método 1: Instalação Local (atual)
O plugin está disponível como fonte local. Para instalar:

```bash
DEST="$HOME/.local/share/noctalia/plugins/print-toolkit"
mkdir -p "$DEST"
cp -r plugin.toml widget.luau capture.luau panel.luau scripts translations "$DEST"
chmod +x "$DEST"/scripts/*.sh
noctalia msg plugins disable alvaro/print-toolkit
noctalia msg plugins enable alvaro/print-toolkit
# ou simplesmente
noctalia msg config-reload
```

### Método 2: Via Noctalia (futuro)
Quando publicado no repositório comunitário do Noctalia, será instalável diretamente pela interface:
1. Abra **Configurações do Noctalia** → **Plugins** → **Comunidade**
2. Busque por **"Print Toolkit"** (autor: `alvaro`)
3. Clique em **Instalar** → **Habilitar**

## Como Usar

Após instalar e habilitar o plugin, existem **duas formas** de acessar a toolbar de captura:

### 1. Tecla `Print` (recomendado)
Pressione a tecla **Print** no teclado → abre a toolbar na base da tela.

> Requer o keybinding configurado no Niri (veja seção Keybindings abaixo).

### 2. Widget na Barra (ícone)
Clique no ícone **📸 (screenshot)** na barra do Noctalia → abre a mesma toolbar.

> O widget é adicionado automaticamente ao habilitar o plugin. Se não aparecer, adicione manualmente em **Configurações → Barras → Widgets → Print Toolkit**.

### ⚠️ Importante: Parar Gravação
Para poder **parar a gravação** pela barra, você tem duas opções:

1. **Widget do Print Toolkit (recomendado)**: O plugin adiciona um widget **record-status** que mostra um ícone vermelho ● quando gravando, com o tempo decorrido no tooltip. Clique nele para parar.
   - **Precisa adicionar na barra**: Configurações → Barras → Widgets → **Print Toolkit Record Status**.
   - Mostra ícone vermelho ● quando gravando, tooltip com tempo (ex: "Gravando há 01:23").

2. **Plugin oficial `screen_recorder`**: Mantenha o widget do plugin `noctalia/screen_recorder` na barra.
   - Em **Configurações → Barras → Widgets**, adicione **Screen Recorder**.
   - Mostra tempo de gravação e botão de parar.

> **Dica:** O botão "Gravar" na toolbar **fecha a toolbar** ao iniciar. Para parar, use um dos widgets acima (o botão da toolbar não reaparece enquanto grava).

---

## Keybindings (Niri)

A migração completa iNiR → Noctalia para `~/.config/niri/config.d/70-binds.kdl`:

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

> **Nota:** O bind da tecla `Print` é essencial para usar o método 1. Adicione ao seu `70-binds.kdl` ou `90-user-extra.kdl`.

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
│   ├── search-region.sh
│   └── record-widget.luau   # Widget status gravação (ícone + tempo)
├── translations/
│   ├── en.json
│   └── pt-BR.json
└── README.md
```

## Licença
MIT