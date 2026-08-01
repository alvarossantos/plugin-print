--!nonstrict
-- Print Toolkit - Recording Status Widget
-- Mostra status de gravação na barra e permite parar

local PANEL_ID = "alvaro/print-toolkit:capture"

local function render()
  -- Verifica se está gravando
  noctalia.processMatches(function(matched)
    local is_recording = matched == true
    
    if is_recording then
      barWidget.setGlyph("record-circle")  -- ícone vermelho de gravação
      barWidget.setTooltip("Gravando... Clique para parar")
    else
      barWidget.setGlyph("")  -- vazio quando não gravando
      barWidget.setTooltip("Print Toolkit")
    end
  end, "gpu-screen-recorder")
end

function update()
  render()
end

function onClick()
  -- Toggle gravação via IPC
  local source = noctalia.getConfig("record_source") or "focused"
  noctalia.msg("plugin", "alvaro/print-toolkit:capture", "all", "record")
end

-- Atualiza a cada 2 segundos quando gravando, 10s quando não
noctalia.setUpdateInterval(10000)
render()