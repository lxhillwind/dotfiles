#!/usr/bin/env python3

'''
reverse of http-serve
'''

import os
from flask import request, abort, Flask
from werkzeug.utils import secure_filename

app = Flask(__name__)
cwd = os.getcwd()


@app.route('/', methods=['GET', 'POST'])
def root():
    response = f'''
        current dir: {cwd}
        <hr />
        <form method="POST" enctype="multipart/form-data">
        <input type="file" name="files" id="files" accept="*/*" multiple>
        <hr />
        <button type="submit">upload</button>
        </form>
        '''
    if request.method == 'POST':
        for obj in request.files.getlist('files'):
            name = secure_filename(obj.filename)
            print(f'upload {name}...')
            obj.save(name)
            response = f'uploaded: {name}<br />' + response
    return response


if __name__ == '__main__':
    print(f'\x1b[1;36mcwd: {cwd}\x1b[0m')
    app.run('localhost', port=8000)
