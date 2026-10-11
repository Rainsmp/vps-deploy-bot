#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
read -r -p "Stop bot and remove venv/logs? [y/N] " answer
case "$answer" in
 y|Y) bash modules/stop.sh || true; rm -rf venv logs .bot.pid; echo "Runtime removed; source and .env kept." ;;
 *) echo "Cancelled." ;;
esac
