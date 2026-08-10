# Centralny Dashboard (Flutter)

Offline-first Flutter web cockpit pre CMR+: bugs/projects, CRM klienti, lead inbox/pipeline (AI + Gmail), AI asistent, SEO iframe, web apps hub a AutoOps UI (mock dáta).

Glassmorphic dark UI. Auth cez Firebase, dáta cez Supabase (+ lokálny Isar/Sembast). Hosting: Firebase Hosting + Vercel SPA.

> Aktuálny audit stavu: [`docs/PROJECT_DIAGNOSTICS.md`](docs/PROJECT_DIAGNOSTICS.md) (august 2026).

---

## Projekty a URL

| Služba | Hodnota |
|--------|---------|
| Firebase project | `machinegunslots` |
| Firebase Hosting (E2E default) | https://machinegunslots.web.app |
| Vercel (alt deploy) | https://flutterdashb-h4ck3d.vercel.app |
| Supabase project | `bizagent-app-2026` / `kpsnwpuydqqojwmrnkdy` |
| Supabase Console | https://app.supabase.com/project/kpsnwpuydqqojwmrnkdy |
| Firebase Console | https://console.firebase.google.com/project/machinegunslots |

Produkčný base URL pre Playwright: `E2E_BASE_URL` (default `https://machinegunslots.web.app`).

---

## Stack

| Vrstva | Voľba |
|--------|-------|
| Flutter / Dart | SDK `^3.12.0` (`centralny_dashboard` v `pubspec.yaml`) |
| State | **Provider** (`ChangeNotifier`) — nie Riverpod |
| Routing | `go_router` + `ShellRoute` + auth redirect |
| Auth | Firebase Auth (email / Google) |
| Backend | Supabase Postgres + Realtime |
| Edge Functions | `lead-assistant`, `ai-router`, `wp-proxy` |
| Local DB | Isar (bugs/projects/queue, native); Sembast (leady, web + native) |
| Config | `--dart-define` / `VITE_*` cez `secrets.json` |
| E2E | Playwright (`e2e/`, root `package.json`) |

---

## Moduly a routy

Zdroj: [`lib/app/router.dart`](lib/app/router.dart)

| Route | Modul | Poznámka |
|-------|--------|----------|
| `/auth` | Auth | Firebase sign-in |
| `/` | Dashboard | Bug stats, filtre |
| `/projects` | Projects | Zoznam projektov |
| `/bugs`, `/bugs/create`, `/bugs/:id` | Bugs | CRUD |
| `/crm`, `/crm/clients/:id` | CRM | Klienti + leady (natívne UI) |
| `/leads`, `/leads/inbox`, `/leads/:id` | Leads | Pipeline + AI inbox |
| `/seo-ai` | SEO AI | Iframe |
| `/analytics` | Analytics | fl_chart nad bugs/projects |
| `/ai-assistant` | AI | Chat + optional AnythingLLM iframe |
| `/autoops` (+ inbox/builder/integrations/analytics) | AutoOps | UI; **mock repository** |
| `/settings` | Settings | Profil, connection status |
| `/changelog` | Changelog | Hardcoded poznámky |
| `/web-app/:appId` | Web apps | Embed user-configured apps |

**Dátové toky (stručne):**

- Bugs / projects / profiles → Supabase + Isar cache
- Leady / drafty → lokálne Sembast; AI/Gmail cez Edge Function `lead-assistant` (nie remote `cmr_leads` CRUD v appke)
- AutoOps → `autoops_mock_data.dart` (zatiaľ bez live backendu)

---

## Štruktúra repozitára

```
centralny-dashboard-flutter/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── bootstrap.dart          # MultiProvider wiring
│   │   └── router.dart             # GoRouter + AppRoutes
│   ├── core/                       # auth, config, database, network, sync, ui
│   ├── domain/autoops/
│   ├── features/                   # ai, analytics, auth, autoops, bugs, changelog,
│   │                               # crm, dashboard, leads, projects, seo_ai,
│   │                               # settings, shell, web_apps
│   └── shared/widgets/
├── supabase/
│   ├── migrations/
│   └── functions/                  # lead-assistant, ai-router, wp-proxy
├── tool/
│   ├── patch_isar_web.dart
│   ├── smoke_lead_diagnostic.sh
│   ├── security_preflight.sh
│   └── test.sh
├── test/                           # unit, widget, repository, integration, smoke
├── e2e/                            # Playwright
├── docs/
├── secrets.json.example
├── TESTING.md
├── vercel.json
├── firebase.json
└── pubspec.yaml
```

---

## Secrets a konfigurácia

Citlivé hodnoty **nie sú v Gite**. Skopíruj šablónu a doplň hodnoty:

