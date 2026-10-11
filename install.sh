#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

APP_DIR="${VPS_DEPLOY_BOT_DIR:-$HOME/vps-deploy-bot}"
mkdir -p "$APP_DIR/modules" "$APP_DIR/logs"
cd "$APP_DIR"

echo "======================================"
echo "       VPS DEPLOY BOT INSTALLER"
echo "======================================"

# Preserve existing source and secrets.
if [[ ! -f bot.py ]]; then
cat > bot.py <<'PYBOT'
import os, platform, shutil, time, asyncio
from pathlib import Path
import discord
from discord.ext import commands
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent
load_dotenv(ROOT / ".env")
TOKEN = os.getenv("DISCORD_TOKEN", "").strip()
OWNER_IDS = {int(x) for x in os.getenv("OWNER_IDS", "").split(",") if x.strip().isdigit()}
PREFIX = os.getenv("COMMAND_PREFIX", "!")
STARTED = time.time()

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix=PREFIX, intents=intents, help_command=None)

def owner_only():
    async def check(ctx):
        if not OWNER_IDS or ctx.author.id not in OWNER_IDS:
            raise commands.CheckFailure("Only configured bot owners can use this command.")
        return True
    return commands.check(check)

@bot.event
async def on_ready():
    print(f"Connected as {bot.user} ({bot.user.id})")
    try:
        synced = await bot.tree.sync()
        print(f"Synced {len(synced)} slash commands")
    except Exception as e:
        print(f"Slash sync error: {e}")

@bot.command()
async def ping(ctx):
    await ctx.reply(f"Pong! {round(bot.latency*1000)} ms", mention_author=False)

@bot.command(name="help")
async def help_command(ctx):
    await ctx.reply(
        f"**VPS Deploy Bot**\n`{PREFIX}ping` — latency\n"
        f"`{PREFIX}status` — host status\n`{PREFIX}help` — help\n"
        f"`{PREFIX}diagnose disk|uptime|python` — owner diagnostics",
        mention_author=False
    )

@bot.command()
async def status(ctx):
    total, used, free = shutil.disk_usage(ROOT)
    await ctx.reply(
        f"**Host Status**\nPlatform: `{platform.platform()}`\n"
        f"Disk used: `{used/1024**3:.2f}/{total/1024**3:.2f} GiB`\n"
        f"Free: `{free/1024**3:.2f} GiB`\nUptime: `{int(time.time()-STARTED)}s`",
        mention_author=False
    )

@bot.command()
@owner_only()
async def diagnose(ctx, kind: str = "disk"):
    commands_map = {
        "disk": ["df", "-h"],
        "uptime": ["uptime"],
        "python": [os.sys.executable, "--version"],
    }
    if kind not in commands_map:
        await ctx.reply("Allowed: `disk`, `uptime`, `python`", mention_author=False)
        return
    try:
        p = await asyncio.create_subprocess_exec(
            *commands_map[kind], stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )
        out, _ = await asyncio.wait_for(p.communicate(), timeout=10)
        await ctx.reply("```text\n" + out.decode(errors="replace")[:1700] + "\n```", mention_author=False)
    except Exception as e:
        await ctx.reply(f"Diagnostic failed: `{e}`", mention_author=False)

@bot.tree.command(name="ping", description="Check bot latency")
async def slash_ping(interaction: discord.Interaction):
    await interaction.response.send_message(f"Pong! {round(bot.latency*1000)} ms", ephemeral=True)

@bot.tree.command(name="status", description="Show host disk status")
async def slash_status(interaction: discord.Interaction):
    total, used, free = shutil.disk_usage(ROOT)
    await interaction.response.send_message(
        f"Platform: `{platform.system()} {platform.release()}`\n"
        f"Disk: `{used/1024**3:.2f}/{total/1024**3:.2f} GiB used`",
        ephemeral=True
    )

if __name__ == "__main__":
    if not TOKEN:
        raise SystemExit("DISCORD_TOKEN missing. Choose menu option 2 first.")
    bot.run(TOKEN, log_handler=None)
PYBOT
fi

cat > requirements-termux.txt <<'REQ'
discord.py
python-dotenv
aiohttp
requests
PyYAML
rich
colorama
GitPython
aiosqlite
packaging
docker
Jinja2
schedule
tenacity
websockets
uvicorn
APScheduler
prometheus-client
REQ

cat > modules/setup.sh <<'SETUP'
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
SETUP

cat > modules/install.sh <<'INSTALL'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
cd "$HOME/vps-deploy-bot"
python -m venv venv 2>/dev/null || true
venv/bin/python -m pip install -r requirements-termux.txt
mkdir -p logs
echo "Dependencies installed."
INSTALL

