-- TODO: move tab to new window (native tab).

local wezterm = require 'wezterm'
local config = {}
local act = wezterm.action
local is_mac = string.find(wezterm.target_triple, 'darwin', 1, 1)
config.keys = {}

local search_mode = nil
if wezterm.gui then
  search_mode = wezterm.gui.default_key_tables().search_mode
end

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
    return 'MaterialDarker'
  else
    return 'Builtin Light'
  end
end
config.color_scheme = scheme_for_appearance(get_appearance())
config.bold_brightens_ansi_colors = 'No'
config.hide_tab_bar_if_only_one_tab = true
-- fancy tab bar causes window height not aligned.
config.use_fancy_tab_bar = false
config.cursor_blink_rate = 0

--- font {{{1
config.font = wezterm.font_with_fallback {
    { family = 'JetBrains Mono NL', weight = is_mac and 'Medium' or nil },
    { family = 'Microsoft YaHei', scale = 1.0 },  -- TODO test this on Windows.
    { family = '苹方-简' },
    { family = 'Jigmo' },
    { family = 'Jigmo2' },
    { family = 'Jigmo3' },
}
config.font_size = is_mac and 16.0 or 14.0

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
table.insert(config.keys, {
  key = 'f', mods = is_mac and 'SUPER' or 'ALT', action = act.Search {
    CaseInSensitiveString = '',
  }
})

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

--- "fix" search key {{{1
if search_mode then
  table.insert(search_mode, {
    key = 'Enter', mods = 'NONE', action = act.CopyMode 'NextMatch'
  })
  table.insert(search_mode, {
    key = 'Enter', mods = 'SHIFT', action = act.CopyMode 'PriorMatch'
  })
  table.insert(search_mode, {
    key = 'c', mods = 'CTRL', action = act.CopyMode 'Close'
  })
end

--- mouse {{{1
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = is_mac and 'SUPER' or 'CTRL',
    action = act.OpenLinkAtMouseCursor,
    mouse_reporting = true,  -- prevent application from handling the click
  },
  {
    event = { Up = { streak = 1, button = 'Right' } },
    action = act.PaneSelect {
      mode = 'MoveToNewWindow',
    },
  },
}

--- finish {{{1
config.key_tables = {
  search_mode = search_mode,
}
return config

-- vim:sw=2
