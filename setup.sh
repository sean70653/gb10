#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/lib/messages.sh"
if [ -z "${GB10_LANG:-}" ]; then
  select_language
fi
_load_messages

echo ""
echo -e "${BOLD}$(msg banner)${NC}"
echo ""

if ! id -nG "$USER" | grep -qw docker; then
  echo ""
  warn docker_no_perm
  echo ""
  sudo usermod -aG docker "$USER"
  info docker_group_add
  exec sg docker -c "GB10_LANG=${GB10_LANG} \"$0\" $*"
fi

if [ ! -f .env ]; then
  info creating_env
  cp .env.example .env

  WEBUI_KEY=$(openssl rand -hex 24)
  SEARX_KEY=$(openssl rand -hex 24)
  sed -i "s|WEBUI_SECRET_KEY=change-me-to-a-random-string|WEBUI_SECRET_KEY=$WEBUI_KEY|" .env
  sed -i "s|SEARXNG_SECRET=change-me-to-another-random-string|SEARXNG_SECRET=$SEARX_KEY|" .env
  echo ""
  info sudo_searxng_explain
  echo ""
  sudo chown -R "$USER:$USER" searxng/
  sed -i "s|^  secret_key:.*|  secret_key: \"$SEARX_KEY\"|" searxng/settings.yml
  ok env_created
fi

_LOCALE="$(webui_locale)"
if grep -q '^DEFAULT_LOCALE=' .env 2>/dev/null; then
  sed -i "s|^DEFAULT_LOCALE=.*|DEFAULT_LOCALE=${_LOCALE}|" .env
else
  echo "DEFAULT_LOCALE=${_LOCALE}" >> .env
fi

set -a
source .env
set +a

info preflight
command -v docker &>/dev/null || fail docker_not_found
command -v curl &>/dev/null || fail curl_not_found
nvidia-smi &>/dev/null || fail gpu_not_found
docker compose version &>/dev/null || fail docker_compose_missing
docker info &>/dev/null || fail docker_no_perm
ok preflight_ok

_gpu_container_name() {
  local pid=$1 cid name
  if [ -f "/proc/$pid/cgroup" ]; then
    cid=$(tr '\n' ' ' < "/proc/$pid/cgroup" | grep -oE '[0-9a-f]{64}' | head -1)
    if [ -z "$cid" ]; then
      cid=$(tr '\n' ' ' < "/proc/$pid/cgroup" | grep -oE '[0-9a-f]{12,64}' | head -1)
    fi
    if [ -n "$cid" ]; then
      name=$(docker ps -a --format '{{.Names}}' --filter "id=$cid" 2>/dev/null | head -1)
      [ -n "$name" ] && { echo "$name"; return 0; }
    fi
  fi
  for cid in $(docker ps -aq 2>/dev/null); do
    if [ "$(docker inspect -f '{{.State.Pid}}' "$cid" 2>/dev/null)" = "$pid" ]; then
      docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's|^/||'
      return 0
    fi
  done
  return 1
}

_gpu_is_docker_pid() {
  local pid=$1
  grep -qE 'docker|containerd' "/proc/$pid/cgroup" 2>/dev/null
}

_gpu_conflicts_declined=0
_gpu_lines=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null || true)
if [ -n "$_gpu_lines" ]; then
  info gpu_conflict_title
  while IFS= read -r _gpu_line; do
    [ -n "$_gpu_line" ] || continue
    _gpu_pid=$(echo "$_gpu_line" | cut -d',' -f1 | tr -d ' ')
    _gpu_name=$(echo "$_gpu_line" | cut -d',' -f2 | sed 's/^ //')
    [ -n "$_gpu_pid" ] || continue
    kill -0 "$_gpu_pid" 2>/dev/null || continue

    if _gpu_is_docker_pid "$_gpu_pid"; then
      _cname=$(_gpu_container_name "$_gpu_pid" || true)
      if [ -n "$_cname" ] && [[ "$_cname" =~ ^(vllm|open-webui|searxng)$ ]]; then
        continue
      fi
      if [ -n "$_cname" ]; then
        if ask_yn "$(msg gpu_conflict_docker "$_cname")"; then
          docker stop "$_cname" 2>/dev/null || true
          docker rm "$_cname" 2>/dev/null || true
        else
          _gpu_conflicts_declined=1
        fi
      fi
    else
      if ask_yn "$(msg gpu_conflict_host "$_gpu_name" "$_gpu_pid")"; then
        kill "$_gpu_pid" 2>/dev/null || true
      else
        _gpu_conflicts_declined=1
      fi
    fi
  done <<< "$_gpu_lines"

  if [ "$_gpu_conflicts_declined" -eq 1 ]; then
    _remaining=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits 2>/dev/null | grep -c '[0-9]' || true)
    if [ "$_remaining" -gt 0 ]; then
      warn gpu_conflict_warn
    fi
  fi
fi

if [ ! -d "$MODEL_DIR" ]; then
  info creating_model_dir "$MODEL_DIR"
  echo ""
  info sudo_model_dir_explain "$MODEL_DIR"
  echo ""
  sudo mkdir -p "$MODEL_DIR"
  sudo chown "$USER:$USER" "$MODEL_DIR"
