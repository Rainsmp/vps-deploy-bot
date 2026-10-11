#!/data/data/com.termux/files/usr/bin/bash
echo "=== SYSTEM INFORMATION ==="
uname -a
python --version 2>&1 || true
df -h . 2>/dev/null || true
command -v free >/dev/null 2>&1 && free -h || echo "RAM details unavailable in Termux."
