" dummy function to make source work.
function! vimrc#terminal_api#source() abort
endfunction

" sync terminal path to buffer path.
" TODO follow cd even when terminal buffer not in focus (with event?).

function! Tapi_cd(nr, arg)
  if bufnr() == a:nr
    execute 'lcd' fnameescape(a:arg[0])
  endif
endfunction
