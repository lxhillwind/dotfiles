#!/usr/bin/env python3


'''
share text between host and guest.

refresh to get updated text; modify text to update text on the server.
'''


import argparse
import subprocess

import flask
import jinja2


GLOBAL_OPTION = {}


index = '''
<!DOCTYPE html>
<html>
<head>
</head>
<body>
<textarea readonly rows=32 cols=128 id='main' v-model='content' v-on:input='text'>{{ content }}</textarea>
{% raw %}
<script src="https://cdn.jsdelivr.net/npm/vue/dist/vue.js"></script>
<script>
fetch('/api').then(s => s.json()).then(s => {
    let el = document.querySelector('#main');
    el.removeAttribute('readonly');
    el.innerHTML = '{{ content }}';
    new Vue({
        el: '#main',
        data: {
            content: s.text,
        },
        methods: {
            text: function() {
                console.log(this.content);
                fetch('/api', {
                    method: 'POST',
                    headers: {'content-type': 'application/json'},
                    body: JSON.stringify({'text': this.content}),
                }).then(s => s.text()).then(s => {
                    console.log(s);
                });
            }
        }
    });
});
</script>
{% endraw %}
</body>
</html>
'''

clipboard = {'content': ''}


app = flask.Flask(__name__)


def pbcopy():
    if not GLOBAL_OPTION['clipboard']:
        return
    s = clipboard['content']
    subprocess.run(['pbcopy'], input=s, text=True, check=True, capture_output=True).stdout


def pbpaste():
    if not GLOBAL_OPTION['clipboard']:
        return
    clipboard['content'] = subprocess.check_output(['pbpaste'], text=True)


@app.route('/')
def root():
    pbpaste()
    return jinja2.Template(index).render(content=clipboard.get('content'))


@app.route('/http-board-ping')
def ping():
    return flask.jsonify({'ok': 1})


@app.route('/raw')
def raw():
    pbpaste()
    return clipboard['content']


@app.route('/api', methods=['POST', 'GET'])
def api():
    print(clipboard['content'])
    if flask.request.method == 'POST':

        data = flask.request.get_json()
        if data:
            clipboard['content'] = data.get('text')
            pbcopy()
            return 'ok'

        data = flask.request.form
        if data:
            clipboard['content'] = data.get('text')
            pbcopy()
            return 'ok'

        return 'err'
    else:
        pbpaste()
        return flask.jsonify({'text': clipboard['content']})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('port', type=int, default=8000, nargs='?')
    parser.add_argument('-c', '--clipboard', action='store_true', help='using system clipboard')
    args = parser.parse_args()
    GLOBAL_OPTION['clipboard'] = args.clipboard
    app.run(host='localhost', port=args.port)


if __name__ == '__main__':
    main()
