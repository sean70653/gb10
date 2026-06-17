[English](README.md) | [繁體中文](README.zh-TW.md) | **简体中文** | [日本語](README.ja.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md)

# GB10 AI 助手

只需一条命令，即可将你的 NVIDIA GB10（DGX Spark）变成个人 AI 助手。本项目会搭建完整的自托管 AI 技术栈：高性能 LLM 推理、精美的 Web 界面、网页搜索与终端 AI 代理——全部在你的硬件上本地运行。

## 你将获得

| 组件 | 用途 |
|------|------|
| **[vLLM](https://docs.vllm.ai/)** | 高性能 LLM 推理服务器，具备 PagedAttention、speculative decoding 与 tool calling |
| **[Open WebUI](https://openwebui.com/)** | 类似 ChatGPT 的 Web 界面，支持网页搜索、代码解释器与多模型 |
| **[SearXNG](https://docs.searxng.org/)** | 注重隐私的 meta-search 引擎，为 Open WebUI 与 Hermes 提供网页搜索 |
| **[Hermes Agent](https://github.com/nousresearch/hermes-agent)** | 终端 AI 助手，支持网页搜索与消息网关（Telegram、Slack、Discord…） |

## 架构

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

## 快速开始

### 前置条件

- 运行 Ubuntu 24.04 的 NVIDIA GB10（DGX Spark）
- 已安装 Docker 与 Docker Compose v2
- 已安装 NVIDIA Container Toolkit
- 默认模型至少需要 90 GB 可用内存

### 一键安装

```bash
git clone https://github.com/sean70653/gb10.git
cd gb10
./setup.sh
```

安装脚本会：

1. **询问偏好的语言** — 所有消息会以你选择的语言显示（支持 9 种语言）
2. **处理 Docker 权限** — 必要时自动将你加入 docker 组
3. **检查 GPU 冲突** — 检测其他 GPU 进程并询问是否要停止
4. **下载模型** — 使用 Hugging Face CLI 获取 Qwen3.6-35B-A3B-FP8（约 35 GB）
5. **启动所有服务** — 通过 Docker Compose 启动 vLLM、SearXNG 与 Open WebUI
6. **等待就绪** — 监控 vLLM 健康状态直到模型加载完成（3–5 分钟）
7. **提供 Hermes Agent** — 可选的终端 AI 助手，附带消息网关

### 访问你的 AI

安装完成后：

| 服务 | URL |
|------|-----|
| Open WebUI | http://localhost:3000 |
| vLLM API | http://localhost:8000/v1 |
| SearXNG | http://localhost:8080 |

首次打开 Open WebUI 时，请创建管理员账号。第一个注册的账号将成为管理员。

## 默认模型

默认模型为 **Qwen/Qwen3.6-35B-A3B-FP8** — 350 亿参数的 mixture-of-experts 模型，每个 token 仅激活 30 亿参数，在 GB10 的 unified memory 架构上极为高效。

开箱即用的主要功能：
- **Reasoning** — `--reasoning-parser qwen3` 启用结构化思考输出
- **Tool calling** — `--tool-call-parser qwen3_coder` 为 Open WebUI 工具启用 function calling
- **Speculative decoding** — Multi-Token Prediction（MTP）可加快 1.5–2 倍生成速度
- **262K context** — 完整长上下文支持

## 切换模型

vLLM 在启动时会预先分配 GPU 内存给 KV cache。这是刻意的设计选择——可确保推理过程中不会发生内存不足错误，不像 Ollama 或 llama.cpp 采用按需分配，可能在对话中途失败。代价是切换模型需要重启容器。

使用提供的辅助脚本：

```bash
./switch-model.sh
```

脚本会：
1. 显示你当前的模型
2. 询问新的模型 repo（例如 `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8`）
3. 若尚未下载则进行下载
4. 更新配置
5. 仅重启 vLLM 容器（Open WebUI 与 SearXNG 保持运行）
6. 等待新模型就绪
7. 若已安装则更新 Hermes Agent 配置

## 网页搜索

### SearXNG（自托管搜索）

Open WebUI 与 Hermes Agent 都使用本地 SearXNG 实例进行网页搜索。SearXNG 是 meta-search 引擎，聚合多个搜索引擎的结果且不追踪用户。

相较于 DuckDuckGo（先前的默认）的优势：
- **无速率限制** — DuckDuckGo 会封锁自动化查询；SearXNG 自托管后没有限制
- **多引擎** — 聚合 Google、Bing、DuckDuckGo 等结果
- **隐私** — 所有查询都留在你的机器上
- **可靠性** — 不依赖外部 API 可用性

SearXNG 会自动配置——无需 API 密钥。

## Hermes Agent

Hermes Agent 是连接本地 vLLM 的终端 AI 助手，提供：

- **网页搜索** — 使用 SearXNG 获取实时信息
- **文件操作** — 读取、写入与分析文件
- **代码执行** — 在沙箱环境中运行代码
- **消息网关** — 连接 Telegram、Slack、Discord 等平台

### 安装

```bash
./setup-hermes.sh
```

或在 `setup.sh` 结尾提示时选择「是」。

### 消息网关

安装 Hermes 后，可将其连接至消息平台：

```bash
hermes gateway setup    # Interactive wizard for platform setup
hermes gateway status   # Check gateway status
hermes gateway logs     # View gateway logs
```

安装脚本会自动将网关安装为 systemd 用户服务，因此重启后仍会保留，且即使未登录也会运行。

支持的平台包括 Telegram、Discord、Slack、WhatsApp、Signal、Matrix 等。

## 配置

所有配置都在 `.env` 文件中（安装时由 `.env.example` 创建）：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MODEL_REPO` | `Qwen/Qwen3.6-35B-A3B-FP8` | Hugging Face 模型 repository |
| `MODEL_DIR` | `/data/models/Qwen--Qwen3.6-35B-A3B-FP8` | 本地模型存储路径 |
| `SERVED_MODEL_NAME` | `Qwen/Qwen3.6-35B-A3B-FP8` | 通过 OpenAI API 暴露的名称 |
| `VLLM_IMAGE` | `nvcr.io/nvidia/vllm:26.05-py3` | vLLM Docker 镜像 |
| `VLLM_PORT` | `8000` | vLLM API 端口 |
| `GPU_MEMORY_UTILIZATION` | `0.75` | 用于 KV cache 的 GPU 内存比例 |
| `MAX_MODEL_LEN` | `262144` | 最大上下文长度 |
| `REASONING_PARSER` | `qwen3` | Reasoning 输出 parser |
| `TOOL_CALL_PARSER` | `qwen3_coder` | Tool/function call parser |
| `OPEN_WEBUI_PORT` | `3000` | Open WebUI 端口 |
| `SEARXNG_PORT` | `8080` | SearXNG 端口 |
| `DEFAULT_LOCALE` | (auto) | Open WebUI 的 UI 语言 |

## 性能调优

### GPU 内存利用率

`GPU_MEMORY_UTILIZATION` 设置（默认 `0.75`）控制 vLLM 为 KV cache 保留多少 GPU 内存。在具备 128 GB unified memory 的 GB10 上：

- `0.75` — 默认值，对 262K context 的大多数工作负载安全
- `0.85` — 更多 KV cache = 更多并发请求或更长上下文
- `0.60` — 为其他 GPU 工作负载保留更多内存

### 上下文长度

若不需要 262K context，可缩减 `MAX_MODEL_LEN`。较短的上下文使用更少内存且启动更快：
- `131072`（128K）— 良好平衡
- `65536`（64K）— 快速启动，足以应付大多数任务
- `32768`（32K）— 最低内存占用

### Speculative Decoding

默认配置使用 2 个 speculative token 的 Multi-Token Prediction。若要禁用（节省内存，生成略慢），编辑 `docker-compose.yml` 中的 `--speculative-config` 行：

```yaml
      - --speculative-config
      - '{}'
```

## 清理

若要完全重置安装以重新开始：

```bash
./clean.sh
```

这会移除所有容器、卷、网络、`.env` 文件、SearXNG 修改项以及 Hermes Agent 配置。`/data/models` 中的模型文件会保留，以避免重新下载。

若要一并移除 Docker 镜像：

```bash
./clean.sh --images
```

## 故障排除

### vLLM 启动时间过长

首次启动会将模型加载到内存（约 3–5 分钟）。查看进度：

```bash
docker compose logs -f vllm
```

### 内存不足

1. 停止其他 GPU 进程：使用 `nvidia-smi` 查看运行中的进程
2. 在 `.env` 中降低 `GPU_MEMORY_UTILIZATION`
3. 在 `.env` 中降低 `MAX_MODEL_LEN`
4. 重启：`docker compose up -d --force-recreate vllm`

### SearXNG 没有返回结果

确认已启用 JSON 格式：

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | head -c 200
```

若出现 403 错误，请检查 `searxng/settings.yml` 的 `formats` 列表中是否包含 `json`。

### Open WebUI 无法连接 vLLM

请先等待 vLLM 就绪：

```bash
curl http://localhost:8000/health
```

vLLM 就绪后，Open WebUI 会自动重新连接。

### Docker 权限被拒绝

再次运行 `setup.sh` — 它会自动处理 docker 组成员资格。

## 文件结构

```
gb10/
├── setup.sh                 # 主安装脚本
├── setup-hermes.sh          # Hermes Agent 安装程序
├── switch-model.sh          # 模型切换辅助工具
├── clean.sh                 # 完整清理 / 重置
├── docker-compose.yml       # 主要服务
├── .env.example             # 配置模板
├── lib/
│   └── messages.sh          # i18n 消息库（9 种语言）
└── searxng/
    ├── settings.yml         # SearXNG 配置
    └── limiter.toml         # SearXNG 速率限制器
```

## 许可证

MIT
