#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/vps-deploy-bot"
[[ -x venv/bin/python ]] || { echo "Choose option 1 first."; exit 1; }
[[ -f .env ]] || { echo "Choose option 2 first."; exit 1; }
if [[ -f .bot.pid ]] && kill -0 "$(cat .bot.pid)" 2>/dev/null; then
 echo "Bot already running."; exit 0
fi
mkdir -p logs
nohup venv/bin/python bot.py >> logs/console.log 2>&1 </dev/null &
echo "$!" > .bot.pid
sleep 2
if kill -0 "$(cat .bot.pid)" 2>/dev/null; then
 echo "Bot started. PID $(cat .bot.pid)"
else
 echo "Bot failed. Recent logs:"
 tail -n 30 logs/console.log
 exit 1
fi
