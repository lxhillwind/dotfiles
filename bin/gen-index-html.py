#!/usr/bin/env python3

"""
usage:
    $0

add symbolic link to a html file or folder in ~/html, then call this script;
then ~/html/index.html will contain link (<a />) to these files.
"""

import os

import yaml
import jinja2


template = """
<!DOCTYPE html>
<html>
    <head>
        <title>local index page</title>
    </head>
    <body>
        <style>
        a {
            font-size: xx-large;
        }
        </style>
        {% for item in paths %}
        <a href='{{ item.path }}'>{{ item.name }}</a>
        <br>
        {% endfor %}
    </body>
</html>
"""

os.chdir(os.path.expanduser('~/html'))

# config example:
# ```yaml
# <file_or_folder_basename>:
#   name: <str_to_show>  # optional
#   index: <path_to_concat_folder_path>  # optional; example: doc/index.html
# ```
config_path = 'config.yml'
if os.path.exists(config_path):
    with open(config_path) as f:
        config = yaml.load(f, Loader=yaml.SafeLoader)
else:
    config = {}

paths = []
for p in sorted(os.listdir('.')):
    path = p
    if os.path.islink(path):
        if os.path.isdir(path):
            for i in [config.get(p, {}).get('index'), 'index.html', 'index.htm']:
                if not i:
                    continue
                # use normpath to allow ../ in index (config.yml)
                index = os.path.normpath(os.path.join(path, i))
                if os.path.exists(index):
                    path = index
                    break
        paths.append({
            'path': path,
            'name': config.get(p, {}).get('name') or p,
            })

with open('index.html', 'w') as f:
    f.write(jinja2.Template(template).render(paths=paths))
