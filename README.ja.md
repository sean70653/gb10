[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | **日本語** | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md)

# GB10 AIアシスタント

ワンコマンドで NVIDIA GB10（DGX Spark）をパーソナル AI アシスタントに変えられます。本プロジェクトは、完全なセルフホスト型 AI スタックをセットアップします。高性能 LLM 推論、美しい Web インターフェース、Web 検索、ターミナル AI エージェント——すべてをローカルハードウェア上で実行します。

## 含まれるもの

| コンポーネント | 用途 |
|-----------|---------|
| **[vLLM](https://docs.vllm.ai/)** | PagedAttention、speculative decoding、tool calling を備えた高性能 LLM 推論サーバー |
| **[Open WebUI](https://openwebui.com/)** | Web 検索、コードインタープリター、マルチモデル対応の ChatGPT 風 Web インターフェース |
| **[SearXNG](https://docs.searxng.org/)** | プライバシーに配慮した meta-search エンジン。Open WebUI と Hermes の両方に Web 検索を提供 |
| **[Hermes Agent](https://github.com/nousresearch/hermes-agent)** | Web 検索とメッセージング gateway（Telegram、Slack、Discord…）を備えたターミナルベースの AI アシスタント |

## アーキテクチャ

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

## クイックスタート

### 前提条件

- Ubuntu 24.04 搭載の NVIDIA GB10（DGX Spark）
- Docker および Docker Compose v2 がインストール済み
- NVIDIA Container Toolkit がインストール済み
- デフォルトモデル用に少なくとも 90 GB の空きメモリ

### ワンコマンドセットアップ

```bash
git clone https://github.com/sean70653/gb10.git
cd gb10
./setup.sh
```

セットアップスクリプトは次の処理を行います：

1. **希望する言語を確認** — すべてのメッセージが選択した言語で表示されます（9 言語対応）
2. **Docker 権限を処理** — 必要に応じて docker グループへ自動追加
3. **GPU 競合を確認** — 他の GPU プロセスを検出し、停止するか確認
4. **モデルをダウンロード** — Hugging Face CLI で Qwen3.6-35B-A3B-FP8（約 35 GB）を取得
5. **すべてのサービスを起動** — Docker Compose で vLLM、SearXNG、Open WebUI を起動
6. **準備完了を待機** — モデルが読み込まれるまで vLLM のヘルスを監視（3–5 分）
7. **Hermes Agent を提案** — メッセージング gateway 付きのオプションのターミナル AI アシスタント

### AI へのアクセス

セットアップ完了後：

| サービス | URL |
|---------|-----|
| Open WebUI | http://localhost:3000 |
| vLLM API | http://localhost:8000/v1 |
| SearXNG | http://localhost:8080 |

Open WebUI を初めて開く際は、管理者アカウントを作成してください。最初に登録したアカウントが管理者になります。

## デフォルトモデル

デフォルトモデルは **Qwen/Qwen3.6-35B-A3B-FP8** です。350 億パラメータの mixture-of-experts モデルで、トークンあたりアクティブなパラメータは 30 億のみ。GB10 の unified memory アーキテクチャ上で非常に効率的に動作します。

初期設定で有効な主な機能：
- **Reasoning** — `--reasoning-parser qwen3` で構造化された思考出力を有効化
- **Tool calling** — `--tool-call-parser qwen3_coder` で Open WebUI ツール用の function calling を有効化
- **Speculative decoding** — Multi-Token Prediction（MTP）により 1.5–2 倍高速な生成
- **262K context** — 完全な長コンテキスト対応

## モデルの切り替え

vLLM は起動時に KV cache 用の GPU メモリを事前割り当てします。これは意図的な設計です。Ollama や llama.cpp のようにオンデマンドで割り当てて会話途中で失敗するのではなく、推論中のメモリ不足エラーを防ぎます。トレードオフとして、モデル切り替えにはコンテナの再起動が必要です。

付属のヘルパースクリプトを使用してください：

```bash
./switch-model.sh
```

スクリプトは次の処理を行います：
1. 現在のモデルを表示
2. 新しいモデル repo を入力（例：`Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8`）
3. 未ダウンロードの場合はダウンロード
4. 設定を更新
5. vLLM コンテナのみ再起動（Open WebUI と SearXNG は稼働継続）
6. 新しいモデルが healthy になるまで待機
7. インストール済みの場合は Hermes Agent の設定を更新

## Web 検索

### SearXNG（セルフホスト検索）

Open WebUI と Hermes Agent の両方が、Web 検索にローカルの SearXNG インスタンスを使用します。SearXNG は meta-search エンジンで、複数の検索エンジンの結果を集約し、ユーザーを追跡しません。

DuckDuckGo（以前のデフォルト）と比較した利点：
- **レート制限なし** — DuckDuckGo は自動化クエリをブロックしますが、SearXNG はセルフホストのため制限がありません
- **マルチエンジン** — Google、Bing、DuckDuckGo などの結果を集約
- **プライバシー** — すべてのクエリはマシン内に留まります
- **信頼性** — 外部 API の可用性に依存しません

SearXNG は自動設定されます——API キーは不要です。

## Hermes Agent

Hermes Agent はローカルの vLLM に接続するターミナルベースの AI アシスタントです。次の機能を提供します：

- **Web 検索** — SearXNG でリアルタイム情報を取得
- **ファイル操作** — ファイルの読み取り、書き込み、分析
- **コード実行** — サンドボックス環境でコードを実行
- **メッセージング gateway** — Telegram、Slack、Discord などのプラットフォームに接続

### インストール

```bash
./setup-hermes.sh
```

または `setup.sh` の最後でプロンプトが表示された際に「yes」を選択してください。

### メッセージング Gateway

Hermes をインストール後、メッセージングプラットフォームに接続できます：

```bash
hermes gateway setup    # Interactive wizard for platform setup
hermes gateway status   # Check gateway status
hermes gateway logs     # View gateway logs
```

セットアップスクリプトは gateway を systemd ユーザーサービスとして自動インストールするため、再起動後も永続し、ログインしていなくても実行されます。

対応プラットフォームには Telegram、Discord、Slack、WhatsApp、Signal、Matrix などがあります。

## 設定

すべての設定は `.env` ファイルにあります（セットアップ時に `.env.example` から作成）：

| 変数 | デフォルト | 説明 |
|----------|---------|-------------|
| `MODEL_REPO` | `Qwen/Qwen3.6-35B-A3B-FP8` | Hugging Face モデル repository |
| `MODEL_DIR` | `/data/models/Qwen--Qwen3.6-35B-A3B-FP8` | ローカルモデル保存パス |
| `SERVED_MODEL_NAME` | `Qwen/Qwen3.6-35B-A3B-FP8` | OpenAI API 経由で公開される名前 |
| `VLLM_IMAGE` | `nvcr.io/nvidia/vllm:26.05-py3` | vLLM Docker イメージ |
| `VLLM_PORT` | `8000` | vLLM API ポート |
| `GPU_MEMORY_UTILIZATION` | `0.75` | KV cache 用 GPU メモリの割合 |
| `MAX_MODEL_LEN` | `262144` | 最大コンテキスト長 |
| `REASONING_PARSER` | `qwen3` | Reasoning 出力 parser |
| `TOOL_CALL_PARSER` | `qwen3_coder` | Tool/function call parser |
| `OPEN_WEBUI_PORT` | `3000` | Open WebUI ポート |
| `SEARXNG_PORT` | `8080` | SearXNG ポート |
| `DEFAULT_LOCALE` | (auto) | Open WebUI の UI 言語 |

## パフォーマンスチューニング

### GPU メモリ使用率

`GPU_MEMORY_UTILIZATION` 設定（デフォルト `0.75`）は、vLLM が KV cache 用に予約する GPU メモリ量を制御します。128 GB unified memory を備えた GB10 では：

- `0.75` — デフォルト。262K context のほとんどのワークロードで安全
- `0.85` — より多くの KV cache = より多くの同時リクエストまたはより長いコンテキスト
- `0.60` — 他の GPU ワークロード用にメモリを多く残す

### コンテキスト長

262K context が不要な場合は `MAX_MODEL_LEN` を減らしてください。短いコンテキストはメモリ使用量が少なく、起動も速くなります：
- `131072`（128K）— バランスが良い
- `65536`（64K）— 高速起動。ほとんどのタスクに十分
- `32768`（32K）— 最小メモリ使用量

### Speculative Decoding

デフォルト設定は 2 つの speculative token を使用する Multi-Token Prediction です。無効にする場合（メモリ節約、生成はやや遅くなる）、`docker-compose.yml` の `--speculative-config` 行を編集します：

```yaml
      - --speculative-config
      - '{}'
```

## クリーンアップ

インストールを完全にリセットして最初からやり直すには：

```bash
./clean.sh
```

すべてのコンテナ、ボリューム、ネットワーク、`.env` ファイル、SearXNG の変更、Hermes Agent の設定を削除します。`/data/models` 内のモデルファイルは再ダウンロードを避けるため保持されます。

Docker イメージも削除するには：

```bash
./clean.sh --images
```

## トラブルシューティング

### vLLM の起動に時間がかかる

初回起動時はモデルをメモリに読み込みます（約 3–5 分）。進捗を確認：

```bash
docker compose logs -f vllm
```

### メモリ不足

1. 他の GPU プロセスを停止：`nvidia-smi` で実行中のプロセスを確認
2. `.env` で `GPU_MEMORY_UTILIZATION` を下げる
3. `.env` で `MAX_MODEL_LEN` を下げる
4. 再起動：`docker compose up -d --force-recreate vllm`

### SearXNG が結果を返さない

JSON 形式が有効か確認：

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | head -c 200
```

403 エラーが出る場合は、`searxng/settings.yml` の `formats` リストに `json` が含まれているか確認してください。

### Open WebUI が vLLM に接続できない

まず vLLM が healthy になるまで待ってください：

```bash
curl http://localhost:8000/health
```

vLLM の準備が整うと、Open WebUI は自動的に再接続します。

### Docker 権限が拒否される

`setup.sh` を再実行してください——docker グループへの追加を自動で処理します。

## ファイル構成

```
gb10/
├── setup.sh                 # メインセットアップスクリプト
├── setup-hermes.sh          # Hermes Agent インストーラー
├── switch-model.sh          # モデル切り替えヘルパー
├── clean.sh                 # 完全クリーンアップ / リセット
├── docker-compose.yml       # メインサービス
├── .env.example             # 設定テンプレート
├── lib/
│   └── messages.sh          # i18n メッセージライブラリ（9 言語）
└── searxng/
    ├── settings.yml         # SearXNG 設定
    └── limiter.toml         # SearXNG レートリミッター
```

## ライセンス

MIT
