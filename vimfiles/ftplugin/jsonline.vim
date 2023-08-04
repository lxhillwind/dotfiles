vim9script

# TODO impl
syntax include @json syntax/json.vim
syntax region jsonL start=/\v^[^#]/ keepend end=/$/ contains=@json
