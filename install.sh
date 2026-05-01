#!/usr/bin/env bash
# =============================================================
#  Claude Code × DeepSeek — One-click Installer
#  Usage: curl -fsSL https://your-host/install.sh | bash
# =============================================================

set -euo pipefail

# ── ANSI colors ───────────────────────────────────────────────
GREEN='\033[0;32m'
TEAL='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Logging helpers ───────────────────────────────────────────
info()    { echo -e "${TEAL}  i  $*${RESET}"; }
success() { echo -e "${GREEN}  v  $*${RESET}"; }
warn()    { echo -e "${YELLOW}  !  $*${RESET}"; }
error()   { echo -e "${RED}  x  $*${RESET}"; exit 1; }
step()    { echo -e "\n${BOLD}${GREEN}>> $*${RESET}"; }
dim()     { echo -e "${GRAY}     $*${RESET}"; }

# ── Model menu helper ─────────────────────────────────────────
print_model_menu() {
    echo -e "
  ${TEAL}[1]${RESET} deepseek-v4-flash  ${GRAY}fast & cheap, great for everyday coding${RESET}
  ${TEAL}[2]${RESET} deepseek-v4-pro    ${GRAY}chain-of-thought, best for hard problems${RESET}"
}

# Prompt user to pick a model; writes result into $1 (nameref).
# $2 = prompt label, $3 = default choice (1 or 2)
pick_model() {
    local __varname="$1"
    local prompt="$2"
    local default="${3:-1}"

    print_model_menu
    while true; do
        echo -ne "\n  ${TEAL}${prompt} [1/2] (default ${default}):${RESET} "
        read -r choice </dev/tty
        choice="${choice:-$default}"
        case "$choice" in
            1) eval "$__varname='deepseek-v4-flash'"; break ;;
            2) eval "$__varname='deepseek-v4-pro'"; break ;;
            *) warn "Please enter 1 or 2." ;;
        esac
    done
}

# ── Detect shell RC file ──────────────────────────────────────
detect_rc() {
    local sh
    sh=$(basename "${SHELL:-bash}")
    case "$sh" in
        zsh)  echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        fish) echo "$HOME/.config/fish/config.fish" ;;
        *)    echo "$HOME/.profile" ;;
    esac
}

# ── Node.js installers ────────────────────────────────────────
install_node_nvm() {
    info "Installing Node.js 20 via nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    nvm install 20 && nvm use 20
}

install_node_mac() {
    if command -v brew &>/dev/null; then
        info "Installing Node.js via Homebrew..."
        brew install node
    else
        warn "Homebrew not found, falling back to nvm..."
        install_node_nvm
    fi
}

install_node_linux() {
    if command -v apt-get &>/dev/null; then
        info "Installing Node.js 20 via apt..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v yum &>/dev/null; then
        info "Installing Node.js 20 via yum..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
    else
        warn "No package manager found, falling back to nvm..."
        install_node_nvm
    fi
}

# =============================================================
#  MAIN
# =============================================================

echo -e "
${GREEN}╔══════════════════════════════════════════════╗
║   Claude Code × DeepSeek  —  Installer       ║
╚══════════════════════════════════════════════╝${RESET}
"

# ── Step 1: OS check ──────────────────────────────────────────
step "Step 1/6 — Checking OS"

OS="$(uname -s)"
case "$OS" in
    Darwin) success "macOS detected" ;;
    Linux)  success "Linux detected" ;;
    *)      error "Unsupported OS: $OS (macOS and Linux only)" ;;
esac

# ── Step 2: Node.js ───────────────────────────────────────────
step "Step 2/6 — Checking Node.js (required >= v18)"

MIN_NODE=18

if command -v node &>/dev/null; then
    NODE_VER=$(node -e "process.stdout.write(process.versions.node.split('.')[0])")
    if [ "$NODE_VER" -ge "$MIN_NODE" ]; then
        success "Node.js $(node --version) already installed"
    else
        warn "Node.js $(node --version) is too old, upgrading..."
        [ "$OS" = "Darwin" ] && install_node_mac || install_node_linux
    fi
