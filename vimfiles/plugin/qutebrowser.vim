" qutebrowser userscript: vim-edit-cmd.

if empty($QUTE_FIFO)
  finish
endif

command! KqutebrowserEditCmd call s:qutebrowser_edit_cmd()

function! s:qutebrowser_edit_cmd()
  setl buftype=nofile noswapfile
  call setline(1, $QUTE_COMMANDLINE_TEXT[1:])
  call setline(2, '')
  call setline(3, 'hit `<Space>q` to save cmd (first line) and quit')
  nnoremap <buffer> <Space>q :call writefile(['set-cmd-text -s :' . getline(1)], $QUTE_FIFO) \| q<CR>
endfunction
