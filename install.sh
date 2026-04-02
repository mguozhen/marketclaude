#!/usr/bin/env bash
# MarketClaude — 一键安装脚本
# 用法：bash install.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${BOLD}"
cat <<'BANNER'
  __  __            _        _    ____ _                 _
 |  \/  | __ _ _ __| | _____| |_ / ___| | __ _ _   _  _| |___
 | |\/| |/ _` | '__| |/ / _ \ __| |   | |/ _` | | | |/ _` / _ \
 | |  | | (_| | |  |   <  __/ |_| |___| | (_| | |_| | (_| |  __/
 |_|  |_|\__,_|_|  |_|\_\___|\__|\____|_|\__,_|\__,_|\__,_|\___|

BANNER
echo -e "${NC}  Solvea GTM Agent — DingTalk × Claude Code"
echo -e "  ────────────────────────────────────────────\n"

# ── 1. 检查 Python ─────────────────────────────────────────────────────────────
echo -e "${BOLD}[1/5] 检查 Python 3.13+${NC}"
PYTHON=""
for cmd in python3.13 python3 python; do
  if command -v "$cmd" &>/dev/null; then
    VER=$("$cmd" -c "import sys; print(sys.version_info[:2])")
    if "$cmd" -c "import sys; assert sys.version_info >= (3,10)" 2>/dev/null; then
      PYTHON="$cmd"
      echo -e "  ${GREEN}✓${NC} 找到 $cmd ($VER)"
      break
    fi
  fi
done

if [[ -z "$PYTHON" ]]; then
  echo -e "  ${RED}✗ 未找到 Python 3.10+${NC}"
  echo "  macOS 安装: brew install python@3.13"
  echo "  Ubuntu 安装: sudo apt install python3.13 python3.13-pip"
  exit 1
fi

# ── 2. 安装 Python 依赖 ────────────────────────────────────────────────────────
echo -e "\n${BOLD}[2/5] 安装 Python 依赖${NC}"
"$PYTHON" -m pip install -r "$DIR/requirements.txt" -q
echo -e "  ${GREEN}✓${NC} dingtalk-stream + python-dotenv 已安装"

# ── 3. 检查 Claude CLI ─────────────────────────────────────────────────────────
echo -e "\n${BOLD}[3/5] 检查 Claude Code CLI${NC}"
CLAUDE_BIN=""
for p in /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME/.local/bin/claude" claude; do
  if command -v "$p" &>/dev/null 2>&1; then
    CLAUDE_BIN="$p"
    echo -e "  ${GREEN}✓${NC} 找到 claude: $CLAUDE_BIN"
    break
  fi
done

if [[ -z "$CLAUDE_BIN" ]]; then
  echo -e "  ${YELLOW}⚠${NC}  未找到 claude CLI，AI 回复功能不可用"
  echo "  安装方法: npm install -g @anthropic-ai/claude-code"
  CLAUDE_BIN="claude"
fi

# 写入实际路径到 .env
if ! grep -q "^CLAUDE_BIN=" "$DIR/.env" 2>/dev/null; then
  echo "" >> "$DIR/.env"
  echo "# Claude Code CLI 路径（自动检测）" >> "$DIR/.env"
  echo "CLAUDE_BIN=$CLAUDE_BIN" >> "$DIR/.env"
fi

# ── 4. 检查工作目录 ────────────────────────────────────────────────────────────
echo -e "\n${BOLD}[4/5] 检查工作目录${NC}"
WORK_DIR="$HOME/reddit-matrix-operator"
if [[ ! -d "$WORK_DIR" ]]; then
  echo -e "  ${YELLOW}⚠${NC}  $WORK_DIR 不存在，创建空目录"
  mkdir -p "$WORK_DIR"
fi
echo -e "  ${GREEN}✓${NC} 工作目录: $WORK_DIR"

# ── 5. 注册开机自启 ────────────────────────────────────────────────────────────
echo -e "\n${BOLD}[5/5] 注册开机自启${NC}"

OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
  # ── macOS launchd ──────────────────────────────────────────────────────────
  PLIST="$HOME/Library/LaunchAgents/com.solvea.marketclaude.plist"
  CURRENT_USER="$(whoami)"

  cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.solvea.marketclaude</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${DIR}/watchdog.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key>
  <string>${DIR}/watchdog.log</string>
  <key>StandardErrorPath</key>
  <string>${DIR}/watchdog.log</string>
  <key>WorkingDirectory</key>
  <string>${DIR}</string>
</dict>
</plist>
PLIST_EOF

  # 先卸载旧的（如有）
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST"
  echo -e "  ${GREEN}✓${NC} launchd 已注册 (com.solvea.marketclaude)"
  echo "  查看状态: launchctl list | grep marketclaude"

elif [[ "$OS" == "Linux" ]]; then
  # ── Linux systemd ──────────────────────────────────────────────────────────
  SERVICE_FILE="/etc/systemd/system/marketclaude.service"
  CURRENT_USER="$(whoami)"

  sudo tee "$SERVICE_FILE" > /dev/null <<SERVICE_EOF
[Unit]
Description=MarketClaude GTM Agent
After=network.target

[Service]
Type=simple
User=${CURRENT_USER}
WorkingDirectory=${DIR}
ExecStart=/bin/bash ${DIR}/watchdog.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now marketclaude
  echo -e "  ${GREEN}✓${NC} systemd service 已注册并启动"
  echo "  查看状态: sudo systemctl status marketclaude"

else
  echo -e "  ${YELLOW}⚠${NC}  不支持的系统 ($OS)，请手动启动:"
  echo "  bash $DIR/watchdog.sh &"
fi

# ── 完成 ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✅ 安装完成！${NC}"
echo ""
echo "  进程日志:   tail -f $DIR/agent.log"
echo "  Watchdog:   tail -f $DIR/watchdog.log"
echo ""
echo "  GTM 群指令示例:"
echo "    @MarketClaude report now"
echo "    @MarketClaude x-poster-solvea command: 今天发什么内容"
echo "    @MarketClaude reddit-ivy taste: 这条太硬广，下次避免"
echo ""
echo "  手动停止:"
if [[ "$OS" == "Darwin" ]]; then
  echo "    launchctl unload $HOME/Library/LaunchAgents/com.solvea.marketclaude.plist"
elif [[ "$OS" == "Linux" ]]; then
  echo "    sudo systemctl stop marketclaude"
fi
echo ""
