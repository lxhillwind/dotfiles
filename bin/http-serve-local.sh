#!/bin/sh
echo
pwd
echo
python -m http.server --bind 127.0.0.1 "${1:-8000}"
