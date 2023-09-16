vim9script

# $VIMRUNTIME also defines l:keywordprg, so we move current file to after
# directory, to overwrite it.

&l:keywordprg = ':ManAndSearch ' .. expand('<amatch>')
command! -buffer -nargs=* ManAndSearch ManAndSearch(<q-args>)

def ManAndSearch(arg: string)
    const arr = arg->split('\v^\S+\zs\s+')
    const filetype: string = arr[0]
    const keyword: string = arr[1]->tolower()
    const program = {
        sshconfig: 'ssh_config',
    }->get(filetype, filetype)
    execute printf('Sh -t=sp,c LESS="+/^\s*"%s man %s', shellescape(keyword), program)
enddef
