#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
mkdir -p logs
touch logs/console.log
tail -n 60 -f logs/console.log
