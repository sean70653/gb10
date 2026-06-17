#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/lib/messages.sh"
if [ -z "${GB10_LANG:-}" ]; then
  select_language
  _load_messages
fi

REMOVE_IMAGES=false
if [[ "${1:-}" == "--images" ]]; then
  REMOVE_IMAGES=true
fi

echo ""
echo -e "${BOLD}$(msg clean_banner)${NC}"
echo ""
echo -e "  $(msg clean_desc)"
echo -e "    • $(msg clean_item_docker)"
echo -e "    • $(msg clean_item_env)"
echo -e "    • $(msg clean_item_searxng)"
echo -e "    • $(msg clean_item_hermes)"
echo -e "    • $(msg clean_item_gateway)"
echo ""
echo -e "  ${YELLOW}$(msg clean_note_model)${NC}"
echo -e "  ${YELLOW}$(msg clean_note_images)${NC}"
echo ""

if ! ask_yn "$(msg clean_proceed)"; then
  echo "  $(msg clean_aborted)"
  exit 0
fi

echo ""

# ── 1. Stop and remove Docker containers + volumes + networks ──
info clean_stopping_docker
docker compose -f docker-compose.yml down -v 2>/dev/null && ok clean_main_removed || warn clean_main_not_running

# Remove any orphaned containers by name
for cname in vllm open-webui searxng; do
  if docker ps -aq -f "name=^${cname}$" 2>/dev/null | grep -q .; then
    docker rm -f "$cname" 2>/dev/null || true
    ok clean_orphan_removed "$cname"
  fi
done

# Remove the named volume if it survived
if docker volume ls -q 2>/dev/null | grep -q "^gb10_open-webui-data$"; then
  docker volume rm gb10_open-webui-data 2>/dev/null || true
  ok clean_volume_removed "gb10_open-webui-data"
fi

# Remove the network if it survived
if docker network ls -q -f "name=^gb10_default$" 2>/dev/null | grep -q .; then
  docker network rm gb10_default 2>/dev/null || true
  ok clean_network_removed "gb10_default"
fi

# ── 2. Optionally remove Docker images ──
if $REMOVE_IMAGES; then
  info clean_removing_images
  for img in "nvcr.io/nvidia/vllm:26.05-py3" "searxng/searxng:latest" "ghcr.io/open-webui/open-webui:main"; do
    if docker image inspect "$img" &>/dev/null; then
      docker rmi "$img" 2>/dev/null && ok clean_image_removed "$img" || warn clean_image_failed "$img"
    fi
  done
fi

# ── 3. Remove generated .env ──
if [ -f .env ]; then
  rm -f .env
  ok clean_env_removed
fi

# ── 4. Restore SearXNG settings.yml (reset secret_key to placeholder) ──
info clean_restoring_searxng
sudo chown -R "$USER:$USER" searxng/ 2>/dev/null || true
if [ -f searxng/settings.yml ]; then
  sed -i 's|^  secret_key:.*|  secret_key: "change-me-to-another-random-string"|' searxng/settings.yml
  ok clean_searxng_reset
fi

# ── 5. Remove Hermes Agent config ──
if [ -d "$HOME/.hermes" ]; then
  # Stop gateway service first
  if systemctl --user is-active hermes-gateway.service &>/dev/null; then
    systemctl --user stop hermes-gateway.service 2>/dev/null || true
    systemctl --user disable hermes-gateway.service 2>/dev/null || true
    ok clean_gateway_stopped
  fi
  if [ -f "$HOME/.config/systemd/user/hermes-gateway.service" ]; then
    rm -f "$HOME/.config/systemd/user/hermes-gateway.service"
    systemctl --user daemon-reload 2>/dev/null || true
    ok clean_gateway_unit_removed
  fi
  rm -rf "$HOME/.hermes"
  ok clean_hermes_removed
fi

# Remove hermes wrapper binary if it exists
for _hbin in "$HOME/.local/bin/hermes" "$HOME/bin/hermes"; do
  if [ -f "$_hbin" ]; then
    rm -f "$_hbin"
    ok clean_hermes_bin_removed "$_hbin"
  fi
done

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  $(msg clean_complete)${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
if ! $REMOVE_IMAGES; then
  info clean_tip_images
  echo ""
fi
