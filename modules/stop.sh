#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
if [[ -f .bot.pid ]] && kill -0 "$(cat .bot.pid)" 2>/dev/null; then
 kill "$(cat .bot.pid)" && rm -f .bot.pid
 echo "Bot stopped."
else
 rm -f .bot.pid; echo "Bot is not running."
fi
