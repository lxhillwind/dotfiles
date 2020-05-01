#!/usr/bin/env python3

import dataclasses
import typing
import copy

__all__ = ['parse', 'dumps']

T = typing.TypeVar('T')

default_type_table = dict(
        {k: None for k in [bool, float, int, str, list, dict]}
        )


# TODO use dataclass?
class ParseError(ValueError):
    def __init__(self,
            field: str = None,
            type: typing.Any = None,
            value: typing.Any = dataclasses.MISSING,
            msg: str = None,
            source: Exception = None
            ):
        error_info = {}
        if type:
            error_info['type'] = type
        if value is not dataclasses.MISSING:
            error_info['value'] = value
        if field:
            error_info['field'] = field
        if msg:
            error_info['msg'] = msg
        if source:
            error_info['source'] = source
        self.args = (error_info,)


def parse(cls: T, value: typing.Any, type_table: dict = None) -> T:
    kwargs = dict(
            type_table=type_table
            )
    mixed_type_table = copy.copy(default_type_table)
    mixed_type_table.update(type_table or {})

    v = value
    generic = typing.get_origin(cls)
    if generic:
        args = typing.get_args(cls)
        if generic is typing.Union:
            if args[1] == type(None):
                if v is None:
                    return None
                else:
                    try:
                        return parse(args[0], v, **kwargs)
                    except Exception as e:
                        raise ParseError(type=cls, value=v, source=e) from None
            else:
                raise ParseError(
                        type=cls, value=v,
                        msg='typing.Union is not supported'
                        )
        elif generic is dict:
            if not isinstance(v, dict):
                raise ParseError(
                        type=cls, value=v,
                        msg='is not dict'
                        )
            return {
                    parse(args[0], s_k, **kwargs): parse(args[1], s_v, **kwargs)
                    for s_k, s_v in v.items()
                }
        elif generic is list:
            if not isinstance(v, list):
                raise ParseError(
                        type=cls, value=v,
                        msg='is not list'
                        )
            return [parse(args[0], s_i, **kwargs) for s_i in v]
        else:
            raise ParseError(
                    type=cls, value=v,
                    msg='type is not supported'
                    )

#    if v is None:
#        raise ParseError(
#                type=cls, value=v,
#                msg='value is missing'
#                )
#
    if cls in mixed_type_table:
        if not isinstance(v, cls) and callable(mixed_type_table[cls]):
            v = mixed_type_table[cls](v)
        if isinstance(v, cls):
            return v
        else:
            raise ParseError(
                    type=cls, value=value,
                    msg='type not match'
                    )
    elif dataclasses.is_dataclass(cls) and isinstance(cls, type):
        result = {}
        for item in dataclasses.fields(cls):
            k = item.name
            spec = item.type
            if k in value:
                v = value[k]
            else:
                if item.default_factory is not dataclasses.MISSING:
                    result[k] = item.default_factory()
                    continue
                elif item.default is not dataclasses.MISSING:
                    result[k] = item.default
                    continue
                else:
                    # TODO handle optional type
                    #raise ParseError(field=k, type=spec, msg='field is missing')
                    v = None
            try:
                result[k] = parse(spec, v, **kwargs)
            except Exception as e:
                raise ParseError(field=k, type=spec, value=v, source=e) from None
        return cls(**result)
    else:
        raise ParseError(
                type=cls, value=value,
                msg='unsupported type'
                )


def dumps(obj: typing.Any, type_table: dict = None):
    kwargs = dict(
            type_table=type_table
            )
    mixed_type_table = copy.copy(default_type_table)
    mixed_type_table.update(type_table or {})

    if obj is None:
        return obj
    elif isinstance(obj, list):
        return [dumps(i, **kwargs) for i in obj]
    elif isinstance(obj, dict):
        return {dumps(k, **kwargs): dumps(v, **kwargs) for k, v in obj.items()}
    elif type(obj) in mixed_type_table:
        converter = mixed_type_table[type(obj)]
        if callable(converter):
            return converter(obj)
        else:
            return obj
    elif dataclasses.is_dataclass(obj) and not isinstance(obj, type):
        return dumps(dataclasses.asdict(obj), **kwargs)
    else:
        raise ValueError('unsupported type: %s; value: %s' % (type(obj), obj))