cat > modules/dependencies.sh <<'DEPS'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/vps-deploy-bot"
[[ -x venv/bin/python ]] || { echo "Run option 1 first."; exit 1; }
venv/bin/python -m pip install -r requirements-termux.txt
venv/bin/python -m pip check
DEPS

cat > modules/start.sh <<'START'
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
START

cat > modules/stop.sh <<'STOP'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
if [[ -f .bot.pid ]] && kill -0 "$(cat .bot.pid)" 2>/dev/null; then
 kill "$(cat .bot.pid)" && rm -f .bot.pid
 echo "Bot stopped."
else
 rm -f .bot.pid; echo "Bot is not running."
fi
STOP

cat > modules/restart.sh <<'RESTART'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
bash modules/stop.sh
sleep 1
exec bash modules/start.sh
RESTART

cat > modules/status.sh <<'STATUS'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
if [[ -f .bot.pid ]] && kill -0 "$(cat .bot.pid)" 2>/dev/null; then
 echo "Bot RUNNING (PID $(cat .bot.pid))"
else
 echo "Bot STOPPED"
fi
[[ -f .env ]] && echo "Configuration: present" || echo "Configuration: missing"
[[ -f logs/console.log ]] && tail -n 12 logs/console.log
STATUS

cat > modules/configuration.sh <<'CONFIG'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
if [[ -f .env ]]; then
 echo "Configuration keys (values hidden):"
 sed 's/=.*//' .env
 echo "Use option 2 to update settings."
else
 echo "No configuration. Choose option 2."
fi
CONFIG

cat > modules/logs.sh <<'LOGS'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
mkdir -p logs
touch logs/console.log
tail -n 60 -f logs/console.log
LOGS

cat > modules/update.sh <<'UPDATE'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
echo "Update the GitHub installer and rerun it to regenerate modules."
echo "Existing bot source and .env are preserved."
UPDATE

cat > modules/system_info.sh <<'SYS'
#!/data/data/com.termux/files/usr/bin/bash
echo "=== SYSTEM INFORMATION ==="
uname -a
python --version 2>&1 || true
df -h . 2>/dev/null || true
command -v free >/dev/null 2>&1 && free -h || echo "RAM details unavailable in Termux."
SYS

cat > modules/uninstall.sh <<'UNINSTALL'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/vps-deploy-bot"
read -r -p "Stop bot and remove venv/logs? [y/N] " answer
case "$answer" in
 y|Y) bash modules/stop.sh || true; rm -rf venv logs .bot.pid; echo "Runtime removed; source and .env kept." ;;
 *) echo "Cancelled." ;;
esac
UNINSTALL

cat > menu.sh <<'MENU'
#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/vps-deploy-bot"
while true; do
 clear 2>/dev/null || true
 cat <<'BANNER'
VPS DEPLOY BOT
Advanced Management Console
────────────────────────────────────────────────────
BOT MANAGEMENT
[01] Install Bot          [07] Update Bot
[02] Set Up Bot           [08] Dependencies
[03] Start Bot            [09] Configuration
[04] Stop Bot             [10] View Logs
[05] Restart Bot          [11] Uninstall
[06] Bot Status           [12] System Information

CONSOLE TOOLS
[R] Refresh Menu          [H] Help
[L] Console Log            [0] Exit
────────────────────────────────────────────────────
BANNER
 read -r -p "Select option [0-12, R, H, L]: " c
 case "${c,,}" in
  1|01) m=install ;;
  2|02) m=setup ;;
  3|03) m=start ;;
  4|04) m=stop ;;
  5|05) m=restart ;;
  6|06) m=status ;;
  7|07) m=update ;;
  8|08) m=dependencies ;;
  9|09) m=configuration ;;
  10) m=logs ;;
  11) m=uninstall ;;
  12) m=system_info ;;
  r) continue ;;
  h) echo "Choose 1 to install, 2 to configure, 3 to start."; read -r -p "Enter..." _; continue ;;
  l) tail -n 60 logs/console.log 2>/dev/null || echo "No logs yet."; read -r -p "Enter..." _; continue ;;
  0) exit 0 ;;
  *) echo "Invalid option."; sleep 1; continue ;;
 esac
 echo
 bash "modules/$m.sh"
 rc=$?
 echo "Module finished. Exit code: $rc"
 read -r -p "Press Enter to continue..." _
done
MENU

chmod +x menu.sh modules/*.sh
touch logs/console.log
echo
echo "Complete VPS Deploy Bot installer files generated in: $APP_DIR"
echo "Run: cd \"$APP_DIR\" && bash menu.sh"
echo "Menu sequence: 1 Install, 2 Set Up, 3 Start."
