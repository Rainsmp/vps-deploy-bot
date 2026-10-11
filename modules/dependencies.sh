#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/vps-deploy-bot"
[[ -x venv/bin/python ]] || { echo "Run option 1 first."; exit 1; }
venv/bin/python -m pip install -r requirements-termux.txt
venv/bin/python -m pip check
