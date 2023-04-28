-- link this file to ~/.hammerspoon/init.lua

-- config is largely token from:
-- https://github.com/kbd/setup/blob/master/HOME/.hammerspoon/init.lua

-- import:
-- https://github.com/dbalatero/SkyRocket.spoon (commit: 358c683)

hs.alert.show("Hammerspoon config loaded")

hyper_shift = {"cmd", "shift"}
hyper = {"cmd"}
meta = {"alt"}

hs.hotkey.bind(hyper_shift, ";", hs.reload)

-- move / resize window when holding key {{{
local SkyRocket = hs.loadSpoon("SkyRocket")
sky = SkyRocket:new({
  -- Opacity of resize canvas
  opacity = 0.3,

  -- Which modifiers to hold to move a window?
  moveModifiers = meta,

  -- Which mouse button to hold to move a window?
  moveMouseButton = 'left',

  -- Which modifiers to hold to resize a window?
  resizeModifiers = meta,

  -- Which mouse button to hold to resize a window?
  resizeMouseButton = 'right',

  disabledApps = {},
})
-- }}}

-- Defines for window maximize toggler {{{
-- copied from https://github.com/wangshub/hammerspoon-config/blob/master/window/window.lua
local frameCache = {}
function toggleWindowMaximized()
    local win = hs.window.focusedWindow()
    if win == nil then
        return
    end
    if frameCache[win:id()] then
       win:setFrame(frameCache[win:id()])
       frameCache[win:id()] = nil
    else
       frameCache[win:id()] = win:frame()
       win:maximize()
    end
 end
-- }}}
hs.hotkey.bind(hyper, "return", toggleWindowMaximized)
-- avoid command+enter (to fullscreen causing new workspace)
-- why maximize not fullscreen?
-- since macOS fullscreen will move window to new workspace,
-- then app show all window won't work as expected

function bindApp(char, app, with_shift) -- {{{
    local key = hyper
    if with_shift ~= nil then
        key = hyper_shift
    end
    hs.hotkey.bind(key, char, function()
        hs.application.launchOrFocus(app)
    end)
end -- }}}

-- "command+," 通常为系统设置, 所以在 karabiner 将其与 "shift+command+," 对调,
-- 然后此处设置带 shift 的.
bindApp(",", "Firefox", true)
bindApp(".", "sioyek")
bindApp("/", "kitty")

-- don't set key for <M-q>, since it may shutdown PC (luckily with prompt)
-- if hammerspoon is not started yet.

function showClipboard() -- {{{
    hs.alert.show("content in clipboard: ")
    local text = hs.pasteboard.readString()
    if text:len() > 100 then
        text = text:sub(0, 100) .. ' ...'
    end
    hs.alert.show(text)
end -- }}}
hs.hotkey.bind(meta, "i", showClipboard)
-- need to bind option+l to shift+option+l in karabiner.
hs.hotkey.bind({"alt", "shift"}, "l", hs.caffeinate.lockScreen)

-- move current window to the space
-- https://stackoverflow.com/questions/46818712/using-hammerspoon-and-the-spaces-module-to-move-window-to-new-space
-- slightly modified {{{
function MoveWindowToSpace(direction)
  -- direction: 1 (right) or -1 (left)
  local spaces = require("hs.spaces")
  local win = hs.window.focusedWindow()      -- current window
  local cur_screen = hs.screen.mainScreen()
  local cur_screen_id = cur_screen:getUUID()
  local all_spaces=spaces.allSpaces()
  local cur_space = spaces.focusedSpace()
  local target_space = nil
  for i, j in pairs(all_spaces[cur_screen_id]) do
    if j == cur_space then
      target_space = all_spaces[cur_screen_id][i+direction]
      break
    end
  end
  if target_space ~= nil then
    spaces.moveWindowToSpace(win:id(), target_space)
    local map = {[1]="]", [-1]="["}
    -- cmd+[ / cmd+] is defined in os keyboard preference.
    hs.eventtap.keyStroke({"cmd"}, map[direction], 0)
    -- this does not work, don't know why:
    --spaces.gotoSpace(target_space)
  end
end
-- }}}
hs.hotkey.bind(hyper_shift, "[", function() MoveWindowToSpace(-1) end)
hs.hotkey.bind(hyper_shift, "]", function() MoveWindowToSpace(1) end)
