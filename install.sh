#!/bin/bash
# ============================================================
#  BUG Framework v3.0 — Installer
#  Run: sudo bash install.sh
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${RED}${BOLD}"
cat << 'EOF'
██████╗ ██╗   ██╗ ██████╗     ███████╗██████╗  █████╗ ███╗   ███╗███████╗██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗
██╔══██╗██║   ██║██╔════╝     ██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝
██████╔╝██║   ██║██║  ███╗    █████╗  ██████╔╝███████║██╔████╔██║█████╗  ██║ █╗ ██║██║   ██║██████╔╝█████╔╝
██╔══██╗██║   ██║██║   ██║    ██╔══╝  ██╔══██╗██╔══██║██║╚██╔╝██║██╔══╝  ██║███╗██║██║   ██║██╔══██╗██╔═██╗
██████╔╝╚██████╔╝╚██████╔╝    ██║     ██║  ██║██║  ██║██║ ╚═╝ ██║███████╗╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗
╚═════╝  ╚═════╝  ╚═════╝     ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝ ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
EOF
echo -e "${NC}${GREEN}  Bug Bounty Automation Framework v3.0 — Installer${NC}"
echo ""

log()   { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
  error "Run as root: sudo bash install.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install bug command
log "Installing bug → /usr/local/bin/bug"
cp "$SCRIPT_DIR/bug.sh" /usr/local/bin/bug
chmod +x /usr/local/bin/bug

# PATH setup
for RC in /root/.bashrc /root/.zshrc; do
  grep -q "go/bin" "$RC" 2>/dev/null || \
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$RC"
done

# SecLists
if [ ! -d "/usr/share/seclists" ]; then
  log "Installing SecLists (this may take a few minutes)..."
  apt-get install -y seclists -qq 2>/dev/null || \
    git clone -q --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists
  log "SecLists installed"
fi

echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✓ Installation complete!${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Commands:${NC}"
echo -e "  ${BOLD}bug -d example.com${NC}                    Full aggressive scan"
echo -e "  ${BOLD}bug -d example.com -t 100${NC}             Custom threads"
echo -e "  ${BOLD}bug -d example.com -p${NC}                 Passive mode"
echo -e "  ${BOLD}bug -d example.com -s${NC}                 Skip tool check"
echo -e "  ${BOLD}bug -d example.com -c your.oast.fun${NC}   With OOB/SSRF callback"
echo -e "  ${BOLD}bug -d example.com -o /tmp/results${NC}    Custom output dir"
echo ""
echo -e "  ${YELLOW}Results saved to:${NC} ~/bug-results/<domain>/"
echo -e "  ${YELLOW}Report:${NC}          ~/bug-results/<domain>/08-report/report.md"
echo ""
echo -e "  ${RED}Optional — set API keys for more sources:${NC}"
echo -e "  export SECTRAILS_KEY=your_key"
echo ""
