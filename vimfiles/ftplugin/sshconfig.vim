vim9script

&l:keywordprg = ':ManAndSearch ' .. expand('<amatch>')
command! -buffer -nargs=* ManAndSearch ManAndSearch(<q-args>)

def ManAndSearch(arg: string)
    const arr = arg->split('\v^\S+\zs\s+')
    const filetype: string = arr[0]
    const keyword: string = arr[1]
    const program = {
        sshconfig: 'ssh_config',
    }->get(filetype, filetype)
    execute printf('Sh -t=sp LESS=+/%s man %s', shellescape(keyword), program)
enddef
