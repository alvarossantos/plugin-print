--!nonstrict
-- Print Toolkit - Capture toolbar (tecla Print), estilo iNiR Region Tools.
-- Barra horizontal compacta na base da tela com 5 ações de captura.
-- Abre com:  Print  →  noctalia msg panel-toggle alvaro/print-toolkit:capture
-- Modos: region (padrão), ocr, search, fullscreen, record

local state = {
  recording = false,      -- se gpu-screen-recorder está rodando
  active_mode = nil,      -- nil = nenhum modo ativo por padrão
  region_pending = false, -- região sendo selecionada (slurp ativo)
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

-- Retorna variant do botão baseado no modo ativo
local function button_variant(mode)
  if state.active_mode == mode then
    return "primary" -- modo ativo = primary (destaque)
  end
  if mode == "record" then
    return state.recording and "destructive" or "secondary"
  end
  return "secondary"
end

-- Retorna texto do botão (para record muda conforme estado)
local function button_text(mode)
  if mode == "record" then
    return state.recording and tr("capture.record_stop") or tr("capture.record_start")
  end
  if mode == "search" then
    return tr("capture.reverse_search")
  end
  return tr("capture." .. mode)
end

-- Retorna glyph do botão
local function button_glyph(mode)
  if mode == "record" then
    return state.recording and "square" or "video"
  end
  if mode == "region" then return "crop" end
  if mode == "ocr" then return "scan-eye" end
  if mode == "search" then return "search" end
  if mode == "fullscreen" then return "screen-share" end
  return "help"
end

local function render()
  panel.render(
    ui.row({ gap = 6, align = "center", padding = { 8, 16 } }, {
      -- Botão Tela Cheia
      ui.button({
        text = button_text("fullscreen"),
        glyph = button_glyph("fullscreen"),
        variant = button_variant("fullscreen"),
        onClick = "onFullscreen",
      }),
      -- Botão Região
      ui.button({
        text = button_text("region"),
        glyph = button_glyph("region"),
        variant = button_variant("region"),
        onClick = "onRegion",
      }),
      -- Separador
      ui.separator({ vertical = true }),
      -- Botão OCR
      ui.button({
        text = button_text("ocr"),
        glyph = button_glyph("ocr"),
        variant = button_variant("ocr"),
        onClick = "onOCR",
      }),
      -- Botão Pesquisa Imagem
      ui.button({
        text = button_text("search"),
        glyph = button_glyph("search"),
        variant = button_variant("search"),
        onClick = "onReverseSearch",
      }),
      -- Separador
      ui.separator({ vertical = true }),
      -- Botão Gravar
      ui.button({
        text = button_text("record"),
        glyph = button_glyph("record"),
        variant = button_variant("record"),
        onClick = "onToggleRecord",
      }),
    })
  )
end

-- Atualiza indicador de gravação
local function refreshRecordingState(cb)
  noctalia.processMatches(function(matched)
    state.recording = matched == true
    render()
    if cb then cb(state.recording) end
  end, "gpu-screen-recorder")
end

-- Inicia seleção de região (slurp) e chama callback com arquivo temporário
local function start_region_selection(callback)
  if state.region_pending then return end
  state.region_pending = true
  local tmpfile = "/tmp/print-toolkit-region-" .. os.time() .. ".png"
  local cmd = string.format("grim -g \"$(slurp)\" %s", shq(tmpfile))
  noctalia.runAsync(cmd, function(result)
    state.region_pending = false
    if tonumber(result.exitCode) ~= 0 then
      -- Usuário cancelou (ESC) ou erro
      callback(nil)
      return
    end
    callback(tmpfile)
  end)
end

-- ── Ciclo de vida ─────────────────────────────────────────────────────────
function onOpen(_context)
  -- active_mode = nil (nenhum modo ativo por padrão)
  render()
  refreshRecordingState()
  -- NÃO inicia seleção automática — painel fica acessível para trocar opções
  -- Seleção de região só inicia ao clicar no botão desejado
end

-- ── Ações ─────────────────────────────────────────────────────────────────

function onFullscreen()
  state.active_mode = "fullscreen"
  render()
  panel.close()
  -- Captura tela cheia, depois copia para clipboard e reabre painel
  noctalia.runAsync("sleep 0.35 && noctalia msg screenshot-fullscreen", function()
    -- Aguarda um pouco para o arquivo ser salvo, depois copia o mais recente
    noctalia.runAsync("sleep 0.5 && " .. string.format([[
      latest=$(find %s -maxdepth 1 -type f -name '*.png' -printf '%%T@ %%p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
      if [ -n "$latest" ] && [ -f "$latest" ]; then
        wl-copy --type image/png < "$latest"
      fi
    ]], shq(noctalia.expandPath(noctalia.getConfig("screenshot_dir") or "~/Pictures"))))
    -- Notificação de sucesso
    noctalia.runAsync("sleep 0.5 && " .. string.format("noctalia msg notification-show '%s' -- '%s'",
      shq(tr("notification.fullscreen.title")),
      shq(tr("notification.fullscreen.saved"))))
    -- Reabre painel
    noctalia.runAsync("sleep 0.2 && noctalia msg panel-toggle alvaro/print-toolkit:capture")
  end)
end

function onRegion()
  state.active_mode = "region"
  render()
  -- Seleção de região, depois reabre painel
  start_region_selection(function(file)
    if file then
      local dest = string.format("%s/screenshot_%s-region.png",
        shq(noctalia.expandPath(noctalia.getConfig("screenshot_dir") or "~/Pictures")),
        os.date("%Y%m%d_%H%M%S"))
      noctalia.runAsync(string.format("cp %s %s", shq(file), dest))
      -- Copia a imagem para o clipboard
      noctalia.runAsync(string.format("wl-copy --type image/png < %s", shq(file)))
      noctalia.runAsync("rm -f " .. shq(file))
      -- Notificação de sucesso
      noctalia.notify(tr("notification.region.title"), tr("notification.region.saved"))
    end
    -- Reabre painel para permitir trocar de opção
    noctalia.runAsync("sleep 0.2 && noctalia msg panel-toggle alvaro/print-toolkit:capture")
  end)
end

function onOCR()
  state.active_mode = "ocr"
  render()
  -- Seleciona região para OCR, depois reabre painel
  start_region_selection(function(file)
    if not file then return end
    local script = noctalia.pluginDir() .. "/scripts/ocr-region.sh"
    local env = string.format("OCR_FILE=%s OCR_LANG=%s",
      shq(file),
      shq(noctalia.getConfig("ocr_language") or "por+eng"))
    noctalia.runAsync(env .. " " .. script, function(r)
      noctalia.runAsync("rm -f " .. shq(file))
      -- O script já copia o texto para clipboard e notifica
      -- Reabre painel para permitir trocar de opção
      noctalia.runAsync("sleep 0.2 && noctalia msg panel-toggle alvaro/print-toolkit:capture")
    end)
  end)
end

function onReverseSearch()
  state.active_mode = "search"
  render()
  -- Seleciona região para pesquisa, depois reabre painel
  start_region_selection(function(file)
    if not file then return end
    local script = noctalia.pluginDir() .. "/scripts/search-region.sh"
    local env = string.format("SEARCH_FILE=%s SEARCH_ENGINE=%s",
      shq(file),
      shq(noctalia.getConfig("search_engine") or "google"))
    noctalia.runAsync(env .. " " .. script, function(r)
      noctalia.runAsync("rm -f " .. shq(file))
      -- Notificação de sucesso
      noctalia.notify(tr("notification.search.title"), tr("notification.search.opened"))
      -- Reabre painel para permitir trocar de opção
      noctalia.runAsync("sleep 0.2 && noctalia msg panel-toggle alvaro/print-toolkit:capture")
    end)
  end)
end

function onToggleRecord()
  state.active_mode = "record"
  render()
  local source = noctalia.getConfig("record_source") or "focused"
  local was_recording = state.recording
  panel.close()
  noctalia.runAsync(
    string.format("sleep 0.35 && noctalia msg plugin noctalia/screen_recorder:service all toggle %s", shq(source)),
    function(result)
      refreshRecordingState()
      if tonumber(result.exitCode) ~= 0 then
        noctalia.notifyError(tr("notification.record.title"), tr("notification.record.failed"))
      else
        -- Notificação baseada no estado anterior
        if was_recording then
          noctalia.notify(tr("notification.record.title"), tr("notification.record.stopped"))
        else
          noctalia.notify(tr("notification.record.title"), tr("notification.record.started"))
        end
      end
    end
  )
end

-- Dispara as ações via IPC (atalhos/scripts):
--   noctalia msg plugin alvaro/print-toolkit:capture all <screenshot-fullscreen|screenshot-region|ocr|reverse-search|record>
function onIpc(event, _payload)
  if event == "screenshot-fullscreen" then
    onFullscreen()
    return true
  elseif event == "screenshot-region" then
    onRegion()
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