else
    warn "Node.js not found, installing..."
    [ "$OS" = "Darwin" ] && install_node_mac || install_node_linux
fi

command -v node &>/dev/null || error "Node.js installation failed. Please install manually."
success "Node.js $(node --version) ready"

# ── Step 3: Claude Code ───────────────────────────────────────
step "Step 3/6 — Installing Claude Code"

if command -v claude &>/dev/null; then
    info "Claude Code already installed ($(claude --version 2>/dev/null | head -1)), skipping..."
else
    info "Running: npm install -g @anthropic-ai/claude-code"
    if ! npm install -g @anthropic-ai/claude-code 2>&1; then
        warn "Permission error, retrying with sudo..."
        sudo npm install -g @anthropic-ai/claude-code
    fi
fi

command -v claude &>/dev/null || error "Claude Code installation failed."
success "Claude Code $(claude --version 2>/dev/null | head -1) ready"

# ── Step 4: DeepSeek API key ──────────────────────────────────
step "Step 4/6 — DeepSeek API Key"

dim "Get your key at: https://platform.deepseek.com"
dim "New accounts receive \$10 free credits."
echo

while true; do
    echo -ne "  ${TEAL}Paste your API key (input hidden):${RESET} "
    read -rs API_KEY </dev/tty
    echo
    if [[ "$API_KEY" =~ ^sk-.{8,}$ ]]; then
        success "API key format looks good"
        break
    else
        warn "Key should start with 'sk-' and be at least 10 chars. Try again."
    fi
done

# ── Step 5: Model mapping ─────────────────────────────────────
step "Step 5/6 — Model Mapping"

echo -e "
  ${BOLD}Map each Claude tier to a DeepSeek model.${RESET}
  ${GRAY}Claude Code uses opus / sonnet / haiku internally to pick quality levels.
  You control which DeepSeek model each tier calls.${RESET}
"

# opus: defaults to pro (hardest tasks)
echo -e "  ${BOLD}Opus${RESET}  ${GRAY}— hardest tasks, architect mode${RESET}"
pick_model MODEL_OPUS "Choose model for opus" 2

# sonnet: defaults to flash (main workhorse)
echo -e "\n  ${BOLD}Sonnet${RESET}  ${GRAY}— everyday coding, main workhorse${RESET}"
pick_model MODEL_SONNET "Choose model for sonnet" 1

# haiku: defaults to flash (quick tasks, subagents)
echo -e "\n  ${BOLD}Haiku${RESET}  ${GRAY}— quick tasks, subagents, autocomplete${RESET}"
pick_model MODEL_HAIKU "Choose model for haiku" 1

# ANTHROPIC_MODEL: catch-all when no tier hint is given — follow sonnet
MODEL_DEFAULT="$MODEL_SONNET"
# Subagents follow haiku mapping for speed
MODEL_SUBAGENT="$MODEL_HAIKU"

echo -e "
  ${GRAY}Mapping summary:${RESET}
    opus    ->  ${GREEN}${MODEL_OPUS}${RESET}
    sonnet  ->  ${GREEN}${MODEL_SONNET}${RESET}
    haiku   ->  ${GREEN}${MODEL_HAIKU}${RESET}
"

# ── Step 6: Write config ──────────────────────────────────────
step "Step 6/6 — Writing config"

RC_FILE=$(detect_rc)
info "Target file: $RC_FILE"

# Remove previous block if present (makes re-runs idempotent)
if grep -q "# BEGIN claude-deepseek" "$RC_FILE" 2>/dev/null; then
    warn "Removing existing config block first..."
    sed -i.bak '/# BEGIN claude-deepseek/,/# END claude-deepseek/d' "$RC_FILE"
fi

# Append new config block with clear markers for future updates
cat >> "$RC_FILE" <<EOF

