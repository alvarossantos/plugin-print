--!nonstrict
-- Print Toolkit - Recording Status Widget
-- Mostra ícone vermelho quando gravando + tempo no tooltip, clique para parar

local state = {
  is_recording = false,
  start_time = 0,
}

local function format_time(seconds)
  local mins = math.floor(seconds / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d", mins, secs)
end

local function update_widget()
  if state.is_recording then
    local elapsed = os.time() - state.start_time
    local time_str = format_time(elapsed)
    -- Ícone vermelho de gravação
    barWidget.setGlyph("record-circle")
    barWidget.setTooltip("Gravando há " .. time_str .. " — Clique para parar")
  else
    barWidget.setGlyph("")
    barWidget.setTooltip("Print Toolkit — Sem gravação ativa")
  end
end

local function check_recording()
  noctalia.processMatches(function(matched)
    local is_recording = matched == true
    
    if is_recording and not state.is_recording then
      -- Iniciou gravação
      state.is_recording = true
      state.start_time = os.time()
      -- Atualiza a cada segundo
      noctalia.setUpdateInterval(1000)
    elseif not is_recording and state.is_recording then
      -- Parou gravação
      state.is_recording = false
      state.start_time = 0
      -- Volta a intervalo normal
      noctalia.setUpdateInterval(10000)
    end
    update_widget()
  end, "gpu-screen-recorder")
end

function update()
  -- Chamado a cada intervalo (1s quando gravando, 10s quando não)
  check_recording()
end

function onClick()
  if state.is_recording then
    -- Para gravação via IPC
    local source = noctalia.getConfig("record_source") or "focused"
    noctalia.msg("plugin", "alvaro/print-toolkit:capture", "all", "record")
  else
    -- Abre toolbar de captura
    noctalia.togglePanel("alvaro/print-toolkit:capture")
  end
end

-- Inicialização
noctalia.setUpdateInterval(10000)
check_recording()