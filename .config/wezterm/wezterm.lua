-- TODO: alt+hjkl outside tmux in vim.
-- TODO: move tab to new window (native tab).

local wezterm = require 'wezterm'
local config = {}
local act = wezterm.action
local is_mac = string.find(wezterm.target_triple, 'darwin', 1, 1)
config.keys = {}

-- colorscheme: {{{
-- wezterm.gui is not available to the mux server, so take care to
-- do something reasonable when this config is evaluated by the mux
function get_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end
  return 'Dark'
end

function scheme_for_appearance(appearance)
    -- }}}
  if appearance:find 'Dark' then
    return 'Breeze'
  else
    return 'Builtin Light'
  end
end
config.color_scheme = scheme_for_appearance(get_appearance())
config.bold_brightens_ansi_colors = 'No'
config.hide_tab_bar_if_only_one_tab = true

--- font {{{1
config.font = wezterm.font_with_fallback {
    'JetBrains Mono NL',
    { family = 'Microsoft YaHei', scale = 1.0 },  -- TODO test this on Windows.
    { family = '苹方-简', scale = 1.0 },
    { family = 'Jigmo', scale = 1.0 },
    { family = 'Jigmo2', scale = 1.0 },
    { family = 'Jigmo3', scale = 1.0 },
}
config.font_size = 16.0

--- window size {{{1
config.initial_cols = 90
config.initial_rows = 25

config.window_padding = {
  left = '0.5cell',
  right = '0.5cell',
  top = '0.2cell',
  bottom = '0.2cell',
}

--- alt key {{{1
if is_mac then
    local keys_to_remap = {
        'e', 'n', 'o', 'p',  -- tmux
        'h', 'j', 'k', 'l',  -- vim
    }

    -- SUPER to ALT
    for _, key in ipairs(keys_to_remap) do
        table.insert(config.keys, {
            key = key,
            mods = 'SUPER',
            action = act.SendKey { key = key, mods = 'ALT' }
        })
    end
else  -- not macos
    local items = {
        { key = 'c', mods = 'ALT', action = act.CopyTo 'ClipboardAndPrimarySelection' },
        { key = 'v', mods = 'ALT', action = act.PasteFrom 'Clipboard' },
        { key = 't', mods = 'ALT', action = act.SpawnTab 'CurrentPaneDomain' },
        { key = 'w', mods = 'ALT', action = act.CloseCurrentPane { confirm = true } },
    }
    for _, item in ipairs(items) do
        table.insert(config.keys, item)
    end
end

--- pane {{{1
table.insert(config.keys, {
    key = '7', mods = 'CTRL', action = act.SplitPane { direction = 'Right' }
})
table.insert(config.keys, {
    key = 'phys:7', mods = 'CTRL|SHIFT', action = act.SplitPane { direction = 'Down' }
})
table.insert(config.keys, {
    key = '8', mods = 'CTRL', action = act.ActivatePaneDirection 'Prev'
})
table.insert(config.keys, {
    key = '9', mods = 'CTRL', action = act.ActivatePaneDirection 'Next'
})
table.insert(config.keys, {
    key = 'phys:8', mods = 'CTRL|SHIFT', action = act.RotatePanes 'CounterClockwise'
})
table.insert(config.keys, {
    key = 'phys:9', mods = 'CTRL|SHIFT', action = act.RotatePanes 'Clockwise'
})

--- mouse {{{1
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = is_mac and 'SUPER' or 'CTRL',
    action = act.OpenLinkAtMouseCursor,
    mouse_reporting = true,  -- prevent application from handling the click
  },
}

--- finish {{{1
return config
