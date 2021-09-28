import json
import functools
import os
import sys
import traceback
import inspect
import typing
import asyncio


_global_id = 0
_global_resp = {}


async def _gen_future():
    """returns msg id and future"""
    loop = asyncio.get_running_loop()
    global _global_id
    _global_id += 1
    fut = loop.create_future()
    _global_resp[_global_id] = fut
    return (_global_id, fut)


class VimException(Exception):
    pass


class _Cmd:
    def __init__(self, c):
        self.c = c

    async def __call__(self, cmd: str, *args) -> None:
        payload = {'op': 'cmd', 'cmd': ' '.join([cmd, *args])}
        await self.c._eval(payload)

    async def __getattr__(self, key):
        return await functools.partial(self.__call__, key)


class _Fn:
    def __init__(self, c):
        self.c = c

    async def __call__(self, cmd: str, *args):
        payload = {'op': 'fn', 'cmd': cmd, 'args': args}
        return await self.c._eval(payload)

    def __getattr__(self, key):
        return functools.partial(self.__call__, key)


class Client:
    def __init__(self):
        pass

    def _print(self, obj):
        sys.stdout.write(json.dumps(obj) + '\n')

    def _exception(self, msg, stack):
        self._print({
            'op': 'raise', 'cmd': '',
            'args': [msg, stack]
            })

    async def _loop(self, worker):
        """NOTE: worker is a class"""
        self.worker = worker(self)

        funcs = {
                i[0]: i[1].__doc__ or ''
                for i in inspect.getmembers(worker, predicate=inspect.isfunction)
                if not i[0].startswith('_')
                }
        # completion register
        self._print({'op': 'completion', 'args': [funcs]})

        loop = asyncio.get_event_loop()

        is_posix = os.name == 'posix'
        if is_posix:
            reader = asyncio.StreamReader()
            protocol = asyncio.StreamReaderProtocol(reader)
            await loop.connect_read_pipe(lambda: protocol, sys.stdin)

        # used in stdio server
        while True:
            if is_posix:
                data = await reader.readline()
            else:
                # NOTE it doesn't work on Linux, but works on Windows (thinpc).
                data = await loop.run_in_executor(None, sys.stdin.readline)

            if len(data.strip()) == 0:
                continue
            try:
                data = json.loads(data)
            except KeyboardInterrupt:
                sys.exit(-2)
            except:
                self._exception('invalid data: %s' % data, traceback.format_exc())
                continue

            task = asyncio.create_task(self._handle(data))
            task.add_done_callback(self._handle_fut_ex)

    def _handle_fut_ex(self, fut):
        try:
            fut.result()
        except Exception as e:
            self._exception(str(e), traceback.format_exc())

    async def _handle(self, data):
        op = data.get('op')
        if op == 'response':
            resp = data['args'][0]
            fut = _global_resp.pop(resp['id'], None)
            if asyncio.isfuture(fut) and not fut.done():
                if resp['code'] == 0:
                    fut.set_result(resp['data'])
                else:
                    fut.set_exception(VimException(resp['data']))
            return
        elif op:
            args = data.get('args')
            if isinstance(args, list):
                if hasattr(self.worker, op):
                    await getattr(self.worker, op)(*args[:-1], **args[-1])
                    return
        self._exception(f'unknown method: {op or ""}', 'raw data: %s' % data)

    async def _eval(self, obj):
        id_, fut = await _gen_future()

        # send
        self._print(dict(obj, id=id_))
        return await fut

    @property
    def cmd(self):
        """return None"""
        return _Cmd(self)

    async def key(self, cmd: str) -> None:
        payload = {'op': 'key', 'cmd': cmd}
        await self._eval(payload)

    async def eval(self, cmd: str):
        """return Any"""
        payload = {'op': 'eval', 'cmd': cmd}
        return await self._eval(payload)

    async def execute(self, cmd: str) -> typing.List[str]:
        payload = {'op': 'execute', 'cmd': cmd}
        return await self._eval(payload)

    @property
    def fn(self):
        """return Any"""
        return _Fn(self)


class Worker:
    def __init__(self, client: Client):
        self.client = client

    async def help(self):
        """a dummy method"""
        pass

    async def restart(self):
        """a dummy method"""
        pass


class Proxy:
    _client = None

    def _register(self, client):
        self._client = client
        # use it only once.
        # TODO impl it.
        #object.__delattr__(self, 'register')

    def __getattr__(self, key):
        return getattr(self._client, key)


vim: Client = Proxy()
