--!nonstrict
-- Print Toolkit - Recording Panel (simplificado)
-- Timer via loop async (panels não suportam update())
-- 6 posições: top-left, top-center, top-right, bottom-left, bottom-center, bottom-right
-- Comandos via noctalia msg plugin (IPC)
-- Timer inicia imediatamente quando painel abre (assume gravação ativa)

local timer_active = false

local state = {
  is_paused = false,
  start_time = 0,
  paused_time = 0,
  position = "top-center",
}

-- ── Posições ─────────────────────────────────────────────────────────────

local function is_top(pos)
  return pos:find("^top%-") ~= nil
end

local function col(pos)
  if pos:find("left") then return "left" end
  if pos:find("right") then return "right" end
  return "center"
end

local function move_left(pos)
  local c = col(pos)
  if c == "left" then return pos end
  if c == "right" then return is_top(pos) and "top-center" or "bottom-center" end
  return is_top(pos) and "top-left" or "bottom-left"
end

local function move_right(pos)
  local c = col(pos)
  if c == "right" then return pos end
  if c == "left" then return is_top(pos) and "top-center" or "bottom-center" end
  return is_top(pos) and "top-right" or "bottom-right"
end

local function move_up(pos)
  return is_top(pos) and pos or "top-" .. col(pos)
end

local function move_down(pos)
  return (not is_top(pos)) and pos or "bottom-" .. col(pos)
end

-- ── Timer ────────────────────────────────────────────────────────────────

local function format_time(seconds)
  local mins = math.floor(seconds / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d", mins, secs)
end

local function get_elapsed()
  if state.start_time == 0 then return 0 end
  if state.is_paused then return state.paused_time end
  return state.paused_time + (os.time() - state.start_time)
end

-- ── Timer loop ───────────────────────────────────────────────────────────

local render

local function startTimer()
  if timer_active then return end
  state.start_time = os.time()
  timer_active = true
  local function tickOnce()
    if not timer_active then return end
    render()
    noctalia.runAsync("sleep 1", function()
      tickOnce()
    end)
  end
  tickOnce()
end

local function stopTimer()
  timer_active = false
end

-- ── Render ───────────────────────────────────────────────────────────────

render = function()
  local elapsed = get_elapsed()
  local time_str = format_time(elapsed)
  local paused = state.is_paused

  panel.render(
    ui.column({ flexGrow = 1, align = "center", justify = "center" }, {
      ui.row({ gap = 8, align = "center" }, {
        ui.button({ glyph = "chevron-left", controlSize = "sm", variant = "ghost", onClick = "onMoveLeft" }),
        ui.button({ glyph = "chevron-right", controlSize = "sm", variant = "ghost", onClick = "onMoveRight" }),
        ui.button({ glyph = "chevron-up", controlSize = "sm", variant = "ghost", onClick = "onMoveUp" }),
        ui.button({ glyph = "chevron-down", controlSize = "sm", variant = "ghost", onClick = "onMoveDown" }),
        ui.label({ text = "|" }),
        ui.glyph({
          name = paused and "video-off" or "video",
          size = 20,
          color = paused and "primary" or "error",
        }),
        ui.label({
          text = time_str,
          fontSize = 18,
          fontFamily = "monospace",
          fontWeight = "bold",
          color = paused and "primary" or "error",
        }),
        ui.label({ text = "|" }),
        ui.button({
          text = paused and "Retomar" or "Pausar",
          variant = paused and "primary" or "secondary",
          controlSize = "sm",
          onClick = "onTogglePause",
        }),
        ui.button({
          text = "Parar",
          variant = "destructive",
          controlSize = "sm",
          onClick = "onStop",
        }),
        ui.button({
          text = "Cancelar",
          variant = "outline",
          controlSize = "sm",
          onClick = "onCancel",
        }),
      }),
    })
  )
end

-- ── Trocar posição ───────────────────────────────────────────────────────

local function switchTo(target_id, target_pos)
  state.position = target_pos
  stopTimer()
  panel.close()
  noctalia.runAsync("sleep 0.15 && noctalia msg panel-open alvaro/print-toolkit:" .. target_id)
end

-- ── Lifecycle ────────────────────────────────────────────────────────────

function onOpen(_context)
  state.position = state.position or "top-center"
  state.is_paused = false
  state.paused_time = 0
  -- Iniciar timer imediatamente
  startTimer()
end

function onClose()
  stopTimer()
end

-- ── Ações ────────────────────────────────────────────────────────────────

function onTogglePause()
  if state.is_paused then
    state.is_paused = false
    state.start_time = os.time()
  else
    state.is_paused = true
    state.paused_time = state.paused_time + (os.time() - state.start_time)
  end
  noctalia.runAsync("pkill -SIGUSR2 -f 'gpu-screen-recorder' 2>/dev/null || true")
  render()
end

function onStop()
  stopTimer()
  noctalia.runAsync("noctalia msg plugin noctalia/screen_recorder:service all stop")
  noctalia.notify("Gravacao", "Gravacao salva")
  panel.close()
end

function onCancel()
  stopTimer()
  -- Parar gravação e deletar arquivo
  noctalia.runAsync("noctalia msg plugin noctalia/screen_recorder:service all stop")
  noctalia.runAsync("pkill -9 -f 'gpu-screen-recorder' 2>/dev/null || true")
  noctalia.runAsync("sleep 0.3 && f=$(ls -t $HOME/Videos/Recordings/*.mp4 2>/dev/null | head -1) && [ -n \"$f\" ] && rm -f \"$f\"")
  noctalia.notify("Gravacao de Tela", "Gravacao cancelada")
  panel.close()
end

-- ── Posição ──────────────────────────────────────────────────────────────

function onMoveLeft()
  switchTo("record-" .. move_left(state.position), move_left(state.position))
end

function onMoveRight()
  switchTo("record-" .. move_right(state.position), move_right(state.position))
end

function onMoveUp()
  switchTo("record-" .. move_up(state.position), move_up(state.position))
end

function onMoveDown()
  switchTo("record-" .. move_down(state.position), move_down(state.position))
end

-- ── Inicialização ────────────────────────────────────────────────────────

render()
