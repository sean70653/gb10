[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | **Türkçe** | [Українська](README.uk.md)

# GB10 Yapay Zeka Asistanı

NVIDIA GB10 (DGX Spark) cihazınızı tek bir komutla kişisel bir yapay zeka asistanına dönüştürün. Bu proje eksiksiz, kendi sunucunuzda barındırılan bir yapay zeka yığını kurar: yüksek performanslı LLM çıkarımı, güzel bir web arayüzü, web araması ve terminal tabanlı bir yapay zeka ajanı — hepsi donanımınızda yerel olarak çalışır.

## Neler Sunuluyor

| Bileşen | Amaç |
|---------|------|
| **[vLLM](https://docs.vllm.ai/)** | PagedAttention, speculative decoding ve tool calling destekli yüksek performanslı LLM çıkarım sunucusu |
| **[Open WebUI](https://openwebui.com/)** | Web araması, kod yorumlayıcı ve çoklu model desteği sunan ChatGPT benzeri web arayüzü |
| **[SearXNG](https://docs.searxng.org/)** | Open WebUI ve Hermes'e web araması sağlayan, gizliliğe saygılı meta-search motoru |
| **[Hermes Agent](https://github.com/nousresearch/hermes-agent)** | Web araması ve mesajlaşma ağ geçidi (Telegram, Slack, Discord…) sunan terminal tabanlı yapay zeka asistanı |

## Mimari

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

## Hızlı Başlangıç

### Ön Koşullar

- Ubuntu 24.04 yüklü NVIDIA GB10 (DGX Spark)
- Docker ve Docker Compose v2 kurulu
- NVIDIA Container Toolkit kurulu
- Varsayılan model için en az 90 GB kullanılabilir bellek

### Tek Komutla Kurulum

```bash
git clone https://github.com/seandavid/gb10.git
cd gb10
./setup.sh
```

Kurulum betiği şunları yapar:

1. **Tercih ettiğiniz dili sorar** — tüm mesajlar seçtiğiniz dilde görüntülenir (9 dil desteklenir)
2. **Docker izinlerini yönetir** — gerekirse sizi otomatik olarak docker grubuna ekler
3. **GPU çakışmalarını kontrol eder** — diğer GPU süreçlerini algılar ve durdurmak isteyip istemediğinizi sorar
4. **Modeli indirir** — Hugging Face CLI kullanarak Qwen3.6-35B-A3B-FP8 (~35 GB) modelini indirir
5. **Tüm servisleri başlatır** — Docker Compose ile vLLM, SearXNG ve Open WebUI'yi başlatır
6. **Hazır olmayı bekler** — model yüklenene kadar vLLM sağlık durumunu izler (3–5 dakika)
7. **Hermes Agent sunar** — mesajlaşma ağ geçidi ile isteğe bağlı terminal yapay zeka asistanı

### Yapay Zekanıza Erişim

Kurulum tamamlandıktan sonra:

| Servis | URL |
|--------|-----|
| Open WebUI | http://localhost:3000 |
| vLLM API | http://localhost:8000/v1 |
| SearXNG | http://localhost:8080 |

Open WebUI'yi ilk kez açtığınızda bir yönetici hesabı oluşturun. Kaydedilen ilk hesap yönetici olur.

## Varsayılan Model

Varsayılan model **Qwen/Qwen3.6-35B-A3B-FP8** — token başına yalnızca 3B aktif parametreye sahip 35B parametreli bir mixture-of-experts modelidir; bu da GB10'un birleşik bellek mimarisinde son derece verimli çalışmasını sağlar.

Kutudan çıktığı gibi yapılandırılmış temel özellikler:
- **Reasoning** — `--reasoning-parser qwen3` yapılandırılmış düşünme çıktısını etkinleştirir
- **Tool calling** — `--tool-call-parser qwen3_coder` Open WebUI araçları için function calling'i etkinleştirir
- **Speculative decoding** — 1,5–2× daha hızlı üretim için Multi-Token Prediction (MTP)
- **262K context** — Tam uzun bağlam desteği

## Model Değiştirme

vLLM, başlangıçta KV cache için GPU belleğini önceden ayırır. Bu kasıtlı bir tasarım tercihidir — talep üzerine ayırma yapan ve konuşma ortasında başarısız olabilen Ollama veya llama.cpp'nin aksine, çıkarım sırasında bellek yetersizliği hatası olmayacağını garanti eder. Karşılığında model değiştirmek bir container yeniden başlatması gerektirir.

Sağlanan yardımcı betiği kullanın:

```bash
./switch-model.sh
```

Betiğin yaptıkları:
1. Mevcut modelinizi gösterir
2. Yeni model deposunu sorar (örn. `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8`)
3. Henüz mevcut değilse indirir
4. Yapılandırmayı günceller
5. Yalnızca vLLM container'ını yeniden başlatır (Open WebUI ve SearXNG çalışmaya devam eder)
6. Yeni modelin sağlıklı hale gelmesini bekler
7. Kuruluysa Hermes Agent yapılandırmasını günceller

## Web Araması

### SearXNG (Kendi Sunucunuzda Arama)

Hem Open WebUI hem de Hermes Agent, web araması için yerel SearXNG örneğini kullanır. SearXNG, sizi izlemeden birden fazla arama motorundan sonuçları birleştiren bir meta-search motorudur.

DuckDuckGo'ya (önceki varsayılan) göre avantajları:
- **Hız sınırı yok** — DuckDuckGo otomatik sorguları engeller; SearXNG kendi sunucunuzda barındırıldığı için sınır yoktur
- **Çoklu motor** — Google, Bing, DuckDuckGo ve daha fazlasından sonuçları birleştirir
- **Gizlilik** — Tüm sorgular makinenizde kalır
- **Güvenilirlik** — Harici API kullanılabilirliğine bağımlılık yok

SearXNG otomatik olarak yapılandırılır — API anahtarı gerekmez.

## Hermes Agent

Hermes Agent, yerel vLLM'inize bağlanan terminal tabanlı bir yapay zeka asistanıdır. Şunları sağlar:

- **Web araması** — Gerçek zamanlı bilgi için SearXNG kullanır
- **Dosya işlemleri** — Dosyaları okuma, yazma ve analiz etme
- **Kod çalıştırma** — Kodu sandbox ortamında çalıştırma
- **Messaging gateway** — Telegram, Slack, Discord ve diğer platformlara bağlanma

### Kurulum

```bash
./setup-hermes.sh
```

Veya `setup.sh` sonunda sorulduğunda "yes" seçin.

### Messaging Gateway

Hermes'i kurduktan sonra mesajlaşma platformlarına bağlayabilirsiniz:

```bash
hermes gateway setup    # Interactive wizard for platform setup
hermes gateway status   # Check gateway status
hermes gateway logs     # View gateway logs
```

Kurulum betiği ağ geçidini otomatik olarak bir systemd user service olarak kurar; böylece yeniden başlatmalarda kalıcı olur ve oturum açmamış olsanız bile çalışır.

Desteklenen platformlar arasında Telegram, Discord, Slack, WhatsApp, Signal, Matrix ve daha fazlası bulunur.

## Yapılandırma

Tüm yapılandırma `.env` dosyasındadır (kurulum sırasında `.env.example` dosyasından oluşturulur):

| Değişken | Varsayılan | Açıklama |
|----------|------------|----------|
| `MODEL_REPO` | `Qwen/Qwen3.6-35B-A3B-FP8` | Hugging Face model repository |
| `MODEL_DIR` | `/data/models/Qwen--Qwen3.6-35B-A3B-FP8` | Yerel model depolama yolu |
| `SERVED_MODEL_NAME` | `Qwen/Qwen3.6-35B-A3B-FP8` | OpenAI API üzerinden sunulan ad |
| `VLLM_IMAGE` | `nvcr.io/nvidia/vllm:26.05-py3` | vLLM Docker image |
| `VLLM_PORT` | `8000` | vLLM API port |
| `GPU_MEMORY_UTILIZATION` | `0.75` | KV cache için ayrılan GPU bellek oranı |
| `MAX_MODEL_LEN` | `262144` | Maksimum context length |
| `REASONING_PARSER` | `qwen3` | Reasoning output parser |
| `TOOL_CALL_PARSER` | `qwen3_coder` | Tool/function call parser |
| `OPEN_WEBUI_PORT` | `3000` | Open WebUI port |
| `SEARXNG_PORT` | `8080` | SearXNG port |
| `DEFAULT_LOCALE` | (auto) | Open WebUI için arayüz dili |

## Performans Ayarları

### GPU Memory Utilization

`GPU_MEMORY_UTILIZATION` ayarı (varsayılan `0.75`), vLLM'in KV cache için ne kadar GPU belleği ayıracağını kontrol eder. 128 GB birleşik belleğe sahip GB10'da:

- `0.75` — Varsayılan, 262K context ile çoğu iş yükü için güvenli
- `0.85` — Daha fazla KV cache = daha fazla eşzamanlı istek veya daha uzun bağlamlar
- `0.60` — Diğer GPU iş yükleri için daha fazla bellek bırakır

### Context Length

262K context'e ihtiyacınız yoksa `MAX_MODEL_LEN` değerini düşürün. Daha kısa bağlamlar daha az bellek kullanır ve daha hızlı başlar:
- `131072` (128K) — İyi denge
- `65536` (64K) — Hızlı başlangıç, çoğu görev için yeterli
- `32768` (32K) — Minimum bellek kullanımı

### Speculative Decoding

Varsayılan yapılandırma, 2 speculative token ile Multi-Token Prediction kullanır. Devre dışı bırakmak için (bellek tasarrufu, biraz daha yavaş üretim), `docker-compose.yml` dosyasındaki `--speculative-config` satırını düzenleyin:

```yaml
      - --speculative-config
      - '{}'
```

## Temizlik

Kurulumu tamamen sıfırlayıp yeniden başlamak için:

```bash
./clean.sh
```

Bu, tüm container'ları, volume'ları, ağları, `.env` dosyasını, SearXNG değişikliklerini ve Hermes Agent yapılandırmasını kaldırır. `/data/models` içindeki model dosyaları yeniden indirmeyi önlemek için korunur.

Docker image'larını da kaldırmak için:

```bash
./clean.sh --images
```

## Sorun Giderme

### vLLM başlaması çok uzun sürüyor

İlk başlangıç modeli belleğe yükler (~3–5 dakika). İlerlemeyi kontrol edin:

```bash
docker compose logs -f vllm
```

### Bellek yetersizliği

1. Diğer GPU süreçlerini durdurun: ne çalıştığını kontrol etmek için `nvidia-smi`
2. `.env` dosyasında `GPU_MEMORY_UTILIZATION` değerini düşürün
3. `.env` dosyasında `MAX_MODEL_LEN` değerini düşürün
4. Yeniden başlatın: `docker compose up -d --force-recreate vllm`

### SearXNG sonuç döndürmüyor

JSON formatının etkin olduğunu doğrulayın:

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | head -c 200
```

403 hatası alırsanız, `searxng/settings.yml` dosyasında `formats` listesinde `json` olduğunu kontrol edin.

### Open WebUI vLLM'e bağlanamıyor

Önce vLLM'in sağlıklı hale gelmesini bekleyin:

```bash
curl http://localhost:8000/health
```

vLLM hazır olduğunda Open WebUI otomatik olarak yeniden bağlanır.

### Docker izin reddedildi

`setup.sh` betiğini tekrar çalıştırın — docker grup üyeliğini otomatik olarak yönetir.

## Dosya Yapısı

```
gb10/
├── setup.sh                 # Ana kurulum betiği
├── setup-hermes.sh          # Hermes Agent kurucusu
├── switch-model.sh          # Model değiştirme yardımcısı
├── clean.sh                 # Tam temizlik / sıfırlama
├── docker-compose.yml       # Ana servisler
├── .env.example             # Yapılandırma şablonu
├── lib/
│   └── messages.sh          # i18n mesaj kütüphanesi (9 dil)
└── searxng/
    ├── settings.yml         # SearXNG yapılandırması
    └── limiter.toml         # SearXNG hız sınırlayıcı
```

## Lisans

MIT
