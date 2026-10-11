#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
cd "$HOME/vps-deploy-bot"
python -m venv venv 2>/dev/null || true
venv/bin/python -m pip install -r requirements-termux.txt
mkdir -p logs
echo "Dependencies installed."
