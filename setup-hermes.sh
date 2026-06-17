#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/lib/messages.sh"
if [ -z "${GB10_LANG:-}" ]; then
  select_language
  _load_messages
fi

[ -f .env ] && source .env

VLLM_PORT="${VLLM_PORT:-8000}"
SEARXNG_PORT="${SEARXNG_PORT:-8080}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-Qwen/Qwen3.6-35B-A3B-FP8}"

echo ""
echo -e "${BOLD}$(msg hermes_banner)${NC}"
echo ""

_hermes_works=false
if command -v hermes &>/dev/null && hermes --version &>/dev/null; then
  _hermes_works=true
fi

if $_hermes_works; then
  ok hermes_installed
else
  if command -v hermes &>/dev/null; then
    warn hermes_reinstalling
  else
    info hermes_installing
  fi
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    [ -f "$rc" ] && source "$rc" 2>/dev/null || true
  done
fi

if ! command -v hermes &>/dev/null || ! hermes --version &>/dev/null; then
  warn hermes_not_found
  exit 1
fi

HERMES_DIR="$HOME/.hermes"
mkdir -p "$HERMES_DIR"

CONFIG_FILE="$HERMES_DIR/config.yaml"
if [ -f "$CONFIG_FILE" ]; then
  cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
  ok hermes_config_backup "$CONFIG_FILE"
fi

cat > "$CONFIG_FILE" <<EOF
model:
  provider: custom
  base_url: http://localhost:${VLLM_PORT}/v1
  default: ${SERVED_MODEL_NAME}
  api_key: not-needed
  context_length: 65536

display:
  language: $(hermes_lang)

web:
  search_backend: "searxng"

terminal:
  backend: local
EOF

ok hermes_config_written "$CONFIG_FILE"

cat > "$HERMES_DIR/.env" <<EOF
SEARXNG_URL=http://localhost:${SEARXNG_PORT}
EOF

if curl -sf "http://localhost:${VLLM_PORT}/health" &>/dev/null; then
  ok hermes_vllm_ok "$VLLM_PORT"
else
  fail hermes_vllm_fail "$VLLM_PORT"
fi

if ask_yn "$(msg ask_gateway)"; then
  hermes gateway setup
  info gateway_systemd
  hermes gateway install
  loginctl enable-linger "$USER" 2>/dev/null || true
  hermes gateway start
  ok gateway_started
  info gateway_help_status
  info gateway_help_logs
  info gateway_help_add
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  $(msg hermes_ready)${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}$(msg hermes_hint_title)${NC}"
echo ""
echo -e "    ${CYAN}\$ hermes${NC}"
echo ""
info hermes_hint_web_search
info hermes_hint_gateway
echo ""