# BEGIN claude-deepseek ──────────────────────────────────────
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
export ANTHROPIC_AUTH_TOKEN="$API_KEY"
export ANTHROPIC_MODEL="$MODEL_DEFAULT"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL_OPUS"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL_SONNET"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL_HAIKU"
export CLAUDE_CODE_SUBAGENT_MODEL="$MODEL_SUBAGENT"
export CLAUDE_CODE_EFFORT_LEVEL="max"
# END claude-deepseek ────────────────────────────────────────
EOF

success "Config written to $RC_FILE"

# ── Clean conflicting Claude Code settings.json fields ───────
# settings.json's "env" overrides shell env vars, and "apiKeyHelper"
# conflicts with ANTHROPIC_AUTH_TOKEN. Strip leftovers from prior setups
# (e.g. poe.com BASE_URL) so this install actually takes effect.
fix_settings_file() {
    local f="$1"
    [ -f "$f" ] || return 0

    local needs_fix=0
    grep -q '"apiKeyHelper"' "$f" 2>/dev/null && needs_fix=1
    grep -qE '"ANTHROPIC_BASE_URL"|"ANTHROPIC_AUTH_TOKEN"|"ANTHROPIC_API_KEY"|"ANTHROPIC_MODEL"' "$f" 2>/dev/null && needs_fix=1
    [ "$needs_fix" -eq 1 ] || return 0

    info "Cleaning conflicting fields in $f"
    cp "$f" "${f}.bak.$(date +%s)"

    if command -v node &>/dev/null; then
        node -e "
            const fs=require('fs'), p=process.argv[1];
            let j; try { j=JSON.parse(fs.readFileSync(p,'utf8')); } catch(e){ process.exit(2); }
            delete j.apiKeyHelper;
            if (j.env && typeof j.env === 'object') {
                for (const k of ['ANTHROPIC_BASE_URL','ANTHROPIC_AUTH_TOKEN','ANTHROPIC_API_KEY','ANTHROPIC_MODEL','ANTHROPIC_DEFAULT_OPUS_MODEL','ANTHROPIC_DEFAULT_SONNET_MODEL','ANTHROPIC_DEFAULT_HAIKU_MODEL','CLAUDE_CODE_SUBAGENT_MODEL']) {
                    delete j.env[k];
                }
                if (Object.keys(j.env).length === 0) delete j.env;
            }
            fs.writeFileSync(p, JSON.stringify(j,null,2)+'\n');
        " "$f" && success "Cleaned $f (backup saved)" || warn "Could not auto-clean $f — please edit it manually"
    else
        warn "node not available; please manually remove apiKeyHelper and env.ANTHROPIC_* from $f"
    fi
}

for SETTINGS in \
    "$HOME/.claude/settings.json" \
    "$HOME/.claude/settings.local.json" \
    "$PWD/.claude/settings.json" \
    "$PWD/.claude/settings.local.json"
do
    fix_settings_file "$SETTINGS"
done

# Apply to current session so claude works immediately without re-sourcing
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
export ANTHROPIC_AUTH_TOKEN="$API_KEY"
export ANTHROPIC_MODEL="$MODEL_DEFAULT"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL_OPUS"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL_SONNET"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL_HAIKU"
export CLAUDE_CODE_SUBAGENT_MODEL="$MODEL_SUBAGENT"
export CLAUDE_CODE_EFFORT_LEVEL="max"

# ── Done ──────────────────────────────────────────────────────
echo -e "
${GREEN}╔══════════════════════════════════════════════╗
║            Installation complete!            ║
╚══════════════════════════════════════════════╝${RESET}

  ${BOLD}Apply to new terminals:${RESET}
    ${TEAL}source ${RC_FILE}${RESET}

  ${BOLD}Start coding:${RESET}
    ${TEAL}claude \"refactor this function\"${RESET}

  ${BOLD}Model mapping:${RESET}
    opus    ->  ${GREEN}${MODEL_OPUS}${RESET}
    sonnet  ->  ${GREEN}${MODEL_SONNET}${RESET}
    haiku   ->  ${GREEN}${MODEL_HAIKU}${RESET}

  ${GRAY}Pricing: https://api-docs.deepseek.com/models-pricing${RESET}
"