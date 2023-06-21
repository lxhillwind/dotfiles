vim9script

const coc_settings_default =<< END
{
    "suggest.noselect": true,
    "languageserver": {
        "zig": {
            "command": "zls",
            "filetypes": ["zig"]
        }
    }
}
END

const coc_settings_file = expand('~/.vim/coc-settings.json')
if !coc_settings_file->filereadable()
    coc_settings_default->writefile(coc_settings_file)
    echo 'vimrc: ~/.vim/coc-settings.json is not found. created a default one.'
endif
