[English](README.md) | **繁體中文** | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md)

# GB10 AI Assistant

只需一個指令，就能將您的 NVIDIA GB10（DGX Spark）變成個人 AI 助理。本專案會設定完整的自架 AI 技術堆疊：高效能 LLM 推論、精美的網頁介面、網頁搜尋與終端機 AI 代理——全部在您的硬體上本地執行。

## 您將獲得

| 元件 | 用途 |
|------|------|
| **[vLLM](https://docs.vllm.ai/)** | 高效能 LLM 推論伺服器，具備 PagedAttention、speculative decoding 與 tool calling |
| **[Open WebUI](https://openwebui.com/)** | 類似 ChatGPT 的網頁介面，支援網頁搜尋、程式碼解譯器與多模型 |
| **[SearXNG](https://docs.searxng.org/)** | 注重隱私的 meta-search 引擎，為 Open WebUI 與 Hermes 提供網頁搜尋 |
| **[Hermes Agent](https://github.com/nousresearch/hermes-agent)** | 終端機 AI 助理，支援網頁搜尋與訊息閘道（Telegram、Slack、Discord…） |

## 架構

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

## 快速開始

### 先決條件

- 執行 Ubuntu 24.04 的 NVIDIA GB10（DGX Spark）
- 已安裝 Docker 與 Docker Compose v2
- 已安裝 NVIDIA Container Toolkit
- 預設模型至少需要 90 GB 可用記憶體

### 一鍵安裝

```bash
git clone https://github.com/seandavid/gb10.git
cd gb10
./setup.sh
```

安裝腳本會：

1. **詢問偏好的語言** — 所有訊息會以您選擇的語言顯示（支援 9 種語言）
2. **處理 Docker 權限** — 必要時自動將您加入 docker 群組
3. **檢查 GPU 衝突** — 偵測其他 GPU 程序並詢問是否要停止
4. **下載模型** — 使用 Hugging Face CLI 取得 Qwen3.6-35B-A3B-FP8（約 35 GB）
5. **啟動所有服務** — 透過 Docker Compose 啟動 vLLM、SearXNG 與 Open WebUI
6. **等待就緒** — 監控 vLLM 健康狀態直到模型載入完成（3–5 分鐘）
7. **提供 Hermes Agent** — 可選的終端機 AI 助理，附訊息閘道

### 存取您的 AI

安裝完成後：

| 服務 | URL |
|------|-----|
| Open WebUI | http://localhost:3000 |
| vLLM API | http://localhost:8000/v1 |
| SearXNG | http://localhost:8080 |

首次開啟 Open WebUI 時，請建立管理員帳號。第一個註冊的帳號將成為管理員。

## 預設模型

預設模型為 **Qwen/Qwen3.6-35B-A3B-FP8** — 350 億參數的 mixture-of-experts 模型，每個 token 僅啟用 30 億參數，在 GB10 的 unified memory 架構上極為高效。

開箱即用的主要功能：
- **Reasoning** — `--reasoning-parser qwen3` 啟用結構化思考輸出
- **Tool calling** — `--tool-call-parser qwen3_coder` 為 Open WebUI 工具啟用 function calling
- **Speculative decoding** — Multi-Token Prediction（MTP）可加快 1.5–2 倍生成速度
- **262K context** — 完整長上下文支援

## 切換模型

vLLM 在啟動時會預先分配 GPU 記憶體給 KV cache。這是刻意的設計選擇——可確保推論過程不會發生記憶體不足錯誤，不像 Ollama 或 llama.cpp 採用按需分配，可能在對話中途失敗。代價是切換模型需要重新啟動容器。

使用提供的輔助腳本：

```bash
./switch-model.sh
```

腳本會：
1. 顯示您目前的模型
2. 詢問新的模型 repo（例如 `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8`）
3. 若尚未下載則進行下載
4. 更新設定
5. 僅重新啟動 vLLM 容器（Open WebUI 與 SearXNG 保持執行）
6. 等待新模型就緒
7. 若已安裝則更新 Hermes Agent 設定

## 網頁搜尋

### SearXNG（自架搜尋）

Open WebUI 與 Hermes Agent 都使用本機 SearXNG 執行個體進行網頁搜尋。SearXNG 是 meta-search 引擎，彙整多個搜尋引擎的結果且不追蹤使用者。

相較於 DuckDuckGo（先前的預設）的優勢：
- **無速率限制** — DuckDuckGo 會封鎖自動化查詢；SearXNG 自架後沒有限制
- **多引擎** — 彙整 Google、Bing、DuckDuckGo 等結果
- **隱私** — 所有查詢都留在您的機器上
- **可靠性** — 不依賴外部 API 可用性

SearXNG 會自動設定——無需 API 金鑰。

## Hermes Agent

Hermes Agent 是連接本機 vLLM 的終端機 AI 助理，提供：

- **網頁搜尋** — 使用 SearXNG 取得即時資訊
- **檔案操作** — 讀取、寫入與分析檔案
- **程式碼執行** — 在沙箱環境中執行程式碼
- **訊息閘道** — 連接 Telegram、Slack、Discord 等平台

### 安裝

```bash
./setup-hermes.sh
```

或在 `setup.sh` 結尾提示時選擇「是」。

### 訊息閘道

安裝 Hermes 後，可將其連接至訊息平台：

```bash
hermes gateway setup    # Interactive wizard for platform setup
hermes gateway status   # Check gateway status
hermes gateway logs     # View gateway logs
```

安裝腳本會自動將閘道安裝為 systemd 使用者服務，因此重開機後仍會保留，且即使未登入也會執行。

支援的平台包括 Telegram、Discord、Slack、WhatsApp、Signal、Matrix 等。

## 設定

所有設定都在 `.env` 檔案中（安裝時由 `.env.example` 建立）：

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `MODEL_REPO` | `Qwen/Qwen3.6-35B-A3B-FP8` | Hugging Face 模型 repository |
| `MODEL_DIR` | `/data/models/Qwen--Qwen3.6-35B-A3B-FP8` | 本機模型儲存路徑 |
| `SERVED_MODEL_NAME` | `Qwen/Qwen3.6-35B-A3B-FP8` | 透過 OpenAI API 暴露的名稱 |
| `VLLM_IMAGE` | `nvcr.io/nvidia/vllm:26.05-py3` | vLLM Docker 映像 |
| `VLLM_PORT` | `8000` | vLLM API 連接埠 |
| `GPU_MEMORY_UTILIZATION` | `0.75` | 用於 KV cache 的 GPU 記憶體比例 |
| `MAX_MODEL_LEN` | `262144` | 最大上下文長度 |
| `REASONING_PARSER` | `qwen3` | Reasoning 輸出 parser |
| `TOOL_CALL_PARSER` | `qwen3_coder` | Tool/function call parser |
| `OPEN_WEBUI_PORT` | `3000` | Open WebUI 連接埠 |
| `SEARXNG_PORT` | `8080` | SearXNG 連接埠 |
| `DEFAULT_LOCALE` | (auto) | Open WebUI 的 UI 語言 |

## 效能調校

### GPU 記憶體使用率

`GPU_MEMORY_UTILIZATION` 設定（預設 `0.75`）控制 vLLM 為 KV cache 保留多少 GPU 記憶體。在具備 128 GB unified memory 的 GB10 上：

- `0.75` — 預設值，對 262K context 的大多數工作負載安全
- `0.85` — 更多 KV cache = 更多並發請求或更長上下文
- `0.60` — 為其他 GPU 工作負載保留更多記憶體

### 上下文長度

若不需要 262K context，可縮減 `MAX_MODEL_LEN`。較短的上下文使用較少記憶體且啟動更快：
- `131072`（128K）— 良好平衡
- `65536`（64K）— 快速啟動，足以應付大多數任務
- `32768`（32K）— 最低記憶體用量

### Speculative Decoding

預設設定使用 2 個 speculative token 的 Multi-Token Prediction。若要停用（節省記憶體，生成略慢），編輯 `docker-compose.yml` 中的 `--speculative-config` 行：

```yaml
      - --speculative-config
      - '{}'
```

## 清理

若要完全重置安裝以重新開始：

```bash
./clean.sh
```

這會移除所有容器、磁碟區、網路、`.env` 檔案、SearXNG 修改項目以及 Hermes Agent 設定。`/data/models` 中的模型檔案會保留，以避免重新下載。

若要一併移除 Docker 映像：

```bash
./clean.sh --images
```

## 疑難排解

### vLLM 啟動時間過長

首次啟動會將模型載入記憶體（約 3–5 分鐘）。查看進度：

```bash
docker compose logs -f vllm
```

### 記憶體不足

1. 停止其他 GPU 程序：使用 `nvidia-smi` 查看執行中的程序
2. 在 `.env` 中降低 `GPU_MEMORY_UTILIZATION`
3. 在 `.env` 中降低 `MAX_MODEL_LEN`
4. 重新啟動：`docker compose up -d --force-recreate vllm`

### SearXNG 沒有回傳結果

確認已啟用 JSON 格式：

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | head -c 200
```

若出現 403 錯誤，請檢查 `searxng/settings.yml` 的 `formats` 清單中是否包含 `json`。

### Open WebUI 無法連接 vLLM

請先等待 vLLM 就緒：

```bash
curl http://localhost:8000/health
```

vLLM 就緒後，Open WebUI 會自動重新連接。

### Docker 權限遭拒

再次執行 `setup.sh` — 它會自動處理 docker 群組成員資格。

## 目錄結構

```
gb10/
├── setup.sh                 # 主要安裝腳本
├── setup-hermes.sh          # Hermes Agent 安裝程式
├── switch-model.sh          # 模型切換輔助工具
├── clean.sh                 # 完整清理 / 重置
├── docker-compose.yml       # 主要服務
├── .env.example             # 設定範本
├── lib/
│   └── messages.sh          # i18n 訊息函式庫（9 種語言）
└── searxng/
    ├── settings.yml         # SearXNG 設定
    └── limiter.toml         # SearXNG 速率限制器
```

## 授權條款

MIT
