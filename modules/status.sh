#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
if [[ -f .bot.pid ]] && kill -0 "$(cat .bot.pid)" 2>/dev/null; then
 echo "Bot RUNNING (PID $(cat .bot.pid))"
else
 echo "Bot STOPPED"
fi
[[ -f .env ]] && echo "Configuration: present" || echo "Configuration: missing"
[[ -f logs/console.log ]] && tail -n 12 logs/console.log
