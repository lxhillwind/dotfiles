#!/usr/bin/env python3

"""
used by vim System() function.
"""


import subprocess
import argparse
from flask import Flask, request, jsonify


# value type: bool() will executed; callable() will be called; otherwise ignored.
whitelist = {
        'pbcopy': 1, 'pbpaste': 1,
        'urlencode': 1, 'urldecode': 1,
        }

app = Flask(__name__)


@app.route('/', methods=['POST'])
def index():
    req = request.json
    if isinstance(req, dict):
        cmd, stdin = req.get('cmd'), req.get('input')
        if not cmd:
            return jsonify({'exit_code': -1, 'stderr': '`cmd` is missing'})
        if not whitelist.get(cmd):
            return jsonify({'exit_code': -1, 'stderr': '`cmd` not in whitelist'})
        opts = {}
        if callable(whitelist[cmd]):
            try:
                return jsonify({'exit_code': 0, 'stdout': whitelist[cmd](stdin)})
            except Exception as e:
                return jsonify({'exit_code': -1, 'stderr': str(e)})
        if stdin is None:
            opts['stdin'] = subprocess.PIPE
        p = subprocess.run([cmd], timeout=3, input=stdin, text=True, capture_output=True, **opts)
        return jsonify({'exit_code': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr})
    else:
        return jsonify({'exit_code': -1, 'stderr': 'payload is not dict'})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='localhost')
    parser.add_argument('--port', '-p', type=int, default=8001)
    args = parser.parse_args()
    app.run(host=args.host, port=args.port)


if __name__ == '__main__':
    main()
