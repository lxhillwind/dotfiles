vim9script

&l:keywordprg = ':TerraformDoc'
command! -buffer -nargs=* TerraformDoc TerraformDoc(<q-args>)

def TerraformDoc(...arg: list<string>)
    const line = getline('.')
    var type = ''
    if line->match('resource\s\+"') >= 0
        type = 'resources'
    endif
    if line->match('data\s\+"') >= 0
        type = 'data-sources'
    endif
    if !empty(type)
        const resource_long_name = line->matchstr('\v(resource|data)\s+"\zs[^"]+\ze')
        if !empty(resource_long_name)
            const idx = resource_long_name->match('_')
            const provider = resource_long_name[: idx - 1]
            const resource = resource_long_name[idx + 1 :]
            const group = {
                alicloud: 'aliyun',
                dyn: 'terraform-providers',
                vultr: 'vultr',
                grafana: 'grafana',
            }->get(provider, 'hashicorp')
            const url = $'https://registry.terraform.io/providers/{group}/{provider}/latest/docs/{type}/{resource}'
            execute 'Sh -g' shellescape(url)
        endif
    else
        if exists(':LspHover') == 2
            execute 'LspHover'
        endif
    endif
enddef

# override vim's builtin terraform ftplugin.
for terraform_ftlugin in [
        globpath($VIMRUNTIME, 'ftplugin/terraform.vim'),
        globpath(expand('~/vimfiles/pack'), '*/opt/vim-terraform/ftplugin/terraform.vim'),
        ]
    if terraform_ftlugin->filereadable()
        silent! unlet b:did_ftplugin
        exec 'source' terraform_ftlugin->fnameescape()
    endif
endfor
