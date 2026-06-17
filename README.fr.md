[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Deutsch](README.de.md) | [Español](README.es.md) | **Français** | [Türkçe](README.tr.md) | [Українська](README.uk.md)

# GB10 Assistant IA

Transformez votre NVIDIA GB10 (DGX Spark) en assistant IA personnel avec une seule commande. Ce projet met en place une stack IA complète et auto-hébergée : inférence LLM haute performance, interface web élégante, recherche web et agent IA en terminal — le tout s'exécute localement sur votre matériel.

## Ce que vous obtenez

| Composant | Rôle |
|-----------|------|
| **[vLLM](https://docs.vllm.ai/)** | Serveur d'inférence LLM haute performance avec PagedAttention, speculative decoding et tool calling |
| **[Open WebUI](https://openwebui.com/)** | Interface web de type ChatGPT avec recherche web, interpréteur de code et prise en charge multi-modèles |
| **[SearXNG](https://docs.searxng.org/)** | Meta-search engine respectueux de la vie privée, fournissant la recherche web à Open WebUI et Hermes |
| **[Hermes Agent](https://github.com/nousresearch/hermes-agent)** | Assistant IA en terminal avec recherche web et messaging gateway (Telegram, Slack, Discord…) |

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

## Démarrage rapide

### Prérequis

- NVIDIA GB10 (DGX Spark) avec Ubuntu 24.04
- Docker et Docker Compose v2 installés
- NVIDIA Container Toolkit installé
- Au moins 90 Go de mémoire disponible pour le modèle par défaut

### Configuration en une commande

```bash
git clone https://github.com/sean70653/gb10.git
cd gb10
./setup.sh
```

Le script de configuration va :

1. **Demander votre langue préférée** — tous les messages s'affichent dans la langue choisie (9 langues prises en charge)
2. **Gérer les permissions Docker** — vous ajoute automatiquement au groupe docker si nécessaire
3. **Vérifier les conflits GPU** — détecte les autres processus GPU et demande si vous souhaitez les arrêter
4. **Télécharger le modèle** — récupère Qwen3.6-35B-A3B-FP8 (~35 Go) via la CLI Hugging Face
5. **Démarrer tous les services** — lance vLLM, SearXNG et Open WebUI via Docker Compose
6. **Attendre la disponibilité** — surveille l'état de santé de vLLM jusqu'au chargement du modèle (3–5 minutes)
7. **Proposer Hermes Agent** — assistant IA en terminal optionnel avec messaging gateway

### Accéder à votre IA

Une fois la configuration terminée :

| Service | URL |
|---------|-----|
| Open WebUI | http://localhost:3000 |
| vLLM API | http://localhost:8000/v1 |
| SearXNG | http://localhost:8080 |

Lors de votre première ouverture d'Open WebUI, créez un compte administrateur. Le premier compte enregistré devient l'administrateur.

## Modèle par défaut

Le modèle par défaut est **Qwen/Qwen3.6-35B-A3B-FP8** — un modèle mixture-of-experts de 35B paramètres avec seulement 3B paramètres actifs par token, ce qui le rend extrêmement efficace sur l'architecture de mémoire unifiée du GB10.

Fonctionnalités clés configurées dès l'installation :
- **Reasoning** — `--reasoning-parser qwen3` active une sortie de réflexion structurée
- **Tool calling** — `--tool-call-parser qwen3_coder` active le function calling pour les outils Open WebUI
- **Speculative decoding** — Multi-Token Prediction (MTP) pour une génération 1,5–2× plus rapide
- **Contexte 262K** — Prise en charge complète du long contexte

## Changement de modèle

vLLM pré-alloue la mémoire GPU pour le KV cache au démarrage. C'est un choix de conception délibéré — cela garantit l'absence d'erreurs out-of-memory pendant l'inférence, contrairement à Ollama ou llama.cpp qui allouent à la demande et peuvent échouer en cours de conversation. Le compromis est qu'un changement de modèle nécessite un redémarrage du conteneur.

Utilisez le script d'aide fourni :

```bash
./switch-model.sh
```

Le script va :
1. Afficher votre modèle actuel
2. Demander le nouveau dépôt de modèle (par ex. `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8`)
3. Le télécharger s'il n'est pas déjà présent
4. Mettre à jour la configuration
5. Redémarrer uniquement le conteneur vLLM (Open WebUI et SearXNG restent actifs)
6. Attendre que le nouveau modèle soit opérationnel
7. Mettre à jour la configuration de Hermes Agent s'il est installé

## Recherche web

### SearXNG (recherche auto-hébergée)

Open WebUI et Hermes Agent utilisent tous deux l'instance SearXNG locale pour la recherche web. SearXNG est un meta-search engine qui agrège les résultats de plusieurs moteurs de recherche sans vous suivre.

Avantages par rapport à DuckDuckGo (l'ancien choix par défaut) :
- **Pas de limitation de débit** — DuckDuckGo bloque les requêtes automatisées ; SearXNG n'a aucune limite car il est auto-hébergé
- **Multi-moteurs** — Agrège les résultats de Google, Bing, DuckDuckGo et d'autres
- **Confidentialité** — Toutes les requêtes restent sur votre machine
- **Fiabilité** — Aucune dépendance à la disponibilité d'une API externe

SearXNG est configuré automatiquement — aucune clé API n'est nécessaire.

## Hermes Agent

Hermes Agent est un assistant IA en terminal qui se connecte à votre vLLM local. Il offre :

- **Recherche web** — Utilise SearXNG pour des informations en temps réel
- **Opérations sur les fichiers** — Lire, écrire et analyser des fichiers
- **Exécution de code** — Exécuter du code dans un environnement sandboxé
- **Messaging gateway** — Connexion à Telegram, Slack, Discord et d'autres plateformes

### Installation

```bash
./setup-hermes.sh
```

Ou sélectionnez « oui » lorsque le script `setup.sh` vous le propose à la fin.

### Messaging Gateway

Après l'installation de Hermes, vous pouvez le connecter à des plateformes de messagerie :

```bash
hermes gateway setup    # Assistant interactif pour la configuration des plateformes
hermes gateway status   # Vérifier l'état de la gateway
hermes gateway logs     # Consulter les logs de la gateway
```

Le script de configuration installe automatiquement la gateway en tant que service utilisateur systemd, de sorte qu'elle persiste après les redémarrages et fonctionne même lorsque vous n'êtes pas connecté.

Les plateformes prises en charge incluent Telegram, Discord, Slack, WhatsApp, Signal, Matrix et d'autres.

## Configuration

Toute la configuration se trouve dans le fichier `.env` (créé à partir de `.env.example` lors de la configuration) :

| Variable | Valeur par défaut | Description |
|----------|-------------------|-------------|
| `MODEL_REPO` | `Qwen/Qwen3.6-35B-A3B-FP8` | Dépôt de modèle Hugging Face |
| `MODEL_DIR` | `/data/models/Qwen--Qwen3.6-35B-A3B-FP8` | Chemin de stockage local du modèle |
| `SERVED_MODEL_NAME` | `Qwen/Qwen3.6-35B-A3B-FP8` | Nom exposé via l'API OpenAI |
| `VLLM_IMAGE` | `nvcr.io/nvidia/vllm:26.05-py3` | Image Docker vLLM |
| `VLLM_PORT` | `8000` | Port de l'API vLLM |
| `GPU_MEMORY_UTILIZATION` | `0.75` | Fraction de la mémoire GPU pour le KV cache |
| `MAX_MODEL_LEN` | `262144` | Longueur maximale du contexte |
| `REASONING_PARSER` | `qwen3` | Parser de sortie reasoning |
| `TOOL_CALL_PARSER` | `qwen3_coder` | Parser d'appels d'outils/fonctions |
| `OPEN_WEBUI_PORT` | `3000` | Port Open WebUI |
| `SEARXNG_PORT` | `8080` | Port SearXNG |
| `DEFAULT_LOCALE` | (auto) | Langue de l'interface Open WebUI |

## Optimisation des performances

### Utilisation de la mémoire GPU

Le paramètre `GPU_MEMORY_UTILIZATION` (par défaut `0.75`) contrôle la quantité de mémoire GPU que vLLM réserve pour le KV cache. Sur le GB10 avec ses 128 Go de mémoire unifiée :

- `0.75` — Par défaut, sûr pour la plupart des charges de travail avec un contexte 262K
- `0.85` — Plus de KV cache = plus de requêtes simultanées ou des contextes plus longs
- `0.60` — Laisser plus de mémoire pour d'autres charges de travail GPU

### Longueur du contexte

Réduisez `MAX_MODEL_LEN` si vous n'avez pas besoin d'un contexte 262K. Des contextes plus courts utilisent moins de mémoire et démarrent plus rapidement :
- `131072` (128K) — Bon compromis
- `65536` (64K) — Démarrage rapide, suffisant pour la plupart des tâches
- `32768` (32K) — Utilisation minimale de la mémoire

### Speculative Decoding

La configuration par défaut utilise Multi-Token Prediction avec 2 tokens spéculatifs. Pour le désactiver (économise de la mémoire, génération légèrement plus lente), modifiez la ligne `--speculative-config` dans `docker-compose.yml` :

```yaml
      - --speculative-config
      - '{}'
```

## Nettoyage

Pour réinitialiser complètement l'installation et repartir de zéro :

```bash
./clean.sh
```

Cela supprime tous les conteneurs, volumes, réseaux, le fichier `.env`, les modifications SearXNG et la configuration Hermes Agent. Les fichiers de modèles dans `/data/models` sont conservés pour éviter un nouveau téléchargement.

Pour supprimer également les images Docker :

```bash
./clean.sh --images
```

## Dépannage

### vLLM met trop de temps à démarrer

Le premier démarrage charge le modèle en mémoire (~3–5 minutes). Vérifiez la progression :

```bash
docker compose logs -f vllm
```

### Manque de mémoire

1. Arrêtez les autres processus GPU : `nvidia-smi` pour voir ce qui s'exécute
2. Réduisez `GPU_MEMORY_UTILIZATION` dans `.env`
3. Réduisez `MAX_MODEL_LEN` dans `.env`
4. Redémarrez : `docker compose up -d --force-recreate vllm`

### SearXNG ne renvoie aucun résultat

Vérifiez que le format JSON est activé :

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | head -c 200
```

Si vous obtenez une erreur 403, vérifiez que `searxng/settings.yml` contient `json` dans la liste `formats`.

### Open WebUI ne peut pas se connecter à vLLM

Attendez d'abord que vLLM soit opérationnel :

```bash
curl http://localhost:8000/health
```

Open WebUI se reconnectera automatiquement une fois vLLM prêt.

### Permission Docker refusée

Relancez `setup.sh` — il gère automatiquement l'appartenance au groupe docker.

## Structure des fichiers

```
gb10/
├── setup.sh                 # Script de configuration principal
├── setup-hermes.sh          # Installateur Hermes Agent
├── switch-model.sh          # Assistant de changement de modèle
├── clean.sh                 # Nettoyage complet / réinitialisation
├── docker-compose.yml       # Services principaux
├── .env.example             # Modèle de configuration
├── lib/
│   └── messages.sh          # Bibliothèque de messages i18n (9 langues)
└── searxng/
    ├── settings.yml         # Configuration SearXNG
    └── limiter.toml         # Rate limiter SearXNG
```

## Licence

MIT
