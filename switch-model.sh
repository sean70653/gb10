#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/lib/messages.sh"
if [ -z "${GB10_LANG:-}" ]; then
  select_language
  _load_messages
fi

source .env

VLLM_PORT="${VLLM_PORT:-8000}"

echo ""
echo -e "${BOLD}$(msg switch_banner)${NC}"
echo ""

info current_model "${SERVED_MODEL_NAME:-Qwen/Qwen3.6-35B-A3B-FP8}"

while true; do
  read -rp "  $(msg ask_model_repo) " NEW_REPO
  NEW_REPO="${NEW_REPO// /}"
  [ -n "$NEW_REPO" ] && break
done

read -rp "  $(msg ask_served_name) " NEW_SERVED_NAME
NEW_SERVED_NAME="${NEW_SERVED_NAME:-$NEW_REPO}"

read -rp "  $(msg ask_reasoning_parser "${REASONING_PARSER:-qwen3}") " NEW_REASONING_PARSER
NEW_REASONING_PARSER="${NEW_REASONING_PARSER:-${REASONING_PARSER:-qwen3}}"

read -rp "  $(msg ask_tool_parser "${TOOL_CALL_PARSER:-qwen3_coder}") " NEW_TOOL_PARSER
NEW_TOOL_PARSER="${NEW_TOOL_PARSER:-${TOOL_CALL_PARSER:-qwen3_coder}}"

read -rp "  $(msg ask_max_model_len "${MAX_MODEL_LEN:-262144}") " NEW_MAX_MODEL_LEN
NEW_MAX_MODEL_LEN="${NEW_MAX_MODEL_LEN:-${MAX_MODEL_LEN:-262144}}"

NEW_MODEL_DIR="/data/models/$(echo "$NEW_REPO" | tr '/' '--')"

if [ -d "$NEW_MODEL_DIR" ] && ls "$NEW_MODEL_DIR"/*.safetensors &>/dev/null 2>&1; then
  ok model_present "$NEW_MODEL_DIR"
else
  info downloading_model "$NEW_REPO"
  info download_time
  if [ ! -d "$NEW_MODEL_DIR" ]; then
    sudo mkdir -p "$NEW_MODEL_DIR"
    sudo chown "$USER:$USER" "$NEW_MODEL_DIR"
  fi

  if ! command -v hf &>/dev/null; then
    info installing_hf
    curl -LsSf https://hf.co/cli/install.sh | bash
    export PATH="$HOME/.hf-cli/venv/bin:$PATH"
  fi
  hf download "$NEW_REPO" --local-dir "$NEW_MODEL_DIR"

  ok model_downloaded "$NEW_MODEL_DIR"
fi

sed -i "s|^MODEL_REPO=.*|MODEL_REPO=${NEW_REPO}|" .env
sed -i "s|^MODEL_DIR=.*|MODEL_DIR=${NEW_MODEL_DIR}|" .env
sed -i "s|^SERVED_MODEL_NAME=.*|SERVED_MODEL_NAME=${NEW_SERVED_NAME}|" .env
sed -i "s|^REASONING_PARSER=.*|REASONING_PARSER=${NEW_REASONING_PARSER}|" .env
sed -i "s|^TOOL_CALL_PARSER=.*|TOOL_CALL_PARSER=${NEW_TOOL_PARSER}|" .env
sed -i "s|^MAX_MODEL_LEN=.*|MAX_MODEL_LEN=${NEW_MAX_MODEL_LEN}|" .env

source .env

info restarting_vllm
docker compose up -d --force-recreate vllm

echo ""
info waiting_vllm

TIMEOUT=600
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  if curl -sf "http://localhost:${VLLM_PORT}/health" &>/dev/null; then
    break
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  printf "\r  ⏳ %d / %d seconds …" "$ELAPSED" "$TIMEOUT"
done
echo ""

if [ $ELAPSED -ge $TIMEOUT ]; then
  fail vllm_timeout "$TIMEOUT"
fi

ok vllm_healthy

HERMES_CONFIG="$HOME/.hermes/config.yaml"
if [ -f "$HERMES_CONFIG" ]; then
  sed -i "s|^\([[:space:]]*default:\).*|\1 ${NEW_SERVED_NAME}|" "$HERMES_CONFIG"
  ok hermes_updated
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  $(msg switch_complete)${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
