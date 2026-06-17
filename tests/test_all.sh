#!/usr/bin/env bash
# ============================================================
#  GB10 AI Assistant – Test Suite
#  Validates scripts, configs, and i18n without running a full
#  setup (no Docker/GPU side effects).
#
#  Usage:  ./tests/test_all.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

PASS=0
FAIL=0
TOTAL=0

_test() {
  local name="$1"; shift
  TOTAL=$((TOTAL + 1))
  if "$@" 2>/dev/null; then
    echo -e "  \033[0;32m✓\033[0m $name"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m $name"
    FAIL=$((FAIL + 1))
  fi
}

_test_eq() {
  local name="$1" actual="$2" expected="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$actual" = "$expected" ]; then
    echo -e "  \033[0;32m✓\033[0m $name"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

_test_contains() {
  local name="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$haystack" | grep -qF -- "$needle"; then
    echo -e "  \033[0;32m✓\033[0m $name"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m $name (missing: '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

_test_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if ! echo "$haystack" | grep -qiF -- "$needle"; then
    echo -e "  \033[0;32m✓\033[0m $name"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m $name (should not contain: '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "═══════════════════════════════════════════"
echo "  GB10 AI Assistant – Test Suite"
echo "═══════════════════════════════════════════"

# ─────────────────────────────────────────────
echo ""
echo "── 1. Bash Syntax ──"
# ─────────────────────────────────────────────

for script in setup.sh setup-hermes.sh switch-model.sh clean.sh lib/messages.sh; do
  _test "syntax: $script" bash -n "$script"
done

# ─────────────────────────────────────────────
echo ""
echo "── 2. Required Files Exist ──"
# ─────────────────────────────────────────────

for f in setup.sh setup-hermes.sh switch-model.sh clean.sh docker-compose.yml \
         .env.example lib/messages.sh searxng/settings.yml searxng/limiter.toml \
         .gitignore; do
  _test "exists: $f" test -f "$f"
done

_test "scripts executable: setup.sh" test -x setup.sh
_test "scripts executable: setup-hermes.sh" test -x setup-hermes.sh
_test "scripts executable: switch-model.sh" test -x switch-model.sh
_test "scripts executable: clean.sh" test -x clean.sh

# ─────────────────────────────────────────────
echo ""
echo "── 4. .gitignore ──"
# ─────────────────────────────────────────────

GITIGNORE=$(cat .gitignore)
_test_contains ".gitignore has .env" "$GITIGNORE" ".env"

# ─────────────────────────────────────────────
echo ""
echo "── 5. .env.example Validation ──"
# ─────────────────────────────────────────────

ENV_EXAMPLE=$(cat .env.example)
for var in MODEL_REPO MODEL_DIR SERVED_MODEL_NAME VLLM_IMAGE VLLM_PORT \
           GPU_MEMORY_UTILIZATION MAX_MODEL_LEN REASONING_PARSER TOOL_CALL_PARSER \
           OPEN_WEBUI_PORT WEBUI_SECRET_KEY DEFAULT_LOCALE SEARXNG_PORT SEARXNG_SECRET; do
  _test_contains ".env.example has $var" "$ENV_EXAMPLE" "$var="
done

_test_not_contains ".env.example no SPECULATIVE_CONFIG" "$ENV_EXAMPLE" "SPECULATIVE_CONFIG"

# ─────────────────────────────────────────────
echo ""
echo "── 6. docker-compose.yml Validation ──"
# ─────────────────────────────────────────────

DC=$(cat docker-compose.yml)
_test_contains "compose has vllm service" "$DC" "container_name: vllm"
_test_contains "compose has searxng service" "$DC" "container_name: searxng"
_test_contains "compose has open-webui service" "$DC" "container_name: open-webui"
_test_contains "compose has speculative-config" "$DC" "speculative-config"
_test_contains "compose has valid JSON for speculative" "$DC" '{"method":"qwen3_next_mtp"'
_test_contains "compose has ENABLE_WEB_SEARCH" "$DC" "ENABLE_WEB_SEARCH=True"
_test_contains "compose has WEB_SEARCH_ENGINE=searxng" "$DC" "WEB_SEARCH_ENGINE=searxng"
_test_contains "compose has DEFAULT_MODEL_PARAMS" "$DC" "function_calling"
_test_contains "compose has defaultFeatureIds" "$DC" "defaultFeatureIds"
_test_contains "compose has web_search in defaultFeatureIds" "$DC" '"web_search"'

# ─────────────────────────────────────────────
echo ""
echo "── 7. SearXNG Config ──"
# ─────────────────────────────────────────────

SEARX=$(cat searxng/settings.yml)
_test_contains "searxng has json format" "$SEARX" "- json"
_test_contains "searxng has html format" "$SEARX" "- html"
_test_contains "searxng binds 0.0.0.0" "$SEARX" '0.0.0.0'
_test_contains "searxng has google engine" "$SEARX" "engine: google"

# ─────────────────────────────────────────────
echo ""
echo "── 8. i18n Message Completeness ──"
# ─────────────────────────────────────────────

LANGS=(en zh-TW zh-CN ja de es fr tr uk)

SETUP_KEYS=(banner preflight preflight_ok docker_not_found docker_no_perm
  docker_group_add docker_compose_missing gpu_not_found curl_not_found
  sudo_searxng_explain sudo_model_dir_explain
  creating_env env_created model_present downloading_model download_time
  installing_hf model_downloaded pulling_images images_ready creating_model_dir
  gpu_conflict_title gpu_conflict_docker gpu_conflict_host gpu_conflict_warn
  stopping_containers starting_services waiting_vllm vllm_loading_logs
  vllm_healthy vllm_timeout
  setup_complete first_time_hint open_webui_hint
  hermes_hint_title hermes_hint_cmd hermes_hint_web_search hermes_hint_gateway
  ask_hermes hermes_later yes_no)

HERMES_KEYS=(hermes_banner hermes_installed hermes_reinstalling hermes_installing
  hermes_not_found hermes_config_written hermes_config_backup hermes_vllm_ok
  hermes_vllm_fail hermes_ready ask_gateway gateway_systemd gateway_started
  gateway_help_status gateway_help_logs gateway_help_add)

SWITCH_KEYS=(switch_banner current_model ask_model_repo ask_served_name
  ask_reasoning_parser ask_tool_parser ask_max_model_len restarting_vllm
  hermes_updated switch_complete)

CLEAN_KEYS=(clean_banner clean_desc clean_item_docker clean_item_env
  clean_item_searxng clean_item_hermes clean_item_gateway
  clean_note_model clean_note_images clean_proceed clean_aborted
  clean_stopping_docker clean_main_removed clean_main_not_running
  clean_orphan_removed clean_volume_removed clean_network_removed
  clean_removing_images clean_image_removed clean_image_failed
  clean_env_removed clean_restoring_searxng clean_searxng_reset
  clean_gateway_stopped clean_gateway_unit_removed clean_hermes_removed
  clean_hermes_bin_removed clean_complete clean_tip_images)

ALL_KEYS=("${SETUP_KEYS[@]}" "${HERMES_KEYS[@]}" "${SWITCH_KEYS[@]}" "${CLEAN_KEYS[@]}")

_keys_str="${ALL_KEYS[*]}"
for lang in "${LANGS[@]}"; do
  missing_keys=$(GB10_LANG="$lang" bash --norc --noprofile -c "
    set +eu
    source lib/messages.sh 2>/dev/null
    _load_messages 2>/dev/null
    for key in $_keys_str; do
      v=\"\${_MSG[\$key]:-}\"
      [ -z \"\$v\" ] && printf '%s ' \"\$key\"
    done
  " 2>/dev/null || true)
  missing_keys="${missing_keys% }"

  TOTAL=$((TOTAL + 1))
  if [ -z "$missing_keys" ]; then
    echo -e "  \033[0;32m✓\033[0m i18n keys complete for $lang (${#ALL_KEYS[@]} keys)"
    PASS=$((PASS + 1))
  else
    count=$(echo "$missing_keys" | wc -w)
    echo -e "  \033[0;31m✗\033[0m i18n missing for $lang ($count): $missing_keys"
    FAIL=$((FAIL + 1))
  fi
done

# ─────────────────────────────────────────────
echo ""
echo "── 9. i18n Functional Test ──"
# ─────────────────────────────────────────────

for lang in "${LANGS[@]}"; do
  result=$(GB10_LANG="$lang" bash -c 'source lib/messages.sh; msg banner')
  TOTAL=$((TOTAL + 1))
  if [ -n "$result" ] && [ "$result" != "banner" ]; then
    echo -e "  \033[0;32m✓\033[0m msg(banner) in $lang = \"$result\""
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m msg(banner) in $lang returned empty or key name"
    FAIL=$((FAIL + 1))
  fi
done

for lang in "${LANGS[@]}"; do
  result=$(GB10_LANG="$lang" bash -c 'source lib/messages.sh; msg clean_banner')
  TOTAL=$((TOTAL + 1))
  if [ -n "$result" ] && [ "$result" != "clean_banner" ]; then
    echo -e "  \033[0;32m✓\033[0m msg(clean_banner) in $lang = \"$result\""
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m msg(clean_banner) in $lang returned empty or key name"
    FAIL=$((FAIL + 1))
  fi
done

# ─────────────────────────────────────────────
echo ""
echo "── 10. i18n Printf Substitution ──"
# ─────────────────────────────────────────────

for lang in "${LANGS[@]}"; do
  result=$(GB10_LANG="$lang" bash -c 'source lib/messages.sh; msg model_present "/data/models/test"')
  TOTAL=$((TOTAL + 1))
  if echo "$result" | grep -qF "/data/models/test"; then
    echo -e "  \033[0;32m✓\033[0m printf substitution in $lang"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m printf substitution failed in $lang: $result"
    FAIL=$((FAIL + 1))
  fi
done

# ─────────────────────────────────────────────
echo ""
echo "── 11. Language Mapping ──"
# ─────────────────────────────────────────────

_test_eq "hermes_lang en" "$(GB10_LANG=en bash -c 'source lib/messages.sh; hermes_lang')" "en"
_test_eq "hermes_lang zh-TW" "$(GB10_LANG=zh-TW bash -c 'source lib/messages.sh; hermes_lang')" "zh"
_test_eq "hermes_lang ja" "$(GB10_LANG=ja bash -c 'source lib/messages.sh; hermes_lang')" "ja"

_test_eq "webui_locale en" "$(GB10_LANG=en bash -c 'source lib/messages.sh; webui_locale')" "en-US"
_test_eq "webui_locale zh-TW" "$(GB10_LANG=zh-TW bash -c 'source lib/messages.sh; webui_locale')" "zh-TW"
_test_eq "webui_locale ja" "$(GB10_LANG=ja bash -c 'source lib/messages.sh; webui_locale')" "ja-JP"
_test_eq "webui_locale de" "$(GB10_LANG=de bash -c 'source lib/messages.sh; webui_locale')" "de-DE"

# ─────────────────────────────────────────────
echo ""
echo "── 12. README Completeness ──"
# ─────────────────────────────────────────────

README_FILES=(README.md README.zh-TW.md README.zh-CN.md README.ja.md
  README.de.md README.es.md README.fr.md README.tr.md README.uk.md)

for f in "${README_FILES[@]}"; do
  _test "exists: $f" test -f "$f"
done

for f in "${README_FILES[@]}"; do
  content=$(cat "$f")
  _test_contains "$f has clean.sh" "$content" "clean.sh"
done

# Language selector links in each README (first line should link to other READMEs)
for f in "${README_FILES[@]}"; do
  first_line=$(head -1 "$f")
  link_count=$(echo "$first_line" | grep -oF 'README.' | wc -l)
  TOTAL=$((TOTAL + 1))
  if [ "$link_count" -ge 5 ]; then
    echo -e "  \033[0;32m✓\033[0m $f has language selector ($link_count links)"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m $f missing language selector (only $link_count links)"
    FAIL=$((FAIL + 1))
  fi
done

# ─────────────────────────────────────────────
echo ""
echo "── 13. setup.sh References ──"
# ─────────────────────────────────────────────

SETUP=$(cat setup.sh)
_test_contains "setup.sh sources messages.sh" "$SETUP" 'source "$SCRIPT_DIR/lib/messages.sh"'
_test_contains "setup.sh has docker group check" "$SETUP" "id -nG"
_test_contains "setup.sh has GPU conflict detection" "$SETUP" "nvidia-smi --query-compute-apps"
_test_contains "setup.sh has hf install" "$SETUP" "hf.co/cli/install.sh"
_test_contains "setup.sh has health check loop" "$SETUP" 'curl -sf "http://localhost:${VLLM_PORT}/health"'
_test_contains "setup.sh tails vLLM logs" "$SETUP" "docker compose logs -f"
_test_contains "setup.sh explains sudo for searxng" "$SETUP" "sudo_searxng_explain"
_test_contains "setup.sh explains sudo for model dir" "$SETUP" "sudo_model_dir_explain"
_test_contains "setup.sh has hermes prompt" "$SETUP" "ask_hermes"

# ─────────────────────────────────────────────
echo ""
echo "── 14. clean.sh References ──"
# ─────────────────────────────────────────────

CLEAN=$(cat clean.sh)
_test_contains "clean.sh sources messages.sh" "$CLEAN" 'source "$SCRIPT_DIR/lib/messages.sh"'
_test_contains "clean.sh has docker compose down" "$CLEAN" "docker compose"
_test_contains "clean.sh has volume cleanup" "$CLEAN" "docker volume"
_test_contains "clean.sh has network cleanup" "$CLEAN" "docker network"
_test_contains "clean.sh has .env removal" "$CLEAN" "rm -f .env"
_test_contains "clean.sh has searxng restore" "$CLEAN" "secret_key"
_test_contains "clean.sh has hermes cleanup" "$CLEAN" ".hermes"
_test_contains "clean.sh has --images flag" "$CLEAN" '"--images"'
_test_contains "clean.sh removes hermes binary" "$CLEAN" "clean_hermes_bin_removed"

# ─────────────────────────────────────────────
echo ""
echo "── 15. setup-hermes.sh References ──"
# ─────────────────────────────────────────────

HERMES_SH=$(cat setup-hermes.sh)
_test_contains "setup-hermes.sh sources messages.sh" "$HERMES_SH" 'source "$SCRIPT_DIR/lib/messages.sh"'
_test_contains "setup-hermes.sh checks hermes --version" "$HERMES_SH" "hermes --version"
_test_contains "setup-hermes.sh handles reinstall" "$HERMES_SH" "hermes_reinstalling"
_test_contains "setup-hermes.sh has gateway setup" "$HERMES_SH" "hermes gateway setup"

# ─────────────────────────────────────────────
echo ""
echo "── 16. docker-compose.yml Validation ──"
# ─────────────────────────────────────────────

if command -v python3 &>/dev/null; then
  TOTAL=$((TOTAL + 1))
  if python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2>/dev/null; then
    echo -e "  \033[0;32m✓\033[0m docker-compose.yml valid YAML"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m docker-compose.yml invalid YAML"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  - skipped YAML validation (python3 not available)"
fi

# Validate with docker compose config
TOTAL=$((TOTAL + 1))
if docker compose -f docker-compose.yml config --quiet 2>/dev/null; then
  echo -e "  \033[0;32m✓\033[0m docker compose config validates"
  PASS=$((PASS + 1))
else
  echo -e "  \033[0;31m✗\033[0m docker compose config failed"
  FAIL=$((FAIL + 1))
fi

# ─────────────────────────────────────────────
echo ""
echo "── 17. Speculative Config Integrity ──"
# ─────────────────────────────────────────────

DC=$(cat docker-compose.yml)
_test_contains "speculative-config is YAML list item" "$DC" "--speculative-config"
_test_contains "speculative-config JSON has method" "$DC" '"method":"qwen3_next_mtp"'

TOTAL=$((TOTAL + 1))
SPEC_JSON=$(grep "qwen3_next_mtp" docker-compose.yml | sed "s/^[^{]*//" | sed "s/'//g")
if echo "$SPEC_JSON" | python3 -c "import sys,json; json.loads(sys.stdin.read().strip())" 2>/dev/null; then
  echo -e "  \033[0;32m✓\033[0m speculative-config JSON is valid"
  PASS=$((PASS + 1))
else
  echo -e "  \033[0;31m✗\033[0m speculative-config JSON is invalid"
  FAIL=$((FAIL + 1))
fi

# ─────────────────────────────────────────────
echo ""
echo "── 18. Cross-Script Consistency ──"
# ─────────────────────────────────────────────

ENV_EX=$(cat .env.example)
COMPOSE=$(cat docker-compose.yml)

DEFAULT_PORT=$(echo "$ENV_EX" | grep '^VLLM_PORT=' | cut -d= -f2)
_test_eq "VLLM_PORT default" "$DEFAULT_PORT" "8000"

DEFAULT_GPU=$(echo "$ENV_EX" | grep '^GPU_MEMORY_UTILIZATION=' | cut -d= -f2)
_test_eq "GPU_MEMORY_UTILIZATION default" "$DEFAULT_GPU" "0.75"

_test_contains "compose uses VLLM_PORT var" "$COMPOSE" 'VLLM_PORT:-8000'
_test_contains "compose uses GPU_MEMORY_UTILIZATION var" "$COMPOSE" 'GPU_MEMORY_UTILIZATION:-0.75'

# ─────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo -e "  \033[0;32mAll $TOTAL tests passed!\033[0m"
else
  echo -e "  \033[0;31m$FAIL/$TOTAL tests failed\033[0m"
fi
echo "═══════════════════════════════════════════"
echo ""

exit "$FAIL"
