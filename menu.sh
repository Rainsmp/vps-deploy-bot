#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/vps-deploy-bot" || exit 1

R=$'\033[38;5;203m'
P=$'\033[38;5;141m'
C=$'\033[38;5;81m'
G=$'\033[38;5;114m'
Y=$'\033[38;5;221m'
W=$'\033[1;37m'
D=$'\033[38;5;245m'
X=$'\033[0m'

pause() { echo; read -r -p "Press Enter to continue..." _; }

dashboard() {
  local pid="STOPPED" uptime="N/A"
  if [[ -f .bot.pid ]] && kill -0 "$(cat .bot.pid)" 2>/dev/null; then
    pid="$(cat .bot.pid)"
    uptime="$(ps -o etime= -p "$pid" 2>/dev/null | xargs)"
    uptime="${uptime:-Unknown}"
  fi
  echo "SYSTEM DASHBOARD"
  echo "────────────────────────────────────"
  printf "Bot process : %s\n" "$pid"
  printf "Bot uptime  : %s\n" "$uptime"
  printf "Python      : %s\n" "$(python --version 2>&1)"
  printf "Project     : %s\n" "$PWD"
  printf "Config      : "
  [[ -s .env ]] && echo "Present" || echo "Missing"
  printf "Dependencies: "
  [[ -x venv/bin/python ]] && echo "Virtual environment found" || echo "Not installed"
  echo
  echo "DISK"
  df -h . 2>/dev/null || true
  echo
  echo "MEMORY"
  if [[ -r /proc/meminfo ]]; then
    awk '/MemTotal:|MemAvailable:/ {printf "%-15s %.1f GiB\n", $1, $2/1048576}' /proc/meminfo
  else
    echo "Memory details unavailable."
  fi
  echo
  echo "RECENT BOT LOGS"
  tail -n 8 logs/console.log 2>/dev/null || echo "No logs yet."
}

health_check() {
  echo "HEALTH CHECK"
  echo "────────────────────────────────────"
  bash -n menu.sh && echo "[OK] Menu syntax" || echo "[FAIL] Menu syntax"
  [[ -f bot.py ]] && echo "[OK] bot.py exists" || echo "[FAIL] bot.py missing"
  [[ -s .env ]] && echo "[OK] Configuration exists" || echo "[WARN] Configure with option 2"
  [[ -x venv/bin/python ]] && echo "[OK] Virtual environment exists" || echo "[WARN] Install with option 1"
  if [[ -x venv/bin/python ]]; then
    venv/bin/python -c 'import discord,dotenv; print("[OK] Discord dependencies import")' 2>&1 || true
  fi
  if [[ -f .bot.pid ]] && kill -0 "$(cat .bot.pid)" 2>/dev/null; then
    echo "[OK] Bot process is running"
  else
    echo "[WARN] Bot process is not running"
  fi
  echo
  echo "Latest errors:"
  grep -Ei 'error|exception|traceback|failed|invalid token' logs/console.log 2>/dev/null | tail -n 10 || echo "No matching errors found."
}

backup_project() {
  local dest="$HOME/vps-deploy-bot-backups"
  mkdir -p "$dest"
  local file="$dest/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  if tar -czf "$file" \
    --exclude='./venv' --exclude='./.git' \
    --exclude='./logs/console.log' \
    --exclude='./.bot.pid' .; then
    chmod 600 "$file"
    echo "Backup created: $file"
    echo "Secrets in .env are included. Keep this archive private."
  else
    echo "Backup failed."
    rm -f "$file"
  fi
}