fi

if [ -d "$MODEL_DIR" ] && compgen -G "$MODEL_DIR"/*.safetensors >/dev/null 2>&1; then
  ok model_present "$MODEL_DIR"
else
  info downloading_model "$MODEL_REPO"
  info download_time

  if ! command -v hf &>/dev/null; then
    info installing_hf
    curl -LsSf https://hf.co/cli/install.sh | bash &>/dev/null
    export PATH="$HOME/.hf-cli/venv/bin:$PATH"
  fi

  hf download "$MODEL_REPO" --local-dir "$MODEL_DIR" &>/dev/null &
  _DL_PID=$!

  _DL_TERM_W=$(tput cols 2>/dev/null || echo 80)
  _DL_BAR_W=$(( _DL_TERM_W - 55 ))
  [ "$_DL_BAR_W" -lt 10 ] && _DL_BAR_W=10
  [ "$_DL_BAR_W" -gt 30 ] && _DL_BAR_W=30

  _HF_PYTHON="$HOME/.hf-cli/venv/bin/python3"
  _dl_total_gb=$("$_HF_PYTHON" -c "
from huggingface_hub import HfApi
try:
    info=HfApi().model_info('${MODEL_REPO}',files_metadata=True)
    print(f'{sum(s.size for s in info.siblings if s.size)/1e9:.1f}')
except: print('0')
" 2>/dev/null)
  _dl_total_gb="${_dl_total_gb:-0}"
  [ "$_dl_total_gb" = "0" ] && _dl_total_gb=""

  echo ""
  _DL_START=$(date +%s)
  while kill -0 "$_DL_PID" 2>/dev/null; do
    _dl_bytes=$(du -sb "$MODEL_DIR" 2>/dev/null | cut -f1 || echo 0)
    _dl_bytes="${_dl_bytes:-0}"
    _dl_gb=$(python3 -c "print(f'{int(\"${_dl_bytes}\")/1e9:.1f}')" 2>/dev/null || echo "0.0")
    _dl_now=$(date +%s)
    _dl_elapsed=$(( _dl_now - _DL_START ))
    _dl_min=$(( _dl_elapsed / 60 ))
    _dl_sec=$(( _dl_elapsed % 60 ))

    printf "\033[1A\033[K"
    if [ -n "$_dl_total_gb" ]; then
      _dl_pct=$(python3 -c "
g=float('${_dl_gb}');t=float('${_dl_total_gb}')
p=min(int(g/t*100),99) if t>0 else 0;print(p)
" 2>/dev/null || echo 0)
      _dl_filled=$(( _dl_pct * _DL_BAR_W / 100 ))
      _dl_empty=$(( _DL_BAR_W - _dl_filled ))
      _dl_bar=""
      for _x in $(seq 1 "$_dl_filled" 2>/dev/null); do _dl_bar="${_dl_bar}█"; done
      for _x in $(seq 1 "$_dl_empty" 2>/dev/null); do _dl_bar="${_dl_bar}░"; done
      printf "  \033[0;36m──── Model Download (%d:%02d) \033[0;32m[%s]\033[0m %3d%% %s/%s GB\033[K\n" \
        "$_dl_min" "$_dl_sec" "$_dl_bar" "$_dl_pct" "$_dl_gb" "$_dl_total_gb"
    else
      printf "  \033[0;36m──── Model Download (%d:%02d) \033[0m%s GB downloaded\033[K\n" "$_dl_min" "$_dl_sec" "$_dl_gb"
    fi
    sleep 3
  done

  _DL_EXIT=0
  wait "$_DL_PID" 2>/dev/null || _DL_EXIT=$?

  printf "\033[1A\033[K"

  if [ "$_DL_EXIT" -ne 0 ] || ! compgen -G "$MODEL_DIR"/*.safetensors >/dev/null 2>&1; then
    warn downloading_model "$MODEL_REPO"
    exit 1
  fi
  ok model_downloaded "$MODEL_DIR"
fi

info pulling_images

_PL_LINES=8
_PL_COLS=$(( $(tput cols 2>/dev/null || echo 120) - 4 ))
_PL_LOG=$(mktemp)
_PL_BUF=$(mktemp)

for _ in $(seq 1 $((_PL_LINES + 2))); do echo ""; done

script -q -f -c "docker compose pull --include-deps" "$_PL_LOG" &>/dev/null &
_PL_PID=$!

while kill -0 "$_PL_PID" 2>/dev/null; do
  printf "\033[%dA" $((_PL_LINES + 2))
  printf "  \033[0;36m──── Docker Pull ───────────────────────────────\033[0m\033[K\n"
  python3 -c "
import sys,re
data=open(sys.argv[1],'rb').read()
data=re.sub(rb'\x1b\[[0-9;]*[A-Za-z]',b'',data)
lines=data.replace(b'\r',b'\n').split(b'\n')
lines=[l for l in lines if l.strip() and not l.startswith(b'Script ')]
for l in lines[-int(sys.argv[2]):]:
    sys.stdout.buffer.write(l+b'\n')
" "$_PL_LOG" "$_PL_LINES" > "$_PL_BUF" 2>/dev/null || true
  _pi=0
  while IFS= read -r _pline; do
    printf "  \033[2m%.*s\033[0m\033[K\n" "$_PL_COLS" "$_pline"
    _pi=$((_pi + 1))
  done < "$_PL_BUF"
  while [ "$_pi" -lt "$_PL_LINES" ]; do
    printf "  \033[K\n"
    _pi=$((_pi + 1))
  done
  printf "  \033[0;36m────────────────────────────────────────────────\033[0m\033[K\n"
  sleep 1
done

wait "$_PL_PID" || true

printf "\033[%dA" $((_PL_LINES + 2))
for _ in $(seq 1 $((_PL_LINES + 2))); do printf "\033[K\n"; done
printf "\033[%dA" $((_PL_LINES + 2))

rm -f "$_PL_LOG" "$_PL_BUF"

ok images_ready

if docker ps --format '{{.Names}}' | grep -qE '^(vllm|open-webui|searxng)$'; then
  info stopping_containers
  docker compose down
fi

info starting_services
docker compose up -d --no-deps vllm searxng

info waiting_vllm
echo ""
info vllm_loading_logs

LOG_LINES=12
_LOG_TMP=$(mktemp)

docker compose logs -f --tail=0 vllm > "$_LOG_TMP" 2>&1 &
_LOG_PID=$!

# Reserve screen space for the log window
for _ in $(seq 1 $((LOG_LINES + 2))); do echo ""; done

TIMEOUT=900
EXPECT=480
_COLS=$(( $(tput cols 2>/dev/null || echo 120) - 4 ))
_TAIL_BUF=$(mktemp)
trap 'rm -f "$_LOG_TMP" "$_TAIL_BUF"' EXIT
_START=$(date +%s)
while true; do
  _NOW=$(date +%s)
  ELAPSED=$((_NOW - _START))

  if curl -sf "http://localhost:${VLLM_PORT}/health" &>/dev/null; then
    break
  fi

  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    break
  fi

  # Move cursor up to redraw the log window in-place
  printf '\033[%dA' $((LOG_LINES + 2))

  # Status header with elapsed / expected
  _min=$((ELAPSED / 60))
  _sec=$((ELAPSED % 60))
  _emin=$((EXPECT / 60))
  printf '  \033[0;36m──── vLLM (%d:%02d / ~%d min) ─────────────────────\033[0m\033[K\n' "$_min" "$_sec" "$_emin"

  # Show last N lines of logs, padded to exactly LOG_LINES
  tail -n "$LOG_LINES" "$_LOG_TMP" > "$_TAIL_BUF" 2>/dev/null || true
  _i=0
  while IFS= read -r _line; do
    _line="${_line#vllm  | }"
    printf "  \033[2m%.*s\033[0m\033[K\n" "$_COLS" "$_line"
    _i=$((_i + 1))
  done < "$_TAIL_BUF"
  while [ "$_i" -lt "$LOG_LINES" ]; do
    printf "  \033[K\n"
    _i=$((_i + 1))
  done

  # Bottom border
  printf '  \033[0;36m────────────────────────────────────────────────\033[0m\033[K\n'

  sleep 1
done

kill "$_LOG_PID" 2>/dev/null; wait "$_LOG_PID" 2>/dev/null || true

# Final redraw: clear the log window
printf '\033[%dA' $((LOG_LINES + 2))
for _ in $(seq 1 $((LOG_LINES + 2))); do printf '\033[K\n'; done
printf '\033[%dA' $((LOG_LINES + 2))

if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
  warn vllm_timeout "$TIMEOUT"
else
  ok vllm_healthy
fi

docker compose up -d open-webui

_HOST=$(hostname -I 2>/dev/null | cut -d' ' -f1)
_HOST="${_HOST:-localhost}"

_HERMES_INSTALLED=false
if ask_yn "$(msg ask_hermes)"; then
  GB10_LANG=$GB10_LANG ./setup-hermes.sh && _HERMES_INSTALLED=true
else
  info hermes_later
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  $(msg setup_complete)${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
printf "  Open WebUI  →  ${BOLD}http://%s:%s${NC}\n" "$_HOST" "${OPEN_WEBUI_PORT:-3000}"
printf "  vLLM API    →  http://%s:%s/v1\n" "$_HOST" "${VLLM_PORT:-8000}"
printf "  SearXNG     →  http://%s:%s\n" "$_HOST" "${SEARXNG_PORT:-8080}"
echo ""
info first_time_hint
info open_webui_hint

if $_HERMES_INSTALLED || command -v hermes &>/dev/null; then
  echo ""
  echo -e "  ${BOLD}$(msg hermes_hint_title)${NC}"
  echo ""
  echo -e "    ${CYAN}\$ hermes${NC}"
  echo ""
  info hermes_hint_web_search
  info hermes_hint_gateway
fi
echo ""
