import unittest
from dataclasses import dataclass
import typing
import uuid
import datetime
from serde import parse, dumps


class TestParse(unittest.TestCase):
    def test_parse_simple(self):
        s1 = uuid.uuid1()
        self.assertEqual(parse(uuid.UUID, str(s1), type_table={uuid.UUID: uuid.UUID}), s1)
        with self.assertRaises(ValueError):
            _ = parse(int, '3')
        self.assertEqual(parse(int, '3', type_table={int: int}), 3)

    def test_parse_none(self):
        with self.assertRaises(ValueError):
            _ = parse(None, None)
        with self.assertRaises(ValueError):
            _ = parse(None, 3)
        with self.assertRaises(ValueError):
            _ = parse(int, None)
        self.assertEqual(parse(typing.Optional[bool], None), None)
        self.assertEqual(parse(typing.Optional[str], '3'), '3')
        self.assertEqual(parse(typing.Optional[typing.Optional[typing.Optional[str]]], '3'), '3')
        with self.assertRaises(ValueError):
            _ = parse(typing.Optional[str], 3)
        with self.assertRaises(ValueError):
            _ = parse(typing.Optional[typing.Optional[str]], 3)

    def test_parse_complex(self):
        @dataclass
        class School:
            region: str
            country: typing.Optional[typing.Dict[int, typing.List[typing.Optional[str]]]]
            created: datetime.datetime

        @dataclass
        class Foo:
            name: str
            school: typing.Optional[School]
            age: int = 7

        s = parse(
                Foo,
                {'name': 'Alice', 'age': 233},
                type_table={datetime.datetime: datetime.datetime.fromtimestamp}
                )
        self.assertEqual(s.age, 233)
        self.assertIsNone(s.school)
        s = parse(
                Foo,
                {
                    'name': 'Alice', 'age': 233,
                    'school': {'region': '??', 'country': {2: [], 3: ['???', None]}, 'created': 1585670400}
                },
                type_table={datetime.datetime: datetime.datetime.fromtimestamp}
                )
        self.assertEqual(s.school.created, datetime.datetime(2020, 4, 1))
        self.assertEqual(s.school.country[3].count('???'), 1)

    def test_generic(self):
        @dataclass
        class Foo:
            name: typing.List[str]
            region: typing.Dict[str, str] = None
        with self.assertRaises(ValueError):
            _ = parse(Foo, {})
        self.assertEqual(parse(Foo, {'name': []}), Foo(name=[], region=None))
        @dataclass
        class Foo:
            name: typing.List[str]
            region: typing.Dict[str, str]
        with self.assertRaises(ValueError):
            _ = parse(Foo, {'name': []})


class TestDumps(unittest.TestCase):
    def test_dumps_simple(self):
        self.assertEqual(dumps(None), None)
        s = uuid.uuid1()
        self.assertEqual(dumps(s, type_table={uuid.UUID: str}), str(s))
        with self.assertRaises(ValueError):
            _ = dumps(s)

    def test_dumps_complex(self):
        @dataclass
        class School:
            region: str
            country: typing.Optional[typing.Dict[int, typing.List[typing.Optional[str]]]]
            created: datetime.datetime

        @dataclass
        class Foo:
            name: str
            school: typing.Optional[School]
            age: int = 7

        self.assertEqual(
                dumps(
                    Foo(name='Alice', age=233, school=None),
                    type_table={datetime.datetime: datetime.datetime.fromtimestamp}
                    ),
                {'name': 'Alice', 'age': 233, 'school': None}
            )

        s2 = {
                'name': 'Alice', 'age': 233,
                'school': {'region': '??', 'country': {2: [], 3: ['???', None]}, 'created': 1585670400}
                }
        self.assertEqual(
                dumps(
                    parse(
                        Foo,
                        s2,
                        type_table={datetime.datetime: datetime.datetime.fromtimestamp}
                        ),
                    type_table={datetime.datetime: lambda i: int(i.strftime('%s'))}
                    ),
                s2
                )
