#!/usr/bin/env bash
set -euo pipefail

# Pesquisa reversa de imagem em arquivo de região específico
# Recebe SEARCH_FILE (caminho do PNG) e SEARCH_ENGINE via env

SEARCH_FILE="${SEARCH_FILE:-}"
SEARCH_ENGINE="${SEARCH_ENGINE:-google}"

if [[ -z "$SEARCH_FILE" || ! -f "$SEARCH_FILE" ]]; then
    notify-send "Print Toolkit" "Arquivo de região não encontrado para pesquisa"
    exit 1
fi

response="$(curl -sf -F "files[]=@${SEARCH_FILE}" https://uguu.se/upload)"
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

notify-send "Print Toolkit" "Abrindo pesquisa reversa no navegador..."
xdg-open "$search_url"