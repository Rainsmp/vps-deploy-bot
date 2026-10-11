#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
if [[ -f .env ]]; then
 echo "Configuration keys (values hidden):"
 sed 's/=.*//' .env
 echo "Use option 2 to update settings."
else
 echo "No configuration. Choose option 2."
fi
