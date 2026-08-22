# AI Providers — Mistral, OpenAI, AnythingLLM

Triage má **multi-provider AI router** (edge function `ai-router`), ktorý vie volať Mistral, OpenAI a self-hosted AnythingLLM. UI je na **`/ai-assistant`** (`lib/app/router.dart`) — vyberieš si jedného alebo viacerých providerov a appka pošle dotaz paralelne, odpovede zobrazí side-by-side s latenciou a počtom tokenov.

Router zároveň vystavuje modelom **tool-callingom** prístup do databázy:
- `list_bugs({status?, severity?, limit?})`
- `get_bug({tracking_id})`
- `search_comments({query, bug_id?})`
- `count_bugs_by_status()`

Tooly bežia s JWT prihláseného používateľa — RLS pravidlá tabuliek `bugs` a `comments` sa rešpektujú.

---

## 1. Mistral AI

1. Choď na https://console.mistral.ai/ → **Sign up**.
2. Aktivuj billing (Mistral nemá free tier pre API, ale prvé requesty sú lacné — `mistral-small` ~ €0.20 / 1M tokens).
3. https://console.mistral.ai/api-keys → **Create new key** → skopíruj.
4. V Lovable: Settings → Cloud → Secrets → `MISTRAL_API_KEY` (už som nastavený).

Odporúčané modely:
| Model | Cena (in/out) | Použitie |
|-------|---------------|----------|
| `mistral-large-latest` | $2 / $6 / 1M | Najlepšie reasoning, default |
| `mistral-small-latest` | $0.2 / $0.6 / 1M | Rýchle, lacné |
| `open-mistral-nemo` | $0.15 / $0.15 / 1M | Open-source, dobrá cena |

---

## 2. OpenAI (ChatGPT API)

1. https://platform.openai.com/signup → účet + billing (minimum $5).
2. https://platform.openai.com/api-keys → **Create new secret key** → skopíruj.
3. V Lovable: `OPENAI_API_KEY` (už nastavený).

Odporúčané modely:
| Model | Cena (in/out) | Použitie |
|-------|---------------|----------|
| `gpt-4o-mini` | $0.15 / $0.6 / 1M | Default, dobrý pomer |
| `gpt-4o` | $2.5 / $10 / 1M | Kvalita, multimodálne |
| `o3-mini` | $1.1 / $4.4 / 1M | Reasoning úlohy |

> **Poznámka ku „Codex GPT":** OpenAI Codex bol vyradený v marci 2023. Pre code-completion úlohy použi `gpt-4o-mini` cez Chat Completions API — to robí router automaticky.

---

## 3. AnythingLLM (self-hosted)

AnythingLLM je open-source RAG / chat platforma, ktorú si nahodíš na vlastnom serveri.

### Inštalácia (Docker)
```bash
docker run -d -p 3001:3001 \
  --cap-add SYS_ADMIN \
  -v anythingllm_storage:/app/server/storage \
  --name anythingllm \
  mintplexlabs/anythingllm:latest
```
Otvoríš `http://your-server:3001`, prejdeš onboardingom (vyberieš si LLM provider — môže byť OpenAI, Ollama, atď.), vytvoríš workspace.

### Získanie API kľúča
1. V AnythingLLM UI → **Settings → API Keys → Generate New Key**.
2. Skopíruj kľúč.
3. Z URL workspace-u si zisti **slug** (napr. `https://your-server/workspace/my-docs` → slug je `my-docs`).

### Konfigurácia v Triage
Na stránke `/ai-assistant` zaškrtni **AnythingLLM**, vyplň:
- **Base URL** (napr. `https://anythingllm.mojadomena.com`) — musí byť verejne dostupné, edge function sa k localhostu nedostane.
- **Workspace slug**.

Stlač **Save** — uloží sa do `ai_provider_configs`.

Následne pridaj secret:
```
ANYTHINGLLM_API_KEY = <tvoj kľúč>
```
(cez Lovable Cloud → Secrets, alebo ma o to požiadaj).

> **AnythingLLM v chat móde nepodporuje OpenAI-style function calling** — tooly nad bugmi v jeho odpovediach nefungujú. Použi ho najmä na otázky o dokumentoch, ktoré si do workspace nahral.

---

## Tool-calling: ako pridať nový tool

V `supabase/functions/ai-router/index.ts`:

1. Pridaj definíciu do poľa `tools` (JSON schema podľa OpenAI formátu).
2. Pridaj `if (name === "moj_tool") { ... }` vo funkcii `runTool`.
3. Edge function sa redeployuje automaticky.

---

## Troubleshooting

| Symptóm | Príčina | Riešenie |
|---------|---------|----------|
| `401 unauthorized` | Zlý / expirovaný API kľúč | Vygeneruj nový a aktualizuj secret |
| `429 rate limited` | Príliš veľa requestov | Počkaj minútu; má aj per-user limit 30/min |
| `402 insufficient credits` | Vyčerpaný billing | Dopnúť kredity v OpenAI/Mistral konzole |
| AnythingLLM: `not configured` | Chýba `ANYTHINGLLM_API_KEY` | Pridaj secret |
| AnythingLLM: `fetch failed` | Server nedostupný / localhost | Použi verejnú HTTPS URL |
| Mistral/OpenAI: žiadna tool akcia | Model si nepýtal tool | Skús explicitne: „Použi list_bugs a daj mi…" |

---

## Bezpečnosť

- API kľúče sú **iba v edge funkcii**, nikdy v prehliadači.
- Tabuľky `ai_conversations` / `ai_messages` / `ai_provider_configs` majú RLS — každý user vidí len svoje dáta.
- Tooly bežia s JWT používateľa (RLS bugov/komentárov platí).
- Per-user rate limit 30 req/min (in-memory; pre produkciu odporúčam Redis / Upstash).
- Max dĺžka jednej správy: 8000 znakov.
