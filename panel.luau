--!nonstrict
-- Print Toolkit - Panel para Noctalia v5
-- UI declarativa real confirmada em:
--   docs.noctalia.dev/v5/plugins/development/declarative-ui/   (panel.render, ui.*)
--   docs.noctalia.dev/v5/plugins/development/entries/          (onOpen/onClose/onClick)
--   docs.noctalia.dev/v5/plugins/development/runtime-api/      (noctalia.runAsync,
--     noctalia.pluginDir, noctalia.processMatches, noctalia.notify/notifyError)
-- Padrão idêntico ao panel do plugin "audio-switcher"
-- (materializado em ~/.local/state/noctalia/plugins/materialized/community/).

local state = {
  recording = false,   -- se gpu-screen-recorder está rodando (plugin oficial)
}

local function tr(key, subst)
  return noctalia.tr(key, subst)
end

-- Escapa um valor para uso em aspas simples no shell (à prova de aspas).
local function shq(v)
  if v:find("'") then
    v = v:gsub("'", "'\\''")
  end
  return "'" .. v .. "'"
end

local function render()
  panel.render(ui.column({ gap = 12, padding = 16 }, {
    -- Cabeçalho
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = tr("panel.title"), fontSize = 16, fontWeight = "bold", color = "primary", flexGrow = 1 }),
      ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", tooltip = tr("panel.close"), onClick = "onCloseClicked" }),
    }),
    ui.separator({}),
    ui.label({ text = tr("panel.subtitle"), fontSize = 11, color = "on_surface_variant", maxLines = 2 }),
    ui.separator({}),

    -- Ações de captura
    ui.button({ text = tr("panel.screenshot_region"), glyph = "crop", variant = "primary", width = "fill", onClick = "onScreenshotRegion" }),
    ui.button({ text = tr("panel.screenshot_fullscreen"), glyph = "screen-share", variant = "secondary", width = "fill", onClick = "onScreenshotFullscreen" }),

    -- OCR e pesquisa reversa
    ui.button({ text = tr("panel.ocr"), glyph = "scan-eye", variant = "secondary", width = "fill", onClick = "onOCR" }),
    ui.button({ text = tr("panel.reverse_search"), glyph = "search", variant = "secondary", width = "fill", onClick = "onReverseSearch" }),

    ui.separator({}),

    -- Gravação (delega ao plugin oficial noctalia/screen_recorder via IPC)
    ui.button({
      text = state.recording and tr("panel.record_stop") or tr("panel.record_start"),
      glyph = state.recording and "square" or "video",
      variant = state.recording and "destructive" or "outline",
      width = "fill",
      onClick = "onToggleRecord",
    }),
    ui.label({
      text = tr("panel.record_hint"),
      fontSize = 10,
      color = "on_surface_variant",
      maxLines = 2,
    }),
  }))
end

-- Atualiza o indicador de gravação consultando o processo real
local function refreshRecordingState(cb)
  noctalia.processMatches(function(matched)
    state.recording = matched == true
    render()
    if cb then cb(state.recording) end
  end, "gpu-screen-recorder")
end

-- ── Ciclo de vida do painel ───────────────────────────────────────────────
function onOpen(_context)
  render()
  refreshRecordingState()
end

-- Botão "X" do cabeçalho: fecha o painel via requestClose (mesmo padrão do
-- audio-switcher). Não definimos um global onClose() — o host o invoca por
-- conta própria após o fechamento.
function onCloseClicked()
  panel.close()
end

-- ── Ações ─────────────────────────────────────────────────────────────────
function onScreenshotRegion()
  panel.close()
  -- A animação de fechamento do painel no Noctalia v5 leva ~200ms; o
  -- screenshot disparado imediatamente capturava o painel ainda na tela.
  -- Aguarda o painel desmapear antes de capturar.
  noctalia.runAsync("sleep 0.35 && noctalia msg screenshot-region")
end

function onScreenshotFullscreen()
  panel.close()
  -- Mesma espera: evita capturar o painel durante a animação de fechamento.
  noctalia.runAsync("sleep 0.35 && noctalia msg screenshot-fullscreen")
end

function onOCR()
  panel.close()
  local script = noctalia.pluginDir() .. "/scripts/ocr.sh"
  -- noctalia.expandPath resolve o "~" — sem isso os scripts recebiam
  -- SCREENSHOT_DIR='~/Pictures' e o find falhava ("arquivo inexistente"),
  -- porque o tilde não expande dentro de variável no shell.
  local env = string.format("SCREENSHOT_DIR=%s OCR_LANG=%s",
    shq(noctalia.expandPath(noctalia.getConfig("screenshot_dir") or "~/Pictures")),
    shq(noctalia.getConfig("ocr_language") or "por+eng"))
  noctalia.runAsync(env .. " " .. script, function(result)
    if tonumber(result.exitCode) ~= 0 then
      noctalia.notifyError(tr("notification.ocr.title"), tr("notification.ocr.failed"))
    end
  end)
end

function onReverseSearch()
  panel.close()
  local script = noctalia.pluginDir() .. "/scripts/reverse-search.sh"
  local env = string.format("SCREENSHOT_DIR=%s SEARCH_ENGINE=%s",
    shq(noctalia.expandPath(noctalia.getConfig("screenshot_dir") or "~/Pictures")),
    shq(noctalia.getConfig("search_engine") or "google"))
  noctalia.runAsync(env .. " " .. script, function(result)
    if tonumber(result.exitCode) ~= 0 then
      noctalia.notifyError(tr("notification.search.title"), tr("notification.search.failed"))
    end
  end)
end

function onToggleRecord()
  -- O serviço oficial do screen_recorder expõe onIpc "toggle" (confirmado em
  -- ~/.local/state/noctalia/plugins/materialized/official/screen_recorder/).
  -- O payload "focused" grava o monitor focado direto, SEM abrir o seletor do
  -- XDG Desktop Portal (o default video_source="portal" abria a janelinha de
  -- "compartilhar tela"). O painel é fechado antes para não aparecer na
  -- gravação do monitor focado.
  local source = noctalia.getConfig("record_source") or "focused"
  panel.close()
  noctalia.runAsync(
    string.format("sleep 0.35 && noctalia msg plugin noctalia/screen_recorder:service all toggle %s", shq(source)),
    function(result)
      refreshRecordingState()
      if tonumber(result.exitCode) ~= 0 then
        noctalia.notifyError(tr("notification.record.title"), tr("notification.record.failed"))
      end
    end
  )
end

-- Permite disparar as ações via IPC (testes, atalhos):
--   noctalia msg plugin alvaro/print-toolkit:tools all screenshot-fullscreen
function onIpc(event, _payload)
  if event == "screenshot-region" then
    onScreenshotRegion()
    return true
  elseif event == "screenshot-fullscreen" then
    onScreenshotFullscreen()
    return true
  elseif event == "ocr" then
    onOCR()
    return true
  elseif event == "reverse-search" then
    onReverseSearch()
    return true
  elseif event == "record" then
    onToggleRecord()
    return true
  end
  return false
end

render()
