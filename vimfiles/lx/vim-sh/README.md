# vim-sh

## Usage
Two commands are provided:

- `:Sh [cmd]...`;

- `:Terminal [cmd]...`; (like `:Sh`, but always open tty in current window)

## Option
Pass option as follows:

- show output in new buffer (tty) instead of ex command output area; without
  this option, shell command will be executed without pty, and in block mode.
  (like `system()`)

```vim
:Sh -t [cmd]...
```

- selected text as stdin (this is different from filter, which is line level);
  visual mode

```vim
:<','>Sh -v [cmd]...
```

- execute shell command in new application window. On Windows, it is cmd.exe;
  on other OS, urxvt / alacritty is supported now.

```vim
:Sh -w [cmd]...
```

- close window after execution

```vim
:Sh -c [cmd]...
```

- do not lose focus on current buffer, run in background (implies -t option)

```vim
:Sh -b [cmd]...
```

- try to reuse existing builtin tty window (implies -t option)

```vim
:Sh! [cmd]...
```

- mix these options: (order does not matter)

```vim
Sh -wv [cmd]...
```

NOTE: `:Sh -w -v [cmd]...` will not work!

## Feature

### always use shell

- Content after command will be passed to shell. (this is like builtin
  `:terminal` with `++shell` option)

### proper % expand

- `%` with optional modifiers (`:p` / `:h` / `:t` / `:r` / `:e`) is expanded
  only when passed as a standalone argument; and it is shell-escaped (like
  `:S` modifier is always used).

This means that command like `Sh printf %s %:t:e` will print file basename
(`%s` is not expanded; `%:t:e` should NOT be quoted, as it is escaped
automatically).

### unix shell support in native Windows vim (`has('win32') == 1`)

This requires [busybox-w32](https://frippery.org/busybox/) binary in `$PATH`.

- `:terminal ++shell` with busybox shell syntax.

- Replace `:!` and `!` (filter) with busybox sh (by `cmap <CR>`).
