"""
@dataclasses.dataclass
class Cli:
    id: uuid.UUID
    input: typing.List[str]  # accepts multiple arguments (>=0)
    output: str = dataclasses.field(metadata={'help': 'output file name'})
    fork: bool = option(flag=True)  # option(...) also returns a dataclasses.Field
    verbose: int = 0


args: Cli = cli_parse(
    Cli,
    sys.argv[1:],
    type_table={uuid.UUID: uuid.UUID},
    )
"""

import copy
import typing
import enum
import dataclasses
from collections import defaultdict

from .base import parse

__all__ = ['cli_parse', 'option']

T = typing.TypeVar('T')
default_type_table = {
        str: None,
        bool: lambda x: str(x).lower() in ['1', 'yes', 'on', 'true'],
        int: int, float: float,
        }


def option(
        short=False, long=True,
        nargs : int = None, flag=False, occurence=False,
        collector=False,  # collect positional argument
        **kwargs
        ) -> dataclasses.Field:
    return dataclasses.field(**kwargs, metadata=dict(
        short=short, long=long,
        nargs=nargs, flag=flag, occurence=occurence,
        ))


def extract_optional(cls) -> (typing.Any, bool):
    is_optional = False
    while True:
        generic = typing.get_origin(cls)
        if generic is typing.Union:
            sub_1, sub_2 = typing.get_args(cls)
            if sub_2 is type(None):
                is_optional = True
                cls = sub_1
            else:
                break
        else:
            break
    return cls, is_optional


@enum.unique
class Expect(enum.Enum):
    OPTION = 0
    ARGUMENT = 1
    BOTH = 2


def cli_parse(cls: T, args: typing.List[str], type_table: dict = None) -> T:
    mixed_type_table = copy.copy(default_type_table)
    mixed_type_table.update(type_table or {})
    args_dict = {}
    field_dict = {item.name: item for item in dataclasses.fields(cls)}

    alias_dict = {}
    for item in field_dict.values():
        if item.metadata.get('short'):
            if item.name[0] in alias_dict:
                raise ValueError('duplicate short option: %s, %s'
                        % (alias_dict[item.name[0]], item.name))
            alias_dict[item.name[0]] = item.name
        if item.metadata.get('occurence'):
            args_dict[item.name] = 0

    collector = None
    for item in field_dict.values():
        if item.metadata.get('collector'):
            if collector:
                raise ValueError('duplicate collector: %s, %s'
                        % (collector, item.name))
            collector = item.name
            args_dict[collector] = []

    double_slash = False
    pointer = None
    if collector:
        state = Expect.BOTH
    else:
        state = Expect.OPTION
    for arg in args:
        # handle option: -x, -xyz, --x...
        if len(arg) > 1 and not double_slash and arg[0] == '-':
            if arg == '--':
                double_slash = True
                continue
            if state == Expect.ARGUMENT:
                raise ValueError('expect argument (for %s), get %s'
                        % (pointer, arg))
            if arg[1] == '-':
                options = [arg[2:]]
            else:
                options = []
                for short in arg[1:]:
                    if short not in alias_dict:
                        raise ValueError('unexpected short option: %s'
                                % short)
                    options.append(alias_dict[short])
            for name in options:
                if name not in field_dict:
                    raise ValueError('unexpected option: %s'
                            % name)
                pointer = None
                metadata = field_dict[name].metadata
                if metadata.get('flag'):
                    args_dict[name] = True
                elif metadata.get('occurence'):
                    args_dict[name] += 1
                else:
                    pointer = name
                    state = Expect.ARGUMENT
        # handle argument
        else:
            if state == Expect.OPTION:
                raise ValueError('expect option, get %s'
                        % arg)
            if pointer is None:
                if collector:
                    args_dict[collector].append(arg)
                else:
                    # if state is not Expect.OPTION, then
                    # either pointer or collector is not none.
                    raise ValueError('BUG in cli_parser: #1')
            else:
                if pointer not in args_dict:
                    field_type, _ = extract_optional(field_dict[pointer].type)
                    generic = typing.get_origin(field_type)
                    if generic:
                        if generic is list:
                            args_dict[pointer] = []
                        elif generic is dict:
                            args_dict[pointer] = {}
                        else:
                            # let parse(...) to handle default value
                            args_dict[pointer] = None
                    else:
                        if field_type is list:
                            args_dict[pointer] = []
                        elif field_type is dict or dataclasses.is_dataclass(field_type):
                            args_dict[pointer] = {}
                        else:
                            # TODO support more container type?
                            args_dict[pointer] = None
                if isinstance(args_dict[pointer], list):
                    args_dict[pointer].append(arg)
                    nargs = field_dict[pointer].metadata.get('nargs')
                    if len(args_dict[pointer]) == nargs:
                        pointer = None
                        if collector:
                            state = Expect.BOTH
                        else:
                            state = Expect.OPTION
                    else:
                        state = Expect.BOTH
                elif isinstance(args_dict[pointer], dict):
                    try:
                        k, v = arg.split('=', maxsplit=1)
                    except ValueError:
                        raise ValueError('expect key=value (for %s), found %s'
                                % (pointer, arg))
                    args_dict[pointer][k] = v
                    state = Expect.BOTH
                else:
                    args_dict[pointer] = arg
                    pointer = None
                    if collector:
                        state = Expect.BOTH
                    else:
                        state = Expect.OPTION
    if state == Expect.ARGUMENT:
        raise ValueError('expect argument (for %s), no more argument left'
                % pointer)
    # pre check / init (which is not doable in parse function)
    for item in field_dict.values():
        nargs = item.metadata.get('nargs')
        if isinstance(nargs, int):
            if not isinstance(args_dict.get(item.name), list):
                raise ValueError('"nargs" option can not be used on type %s (for %s)'
                        % (type(args_dict.get(item.name)), item.name))
            if nargs != len(args_dict[item.name]):
                raise ValueError('expect %s argument, found %s (for %s)'
                        % (nargs, len(args_dict[item.name]), item.name))
        if item.metadata.get('flag'):
            if item.name not in args_dict:
                args_dict[item.name] = False
    return parse(cls, args_dict, type_table=mixed_type_table)
