--!nonstrict
-- Print Toolkit - Bar widget para Noctalia v5
-- API real confirmada em:
--   docs.noctalia.dev/v5/plugins/development/entries/  (barWidget.*)
--   docs.noctalia.dev/v5/plugins/development/runtime-api/  (noctalia.togglePanel)
-- Padrão idêntico ao widget do plugin comunitário "audio-switcher"
-- (materializado em ~/.local/state/noctalia/plugins/materialized/community/).

local PANEL_ID = "alvaro/print-toolkit:capture"

local function render()
  barWidget.setGlyph("screenshot")
  barWidget.setTooltip(noctalia.tr("widget.tooltip"))
end

function update()
  render()
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

noctalia.setUpdateInterval(30000)
render()