```bash
cp secrets.json.example secrets.json
```

App číta výhradne `VITE_*` (a `CRM_FRAME_URL` / `WEB_APP_*`) cez `String.fromEnvironment` — pozri [`lib/core/config/config.dart`](lib/core/config/config.dart) a [`secrets.json.example`](secrets.json.example).

| Kľúč | Účel |
|------|------|
| `VITE_SUPABASE_URL` | Supabase project URL |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Anon / publishable key (nie service role) |
| `VITE_FIREBASE_*` | Firebase web config |
| `VITE_WORDPRESS_PUBLIC_SITE_URL` | Voliteľné WP |
| `CRM_FRAME_URL` | Fallback CRM iframe |
| `WEB_APP_1_URL` … `WEB_APP_3_URL` | Predvolené web apps |

**Nikdy** necommituj `secrets.json`, service role key, ani JWT do README/docs. Detail: [`docs/SECURITY_AND_SECRETS.md`](docs/SECURITY_AND_SECRETS.md).

Lead inbox / Gmail Edge secrets: [`docs/LEAD_INBOX_SETUP.md`](docs/LEAD_INBOX_SETUP.md).

---

## Inštalácia a spustenie

**Požiadavky:** Flutter SDK `^3.12.0` (stable), Chrome (web).

```bash
flutter pub get
cp secrets.json.example secrets.json   # doplň reálne hodnoty

# Web
flutter run -d chrome --dart-define-from-file=secrets.json

# Isar codegen (native) + web patch po build_runner
dart run build_runner build --delete-conflicting-outputs
dart run tool/patch_isar_web.dart
```

### Build a deploy

```bash
flutter build web --dart-define-from-file=secrets.json
dart run tool/patch_isar_web.dart

# Firebase Hosting
npx -y firebase-tools@latest deploy --only hosting --project machinegunslots

# Vercel (build/web + SPA rewrite v vercel.json)
npx vercel deploy build/web --prod
```

---

## Testy a diagnostika

```bash
# Flutter (bez ťažkých integračných, podľa potreby)
./tool/test.sh
# alebo:
flutter test test/unit test/widget test/repository test/smoke

# Lead import + lead-assistant smoke (CORS / auth / optional live parse)
./tool/smoke_lead_diagnostic.sh
# FIREBASE_ID_TOKEN='...' ./tool/smoke_lead_diagnostic.sh

# Bezpečnostný preflight
./tool/security_preflight.sh

# Playwright
npm install && npx playwright install chromium
npm run test:integrity
# E2E_BASE_URL=https://flutterdashb-h4ck3d.vercel.app npm run test:integrity
```

Podrobnosti: [`TESTING.md`](TESTING.md), diagnostický audit: [`docs/PROJECT_DIAGNOSTICS.md`](docs/PROJECT_DIAGNOSTICS.md).

---

## Backend (stručne)

**Supabase tabuľky používané appkou:** `profiles`, `bugs`, `projects`, `ai_conversations`, `ai_messages`; Gmail outreach tabuľky `cmr_gmail_outreach_*` (server-only). Lead obsah zostáva lokálne (Sembast) — pozri LEAD_INBOX_SETUP.

**Edge Functions:**

| Function | Účel |
|----------|------|
| `lead-assistant` | Parse leadov, outreach, ponuka, Gmail OAuth/send |
| `ai-router` | Multi-provider AI (Mistral / OpenAI / AnythingLLM) |
| `wp-proxy` | WordPress proxy |

AI setup: [`docs/AI_PROVIDERS.md`](docs/AI_PROVIDERS.md).

---

## Dokumentácia

| Dokument | Obsah |
|----------|--------|
| [`docs/PROJECT_DIAGNOSTICS.md`](docs/PROJECT_DIAGNOSTICS.md) | Aktuálny stav / riziká (august 2026) |
| [`docs/SECURITY_AND_SECRETS.md`](docs/SECURITY_AND_SECRETS.md) | Secrets, gitignore, rotácia |
| [`docs/LEAD_INBOX_SETUP.md`](docs/LEAD_INBOX_SETUP.md) | Lead inbox + Gmail edge |
| [`docs/AI_PROVIDERS.md`](docs/AI_PROVIDERS.md) | AI router / provideri |
| [`TESTING.md`](TESTING.md) | Flutter + Playwright |
| [`docs/PRODUCTION_READINESS_REPORT.md`](docs/PRODUCTION_READINESS_REPORT.md) | Historický snapshot (júl 2026) |

---

*Package: `centralny_dashboard` · Firebase: `machinegunslots` · Supabase: `kpsnwpuydqqojwmrnkdy` · Docs aktualizované: august 2026*
