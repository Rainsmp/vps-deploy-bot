#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/vps-deploy-bot"
touch .env
chmod 600 .env
read -r -s -p "Discord bot token: " TOKEN; echo
[[ -n "$TOKEN" ]] || { echo "Token cannot be empty"; exit 1; }
read -r -p "Discord owner user ID: " OWNER
[[ "$OWNER" =~ ^[0-9]+$ ]] || { echo "Owner ID must be numeric"; exit 1; }
read -r -p "Command prefix [!]: " PREFIX
PREFIX="${PREFIX:-!}"
python - "$TOKEN" "$OWNER" "$PREFIX" <<'PY'
import pathlib,sys
p=pathlib.Path(".env")
d={}
for line in p.read_text().splitlines():
    if "=" in line and not line.lstrip().startswith("#"):
        k,v=line.split("=",1); d[k]=v
d.update(DISCORD_TOKEN=sys.argv[1],OWNER_IDS=sys.argv[2],COMMAND_PREFIX=sys.argv[3])
p.write_text("".join(f"{k}={v}\n" for k,v in d.items()))
PY
chmod 600 .env
echo "Configuration saved."
echo "For prefix commands, enable Message Content Intent in Discord Developer Portal."
