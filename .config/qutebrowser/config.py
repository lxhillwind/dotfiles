import sys
import pathlib
# Documentation:
#   qute://help/configuring.html
#   qute://help/settings.html

config.load_autoconfig(False)

c.aliases = {
        'o': 'open',
        'O': 'open -t',
        'q': 'close',
        'w': 'session-save',
        'qa': 'quit',
        'wqa': 'quit --save',
        'ktsa': 'set tabs.show always',
        'ktsn': 'set tabs.show never',
        'ktph': 'set tabs.position left',
        'ktpl': 'set tabs.position right',
        'ktpk': 'set tabs.position top',
        'ktpj': 'set tabs.position bottom'
        }

c.content.blocking.adblock.lists.extend([
    "https://easylist-downloads.adblockplus.org/easylistchina.txt",
    ])
c.fonts.completion.entry = '12pt monospace'
c.fonts.downloads = '12pt monospace'
c.fonts.hints = 'bold 11pt monospace'
c.fonts.keyhint = '12pt monospace'
c.fonts.messages.error = '12pt monospace'
c.fonts.messages.info = '12pt monospace'
c.fonts.messages.warning = '12pt monospace'
c.fonts.prompts = '12pt sans-serif'
c.fonts.statusbar = '12pt monospace'
c.fonts.tabs.selected = '12pt monospace'
c.fonts.tabs.unselected = '12pt monospace'
c.hints.chars = 'asdfgqwertzxcv'
c.hints.uppercase = False
c.input.forward_unbound_keys = 'none'
c.tabs.background = True
c.tabs.last_close = 'close'
c.tabs.position = 'left'
c.tabs.new_position.unrelated = 'next'
c.tabs.select_on_remove = 'last-used'
c.url.default_page = pathlib.Path('~/html/index.html').expanduser().as_uri()
c.url.searchengines = {
        'DEFAULT': 'https://cn.bing.com/search?q={}&ensearch=1',
        'bd': 'https://www.baidu.com/s?wd={}',
        'bg': 'https://cn.bing.com/search?q={}&ensearch=1',
        'bl': 'https://search.bilibili.com/all?keyword={}',
        'cd': 'https://www.bing.com/dict/search?mkt=zh-CN&q={}',
        'gg': 'https://www.google.com/search?q={}',
        'sh': 'http://symbolhound.com/?q={}',
        'man': 'https://man.archlinux.org/search?q={}&go=Go',
        'man-a': 'https://man.archlinux.org/search?q={}',
        'wk': 'https://www.wikipedia.org/w/index.php?title=Special:Search&search={}',
        }
c.url.start_pages = c.url.default_page
#c.content.proxy = 'socks://localhost:1080'

# Bindings with Keypad
config.bind('<num-insert>', 'mode-enter passthrough')
config.bind('<num-insert>', 'mode-enter normal', mode='passthrough')
config.bind('<num-insert>', 'mode-enter normal', mode='insert')
config.bind('<num-insert>', 'mode-enter normal', mode='prompt')
config.bind('<num-insert>', 'mode-enter normal', mode='yesno')
config.bind('<num-/>', 'back')
config.bind('<num-*>', 'forward')
config.bind('<num-->', 'navigate prev')
config.bind('<num-+>', 'navigate next')
config.bind('<num-delete>', 'scroll-page 0 -0.97')
config.bind('<num-enter>', 'scroll-page 0 0.97')

config.bind('<num-delete>', 'fake-key <shift-space>', mode='passthrough')
config.bind('<num-enter>', 'fake-key <space>', mode='passthrough')

# Bindings for normal mode
config.bind('<ctrl-h>', 'nop')
config.bind('<ctrl-p>', 'nop')
config.bind('<ctrl-s>', 'nop')
config.bind('<shift-space>', 'scroll-page 0 -0.97')
config.bind('<space>', 'scroll-page 0 0.97')
config.bind('F', 'hint all tab-bg')
config.bind('P', 'open -t -- {clipboard}')
config.bind('S', 'stop')
config.bind('X', 'undo')
config.bind('W', 'set-cmd-text -s :open -p')
config.bind('ZQ', 'close')
config.bind('ZZ', 'session-save ;; close')
config.bind('af', 'hint --rapid links tab-bg')
config.bind('cc', 'yank selection')
config.bind('cd', 'spawn -u dict')  # query selected text in bing dict
config.bind('d', 'scroll-page 0 0.49')
config.bind('ef', 'hint all fill :o {hint-url}')
config.bind('f', 'hint all current')
config.bind('gT', 'tab-prev')
config.bind('gf', 'hint all tab-fg')
config.bind('gh', 'home')
config.bind('gi', 'hint inputs')
config.bind('gp', 'tab-pin')
config.bind('gt', 'tab-focus')
config.bind('gm', 'tab-mute')
config.bind('p', 'open -- {clipboard}')
config.bind('u', 'scroll-page 0 -0.49')
config.bind('x', 'tab-close')
config.bind('yf', 'hint links yank')

# Bindings for command mode
config.bind('<ctrl-d>', 'rl-delete-char', mode='command')
config.bind('<ctrl-i>', 'completion-item-focus next', mode='command')
config.bind('<ctrl-shift-i>', 'completion-item-focus prev', mode='command')
config.bind('<ctrl-;>', 'spawn -u vim-edit-cmd', 'command')  # edit cmd text in vim

# Bindings for insert mode
config.bind('<ctrl-a>', 'fake-key <home>', mode='insert')
config.bind('<ctrl-b>', 'fake-key <left>', mode='insert')
config.bind('<ctrl-d>', 'fake-key <delete>', mode='insert')
config.bind('<ctrl-e>', 'fake-key <end>', mode='insert')
config.bind('<ctrl-f>', 'fake-key <right>', mode='insert')
config.bind('<ctrl-h>', 'fake-key <backspace>', mode='insert')
config.bind('<ctrl-k>', 'fake-key <shift-end> ;; fake-key <delete>', mode='insert')
config.bind('<ctrl-n>', 'fake-key <down>', mode='insert')
config.bind('<ctrl-p>', 'fake-key <up>', mode='insert')
config.bind('<ctrl-u>', 'fake-key <shift-home> ;; fake-key <delete>', mode='insert')
if sys.platform.startswith('darwin'):
    config.bind('<ctrl-w>', 'fake-key <alt-backspace>', mode='insert')
else:
    config.bind('<ctrl-/>', 'fake-key <ctrl-a>', mode='insert')
    config.bind('<ctrl-w>', 'fake-key <ctrl-backspace>', mode='insert')

config.unbind(';d')
config.bind(';dc', 'download-clear')
config.bind(';dq', 'download-cancel')

# host config
rc = pathlib.Path(__file__).parent.joinpath('rc.py')
if rc.exists():
    with rc.open() as f:
        exec(f.read())
