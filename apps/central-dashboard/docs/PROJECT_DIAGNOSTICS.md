# Project Diagnostics — Centralny Dashboard

**Dátum:** august 2026  
**Zdroj pravdy:** `lib/`, `pubspec.yaml`, `supabase/`, `tool/`, `test/`, `e2e/`  
**Nahrádza:** zastaranú sekciu „Diagnostika projektu“ v [`lib/features/crm/providers/plan vylepsenia.md`](../lib/features/crm/providers/plan%20vylepsenia.md)

Toto nie je in-app produktová funkcia. Diagnostika = audit stavu kódu + ops smoke (`tool/smoke_lead_diagnostic.sh`). Marketingový text „Online vstupná diagnostika“ na dashboarde s tým nesúvisí.

---

## Verdikt

Použiteľný MVP+ cockpit (bugs/projects, CRM UI, lead inbox s AI edge, iframe nástroje). Ešte nie čistý produkčný operačný systém: leady nemajú remote source of truth, AutoOps je mock, offline vrstva je roztrieštená, dokumentácia bola dlho v rozpore s kódom (opravené v README / tomto súbore).

---

## Skóre podľa oblasti

| Oblasť | Skóre | Verdikt |
|--------|-------|---------|
| UI shell a navigácia | 7/10 | `GoRouter` + `AppShell`, auth redirect funguje |
| Bugs / projects | 7/10 | Supabase + Isar cache; reálny CRUD tok |
| CRM klienti | 6/10 | Natívne UI; lokálne / provider-driven |
| Lead inbox / pipeline | 6/10 | Sembast + `lead-assistant`; chýba jednotný remote SoT |
| Offline-first | 5/10 | Isar vs Sembast vs sync queue — nie jeden engine |
| Supabase integrácia | 6/10 | Shared project `kpsnwpuydqqojwmrnkdy`; RLS stále auditovať |
| Firebase Auth | 6/10 | Funguje; dualita so Supabase session ostáva |
| AutoOps | 3/10 | Plné UI, **mock data**; Provider nie je v `bootstrap.dart` |
| Externé weby / iframe | 6/10 | SEO AI, web apps hub, CRM frame — nie len jeden hardcoded CRM |
| Testy | 6/10 | unit/widget/repository/integration/smoke + Playwright |
| Bezpečnosť / docs | 5/10 | Secrets mimo git OK; starý README mal JWT (odstránené) |
| Produkčná pripravenosť | 5/10 | Deployovateľné; stabilný ops OS ešte nie |

---

## Čo je implementované (august 2026)

- Auth: Firebase (`machinegunslots`) cez `AuthProvider`
- Shell routy: dashboard, projects, bugs, CRM, leads (+ inbox/detail), SEO AI, analytics, AI assistant, AutoOps*, settings, changelog, web-app workspace
- Bugs/projects: `DataProvider` + Supabase + Isar
- Leady: `LeadInboxProvider` / `LeadPipelineProvider` + Sembast repositories + `LeadAiService` → `lead-assistant` (`parse_leads_chunk`, client-side split + progress UI; nie single-call fail-fast)
- Web apps: `WebAppsProvider` + sidebar embed
- Edge: `lead-assistant`, `ai-router`, `wp-proxy`
- Tooling: `tool/test.sh`, `tool/smoke_lead_diagnostic.sh`, `tool/security_preflight.sh`, Playwright

\* AutoOps obrazovky existujú; repository ťahajú `autoops_mock_data.dart`. `AutoOps*` providery **nie sú** registrované v [`lib/app/bootstrap.dart`](../lib/app/bootstrap.dart) — riziko runtime Provider error pri `/autoops`.

---

## P0 / P1 nálezy (aktuálne)

### P0 — Leady bez jedného source of truth

Paralelné cesty: Sembast (web/native), Isar (iné entity), Supabase (bugs/projects/AI), viaceré CRM/lead providery. Lead môže žiť len lokálne a po refreshi/zariadení sa správať nekonzistentne.

**Cieľ:** UI → LeadProvider → LeadRepository → Local + Remote datasource; remote iba cez jasne definované tabuľky/API, nie ad-hoc.

### P0 — AutoOps mock + wiring

UI vyzerá hotovo, dáta nie. Pred produkčným použitím: registrovať providery v bootstrap, nahradiť mock repository, alebo skryť route.

### P1 — Offline sync roztrieštený

`sync_engine.dart` / queue vedľa Sembast lead store. Treba jeden sync kontrakt alebo explicitne zdokumentovať „leady = local-only“.

### P1 — Auth dualita Firebase ↔ Supabase

Edge funkcie validujú Firebase ID token; app môže držať aj Supabase session. Držať jeden kanonický identity príbeh v docs a kóde.

### P1 — RLS / shared Supabase

Projekt zdieľa `kpsnwpuydqqojwmrnkdy` s BizAgent. CMR+ Gmail tabuľky sú server-only; bugs/projects potrebujú overené RLS. Anon key nie je tajný — bezpečnosť = RLS + Firebase rules.

### P1 — Dokumentácia bola stale

README hlásil Riverpod, starý Supabase `gpkjlvwrqrqlrdxmsnke` a obsahoval service_role JWT. Opravené v root README + tomto audite. Historické súbory majú outdated banner.

---

## Ops diagnostika (smoke)

```bash
# Offline Flutter smoke + CORS/auth voči lead-assistant
./tool/smoke_lead_diagnostic.sh

# Voliteľný live parse_leads
FIREBASE_ID_TOKEN='...' ./tool/smoke_lead_diagnostic.sh

# Len offline lead-import smoke
flutter test test/smoke/lead_import_smoke_test.dart
```

Default Edge URL v scripte: `https://kpsnwpuydqqojwmrnkdy.supabase.co/functions/v1/lead-assistant`.

Bezpečnostný preflight: `./tool/security_preflight.sh`.

---

## Čo diagnostika zámerne nie je

- Žiadna obrazovka „Diagnostika“ v aplikácii
- `plan vylepsenia.md` = produktová vízia / starší plán, nie runtime
- Dashboard copy „Online vstupná diagnostika“ = marketing balíčka, nie feature

---

## Odporúčané ďalšie kroky (priorita)

1. Jednotný lead SoT (local + sync kontrakt) alebo explicitne „local-only“ v UI
2. AutoOps: mock → live, alebo skryť z navigácie; opraviť Provider registration
3. RLS audit na shared Supabase (bugs, projects, profiles, AI tables)
4. Rotácia kľúčov, ak boli kedy expoované v starom README / ZIP
5. Držať README + tento súbor ako jediný „aktuálny stav“; historické reporty neaktualizovať dookola

---

## Súvisiace docs

- [`../README.md`](../README.md) — setup, stack, routy
- [`SECURITY_AND_SECRETS.md`](SECURITY_AND_SECRETS.md)
- [`LEAD_INBOX_SETUP.md`](LEAD_INBOX_SETUP.md)
- [`AI_PROVIDERS.md`](AI_PROVIDERS.md)
- [`../TESTING.md`](../TESTING.md)
- [`PRODUCTION_READINESS_REPORT.md`](PRODUCTION_READINESS_REPORT.md) — historický júl 2026
