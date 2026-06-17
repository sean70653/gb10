**English** | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md)

# GB10 AI Assistant

Turn your NVIDIA GB10 (DGX Spark) into a personal AI assistant with one command. This project sets up a complete, self-hosted AI stack: high-performance LLM inference, a beautiful web interface, web search, and a terminal AI agent — all running locally on your hardware.

## What You Get

| Component | Purpose |
|-----------|---------|
| **[vLLM](https://docs.vllm.ai/)** | High-performance LLM inference server with PagedAttention, speculative decoding, and tool calling |
| **[Open WebUI](https://openwebui.com/)** | ChatGPT-like web interface with web search, code interpreter, and multi-model support |
| **[SearXNG](https://docs.searxng.org/)** | Privacy-respecting meta-search engine providing web search to both Open WebUI and Hermes |
| **[Hermes Agent](https://github.com/nousresearch/hermes-agent)** | Terminal-based AI assistant with web search and messaging gateway (Telegram, Slack, Discord…) |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  NVIDIA GB10 (DGX Spark)                                │
│                                                         │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│  │  vLLM    │   │ SearXNG  │   │  Open    │            │
│  │ :8000    │◄──│ :8080    │──►│  WebUI   │            │
│  │          │   │          │   │  :3000   │            │
│  └────┬─────┘   └────┬─────┘   └──────────┘            │
│       │              │                                  │
│       └──────┬───────┘                                  │
│              │                                          │
│       ┌──────▼─────┐                                   │
│       │  Hermes    │                                   │
│       │   Agent    │                                   │
│       │ (terminal) │                                   │
│       └────────────┘                                   │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- NVIDIA GB10 (DGX Spark) with Ubuntu 24.04
- Docker and Docker Compose v2 installed
- NVIDIA Container Toolkit installed
- At least 90 GB of available memory for the default model

### One-Command Setup

```bash
git clone https://github.com/sean70653/gb10
cd gb10
./setup.sh
```

The setup script will:

1. **Ask your preferred language** — all messages display in your chosen language (9 languages supported)
2. **Handle Docker permissions** — automatically adds you to the docker group if needed
3. **Check for GPU conflicts** — detects other GPU processes and asks if you want to stop them
4. **Download the model** — fetches Qwen3.6-35B-A3B-FP8 (~35 GB) using the Hugging Face CLI
5. **Start all services** — launches vLLM, SearXNG, and Open WebUI via Docker Compose
6. **Wait for readiness** — monitors vLLM health until the model is loaded (3–5 minutes)
7. **Offer Hermes Agent** — optional terminal AI assistant with messaging gateway

### Access Your AI

After setup completes:

| Service | URL |
|---------|-----|
| Open WebUI | http://localhost:3000 |
| vLLM API | http://localhost:8000/v1 |
| SearXNG | http://localhost:8080 |

The first time you open Open WebUI, create an admin account. The first account registered becomes the administrator.

## Default Model

The default model is **Qwen/Qwen3.6-35B-A3B-FP8** — a 35B parameter mixture-of-experts model with only 3B active parameters per token, making it extremely efficient on the GB10's unified memory architecture.

Key features configured out of the box:
- **Reasoning** — `--reasoning-parser qwen3` enables structured thinking output
- **Tool calling** — `--tool-call-parser qwen3_coder` enables function calling for Open WebUI tools
- **Speculative decoding** — Multi-Token Prediction (MTP) for 1.5–2× faster generation
- **262K context** — Full long-context support

## Model Switching

vLLM pre-allocates GPU memory for the KV cache at startup. This is a deliberate design choice — it guarantees no out-of-memory errors during inference, unlike Ollama or llama.cpp which allocate on-demand and can fail mid-conversation. The trade-off is that switching models requires a container restart.

Use the provided helper script:

```bash
./switch-model.sh
```

The script will:
1. Show your current model
2. Ask for the new model repo (e.g. `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8`)
3. Download it if not already present
4. Update the configuration
5. Restart only the vLLM container (Open WebUI and SearXNG stay running)
6. Wait for the new model to become healthy
7. Update Hermes Agent config if installed

## Web Search

### SearXNG (Self-Hosted Search)

Both Open WebUI and Hermes Agent use the local SearXNG instance for web search. SearXNG is a meta-search engine that aggregates results from multiple search engines without tracking you.

Advantages over DuckDuckGo (which was the previous default):
- **No rate limiting** — DuckDuckGo blocks automated queries; SearXNG has no limits since it's self-hosted
- **Multi-engine** — Aggregates results from Google, Bing, DuckDuckGo, and more
- **Privacy** — All queries stay on your machine
- **Reliability** — No dependency on external API availability

SearXNG is configured automatically — no API keys needed.

## Hermes Agent

Hermes Agent is a terminal-based AI assistant that connects to your local vLLM. It provides:

- **Web search** — Uses SearXNG for real-time information
- **File operations** — Read, write, and analyze files
- **Code execution** — Run code in a sandboxed environment
- **Messaging gateway** — Connect to Telegram, Slack, Discord, and other platforms

### Install

```bash
./setup-hermes.sh
```

Or select "yes" when prompted at the end of `setup.sh`.

### Messaging Gateway

After installing Hermes, you can connect it to messaging platforms:

```bash
hermes gateway setup    # Interactive wizard for platform setup
hermes gateway status   # Check gateway status
hermes gateway logs     # View gateway logs
```

The setup script automatically installs the gateway as a systemd user service, so it persists across reboots and runs even when you're not logged in.

Supported platforms include Telegram, Discord, Slack, WhatsApp, Signal, Matrix, and more.

## Configuration

All configuration is in the `.env` file (created from `.env.example` during setup):

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_REPO` | `Qwen/Qwen3.6-35B-A3B-FP8` | Hugging Face model repository |
| `MODEL_DIR` | `/data/models/Qwen--Qwen3.6-35B-A3B-FP8` | Local model storage path |
| `SERVED_MODEL_NAME` | `Qwen/Qwen3.6-35B-A3B-FP8` | Name exposed via OpenAI API |
| `VLLM_IMAGE` | `nvcr.io/nvidia/vllm:26.05-py3` | vLLM Docker image |
| `VLLM_PORT` | `8000` | vLLM API port |
| `GPU_MEMORY_UTILIZATION` | `0.75` | Fraction of GPU memory for KV cache |
| `MAX_MODEL_LEN` | `262144` | Maximum context length |
| `REASONING_PARSER` | `qwen3` | Reasoning output parser |
| `TOOL_CALL_PARSER` | `qwen3_coder` | Tool/function call parser |
| `OPEN_WEBUI_PORT` | `3000` | Open WebUI port |
| `SEARXNG_PORT` | `8080` | SearXNG port |
| `DEFAULT_LOCALE` | (auto) | UI language for Open WebUI |

## Performance Tuning

### GPU Memory Utilization

The `GPU_MEMORY_UTILIZATION` setting (default `0.75`) controls how much GPU memory vLLM reserves for the KV cache. On the GB10 with its 128 GB unified memory:

- `0.75` — Default, safe for most workloads with 262K context
- `0.85` — More KV cache = more concurrent requests or longer contexts
- `0.60` — Leave more memory for other GPU workloads

### Context Length

Reduce `MAX_MODEL_LEN` if you don't need 262K context. Shorter contexts use less memory and start faster:
- `131072` (128K) — Good balance
- `65536` (64K) — Fast startup, enough for most tasks
- `32768` (32K) — Minimal memory usage

### Speculative Decoding

The default config uses Multi-Token Prediction with 2 speculative tokens. To disable it (saves memory, slightly slower generation), edit `docker-compose.yml` and replace the `--speculative-config` line:

```yaml
      - --speculative-config
      - '{}'
```

## Cleanup

To completely reset the installation for a fresh start:

```bash
./clean.sh
```

This removes all containers, volumes, networks, the `.env` file, SearXNG modifications, and Hermes Agent config. Model files in `/data/models` are preserved to avoid re-downloading.

To also remove Docker images:

```bash
./clean.sh --images
```

## Troubleshooting

### vLLM takes too long to start

The first startup loads the model into memory (~3–5 minutes). Check progress:

```bash
docker compose logs -f vllm
```

### Out of memory

1. Stop other GPU processes: `nvidia-smi` to check what's running
2. Reduce `GPU_MEMORY_UTILIZATION` in `.env`
3. Reduce `MAX_MODEL_LEN` in `.env`
4. Restart: `docker compose up -d --force-recreate vllm`

### SearXNG returns no results

Verify the JSON format is enabled:

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | head -c 200
```

If you get a 403 error, check `searxng/settings.yml` has `json` in the `formats` list.

### Open WebUI can't connect to vLLM

Wait for vLLM to become healthy first:

```bash
curl http://localhost:8000/health
```

Open WebUI will automatically reconnect once vLLM is ready.

### Docker permission denied

Run `setup.sh` again — it handles docker group membership automatically.

## File Structure

```
gb10/
├── setup.sh                 # Main setup script
├── setup-hermes.sh          # Hermes Agent installer
├── switch-model.sh          # Model switching helper
├── clean.sh                 # Full cleanup / reset
├── docker-compose.yml       # Main services
├── .env.example             # Configuration template
├── lib/
│   └── messages.sh          # i18n message library (9 languages)
└── searxng/
    ├── settings.yml         # SearXNG configuration
    └── limiter.toml         # SearXNG rate limiter
```

## License

MIT
