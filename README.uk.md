[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Türkçe](README.tr.md) | **Українська**

# GB10 ШІ-асистент

Перетворіть ваш NVIDIA GB10 (DGX Spark) на персонального ШІ-асистента однією командою. Цей проєкт налаштовує повний самохостинговий ШІ-стек: високопродуктивний LLM inference, зручний веб-інтерфейс, веб-пошук і термінальний ШІ-агент — усе працює локально на вашому обладнанні.

## Що ви отримуєте

| Компонент | Призначення |
|-----------|---------|
| **[vLLM](https://docs.vllm.ai/)** | Високопродуктивний LLM inference server з PagedAttention, speculative decoding і tool calling |
| **[Open WebUI](https://openwebui.com/)** | Веб-інтерфейс на кшталт ChatGPT з веб-пошуком, інтерпретатором коду та підтримкою кількох моделей |
| **[SearXNG](https://docs.searxng.org/)** | Meta-search engine, що поважає приватність і надає веб-пошук для Open WebUI та Hermes |
| **[Hermes Agent](https://github.com/nousresearch/hermes-agent)** | Термінальний ШІ-асистент з веб-пошуком і messaging gateway (Telegram, Slack, Discord…) |

## Архітектура

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

## Швидкий старт

### Передумови

- NVIDIA GB10 (DGX Spark) з Ubuntu 24.04
- Встановлені Docker і Docker Compose v2
- Встановлений NVIDIA Container Toolkit
- Щонайменше 90 ГБ вільної пам’яті для моделі за замовчуванням

### Налаштування однією командою

```bash
git clone https://github.com/seandavid/gb10.git
cd gb10
./setup.sh
```

Скрипт налаштування:

1. **Запитає вашу мову** — усі повідомлення відображаються обраною мовою (підтримується 9 мов)
2. **Обробить права Docker** — за потреби автоматично додасть вас до групи docker
3. **Перевірить конфлікти GPU** — виявить інші GPU-процеси та запитає, чи зупинити їх
4. **Завантажить модель** — отримає Qwen3.6-35B-A3B-FP8 (~35 ГБ) через Hugging Face CLI
5. **Запустить усі сервіси** — запустить vLLM, SearXNG і Open WebUI через Docker Compose
6. **Дочекається готовності** — відстежуватиме health vLLM, поки модель завантажиться (3–5 хвилин)
7. **Запропонує Hermes Agent** — необов'язковий термінальний ШІ-асистент із messaging gateway

### Доступ до вашого ШІ

Після завершення налаштування:

| Сервіс | URL |
|---------|-----|
| Open WebUI | http://localhost:3000 |
| vLLM API | http://localhost:8000/v1 |
| SearXNG | http://localhost:8080 |

При першому відкритті Open WebUI створіть обліковий запис адміністратора. Перший зареєстрований обліковий запис стає адміністратором.

## Модель за замовчуванням

Модель за замовчуванням — **Qwen/Qwen3.6-35B-A3B-FP8** — mixture-of-experts модель на 35B параметрів із лише 3B активних параметрів на токен, що робить її надзвичайно ефективною на unified memory architecture GB10.

Ключові можливості, налаштовані одразу:
- **Reasoning** — `--reasoning-parser qwen3` увімкнює структурований вивід міркувань
- **Tool calling** — `--tool-call-parser qwen3_coder` увімкнює function calling для інструментів Open WebUI
- **Speculative decoding** — Multi-Token Prediction (MTP) для генерації в 1,5–2 рази швидше
- **262K context** — повна підтримка довгого контексту

## Зміна моделі

vLLM попередньо виділяє GPU-пам’ять для KV cache під час запуску. Це свідомий дизайнерський вибір — він гарантує відсутність out-of-memory помилок під час inference, на відміну від Ollama чи llama.cpp, які виділяють пам’ять за запитом і можуть зазнати збою посеред розмови. Компроміс у тому, що для зміни моделі потрібен перезапуск контейнера.

Скористайтеся допоміжним скриптом:

```bash
./switch-model.sh
```

Скрипт:
1. Покаже поточну модель
2. Запитає repo нової моделі (наприклад, `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8`)
3. Завантажить її, якщо вона ще не присутня
4. Оновить конфігурацію
5. Перезапустить лише контейнер vLLM (Open WebUI і SearXNG залишаються запущеними)
6. Дочекається, поки нова модель стане healthy
7. Оновить конфігурацію Hermes Agent, якщо він встановлений

## Веб-пошук

### SearXNG (самохостинговий пошук)

І Open WebUI, і Hermes Agent використовують локальний екземпляр SearXNG для веб-пошуку. SearXNG — meta-search engine, який агрегує результати з кількох пошукових систем без відстеження вас.

Переваги над DuckDuckGo (який був попереднім стандартом):
- **Без rate limiting** — DuckDuckGo блокує автоматизовані запити; SearXNG не має обмежень, оскільки він самохостинговий
- **Multi-engine** — агрегує результати з Google, Bing, DuckDuckGo та інших
- **Приватність** — усі запити залишаються на вашій машині
- **Надійність** — без залежності від доступності зовнішніх API

SearXNG налаштовується автоматично — API keys не потрібні.

## Hermes Agent

Hermes Agent — термінальний ШІ-асистент, який підключається до вашого локального vLLM. Він надає:

- **Веб-пошук** — використовує SearXNG для інформації в реальному часі
- **Операції з файлами** — читання, запис і аналіз файлів
- **Виконання коду** — запуск коду в sandboxed environment
- **Messaging gateway** — підключення до Telegram, Slack, Discord та інших платформ

### Встановлення

```bash
./setup-hermes.sh
```

Або оберіть «yes», коли запитають наприкінці `setup.sh`.

### Messaging Gateway

Після встановлення Hermes ви можете підключити його до messaging platforms:

```bash
hermes gateway setup    # Interactive wizard for platform setup
hermes gateway status   # Check gateway status
hermes gateway logs     # View gateway logs
```

Скрипт налаштування автоматично встановлює gateway як systemd user service, тож він зберігається після перезавантаження і працює, навіть коли ви не в системі.

Підтримувані платформи включають Telegram, Discord, Slack, WhatsApp, Signal, Matrix та інші.

## Конфігурація

Уся конфігурація знаходиться у файлі `.env` (створюється з `.env.example` під час налаштування):

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_REPO` | `Qwen/Qwen3.6-35B-A3B-FP8` | Hugging Face model repository |
| `MODEL_DIR` | `/data/models/Qwen--Qwen3.6-35B-A3B-FP8` | Локальний шлях зберігання моделі |
| `SERVED_MODEL_NAME` | `Qwen/Qwen3.6-35B-A3B-FP8` | Ім’я, що надається через OpenAI API |
| `VLLM_IMAGE` | `nvcr.io/nvidia/vllm:26.05-py3` | Docker-образ vLLM |
| `VLLM_PORT` | `8000` | Порт vLLM API |
| `GPU_MEMORY_UTILIZATION` | `0.75` | Частка GPU-пам’яті для KV cache |
| `MAX_MODEL_LEN` | `262144` | Максимальна довжина контексту |
| `REASONING_PARSER` | `qwen3` | Reasoning output parser |
| `TOOL_CALL_PARSER` | `qwen3_coder` | Tool/function call parser |
| `OPEN_WEBUI_PORT` | `3000` | Порт Open WebUI |
| `SEARXNG_PORT` | `8080` | Порт SearXNG |
| `DEFAULT_LOCALE` | (auto) | Мова інтерфейсу Open WebUI |

## Налаштування продуктивності

### Використання GPU-пам’яті

Параметр `GPU_MEMORY_UTILIZATION` (за замовчуванням `0.75`) контролює, скільки GPU-пам’яті vLLM резервує для KV cache. На GB10 із 128 ГБ unified memory:

- `0.75` — за замовчуванням, безпечно для більшості навантажень з 262K context
- `0.85` — більше KV cache = більше одночасних запитів або довший контекст
- `0.60` — залишити більше пам’яті для інших GPU-навантажень

### Довжина контексту

Зменшіть `MAX_MODEL_LEN`, якщо вам не потрібен 262K context. Коротший контекст використовує менше пам’яті і запускається швидше:
- `131072` (128K) — гарний баланс
- `65536` (64K) — швидкий запуск, достатньо для більшості задач
- `32768` (32K) — мінімальне використання пам’яті

### Speculative Decoding

Конфігурація за замовчуванням використовує Multi-Token Prediction із 2 speculative tokens. Щоб вимкнути (економить пам’ять, генерація трохи повільніша), відредагуйте рядок `--speculative-config` у `docker-compose.yml`:

```yaml
      - --speculative-config
      - '{}'
```

## Очищення

Щоб повністю скинути встановлення та почати заново:

```bash
./clean.sh
```

Це видаляє всі контейнери, volumes, мережі, файл `.env`, зміни SearXNG і конфігурацію Hermes Agent. Файли моделей у `/data/models` зберігаються, щоб уникнути повторного завантаження.

Щоб також видалити Docker-образи:

```bash
./clean.sh --images
```

## Усунення несправностей

### vLLM надто довго запускається

Перший запуск завантажує модель у пам’ять (~3–5 хвилин). Перевірте прогрес:

```bash
docker compose logs -f vllm
```

### Нестача пам’яті

1. Зупиніть інші GPU-процеси: `nvidia-smi`, щоб перевірити, що працює
2. Зменшіть `GPU_MEMORY_UTILIZATION` у `.env`
3. Зменшіть `MAX_MODEL_LEN` у `.env`
4. Перезапустіть: `docker compose up -d --force-recreate vllm`

### SearXNG не повертає результатів

Перевірте, чи увімкнено JSON format:

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | head -c 200
```

Якщо отримуєте помилку 403, перевірте, чи `json` є у списку `formats` у `searxng/settings.yml`.

### Open WebUI не може підключитися до vLLM

Спочатку дочекайтеся, поки vLLM стане healthy:

```bash
curl http://localhost:8000/health
```

Open WebUI автоматично перепідключиться, коли vLLM буде готовий.

### Відмовлено в доступі Docker

Запустіть `setup.sh` знову — він автоматично обробить членство в групі docker.

## Структура файлів

```
gb10/
├── setup.sh                 # Головний скрипт налаштування
├── setup-hermes.sh          # Інсталятор Hermes Agent
├── switch-model.sh          # Допоміжний скрипт зміни моделі
├── clean.sh                 # Повне очищення / скидання
├── docker-compose.yml       # Основні сервіси
├── .env.example             # Шаблон конфігурації
├── lib/
│   └── messages.sh          # Бібліотека i18n-повідомлень (9 мов)
└── searxng/
    ├── settings.yml         # Конфігурація SearXNG
    └── limiter.toml         # Обмежувач швидкості SearXNG
```

## Ліцензія

MIT
