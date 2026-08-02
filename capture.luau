--!nonstrict
-- Print Toolkit - Capture toolbar (tecla Print)
-- Barra horizontal compacta na base da tela com 5 ações de captura.

local state = {
  recording = false,
  region_pending = false,
}

local function shq(v)
  if v:find("'") then
    v = v:gsub("'", "'\\''")
  end
  return "'" .. v .. "'"
end

local function button_variant(mode)
  if mode == "record" then
    return state.recording and "destructive" or "secondary"
  end
  return "secondary"
end

local function button_text(mode)
  if mode == "record" then
    return state.recording and "Parar" or "Gravar"
  end
  if mode == "fullscreen" then return "Tela cheia" end
  if mode == "region" then return "Regiao" end
  if mode == "ocr" then return "OCR" end
  if mode == "search" then return "Pesquisa" end
  return mode
end

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
    ui.column({ flexGrow = 1, align = "center", justify = "center" }, {
      ui.row({ gap = 4, align = "center" }, {
        ui.button({
          text = button_text("fullscreen"),
          glyph = button_glyph("fullscreen"),
          variant = button_variant("fullscreen"),
          controlSize = "sm",
          onClick = "onFullscreen",
        }),
        ui.button({
          text = button_text("region"),
          glyph = button_glyph("region"),
          variant = button_variant("region"),
          controlSize = "sm",
          onClick = "onRegion",
        }),
        ui.button({
          text = button_text("ocr"),
          glyph = button_glyph("ocr"),
          variant = button_variant("ocr"),
          controlSize = "sm",
          onClick = "onOCR",
        }),
        ui.button({
          text = button_text("search"),
          glyph = button_glyph("search"),
          variant = button_variant("search"),
          controlSize = "sm",
          onClick = "onReverseSearch",
        }),
        ui.button({
          text = button_text("record"),
          glyph = button_glyph("record"),
          variant = button_variant("record"),
          controlSize = "sm",
          onClick = "onToggleRecord",
        }),
      }),
    })
  )
end

local function start_region_selection(callback)
  if state.region_pending then return end
  state.region_pending = true
  local tmpfile = "/tmp/print-toolkit-region-" .. os.time() .. ".png"
  local cmd = string.format("grim -g \"$(slurp)\" %s", shq(tmpfile))
  noctalia.runAsync(cmd, function(result)
    state.region_pending = false
    if tonumber(result.exitCode) ~= 0 then
      callback(nil)
      return
    end
    callback(tmpfile)
  end)
end

-- ── Ciclo de vida ─────────────────────────────────────────────────────────
function onOpen(_context)
  -- Sempre detectar estado real ao abrir
  state.recording = false
  noctalia.processMatches(function(matched)
    state.recording = matched
    render()
  end, "gpu-screen-recorder", " -w ")
  render()
end

-- ── Ações ─────────────────────────────────────────────────────────────────

function onFullscreen()
  render()
  panel.close()
  noctalia.runAsync("sleep 0.35 && noctalia msg screenshot-fullscreen", function()
    noctalia.runAsync("sleep 0.5 && " .. string.format([[
      latest=$(find %s -maxdepth 1 -type f -name '*.png' -printf '%%T@ %%p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
      if [ -n "$latest" ] && [ -f "$latest" ]; then
        wl-copy --type image/png < "$latest"
      fi
    ]], shq(noctalia.expandPath(noctalia.getConfig("screenshot_dir") or "~/Pictures"))))
    noctalia.runAsync("sleep 0.2 && noctalia msg panel-toggle alvaro/print-toolkit:capture")
  end)
end

function onRegion()
  render()
  start_region_selection(function(file)
    if file then
      local dest = string.format("%s/screenshot_%s-region.png",
        shq(noctalia.expandPath(noctalia.getConfig("screenshot_dir") or "~/Pictures")),
        os.date("%Y%m%d_%H%M%S"))
      noctalia.runAsync(string.format("cp %s %s", shq(file), dest))
      noctalia.runAsync(string.format("wl-copy --type image/png < %s", shq(file)))
      noctalia.runAsync("rm -f " .. shq(file))
      noctalia.notify("Screenshot", "Regiao salva e copiada")
    end
    noctalia.runAsync("sleep 0.2 && noctalia msg panel-toggle alvaro/print-toolkit:capture")
  end)
end

function onOCR()
  render()
  start_region_selection(function(file)
    if not file then return end
    local script = noctalia.pluginDir() .. "/scripts/ocr-region.sh"
    local env = string.format("OCR_FILE=%s OCR_LANG=%s",
      shq(file),
      shq(noctalia.getConfig("ocr_language") or "por+eng"))
    noctalia.runAsync(env .. " " .. script, function(r)
      noctalia.runAsync("rm -f " .. shq(file))
      noctalia.runAsync("sleep 0.2 && noctalia msg panel-toggle alvaro/print-toolkit:capture")
    end)
  end)
end

function onReverseSearch()
  render()
  start_region_selection(function(file)
    if not file then return end
    local script = noctalia.pluginDir() .. "/scripts/search-region.sh"
    local env = string.format("SEARCH_FILE=%s SEARCH_ENGINE=%s",
      shq(file),
      shq(noctalia.getConfig("search_engine") or "google"))
    noctalia.runAsync(env .. " " .. script, function(r)
      noctalia.runAsync("rm -f " .. shq(file))
      noctalia.notify("Pesquisa", "Pesquisa reversa aberta")
      noctalia.runAsync("sleep 0.2 && noctalia msg panel-toggle alvaro/print-toolkit:capture")
    end)
  end)
end

function onToggleRecord()
  local source = noctalia.getConfig("record_source") or "focused"

  if state.recording then
    -- Parar gravação
    state.recording = false
    render()
    noctalia.runAsync("noctalia msg plugin noctalia/screen_recorder:service all stop")
    noctalia.notify("Gravacao", "Gravacao salva")
  else
    -- Iniciar gravação
    state.recording = true
    render()
    noctalia.runAsync(string.format(
      "noctalia msg plugin noctalia/screen_recorder:service all toggle %s",
      shq(source)
    ))
    -- Fechar toolbar e abrir painel de gravação
    panel.close()
    noctalia.runAsync("sleep 0.5 && noctalia msg panel-open alvaro/print-toolkit:record-top-center")
  end
end

-- IPC handlers
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
