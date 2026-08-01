#!/usr/bin/env bash
set -euo pipefail

# Roda OCR na captura de tela mais recente do Noctalia e copia o texto
# extraído para a área de transferência.
#
# Dependências (Arch/CachyOS):
#   sudo pacman -S tesseract tesseract-data-por tesseract-data-eng wl-clipboard libnotify
#
# Diretório padrão: o Noctalia v5 salva em $HOME/Pictures quando
# [shell.screenshot].directory está vazio (default), com nome
# screenshot_%Y%m%d_%H%M%S.png (região usa sufixo -region).
# Sobrescreva com a env SCREENSHOT_DIR ou OCR_LANG se necessário.

SCREENSHOT_DIR="${SCREENSHOT_DIR:-$HOME/Pictures}"
# Normaliza um "~" literal no início (ex.: valor padrão da setting do Noctalia).
# O tilde NÃO expande dentro de variáveis, então sem isso "find \"~/Pictures\""
# falharia com "Arquivo ou diretório inexistente".
SCREENSHOT_DIR="${SCREENSHOT_DIR/#\~/$HOME}"
SCREENSHOT_DIR="${SCREENSHOT_DIR%/}"
OCR_LANG="${OCR_LANG:-por+eng}"

latest="$(find "$SCREENSHOT_DIR" -maxdepth 1 -type f -name '*.png' -printf '%T@ %p\n' 2>/dev/null \
	| sort -rn | head -n1 | cut -d' ' -f2-)"

if [[ -z "$latest" ]]; then
	notify-send "Print Toolkit" "Nenhuma captura encontrada em $SCREENSHOT_DIR"
	exit 1
fi

text="$(tesseract "$latest" - -l "$OCR_LANG" 2>/dev/null || true)"

if [[ -z "$text" ]]; then
	notify-send "Print Toolkit" "OCR não encontrou texto na imagem"
	exit 0
fi

printf '%s' "$text" | wl-copy
notify-send "Print Toolkit" "Texto copiado para a área de transferência"
