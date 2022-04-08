# vim:ft=python
# path: ~/vimfiles/config/pyvim.py

import os
import pathlib
import textwrap
import asyncio
import typing
import shlex
from pyvim.libvim import Worker as BaseWorker, vim

# this file may be loaded with exec(), so __file__ can't be used to get cwd.
# so use python process startup cwd (set in plugin/server.vim) and join pyvim.
CWD = pathlib.Path().cwd().joinpath('pyvim')

PYVIM_RC = os.getenv('PYVIM_RC')


class Worker(BaseWorker):

    # it's recommended to keep the config method defined below in "worker.py",
    # then you can open it easily.
    #
    # you can define more methods in this class, and they will appear once
    # the python process is reloaded (restart vim or `:Py3 restart`).

    async def config(self, _args: str, bang: bool = False):
        """open worker.py (pyvim user config file)"""
        config_file = CWD.joinpath('worker.py')
        if PYVIM_RC:
            config_file = pathlib.Path(PYVIM_RC)
        f_exists = config_file.exists()
        f_escaped = await vim.fnameescape(str(config_file))
        f_editcmd = 'e' if bang else 'tabe'
        await vim.executecute(f_editcmd + ' ' + f_escaped)
        if not f_exists:
            content = textwrap.dedent('''\
                # This file is generated from "worker.py.example";
                # once you save this file ("worker.py") to disk,
                # `:Py3` command will load worker.py instead of worker.py.example.
            ''')
            content += '\n'
            with CWD.joinpath('worker.py.example').open() as f:
                content += f.read()
            await vim.append('$', content.rstrip('\n').split('\n'))

    async def eval(self, args: str, range: int = 0, line1: int = 0, line2: int = 0):
        """eval range selection or string after `:Py3 eval`."""
        if range in (1, 2):
            args = '\n'.join(await vim.getline(line1, line2))
        func = 'async def _local():\n' + textwrap.indent(args, ' ' * 4)
        exec(func)
        await locals()['_local']()

    async def dirlist(self, args, **kwargs):
        if await vim.eval('&ft') != 'dirlist':
            await vim.execute('setl buftype=nofile')
            await vim.execute('setl ft=dirlist')
            await vim.execute('nnoremap <buffer> - <cmd>Py3 dirlist %:h<CR>')
            await vim.execute('nnoremap <buffer> i <cmd>Py3 dirlist <line><CR>')
        if len(args) > 0:
            dirname = args
        else:
            dirname = '%'

        if dirname == '<line>':
            path = await vim.fnamemodify(await vim.getline('.'), ':p')
        else:
            path = await vim.fnamemodify(await vim.expand(dirname), ':p')

        import pathlib
        path = pathlib.Path(path)
        if not path.exists():
            await vim.execute('echohl WarningMsg | echomsg "file not exists!" | echohl None')
            return
        if not path.is_dir():
            await vim.execute(f'e %s' % await vim.fn.fnameescape(str(path)))
            return
        result = [
                f'{i}/' if i.is_dir() else f'{i}'
                for i in path.iterdir()
                ]
        await vim.execute('noswapfile file %s' % await vim.fnameescape(str(path)))
        await vim.deletebufline('', 1, '$')
        await vim.append(0, result)
        await vim.deletebufline('', '$')

    async def term(self, args):
        buf = await vim.term_start(shlex.split(args) if args else ['/bin/zsh'], {
            'hidden': 1, 'term_finish': 'close'
            })
        await vim.popup_create(buf, {
            'minwidth': 80, 'minheight': 24,
            'maxwidth': 80, 'maxheight': 24,
            'border': [],
            })


async def test_performance(self: Worker, arg):
    import datetime
    now = datetime.datetime.now()
    import json
    arg = int(arg)
    print(len(json.dumps(await vim.range(arg), ensure_ascii=False)))
    await vim.execute('legacy let g:MyFoo = 0')
    for i in await vim.range(arg):
        await vim.execute('legacy let g:MyFoo += %s' % i)
    now_1 = datetime.datetime.now()
    print(now, await vim.eval('g:MyFoo'), now_1 - now)


Worker.test_performance = test_performance
