#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
bash modules/stop.sh
sleep 1
exec bash modules/start.sh
