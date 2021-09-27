import json
import functools
import sys
import traceback
import inspect
import typing


_global_id = 0
def GenId():
    global _global_id
    _global_id += 1
    return _global_id


class VimException(Exception):
    pass


class _Cmd:
    def __init__(self, c):
        self.c = c

    def __call__(self, cmd: str, *args) -> None:
        payload = {'op': 'cmd', 'cmd': ' '.join([cmd, *args])}
        self.c._eval(payload)

    def __getattr__(self, key):
        return functools.partial(self.__call__, key)


class _Fn:
    def __init__(self, c):
        self.c = c

    def __call__(self, cmd: str, *args):
        payload = {'op': 'fn', 'cmd': cmd, 'args': args}
        return self.c._eval(payload)

    def __getattr__(self, key):
        return functools.partial(self.__call__, key)


class Client:
    def __init__(self):
        pass

    def _read_data(self):
        while True:
            data = sys.stdin.readline()
            try:
                return json.loads(data)
            except KeyboardInterrupt:
                sys.exit(-2)
            except:
                print('invalid data:', data)
                traceback.print_exc(file=sys.stdout)

    def _loop(self, worker):
        """NOTE: worker is a class"""
        self.worker = worker(self)

        funcs = {
                i[0]: i[1].__doc__ or ''
                for i in inspect.getmembers(worker, predicate=inspect.isfunction)
                if not i[0].startswith('_')
                }
        # completion register
        print(json.dumps({'op': 'completion', 'args': [funcs]}) + '\n')

        # used in stdio server
        while True:
            try:
                self._handle(self._read_data())
            except KeyboardInterrupt:
                sys.exit(-2)
            except:
                traceback.print_exc(file=sys.stdout)

    def _handle(self, data):
        op = data.get('op')
        if op:
            args = data.get('args')
            if isinstance(args, list):
                if hasattr(self.worker, op):
                    getattr(self.worker, op)(*args[:-1], **args[-1])
                    return
        print('unknown cmd: %s' % data, file=sys.stderr)

    def _eval(self, obj):
        id_ = GenId()
        # send
        print(json.dumps(dict(obj, id=id_)) + '\n')

        while True:
            data = self._read_data()
            if data['op'] == 'response':
                resp = data['args'][0]
                if resp['code'] == 0:
                    return resp['data']
                else:
                    raise VimException(resp['data'])
            # throw other data away.
            # TODO impl async (await) logic.
            #else:
            #    self._handle(data)

    @property
    def cmd(self):
        """async"""
        return _Cmd(self)

    def key(self, cmd: str) -> None:
        """async"""
        payload = {'op': 'key', 'cmd': cmd}
        self._eval(payload)

    def eval(self, cmd: str):
        """sync"""
        payload = {'op': 'eval', 'cmd': cmd}
        return self._eval(payload)

    def execute(self, cmd: str) -> typing.List[str]:
        """sync"""
        payload = {'op': 'execute', 'cmd': cmd}
        return self._eval(payload)

    @property
    def fn(self):
        """sync"""
        return _Fn(self)


class Worker:
    def __init__(self, client: Client):
        self.client = client

    def help(self):
        """a dummy method"""
        pass

    def restart(self):
        """a dummy method"""
        pass
