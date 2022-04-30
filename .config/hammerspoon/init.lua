-- link this file to ~/.hammerspoon/init.lua

-- config is largely token from:
-- https://github.com/kbd/setup/blob/master/HOME/.hammerspoon/init.lua

hs.alert.show("Hammerspoon config loaded")

hyper_shift = {"cmd", "shift"}
hyper = {"cmd"}
meta = {"alt"}

-- Defines for window maximize toggler
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

hs.hotkey.bind(hyper_shift, ";", hs.reload)

function bindApp(char, app)
    hs.hotkey.bind(hyper, char, function()
        hs.application.launchOrFocus(app)
    end)
end

function fuzzy(choices, func)
    local chooser = hs.chooser.new(func)
    chooser:choices(choices)
    chooser:searchSubText(true)
    chooser:fgColor({hex="#233333"})
    chooser:subTextColor({hex="#666"})
    chooser:width(25)
    chooser:show()
end

function selectWindow(window)
    if window == nil then -- nothing selected
        return
    end
    hs.window.get(window.id):focus()
end

function showWindowFuzzy(app)
    local windows = nil
    if app == nil then -- all windows
        windows = hs.window.allWindows()
    elseif app == true then -- focused app windows
        windows = hs.application.frontmostApplication():allWindows()
    else -- specific app windows
        windows = app:allWindows()
    end

    local focused_id = hs.window.focusedWindow()
    if focused_id ~= nil then
        focused_id = focused_id:id()
    else
        focused_id = -1
    end

    local choices = {}
    local app_images = {}
    local window_idx = 1

    table.sort(windows, function(left, right)
        -- 让中文开头的排在前面.
        return left:title() > right:title()
    end)

    for i=1, #windows do
        local w = windows[i]
        local id = w:id()
        local active = id == focused_id
        local app = w:application()
        if app_images[app] == nil then -- cache the app image per app
            if app:bundleID() ~= nil then
                app_images[app] = hs.image.imageFromAppBundle(app:bundleID())
            end
        end
        local image = app_images[app]
        local text = w:title()
        local subText = app:title() .. (active and " (active)" or "")
        if text ~= "Notification Center" then
            choices[window_idx] = {
                text = text,
                subText = subText,
                image = image,
                valid = not active,
                id = id,
            }
            window_idx = window_idx + 1
        end
    end
    fuzzy(choices, selectWindow)
end

function showClipboard()
    hs.alert.show("content in clipboard: ")
    local text = hs.pasteboard.readString()
    if text:len() > 100 then
        text = text:sub(0, 100) .. ' ...'
    end
    hs.alert.show(text)
end

function terminalIsFun()
    hs.task.new(
        "/opt/homebrew/bin/alacritty",
        nil,
        function(...) return true end,
        {
            "--title", "editing scratch",
            "-e", "zsh", "-c",
            [[~/bin/vim -c 'Scratch popup_text_selection' -c 'call feedkeys(" pp", "t")']]
        }
    ):start()
end

bindApp(",", "Google Chrome")
bindApp(".", "Visual Studio Code")
-- iterm 反馈不够显眼. 其通知中心相关功能好像挂了.
-- https://gitlab.com/gnachman/iterm2/-/issues/10305
--bindApp("/", "iTerm")
bindApp("/", "alacritty")

hs.hotkey.bind(hyper, ";", showWindowFuzzy) -- all windows
hs.hotkey.bind(hyper, "'", function() showWindowFuzzy(true) end) -- app windows

hs.hotkey.bind(hyper, "return", toggleWindowMaximized)
-- avoid command+enter (to fullscreen causing new workspace)
hs.hotkey.bind(hyper, "m", toggleWindowMaximized)
-- maximize
-- since macOS fullscreen will move window to new workspace,
-- then app show all window won't work as expected

-- don't set key for <M-q>, since it may shutdown PC (luckily with prompt)
-- if hammerspoon is not started yet.

hs.hotkey.bind(meta, "a", terminalIsFun)
hs.hotkey.bind(meta, "i", showClipboard)
hs.hotkey.bind(meta, "l", hs.caffeinate.lockScreen)
