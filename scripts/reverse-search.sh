#!/usr/bin/env bash
set -euo pipefail

# Sobe a captura de tela mais recente para um host anônimo e abre a
# pesquisa reversa de imagem no motor escolhido (SEARCH_ENGINE) no
# navegador padrão.
# Mesma abordagem que o antigo plugin Screen Toolkit (v4) usava com o
# uguu.se — links expiram em ~3h, não suba nada sensível de propósito.
#
# Dependências (Arch/CachyOS):
#   sudo pacman -S curl xdg-utils libnotify
#
# Diretório padrão: o Noctalia v5 salva em $HOME/Pictures quando
# [shell.screenshot].directory está vazio (default), com nome
# screenshot_%Y%m%d_%H%M%S.png (região usa sufixo -region).
# Sobrescreva com a env SCREENSHOT_DIR ou SEARCH_ENGINE se necessário.

SCREENSHOT_DIR="${SCREENSHOT_DIR:-$HOME/Pictures}"
# Normaliza um "~" literal no início (ex.: valor padrão da setting do Noctalia).
# O tilde NÃO expande dentro de variáveis, então sem isso "find \"~/Pictures\""
# falharia com "Arquivo ou diretório inexistente".
SCREENSHOT_DIR="${SCREENSHOT_DIR/#\~/$HOME}"
SCREENSHOT_DIR="${SCREENSHOT_DIR%/}"
SEARCH_ENGINE="${SEARCH_ENGINE:-google}"

latest="$(find "$SCREENSHOT_DIR" -maxdepth 1 -type f -name '*.png' -printf '%T@ %p\n' 2>/dev/null \
	| sort -rn | head -n1 | cut -d' ' -f2-)"

if [[ -z "$latest" ]]; then
	notify-send "Print Toolkit" "Nenhuma captura encontrada em $SCREENSHOT_DIR"
	exit 1
fi

response="$(curl -sf -F "files[]=@${latest}" https://uguu.se/upload)"
url="$(printf '%s' "$response" | grep -oP '"url"\s*:\s*"\K[^"]+' | head -n1 | sed 's|\\/|/|g')"

if [[ -z "$url" ]]; then
	notify-send "Print Toolkit" "Falha ao subir a imagem para pesquisa reversa"
	exit 1
fi

case "$SEARCH_ENGINE" in
	google) search_url="https://lens.google.com/uploadbyurl?url=${url}" ;;
	bing)   search_url="https://www.bing.com/images/search?view=detailv2&iss=sbiupload&FORM=INSBIB&q=imgurl:${url}" ;;
	yandex) search_url="https://yandex.com/images/search?rpt=imageview&url=${url}" ;;
	*)      search_url="https://lens.google.com/uploadbyurl?url=${url}" ;;
esac

xdg-open "$search_url"
