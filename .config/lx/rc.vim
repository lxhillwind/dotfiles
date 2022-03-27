" vim:fdm=marker
" path: ~/.vimrc

vim9script

source ~/vimfiles/vimrc.main

augroup vimrc_local
  au!
augroup END

# pkgs {{{1
runtime rc/pkgs.vim

g:loaded_fzf = 1

Pack 'pyvim',#{skip: 1}
g:pyvim_rc = expand('~/vimfiles/config/pyvim.py')

Pack 'https://github.com/ziglang/zig.vim'

Pack 'https://github.com/masukomi/vim-markdown-folding'
g:markdown_fold_style = 'nested'
g:markdown_fold_override_foldtext = 0

# ft {{{1
augroup vimrc_local
  au BufNewFile,BufRead */qutebrowser/qutebrowser.service setl ft=systemd
augroup END

# misc {{{1
if has('gui_running')
  set gfn=Hack\ 12
  set bg=light
endif

command! -nargs=+ Man Terminal zsh -ic 'man <q-args>'

# :Rgbuffer {...} {{{2
command! -nargs=+ Rgbuffer Rgbuffer(<q-args>)

def Jumpback(buf: number)
  const buffers = tabpagebuflist()
  const idx = index(buffers, buf)
  if idx >= 0
    execute 'normal' (idx + 1) "\<Plug>(jump_to_file)"
  else
    echoerr 'buffer not found!'
  endif
enddef

def Rgbuffer(arg: string)
  const buf = bufnr()
  const result = execute(':%Sh rg -I --column ' .. arg)
  bel :7sp +enew | setl buftype=nofile
  put =result
  norm gg"_dd
  execute printf("nnoremap <buffer> <CR> <cmd>call <SID>Jumpback(%s)<CR>", buf)
  syn match String '\v^[0-9]+'
enddef

# exe {{{2
augroup vimrc_local
au BufReadCmd *.exe,*.dll ReadBin(expand('<amatch>'))
au BufWriteCmd *.exe,*.dll WriteBin(expand('<amatch>'))
augroup END

# avoid using busybox xxd.
const xxd_path = exists($VIM .. '/bin/xxd') ? '"$VIM"/bin/xxd' : 'xxd'

def ReadBin(name: string)
  execute printf('silent r !%s %s', xxd_path, shellescape(name))
  normal gg"_dd
enddef

def WriteBin(name: string)
  if has('win32') && !has('nvim')
    # returncode check is ignored.
    job_start('xxd -r', {in_io: 'buffer', in_buf: bufnr(), out_io: 'file', out_name: name})
  else
    execute printf(':%w !%s -r > %s', xxd_path, shellescape(name))
    if !empty(v:shell_error)
      return
    endif
  endif
  setl nomodified
  redrawstatus | echon 'written.'
enddef
