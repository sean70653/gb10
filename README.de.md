[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | **Deutsch** | [Español](README.es.md) | [Français](README.fr.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md)

# GB10 KI-Assistent

Verwandeln Sie Ihren NVIDIA GB10 (DGX Spark) mit einem einzigen Befehl in einen persönlichen KI-Assistenten. Dieses Projekt richtet einen vollständigen, selbst gehosteten KI-Stack ein: leistungsstarke LLM-Inferenz, eine ansprechende Weboberfläche, Websuche und einen Terminal-KI-Agenten — alles läuft lokal auf Ihrer Hardware.

## Was Sie erhalten

| Komponente | Zweck |
|------------|-------|
| **[vLLM](https://docs.vllm.ai/)** | Hochleistungs-LLM-Inferenzserver mit PagedAttention, speculative decoding und Tool Calling |
| **[Open WebUI](https://openwebui.com/)** | ChatGPT-ähnliche Weboberfläche mit Websuche, Code-Interpreter und Multi-Model-Unterstützung |
| **[SearXNG](https://docs.searxng.org/)** | Datenschutzfreundliche Meta-Suchmaschine, die Open WebUI und Hermes mit Websuche versorgt |
| **[Hermes Agent](https://github.com/nousresearch/hermes-agent)** | Terminalbasierter KI-Assistent mit Websuche und Messaging Gateway (Telegram, Slack, Discord …) |

## Architektur

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

## Schnellstart

### Voraussetzungen

- NVIDIA GB10 (DGX Spark) mit Ubuntu 24.04
- Docker und Docker Compose v2 installiert
- NVIDIA Container Toolkit installiert
- Mindestens 90 GB verfügbarer Speicher für das Standardmodell

### Ein-Befehl-Setup

```bash
git clone https://github.com/seandavid/gb10.git
cd gb10
./setup.sh
```

Das Setup-Skript wird:

1. **Nach Ihrer bevorzugten Sprache fragen** — alle Meldungen werden in der gewählten Sprache angezeigt (9 Sprachen unterstützt)
2. **Docker-Berechtigungen handhaben** — fügt Sie bei Bedarf automatisch zur docker-Gruppe hinzu
3. **Auf GPU-Konflikte prüfen** — erkennt andere GPU-Prozesse und fragt, ob diese beendet werden sollen
4. **Das Modell herunterladen** — lädt Qwen3.6-35B-A3B-FP8 (~35 GB) mit der Hugging Face CLI herunter
5. **Alle Dienste starten** — startet vLLM, SearXNG und Open WebUI über Docker Compose
6. **Auf Bereitschaft warten** — überwacht den vLLM-Health-Status, bis das Modell geladen ist (3–5 Minuten)
7. **Hermes Agent anbieten** — optionaler Terminal-KI-Assistent mit Messaging Gateway

### Zugriff auf Ihre KI

Nach Abschluss des Setups:

| Dienst | URL |
|--------|-----|
| Open WebUI | http://localhost:3000 |
| vLLM API | http://localhost:8000/v1 |
| SearXNG | http://localhost:8080 |

Beim ersten Öffnen von Open WebUI erstellen Sie ein Admin-Konto. Das erste registrierte Konto wird zum Administrator.

## Standardmodell

Das Standardmodell ist **Qwen/Qwen3.6-35B-A3B-FP8** — ein 35B-Parameter-Mixture-of-Experts-Modell mit nur 3B aktiven Parametern pro Token, was es auf der Unified-Memory-Architektur des GB10 äußerst effizient macht.

Vorkonfigurierte Hauptmerkmale:
- **Reasoning** — `--reasoning-parser qwen3` aktiviert strukturierte Denkausgabe
- **Tool calling** — `--tool-call-parser qwen3_coder` aktiviert Function Calling für Open WebUI-Tools
- **Speculative decoding** — Multi-Token Prediction (MTP) für 1,5–2× schnellere Generierung
- **262K context** — Vollständige Long-Context-Unterstützung

## Modellwechsel

vLLM reserviert beim Start GPU-Speicher für den KV cache. Das ist eine bewusste Designentscheidung — sie garantiert keine Out-of-Memory-Fehler während der Inferenz, im Gegensatz zu Ollama oder llama.cpp, die bei Bedarf allozieren und mitten in einer Unterhaltung ausfallen können. Der Kompromiss: Ein Modellwechsel erfordert einen Container-Neustart.

Verwenden Sie das mitgelieferte Hilfsskript:

```bash
./switch-model.sh
```

Das Skript wird:
1. Ihr aktuelles Modell anzeigen
2. Nach dem neuen Modell-Repo fragen (z. B. `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8`)
3. Es herunterladen, falls noch nicht vorhanden
4. Die Konfiguration aktualisieren
5. Nur den vLLM-Container neu starten (Open WebUI und SearXNG laufen weiter)
6. Warten, bis das neue Modell bereit ist
7. Die Hermes Agent-Konfiguration aktualisieren, falls installiert

## Websuche

### SearXNG (selbst gehostete Suche)

Sowohl Open WebUI als auch Hermes Agent nutzen die lokale SearXNG-Instanz für die Websuche. SearXNG ist eine Meta-Suchmaschine, die Ergebnisse mehrerer Suchmaschinen zusammenführt, ohne Sie zu tracken.

Vorteile gegenüber DuckDuckGo (dem früheren Standard):
- **Kein Rate Limiting** — DuckDuckGo blockiert automatisierte Anfragen; SearXNG hat keine Limits, da es selbst gehostet ist
- **Multi-Engine** — Aggregiert Ergebnisse von Google, Bing, DuckDuckGo und mehr
- **Datenschutz** — Alle Anfragen bleiben auf Ihrem Rechner
- **Zuverlässigkeit** — Keine Abhängigkeit von der Verfügbarkeit externer APIs

SearXNG wird automatisch konfiguriert — keine API-Schlüssel erforderlich.

## Hermes Agent

Hermes Agent ist ein terminalbasierter KI-Assistent, der sich mit Ihrem lokalen vLLM verbindet. Er bietet:

- **Websuche** — Nutzt SearXNG für Echtzeitinformationen
- **Dateioperationen** — Dateien lesen, schreiben und analysieren
- **Code-Ausführung** — Code in einer Sandbox-Umgebung ausführen
- **Messaging Gateway** — Verbindung zu Telegram, Slack, Discord und anderen Plattformen

### Installation

```bash
./setup-hermes.sh
```

Oder wählen Sie „yes“, wenn Sie am Ende von `setup.sh` dazu aufgefordert werden.

### Messaging Gateway

Nach der Installation von Hermes können Sie es mit Messaging-Plattformen verbinden:

```bash
hermes gateway setup    # Interaktiver Assistent für die Plattform-Einrichtung
hermes gateway status   # Gateway-Status prüfen
hermes gateway logs     # Gateway-Logs anzeigen
```

Das Setup-Skript installiert das Gateway automatisch als systemd User Service, sodass es über Neustarts hinweg läuft und auch dann aktiv ist, wenn Sie nicht angemeldet sind.

Unterstützte Plattformen umfassen Telegram, Discord, Slack, WhatsApp, Signal, Matrix und mehr.

## Konfiguration

Die gesamte Konfiguration befindet sich in der `.env`-Datei (wird beim Setup aus `.env.example` erstellt):

| Variable | Default | Beschreibung |
|----------|---------|--------------|
| `MODEL_REPO` | `Qwen/Qwen3.6-35B-A3B-FP8` | Hugging Face Modell-Repository |
| `MODEL_DIR` | `/data/models/Qwen--Qwen3.6-35B-A3B-FP8` | Lokaler Modellspeicherpfad |
| `SERVED_MODEL_NAME` | `Qwen/Qwen3.6-35B-A3B-FP8` | Über OpenAI API veröffentlichter Name |
| `VLLM_IMAGE` | `nvcr.io/nvidia/vllm:26.05-py3` | vLLM Docker image |
| `VLLM_PORT` | `8000` | vLLM API port |
| `GPU_MEMORY_UTILIZATION` | `0.75` | Anteil des GPU-Speichers für KV cache |
| `MAX_MODEL_LEN` | `262144` | Maximale Kontextlänge |
| `REASONING_PARSER` | `qwen3` | Reasoning output parser |
| `TOOL_CALL_PARSER` | `qwen3_coder` | Tool/function call parser |
| `OPEN_WEBUI_PORT` | `3000` | Open WebUI port |
| `SEARXNG_PORT` | `8080` | SearXNG port |
| `DEFAULT_LOCALE` | (auto) | UI-Sprache für Open WebUI |

## Performance-Tuning

### GPU Memory Utilization

Die Einstellung `GPU_MEMORY_UTILIZATION` (Standard `0.75`) steuert, wie viel GPU-Speicher vLLM für den KV cache reserviert. Auf dem GB10 mit 128 GB Unified Memory:

- `0.75` — Standard, sicher für die meisten Workloads mit 262K context
- `0.85` — Mehr KV cache = mehr gleichzeitige Anfragen oder längere Kontexte
- `0.60` — Mehr Speicher für andere GPU-Workloads freilassen

### Context Length

Reduzieren Sie `MAX_MODEL_LEN`, wenn Sie keinen 262K context benötigen. Kürzere Kontexte verbrauchen weniger Speicher und starten schneller:
- `131072` (128K) — Gute Balance
- `65536` (64K) — Schneller Start, ausreichend für die meisten Aufgaben
- `32768` (32K) — Minimaler Speicherverbrauch

### Speculative Decoding

Die Standardkonfiguration nutzt Multi-Token Prediction mit 2 speculative tokens. Zum Deaktivieren (spart Speicher, etwas langsamere Generierung), bearbeiten Sie die `--speculative-config` Zeile in `docker-compose.yml`:

```yaml
      - --speculative-config
      - '{}'
```

## Bereinigung

Um die Installation vollständig zurückzusetzen und neu zu beginnen:

```bash
./clean.sh
```

Dies entfernt alle Container, Volumes, Netzwerke, die `.env`-Datei, SearXNG-Änderungen und die Hermes Agent-Konfiguration. Modelldateien in `/data/models` bleiben erhalten, um ein erneutes Herunterladen zu vermeiden.

Um auch Docker-Images zu entfernen:

```bash
./clean.sh --images
```

## Fehlerbehebung

### vLLM braucht zu lange zum Starten

Beim ersten Start wird das Modell in den Speicher geladen (~3–5 Minuten). Fortschritt prüfen:

```bash
docker compose logs -f vllm
```

### Out of memory

1. Andere GPU-Prozesse beenden: `nvidia-smi`, um zu prüfen, was läuft
2. `GPU_MEMORY_UTILIZATION` in `.env` reduzieren
3. `MAX_MODEL_LEN` in `.env` reduzieren
4. Neustart: `docker compose up -d --force-recreate vllm`

### SearXNG liefert keine Ergebnisse

Prüfen Sie, ob das JSON-Format aktiviert ist:

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | head -c 200
```

Bei einem 403-Fehler prüfen Sie, ob `searxng/settings.yml` `json` in der `formats`-Liste enthält.

### Open WebUI kann keine Verbindung zu vLLM herstellen

Warten Sie zuerst, bis vLLM bereit ist:

```bash
curl http://localhost:8000/health
```

Open WebUI stellt die Verbindung automatisch wieder her, sobald vLLM bereit ist.

### Docker permission denied

Führen Sie `setup.sh` erneut aus — es kümmert sich automatisch um die docker-Gruppenmitgliedschaft.

## Dateistruktur

```
gb10/
├── setup.sh                 # Haupt-Setup-Skript
├── setup-hermes.sh          # Hermes Agent Installer
├── switch-model.sh          # Hilfsskript für Modellwechsel
├── clean.sh                 # Vollständige Bereinigung / Reset
├── docker-compose.yml       # Hauptdienste
├── .env.example             # Konfigurationsvorlage
├── lib/
│   └── messages.sh          # i18n-Nachrichtenbibliothek (9 Sprachen)
└── searxng/
    ├── settings.yml         # SearXNG-Konfiguration
    └── limiter.toml         # SearXNG Rate Limiter
```

## Lizenz

MIT
