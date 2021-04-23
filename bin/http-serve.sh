#!/bin/sh
echo
pwd
echo
ip a | grep -w inet
echo
python -m http.server 8000
