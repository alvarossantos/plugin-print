--!nonstrict
-- Print Toolkit - Recording Panel (estilo iNiR Recorder overlay)
-- Abre automaticamente ao iniciar gravação, fecha ao parar
-- Mostra tempo decorrido + botões Pausar / Parar / Cancelar

local state = {
  is_recording = false,
  is_paused = false,
  start_time = 0,
  paused_time = 0,
  should_close = false,  -- flag to trigger close in update()
}

local function tr(key, subst)
  return noctalia.tr(key, subst)
end

local function shq(v)
  if v:find("'") then v = v:gsub("'", "'\\''") end
  return "'" .. v .. "'"
end

local function format_time(seconds)
  local mins = math.floor(seconds / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d", mins, secs)
end

local function get_elapsed()
  if not state.is_recording then return 0 end
  if state.is_paused then return state.paused_time end
  return state.paused_time + (os.time() - state.start_time)
end

local function render()
  local elapsed = get_elapsed()
  local time_str = format_time(elapsed)
  local is_rec = state.is_recording and not state.is_paused

  panel.render(
    ui.column({ gap = 12, padding = 16, align = "center" }, {
      -- Título + Timer
      ui.row({ gap = 8, align = "center" }, {
        ui.label({
          text = state.is_paused and tr("record.paused") or tr("record.recording"),
          fontSize = 16,
          fontWeight = "bold",
          color = is_rec and "error" or "on_surface_variant",
        }),
        -- Pulsing red dot + timer
        ui.row({ gap = 6, align = "center" }, {
          ui.label({
            text = "●",
            fontSize = 14,
            color = is_rec and "error" or "on_surface_variant",
          }),
          ui.label({
            text = format_time(get_elapsed()),
            fontSize = 14,
            fontFamily = "monospace",
            fontWeight = "bold",
            color = "on_surface",
          }),
        }),
      }),

      -- Status bar (mic/volume)
      ui.separator({}),
      ui.row({ gap = 16, align = "center" }, {
        ui.row({ gap = 4, align = "center" }, {
          ui.glyph({ text = "mic", fontSize = 14 }),
          ui.label({ text = tr("record.mic_on"), fontSize = 11, color = "on_surface_variant" }),
        }),
        ui.row({ gap = 4, align = "center" }, {
          ui.glyph({ text = "volume_up", fontSize = 14 }),
          ui.label({ text = tr("record.vol_max"), fontSize = 11, color = "on_surface_variant" }),
        }),
      }),

      -- Botões de ação
      ui.separator({}),
      ui.row({ gap = 8, align = "center" }, {
        -- Pausar / Retomar
        ui.button({
          text = state.is_paused and tr("record.resume") or tr("record.pause"),
          glyph = state.is_paused and "play_arrow" or "pause",
          variant = state.is_paused and "primary" or "secondary",
          onClick = "onTogglePause",
          width = 100,
        }),
        -- Parar
        ui.button({
          text = tr("record.stop"),
          glyph = "stop",
          variant = "destructive",
          onClick = "onStop",
          width = 100,
        }),
        -- Cancelar (descarta gravação)
        ui.button({
          text = tr("record.cancel"),
          glyph = "close",
          variant = "outline",
          onClick = "onCancel",
          width = 100,
        }),
      }),

      -- Dica
      ui.separator({}),
      ui.label({
        text = tr("record.hint"),
        fontSize = 10,
        color = "on_surface_variant",
        maxLines = 2,
      }),
    })
  )
end

local function update_widget()
  -- Atualiza apenas o timer se estiver gravando e não pausado
  if state.is_recording and not state.is_paused then
    render()
  end
end

local function check_recording()
  noctalia.log("INFO", "record-panel: check_recording called")
  noctalia.processMatches(function(matched)
    local is_recording = matched == true
    noctalia.log("INFO", "record-panel: processMatches callback, matched=" .. tostring(matched) .. ", state.is_recording=" .. tostring(state.is_recording))
    
    if is_recording and not state.is_recording then
      -- Iniciou gravação
      state.is_recording = true
      state.is_paused = false
      state.start_time = os.time()
      state.paused_time = 0
      noctalia.setUpdateInterval(1000)
      noctalia.log("INFO", "record-panel: Recording started")
      render()
elseif not is_recording and state.is_recording then
      -- Parou gravação
      state.is_recording = false
      state.is_paused = false
      state.start_time = 0
      state.paused_time = 0
      noctalia.setUpdateInterval(10000)
      noctalia.log("INFO", "record-panel: Recording stopped, setting close flag")
      state.should_close = true
      -- Don't call update_widget here, let update() handle it
    end
  end, "gpu-screen-recorder")
end

-- Ciclo de vida
function onOpen(_context)
  check_recording()
  render()
end

function update()
  check_recording()
  if state.should_close then
    state.should_close = false
    panel.close()
    return
  end
  if state.is_recording and not state.is_paused then
    render()  -- Atualiza timer a cada segundo
  end
end

-- Ações
function onTogglePause()
  if state.is_paused then
    -- Retomar
    state.is_paused = false
    state.start_time = os.time()
    -- Reenvia toggle para retomar (o plugin screen_recorder usa toggle para pausar/retomar)
    local source = noctalia.getConfig("record_source") or "focused"
    noctalia.msg("plugin", "noctalia/screen_recorder:service", "all", "toggle", "pause")
    render()
  else
    -- Pausar
    state.is_paused = true
    state.paused_time = state.paused_time + (os.time() - state.start_time)
    local source = noctalia.getConfig("record_source") or "focused"
    noctalia.msg("plugin", "noctalia/screen_recorder:service", "all", "toggle", "pause")
    render()
  end
end

function onStop()
  -- Para e salva
  local source = noctalia.getConfig("record_source") or "focused"
  noctalia.msg("plugin", "noctalia/screen_recorder:service", "all", "toggle", "focused")
  -- O check_recording detecta parada e fecha painel
end

function onCancel()
  -- Para e descarta
  local source = noctalia.getConfig("record_source") or "focused"
  noctalia.msg("plugin", "noctalia/screen_recorder:service", "all", "toggle", "focused")
  -- O check_recording detecta parada e fecha painel
end

-- IPC para abrir painel externamente
function onIpc(event, _payload)
  if event == "record" then
    check_recording()
    if state.is_recording then
      render()
    end
    return true
  end
  return false
end

-- Inicialização
noctalia.setUpdateInterval(1000)  -- Atualiza timer a cada segundo
check_recording()
render()