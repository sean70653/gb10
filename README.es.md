[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Deutsch](README.de.md) | **Español** | [Français](README.fr.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md)

# GB10 Asistente IA

Convierte tu NVIDIA GB10 (DGX Spark) en un asistente de IA personal con un solo comando. Este proyecto configura una pila de IA completa y autoalojada: inferencia de LLM de alto rendimiento, una interfaz web elegante, búsqueda web y un agente de IA en terminal — todo ejecutándose localmente en tu hardware.

## Lo que obtienes

| Componente | Propósito |
|-----------|---------|
| **[vLLM](https://docs.vllm.ai/)** | Servidor de inferencia de LLM de alto rendimiento con PagedAttention, speculative decoding y tool calling |
| **[Open WebUI](https://openwebui.com/)** | Interfaz web similar a ChatGPT con búsqueda web, intérprete de código y soporte multi-modelo |
| **[SearXNG](https://docs.searxng.org/)** | Motor de meta-búsqueda que respeta la privacidad y proporciona búsqueda web tanto a Open WebUI como a Hermes |
| **[Hermes Agent](https://github.com/nousresearch/hermes-agent)** | Asistente de IA en terminal con búsqueda web y messaging gateway (Telegram, Slack, Discord…) |

## Arquitectura

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

## Inicio rápido

### Requisitos previos

- NVIDIA GB10 (DGX Spark) con Ubuntu 24.04
- Docker y Docker Compose v2 instalados
- NVIDIA Container Toolkit instalado
- Al menos 90 GB de memoria disponible para el modelo predeterminado

### Configuración con un solo comando

```bash
git clone https://github.com/sean70653/gb10.git
cd gb10
./setup.sh
```

El script de configuración:

1. **Pregunta tu idioma preferido** — todos los mensajes se muestran en el idioma elegido (9 idiomas disponibles)
2. **Gestiona los permisos de Docker** — te añade automáticamente al grupo docker si es necesario
3. **Comprueba conflictos de GPU** — detecta otros procesos de GPU y pregunta si quieres detenerlos
4. **Descarga el modelo** — obtiene Qwen3.6-35B-A3B-FP8 (~35 GB) mediante la CLI de Hugging Face
5. **Inicia todos los servicios** — lanza vLLM, SearXNG y Open WebUI mediante Docker Compose
6. **Espera a que esté listo** — monitoriza el estado de vLLM hasta que el modelo esté cargado (3–5 minutos)
7. **Ofrecer Hermes Agent** — asistente de IA en terminal opcional con messaging gateway

### Accede a tu IA

Una vez completada la configuración:

| Servicio | URL |
|---------|-----|
| Open WebUI | http://localhost:3000 |
| vLLM API | http://localhost:8000/v1 |
| SearXNG | http://localhost:8080 |

La primera vez que abras Open WebUI, crea una cuenta de administrador. La primera cuenta registrada se convierte en administrador.

## Modelo predeterminado

El modelo predeterminado es **Qwen/Qwen3.6-35B-A3B-FP8** — un modelo mixture-of-experts de 35B parámetros con solo 3B parámetros activos por token, lo que lo hace extremadamente eficiente en la arquitectura de memoria unificada del GB10.

Características clave configuradas de fábrica:
- **Reasoning** — `--reasoning-parser qwen3` habilita la salida de pensamiento estructurado
- **Tool calling** — `--tool-call-parser qwen3_coder` habilita function calling para las herramientas de Open WebUI
- **Speculative decoding** — Multi-Token Prediction (MTP) para una generación 1,5–2× más rápida
- **Contexto de 262K** — Soporte completo de contexto largo

## Cambio de modelo

vLLM preasigna memoria GPU para el KV cache al iniciar. Es una decisión de diseño deliberada — garantiza que no haya errores de falta de memoria durante la inferencia, a diferencia de Ollama o llama.cpp, que asignan bajo demanda y pueden fallar a mitad de una conversación. La contrapartida es que cambiar de modelo requiere reiniciar el contenedor.

Usa el script auxiliar incluido:

```bash
./switch-model.sh
```

El script:
1. Muestra tu modelo actual
2. Pide el nuevo repositorio del modelo (p. ej. `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8`)
3. Lo descarga si aún no está presente
4. Actualiza la configuración
5. Reinicia solo el contenedor de vLLM (Open WebUI y SearXNG siguen en ejecución)
6. Espera a que el nuevo modelo esté operativo
7. Actualiza la configuración de Hermes Agent si está instalado

## Búsqueda web

### SearXNG (búsqueda autoalojada)

Tanto Open WebUI como Hermes Agent usan la instancia local de SearXNG para la búsqueda web. SearXNG es un motor de meta-búsqueda que agrega resultados de varios motores de búsqueda sin rastrearte.

Ventajas frente a DuckDuckGo (que era el predeterminado anterior):
- **Sin límite de tasa** — DuckDuckGo bloquea consultas automatizadas; SearXNG no tiene límites porque es autoalojado
- **Multi-motor** — Agrega resultados de Google, Bing, DuckDuckGo y más
- **Privacidad** — Todas las consultas permanecen en tu máquina
- **Fiabilidad** — Sin dependencia de la disponibilidad de APIs externas

SearXNG se configura automáticamente — no se necesitan claves API.

## Hermes Agent

Hermes Agent es un asistente de IA en terminal que se conecta a tu vLLM local. Proporciona:

- **Búsqueda web** — Usa SearXNG para información en tiempo real
- **Operaciones con archivos** — Leer, escribir y analizar archivos
- **Ejecución de código** — Ejecutar código en un entorno aislado
- **Messaging gateway** — Conexión con Telegram, Slack, Discord y otras plataformas

### Instalación

```bash
./setup-hermes.sh
```

O selecciona "yes" cuando se te pregunte al final de `setup.sh`.

### Messaging Gateway

Después de instalar Hermes, puedes conectarlo a plataformas de mensajería:

```bash
hermes gateway setup    # Interactive wizard for platform setup
hermes gateway status   # Check gateway status
hermes gateway logs     # View gateway logs
```

El script de configuración instala automáticamente el gateway como servicio de usuario de systemd, de modo que persiste tras reinicios y se ejecuta incluso cuando no has iniciado sesión.

Las plataformas compatibles incluyen Telegram, Discord, Slack, WhatsApp, Signal, Matrix y más.

## Configuración

Toda la configuración está en el archivo `.env` (creado a partir de `.env.example` durante la configuración):

| Variable | Default | Descripción |
|----------|---------|-------------|
| `MODEL_REPO` | `Qwen/Qwen3.6-35B-A3B-FP8` | Repositorio del modelo en Hugging Face |
| `MODEL_DIR` | `/data/models/Qwen--Qwen3.6-35B-A3B-FP8` | Ruta local de almacenamiento del modelo |
| `SERVED_MODEL_NAME` | `Qwen/Qwen3.6-35B-A3B-FP8` | Nombre expuesto vía OpenAI API |
| `VLLM_IMAGE` | `nvcr.io/nvidia/vllm:26.05-py3` | vLLM Docker image |
| `VLLM_PORT` | `8000` | vLLM API port |
| `GPU_MEMORY_UTILIZATION` | `0.75` | Fraction of GPU memory for KV cache |
| `MAX_MODEL_LEN` | `262144` | Longitud máxima de contexto |
| `REASONING_PARSER` | `qwen3` | Reasoning output parser |
| `TOOL_CALL_PARSER` | `qwen3_coder` | Tool/function call parser |
| `OPEN_WEBUI_PORT` | `3000` | Open WebUI port |
| `SEARXNG_PORT` | `8080` | SearXNG port |
| `DEFAULT_LOCALE` | (auto) | Idioma de la interfaz de Open WebUI |

## Ajuste de rendimiento

### Utilización de memoria GPU

El ajuste `GPU_MEMORY_UTILIZATION` (predeterminado `0.75`) controla cuánta memoria GPU reserva vLLM para el KV cache. En el GB10 con sus 128 GB de memoria unificada:

- `0.75` — Predeterminado, seguro para la mayoría de cargas de trabajo con contexto de 262K
- `0.85` — Más KV cache = más solicitudes concurrentes o contextos más largos
- `0.60` — Deja más memoria para otras cargas de trabajo GPU

### Longitud de contexto

Reduce `MAX_MODEL_LEN` si no necesitas contexto de 262K. Los contextos más cortos usan menos memoria y arrancan más rápido:
- `131072` (128K) — Buen equilibrio
- `65536` (64K) — Arranque rápido, suficiente para la mayoría de tareas
- `32768` (32K) — Uso mínimo de memoria

### Speculative Decoding

La configuración predeterminada usa Multi-Token Prediction con 2 speculative tokens. Para desactivarlo (ahorra memoria, generación ligeramente más lenta), edite la línea `--speculative-config` en `docker-compose.yml`:

```yaml
      - --speculative-config
      - '{}'
```

## Limpieza

Para restablecer completamente la instalación y empezar de nuevo:

```bash
./clean.sh
```

Esto elimina todos los contenedores, volúmenes, redes, el archivo `.env`, las modificaciones de SearXNG y la configuración de Hermes Agent. Los archivos de modelos en `/data/models` se conservan para evitar volver a descargarlos.

Para eliminar también las imágenes de Docker:

```bash
./clean.sh --images
```

## Solución de problemas

### vLLM tarda demasiado en iniciar

El primer arranque carga el modelo en memoria (~3–5 minutos). Comprueba el progreso:

```bash
docker compose logs -f vllm
```

### Falta de memoria

1. Detén otros procesos GPU: `nvidia-smi` para ver qué está en ejecución
2. Reduce `GPU_MEMORY_UTILIZATION` en `.env`
3. Reduce `MAX_MODEL_LEN` en `.env`
4. Reinicia: `docker compose up -d --force-recreate vllm`

### SearXNG no devuelve resultados

Comprueba que el formato JSON esté habilitado:

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | head -c 200
```

Si obtienes un error 403, comprueba que `searxng/settings.yml` tenga `json` en la lista `formats`.

### Open WebUI no puede conectarse a vLLM

Espera primero a que vLLM esté operativo:

```bash
curl http://localhost:8000/health
```

Open WebUI se reconectará automáticamente cuando vLLM esté listo.

### Permiso denegado de Docker

Ejecuta `setup.sh` de nuevo — gestiona automáticamente la pertenencia al grupo docker.

## Estructura de archivos

```
gb10/
├── setup.sh                 # Script principal de configuración
├── setup-hermes.sh          # Instalador de Hermes Agent
├── switch-model.sh          # Ayudante para cambio de modelo
├── clean.sh                 # Limpieza completa / restablecimiento
├── docker-compose.yml       # Servicios principales
├── .env.example             # Plantilla de configuración
├── lib/
│   └── messages.sh          # Biblioteca de mensajes i18n (9 idiomas)
└── searxng/
    ├── settings.yml         # Configuración de SearXNG
    └── limiter.toml         # Limitador de tasa de SearXNG
```

## Licencia

MIT
