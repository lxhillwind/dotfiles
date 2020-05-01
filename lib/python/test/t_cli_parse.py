import unittest
import uuid
import shlex
import dataclasses
import typing
from serde.cli_parser import cli_parse, option


class TestSerde(unittest.TestCase):
    def test_parse_simple(self):
        @dataclasses.dataclass
        class Foo:
            school: typing.List[str] = option(short=True, nargs=3)
            name: bool = None

        self.assertEqual(
                cli_parse(Foo, shlex.split('-s 2 --name 0 -s -- -- --school ')).school,
                ['2', '--', '--school']
                )

        Cli_1 = dataclasses.make_dataclass('Cli_1', [('x', typing.List[str])])
        with self.assertRaises(ValueError):
            _ = cli_parse(Cli_1, [])
        Cli_2 = dataclasses.make_dataclass('Cli_2', [('x', typing.Optional[typing.List[str]])])
        self.assertEqual(cli_parse(Cli_2, []), Cli_2(x=None))
        Cli_3 = dataclasses.make_dataclass(
                'Cli_3',
                [('x', typing.List[str], dataclasses.field(default_factory=list))]
                )
        self.assertEqual(cli_parse(Cli_3, []), Cli_3(x=[]))

    def test_parse_complex(self):
        @dataclasses.dataclass
        class DB:
            host: str
            username: str
            port: int = 3306

        @dataclasses.dataclass
        class Cli:
            id: uuid.UUID
            db: DB
            fork: bool = option(flag=True)  # option(...) also returns a dataclasses.Field
            input: typing.Optional[typing.List[str]]  # accepts multiple arguments (>=0)
            output: str = dataclasses.field(default='output.txt', metadata={'help': 'output file name'})
            verbose: int = 0

        cli = cli_parse(
                Cli,
                shlex.split(f'--db username=hello --id {uuid.uuid1()} --db host=localhost'),
                type_table={uuid.UUID: uuid.UUID},
                )
        self.assertEqual(cli.output, 'output.txt')
        self.assertEqual(cli.db.username, 'hello')