while true; do
  clear 2>/dev/null || true
  printf "${R}╔══════════════════════════════════════════════════╗${X}\n"
  printf "${R}║${X} ${W}           VPS DEPLOY BOT X                       ${R}║${X}\n"
  printf "${R}║${X} ${P}        ADVANCED CONTROL CENTER                   ${R}║${X}\n"
  printf "${R}╚══════════════════════════════════════════════════╝${X}\n"
  printf "${D}────────────────────────────────────────────────────${X}\n"
  printf "${C} BOT CONTROL${X}                  ${C} MAINTENANCE${X}\n"
  printf "${W} [01]${X} Install Bot               ${W} [07]${X} Update Info\n"
  printf "${W} [02]${X} Configure Bot             ${W} [08]${X} Dependencies\n"
  printf "${W} [03]${X} Start Bot                 ${W} [09]${X} Configuration Info\n"
  printf "${W} [04]${X} Stop Bot                  ${W} [10]${X} Live Logs\n"
  printf "${W} [05]${X} Restart Bot               ${W} [11]${X} Uninstall Runtime\n"
  printf "${W} [06]${X} Bot Status                ${W} [12]${X} System Information\n\n"
  printf "${C} ADVANCED TOOLS${X}\n"
  printf "${G} [13]${X} Live Dashboard\n"
  printf "${G} [14]${X} Full Health Check\n"
  printf "${G} [15]${X} Create Backup\n"
  printf "${G} [16]${X} Clear Logs\n"
  printf "${G} [17]${X} Repair Dependencies\n"
  printf "${G} [18]${X} Check Bot Source\n\n"
  printf "${P} [R]${X} Refresh   ${P}[H]${X} Help   ${P}[L]${X} Recent Logs   ${R}[0]${X} Exit\n"
  printf "${D}────────────────────────────────────────────────────${X}\n"

  read -r -p "$(printf "${C}Select an option: ${X}")" choice
  case "${choice,,}" in
    1|01) m=install; bash "modules/$m.sh"; pause ;;
    2|02) m=setup; bash "modules/$m.sh"; pause ;;
    3|03) m=start; bash "modules/$m.sh"; pause ;;
    4|04) m=stop; bash "modules/$m.sh"; pause ;;
    5|05) m=restart; bash "modules/$m.sh"; pause ;;
    6|06) m=status; bash "modules/$m.sh"; pause ;;
    7|07) m=update; bash "modules/$m.sh"; pause ;;
    8|08) m=dependencies; bash "modules/$m.sh"; pause ;;
    9|09) m=configuration; bash "modules/$m.sh"; pause ;;
    10) bash "modules/logs.sh" ;;
    11) bash "modules/uninstall.sh"; pause ;;
    12) bash "modules/system_info.sh"; pause ;;
    13) dashboard; pause ;;
    14) health_check; pause ;;
    15)
      read -r -p "Create a private project backup? [y/N] " ans
      [[ "${ans,,}" == y ]] && backup_project
      pause ;;
    16)
      read -r -p "Clear the bot log? [y/N] " ans
      if [[ "${ans,,}" == y ]]; then
        mkdir -p logs
        : > logs/console.log
        echo "Log cleared."
      fi
      pause ;;
    17)
      if [[ -x venv/bin/python ]]; then
        venv/bin/python -m pip install --upgrade -r requirements-termux.txt
        venv/bin/python -m pip check
      else
        echo "Choose option 1 first."
      fi
      pause ;;
    18)
      echo "BOT SOURCE CHECK"
      [[ -f bot.py ]] && echo "[OK] bot.py found" || echo "[FAIL] bot.py missing"
      [[ -f requirements-termux.txt ]] && echo "[OK] Requirements found" || echo "[FAIL] Requirements missing"
      [[ -f .env ]] && echo "[OK] .env found (values hidden)" || echo "[WARN] .env missing"
      for f in modules/*.sh; do
        [[ -f "$f" ]] && bash -n "$f" && echo "[OK] $f" || echo "[FAIL] $f"
      done
      pause ;;
    r) continue ;;
    h)
      echo "Use 1 to install, 2 to configure, 3 to start."
      echo "Use 13 for dashboard, 14 for diagnostics, 15 for backups."
      echo "This console manages the bot and the local Termux environment."
      pause ;;
    l) tail -n 60 logs/console.log 2>/dev/null || echo "No logs yet."; pause ;;
    0) exit 0 ;;
    *) printf "${R}Invalid option.${X}\n"; sleep 1 ;;
  esac
done
