#!/usr/bin/env bash
set -euo pipefail

# OCR em arquivo de região específico - copia apenas o TEXTO para o clipboard
# Recebe OCR_FILE (caminho do PNG) e OCR_LANG via env

OCR_FILE="${OCR_FILE:-}"
OCR_LANG="${OCR_LANG:-por+eng}"

if [[ -z "$OCR_FILE" || ! -f "$OCR_FILE" ]]; then
    notify-send "Print Toolkit" "Arquivo de região não encontrado para OCR"
    exit 1
fi

text="$(tesseract "$OCR_FILE" - -l "$OCR_LANG" 2>/dev/null || true)"

if [[ -z "$text" ]]; then
    notify-send "Print Toolkit" "OCR não encontrou texto na região selecionada"
    exit 0
fi

# Copia APENAS o texto para o clipboard (não a imagem)
printf '%s' "$text" | wl-copy

# Mostra notificação com preview do texto
preview="${text:0:200}"
notify-send "Print Toolkit — OCR" "Texto copiado para a área de transferência:\n$preview"