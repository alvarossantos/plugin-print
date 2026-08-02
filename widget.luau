--!nonstrict
-- Print Toolkit - Bar widget para Noctalia v5
-- API real confirmada em:
--   docs.noctalia.dev/v5/plugins/development/entries/  (barWidget.*)
--   docs.noctalia.dev/v5/plugins/development/runtime-api/  (noctalia.togglePanel)
-- Padrão idêntico ao widget do plugin comunitário "audio-switcher"
-- (materializado em ~/.local/state/noctalia/plugins/materialized/community/).

local PANEL_ID = "alvaro/print-toolkit:capture"
local RECORD_PANEL_ID = "alvaro/print-toolkit:record"
local is_recording = false

local function render()
  barWidget.setGlyph("screenshot")
  barWidget.setTooltip(noctalia.tr("widget.tooltip"))
end

function update()
  render()
  
  -- Monitora gravação para abrir painel automaticamente
  noctalia.processMatches(function(matched)
    if matched == true and not is_recording then
      is_recording = true
      noctalia.runAsync("noctalia msg panel-open " .. RECORD_PANEL_ID)
    elseif matched == false then
      is_recording = false
    end
  end, "gpu-screen-recorder")
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

noctalia.setUpdateInterval(2000)
render()
