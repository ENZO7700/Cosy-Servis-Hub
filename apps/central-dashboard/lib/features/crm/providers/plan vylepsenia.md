> **Aktuálna diagnostika (august 2026):** pozri [`docs/PROJECT_DIAGNOSTICS.md`](../../../../docs/PROJECT_DIAGNOSTICS.md). Sekcia „Diagnostika projektu“ nižšie je historický plánovací snapshot a nemusí sedieť s kódom.

Áno, chápem ťa presne.

Chceš z toho spraviť centrálny pracovný cockpit, nie ďalší dashboard, ktorý ukazuje tri grafy a potom predstiera zamestnanie.

Hlavné jadro má byť:

1. Leady musia reálne fungovať — vytvoriť, importovať, upraviť, skórovať, filtrovať, presúvať pipeline, ukladať offline a synchronizovať.
2. Tri vlastné webové aplikácie si zadáš cez nastavenia.
3. Každá sa zobrazí ako samostatná položka v bočnom paneli.
4. Po kliknutí sa otvorí vo veľkom pracovnom iframe/paneli bez opustenia dashboardu.
5. URL, názov, ikona a poradie sa budú dať meniť bez rekompilácie aplikácie.
6. Dashboard sa má stať centrom CRM, outreachu, projektov, AI a externých nástrojov.

⸻

Diagnostika projektu

Celkový verdikt

Projekt má dobrý základ, ale momentálne je to zmes:

- Flutter CRM,
- bug tracker,
- projektový dashboard,
- AI asistenta,
- externého CRM iframe,
- Firebase Auth,
- Supabase,
- Isar,
- Sembast,
- WordPress,
- troch hostingov,
- a zopár kostlivcov pochovaných pod ephemeral.

Technicky je to použiteľný prototyp, ale ešte nie čistý produkčný systém.

Aktuálne hodnotenie

Oblasť Stav Verdikt
UI shell a navigácia 7/10 Dobrý základ
CRM klienti 6/10 Funguje lokálne, potrebuje konsolidáciu
Lead inbox 6/10 Má modely a repository, chýba pevný source of truth
Offline-first 5/10 Existuje, ale je roztrieštený
Supabase integrácia 6/10 Potenciál dobrý, treba audit RLS a dátových tokov
Firebase Auth 6/10 Funguje, ale mieša sa so Supabase identitou
Externé weby/iframe 3/10 Aktuálne iba jeden hardcoded CRM frame
Testy 5/10 Niektoré dobré, E2E aktuálne padá
Bezpečnosť 4/10 Citlivé súbory boli v ZIP-e
Maintainability 5/10 Veľké obrazovky a duplicita providerov
Produkčná pripravenosť 5/10 MVP+, nie stabilný operačný systém

⸻

Najdôležitejšie nálezy

P0 — ZIP obsahoval citlivé a generované súbory

Archív obsahuje:

secrets.json
android/local.properties
supabase/.temp/
default.isar
default.isar.lock
ios/Flutter/Generated.xcconfig
macos/Flutter/ephemeral/
windows/flutter/ephemeral/
linux/flutter/ephemeral/
.flutter-plugins-dependencies

To je problém z dvoch dôvodov:

- secrets.json môže obsahovať produkčné kľúče.
- default.isar môže obsahovať reálne leady alebo klientské dáta.
- supabase/.temp/pooler-url a linked metadata nemajú byť distribuované.
- local.properties obsahuje lokálne SDK cesty.
- ephemeral/.plugin_symlinks nafúkli ZIP na obrovský biologický experiment.

Okamžite odporúčam rotovať všetky neverejné kľúče, ktoré boli v secrets.json, najmä ak bol ZIP niekam uploadnutý mimo tejto konverzácie.

Firebase web API key a Supabase anon key nie sú samy osebe tajné, ale ich bezpečnosť závisí od správnych Firebase pravidiel a Supabase RLS. Ak je RLS slabé, anon key je vstupenka do márnice.

⸻

P0 — Leady nemajú jeden jasný source of truth

Projekt používa:

- Isar pre native,
- Sembast pre web,
- Supabase pre serverové dáta,
- samostatné CRM klientské modely,
- samostatné lead modely,
- DataProvider,
- CrmProvider,
- LeadInboxProvider.

To znamená, že existujú minimálne tri paralelné dátové cesty.

Riziko

Lead sa môže:

- vytvoriť lokálne,
- zobraziť v jednom provideri,
- nezobraziť v druhom,
- synchronizovať iným repository,
- skončiť s rozdielnym ID,
- alebo sa po refreshi „zázračne“ vrátiť z mŕtvych.

Odporúčaná architektúra:

UI
↓
LeadController / LeadProvider
↓
LeadRepository
├── LocalLeadDataSource
└── RemoteLeadDataSource
↓
SyncEngine

UI nesmie vedieť, či používa Isar, Sembast alebo Supabase.

⸻

P0 — Offline sync obsahuje mock správanie

V DataProvider existuje logika typu:

final mockRemoteId = 'synced\_${DateTime.now().millisecondsSinceEpoch}';

To je jasný znak, že časť offline synchronizácie nie je produkčná.

Takýto stav je v prototypovaní normálny. V produkcii je to rovnaké ako mať požiarne dvere namaľované na stene.

Synchronizácia musí používať:

- stabilné UUID vytvorené klientom,
- idempotency key,
- retry count,
- nextAttemptAt,
- permanent failure stav,
- konflikt podľa updated_at alebo version countera,
- dead-letter queue.

⸻

P0 — Aktuálny E2E test padá

Z priloženého test_run.log:

Timed out waiting for widget:
Toto je simulovaná odpoveď na:

Okrem toho sa opakovane objavuje:

Isar initialization failed
Failed to load dynamic library libisar.dylib

Takže README tvrdí, že testy prešli, ale uložený najnovší log ukazuje opak.

Reálny stav

- navigačný test prešiel,
- hlavný workflow test zlyhal,
- Isar test runtime nie je hermetický,
- test čaká na konkrétny UI text namiesto stabilného key/state,
- sieťové volania nie sú riadne mockované.

README je teda optimistickejšie než realita. Dashboard marketing už zvláda, teraz ešte musí zvládnuť pravdu.

⸻

P1 — Iframe je momentálne iba jeden hardcoded CRM frame

Konfigurácia obsahuje:

static const String crmFrameUrl = String.fromEnvironment(
'CRM_FRAME_URL',
defaultValue: 'https://nexify-crm-clean-v1.vercel.app/crm',
);

To nestačí pre tvoj cieľ.

Ty potrebuješ dátový model:

class WorkspaceWebApp {
final String id;
final String name;
final String url;
final String icon;
final int position;
final bool enabled;
final bool openExternallyWhenBlocked;
}

A používateľské nastavenia napríklad:

[
{
"id": "crm",
"name": "Nexify CRM",
"url": "https://crm.example.com",
"icon": "users",
"position": 0,
"enabled": true
},
{
"id": "builder",
"name": "Visual Builder",
"url": "https://builder.example.com",
"icon": "code",
"position": 1,
"enabled": true
},
{
"id": "analytics",
"name": "Analytics",
"url": "https://analytics.example.com",
"icon": "chart",
"position": 2,
"enabled": true
}
]

⸻

P1 — Nie každý web sa dá vložiť do iframe

Toto je dôležité.

Externý web môže iframe zablokovať cez:

X-Frame-Options: DENY

alebo:

Content-Security-Policy: frame-ancestors 'none'

Preto musí mať modul dva režimy:

Embed mode

Web sa zobrazí vo vnútri dashboardu.

External fallback

Ak iframe blokuje embedovanie, zobrazí sa:

- názov webu,
- URL,
- dôvod blokovania,
- tlačidlo „Otvoriť v novej karte“.

Pre tvoje vlastné tri weby treba na ich serveroch nastaviť CSP napríklad:

Content-Security-Policy:
frame-ancestors 'self' https://crm.nexify-studio.tech;

Nepoužívať:

X-Frame-Options: ALLOWALL

To je bezpečnostný ekvivalent odmontovania dverí, pretože kľúč sa občas zasekol.

⸻

P1 — Veľké monolitické obrazovky

Najväčšie ručne písané súbory:

crm_dashboard_screen.dart 1265 riadkov
dashboard_screen.dart 876 riadkov
ai_assistant_screen.dart 845 riadkov
lead_detail_screen.dart 653 riadkov
data_provider.dart 530 riadkov
lead_inbox_screen.dart 515 riadkov

crm_dashboard_screen.dart už nie je obrazovka. Je to menšia obec s vlastnou samosprávou.

Treba ho rozdeliť na:

crm_dashboard/
├── crm_dashboard_screen.dart
├── crm_header.dart
├── crm_filters.dart
├── client_list.dart
├── client_card.dart
├── client_detail_panel.dart
├── activity_timeline.dart
├── task_section.dart
└── crm_metrics.dart

⸻

P1 — Auth architektúra je nejasná

Projekt používa:

- Firebase Auth,
- Supabase databázu,
- Supabase Edge Functions.

Treba jasne definovať, ako Supabase overuje Firebase používateľa.

Možnosti:

1. Supabase Auth ako jediný auth systém.
2. Firebase Auth + backend token exchange.
3. Firebase Auth iba pre UI a Edge Functions overujú Firebase JWT.
4. Anon Supabase klient + veľmi prísne serverové Edge Functions.

Najhoršie riešenie je „nejako to funguje cez anon key“. To zvyčajne funguje až do dňa, keď databáza začne fungovať aj cudziemu človeku.

⸻

P1 — Konfigurácia webov nemá byť v dart-define

Tvoje tri weby nesmú byť napevno cez:

FRAME_1_URL
FRAME_2_URL
FRAME_3_URL

To by znamenalo build pri každej zmene.

Správne:

Supabase user_workspace_apps
↓
Local cache
↓
Dynamic sidebar
↓
WorkspaceWebView

Používateľ ich nastaví v UI a zmena sa prejaví okamžite.

⸻

Cieľová architektúra

Central Dashboard
│
├── Dashboard
├── Leads
│ ├── Inbox
│ ├── Pipeline
│ ├── Detail
│ ├── Outreach
│ ├── AI scoring
│ └── Import/export
│
├── CRM Clients
├── Projects
├── Bugs
├── AI Assistant
│
├── Web Apps
│ ├── Web 1
│ ├── Web 2
│ └── Web 3
│
└── Settings
├── Profile
├── Web Apps
├── Integrations
├── Sync status
└── Security

⸻

10 vylepšovacích promptov

Tieto prompty spúšťaj postupne. Nie všetky naraz. Desať agentov naraz nad jedným providerom je elegantný spôsob, ako vyrobiť paralelnú katastrofu.

✅ **PROMPT 1 — SECURITY CLEANUP A REPOSITORY HYGIENE** (KOMPELTNÉ)

Pracuješ na Flutter projekte:

/Users/erikbabcan/HUB/01-Projekty/cmrPLUScentralny-dashboard-flutter

Správaj sa ako senior Flutter engineer, DevSecOps engineer a security auditor.

Cieľom tejto fázy je bezpečne vyčistiť repozitár bez zmeny funkčnosti aplikácie.

Úlohy

1. Skontroluj a oprav .gitignore, aby nikdy neobsahoval:
   - secrets.json
   - .env, .env.\*
   - android/local.properties
   - supabase/.temp/
   - .dart_tool/
   - build/
   - coverage/
   - .firebase/
   - default.isar
   - default.isar.lock
   - \*.isar
   - \*.isar.lock
   - ios/Flutter/Generated.xcconfig
   - ios/Flutter/flutter_export_environment.sh
   - macos/Flutter/ephemeral/
   - linux/flutter/ephemeral/
   - windows/flutter/ephemeral/
   - .flutter-plugins
   - .flutter-plugins-dependencies
   - _.dylib, _.so, \*.dll, pokiaľ nejde o vedome verzovaný artefakt.
2. Zisti, či sú citlivé súbory sledované Gitom:

git ls-files

3. Ak sú sledované, odstráň ich iba z Git indexu, nie z lokálneho disku.
4. Vytvor bezpečný:
   - secrets.json.example
   - dokument docs/SECURITY_AND_SECRETS.md
5. Pridaj skript:

tool/security_preflight.sh

    ktorý pred commitom skontroluje:
    * secrets,
    * private keys,
    * service-role keys,
    * .isar databázy,
    * lokálne SDK cesty,
    * Supabase temp metadata.

6. Neupravuj produkčné kľúče a nevypisuj ich hodnoty.

Akceptačné kritériá

- Žiadny citlivý alebo generovaný súbor nie je trackovaný.
- git status obsahuje iba zámerné zmeny.
- Aplikácia sa stále zostaví.
- Výstup obsahuje presný zoznam odstránených súborov a rizík.
- Nevytváraj commit ani push bez explicitného príkazu.

✅ **PROMPT 2 — LEAD DOMAIN AKO JEDINÝ SOURCE OF TRUTH** (KOMPELTNÉ)

Správaj sa ako senior Flutter architekt a navrhni jednotnú lead architektúru.

Projekt dnes používa viacero providerov, Isar, Sembast a Supabase. Cieľom je odstrániť duplicitu a vytvoriť jeden source of truth pre leady.

Požadovaná architektúra

Lead UI
↓
LeadController
↓
LeadRepository
├── LocalLeadDataSource
├── RemoteLeadDataSource
└── LeadSyncEngine

Úlohy

1. Zmapuj:
   - LeadInboxProvider
   - CrmProvider
   - lead repository web/native
   - Isar lead model
   - Sembast storage
   - Supabase lead tabuľky a Edge Functions.
2. Definuj jednotný immutable model Lead s poľami minimálne:
   - id
   - tenantId
   - companyName
   - contactName
   - email
   - phone
   - website
   - country
   - source
   - status
   - stage
   - score
   - scoreReason
   - tags
   - notes
   - outreachStatus
   - lastContactedAt
   - nextFollowUpAt
   - createdAt
   - updatedAt
   - deletedAt
   - syncStatus
   - version.
3. Použi klientom generované UUID, aby lokálny a serverový záznam mali rovnaké ID.
4. UI nesmie importovať Isar, Sembast ani Supabase priamo.
5. Zachovaj kompatibilitu web/native cez conditional imports.
6. Vytvor migration/adaptation layer pre existujúce lokálne leady.
7. Zamedz strate dát pri upgrade.

Akceptačné kritériá

- Jeden verejný LeadRepository.
- Jeden provider/controller pre leady.
- Žiadna duplicitná business logika.
- CRUD funguje web aj native.
- Existujú unit testy pre mapping, CRUD a migration.
- Žiadny mock remote ID.

✅ **PROMPT 3 — PRODUKČNÝ LEAD CRUD** (KOMPELTNÉ)

Implementuj kompletný produkčný CRUD pre leady.

Funkcie

- vytvoriť lead,
- upraviť lead,
- soft delete,
- obnoviť odstránený lead,
- trvalé vymazanie iba pre administrátora,
- detail leadu,
- poznámky,
- tagy,
- follow-up dátum,
- zmena stage,
- zmena score,
- bulk zmena statusu,
- bulk tagovanie,
- vyhľadávanie,
- filtrovanie,
- zoradenie,
- stránkovanie alebo virtualizovaný zoznam.

UX

Lead detail musí obsahovať:

Header
Contact information
Company information
Lead score
Pipeline stage
Activity timeline
Notes
Outreach drafts
Follow-up
Sync status

Použi stabilné Key identifikátory pre widget testy.

Bezpečnosť

- Tenant/user scope musí byť vynútený na serveri.
- Klient nesmie rozhodovať, ku ktorému tenantovi záznam patrí.
- Nevkladaj service role key do Flutter aplikácie.
- Všetky mutácie musia rešpektovať RLS alebo serverovú Edge Function.

Akceptačné kritériá

- CRUD prežije refresh.
- Offline vytvorený lead sa po pripojení synchronizuje.
- Duplicitný submit nevytvorí dva leady.
- Chyby sa zobrazia používateľovi.
- Všetko je pokryté testami.

✅ **PROMPT 4 — LEAD PIPELINE A KANBAN** (KOMPELTNÉ)

Pridaj plnohodnotnú lead pipeline.

Stage model

Použi konfigurovateľné stage, predvolene:

new
qualified
contacted
proposal
negotiation
won
lost

Funkcie

- Kanban desktop.
- Kompaktný stage list na mobile.
- Drag & drop medzi stĺpcami.
- Optimistic update.
- Rollback pri chybe.
- Počet leadov v stage.
- Hodnota pipeline, ak lead obsahuje estimatedValue.
- Filter podľa ownera, tagu, score a source.
- Lost reason.
- Won timestamp.
- História stage zmien.

Dátová integrita

Stage zmena musí vytvoriť activity event:

{
"type": "stage_changed",
"from": "qualified",
"to": "proposal",
"created_at": "..."
}

Akceptačné kritériá

- Drag & drop funguje bez straty dát.
- Refresh zachová stage.
- Offline zmena sa zaradí do sync queue.
- Konflikt je deterministicky vyriešený.
- Existujú widget a repository testy.

✅ **PROMPT 5 — ROBUSTNÝ OFFLINE SYNC ENGINE** (KOMPELTNÉ)

Nahraď súčasnú mock alebo čiastočnú offline synchronizáciu produkčným sync enginom.

Queue model

Každá operácia musí obsahovať:

- id
- entityType
- entityId
- operation
- payload
- idempotencyKey
- createdAt
- updatedAt
- attemptCount
- nextAttemptAt
- lastError
- status
- permanentFailure.

Stav operácie

pending
processing
synced
retry
failed
conflict

Požiadavky

- Exponential backoff.
- Maximálny počet retry.
- Idempotentné serverové operácie.
- Žiadne generovanie nového remote ID.
- Zachovať klientské UUID.
- Sync iba pri dostupnom pripojení.
- Manuálne tlačidlo „Synchronizovať“.
- UI indikátor:
  - online,
  - offline,
  - synchronizuje,
  - chyba,
  - počet čakajúcich zmien.
- Dead-letter queue v nastaveniach.
- Možnosť retry a inspect payload bez zobrazovania secrets.

Akceptačné kritériá

- Rovnaká operácia vykonaná dvakrát nevytvorí duplicitu.
- Reštart aplikácie nestratí queue.
- Dočasná chyba sa retryne.
- Permanentná chyba je viditeľná.
- Testy pokrývajú offline create/update/delete/conflict.

✅ **PROMPT 6 — WEB APPS HUB PRE TRI VLASTNÉ WEBY** (KOMPELTNÉ)

Implementuj nový modul Web Apps Hub.

Používateľ musí vedieť zadať tri webové aplikácie v nastaveniach a otvárať ich z bočného panela bez opustenia dashboardu.

Dátový model

Vytvor WorkspaceWebApp:

class WorkspaceWebApp {
final String id;
final String name;
final String url;
final String icon;
final int position;
final bool enabled;
final bool openExternallyWhenBlocked;
final DateTime createdAt;
final DateTime updatedAt;
}

Funkcie

V Nastaveniach pridaj sekciu „Webové aplikácie“.

Používateľ môže pre každý z troch slotov nastaviť:

- názov,
- URL,
- ikonu,
- zapnuté/vypnuté,
- poradie,
- domovskú cestu,
- fallback otvorenia v novej karte.

Konfiguráciu ukladaj:

1. lokálne pre okamžité načítanie,
2. do Supabase používateľských nastavení pre synchronizáciu medzi zariadeniami.

Sidebar

Zapnuté weby sa dynamicky zobrazia v bočnom paneli.

Príklad:

Prehľad
Leady
CRM
Projekty
────────
Nexify CRM
Visual Builder
Analytics
────────
Nastavenia

Akceptačné kritériá

- URL sa nemenia cez source code ani dart-define.
- Zmena názvu alebo URL sa prejaví bez rebuild.
- Po reštarte ostane konfigurácia zachovaná.
- Maximálne tri aktívne weby.
- URL sa validuje.
- Povolené sú iba https:// URL, okrem localhost development módu.

✅ **PROMPT 7 — BEZPEČNÝ MULTI-IFRAME WORKSPACE** (KOMPELTNÉ)

Vytvor univerzálny EmbeddedWebWorkspace pre nakonfigurované webové aplikácie.

Web implementácia

Použi web-only implementáciu cez conditional import a HtmlElementView.

Každá webová aplikácia musí mať unikátny view type podľa svojho ID. Nepoužívaj jeden globálny statický iframe pre všetky URL.

Toolbar

Nad iframe zobraz:

- názov aplikácie,
- aktuálnu URL,
- späť,
- dopredu,
- refresh,
- domov,
- otvoriť v novej karte,
- fullscreen,
- stav načítania,
- chybový stav.

Bezpečnosť

Iframe nastav minimálne:

sandbox
referrerpolicy
allow
loading

Sandbox permissions povoľ iba podľa potreby.

Nezapínaj automaticky:

allow-same-origin
allow-scripts
allow-forms
allow-popups

Navrhni bezpečný konfiguračný profil a vysvetli trade-off.

Implementuj origin allowlist pre postMessage.

Nikdy neakceptuj správu len podľa obsahu; vždy kontroluj event.origin.

Fallback

Ak web odmieta iframe cez CSP/X-Frame-Options:

- zobraz chybový panel,
- vysvetli problém,
- ponúkni otvorenie v novej karte.

Akceptačné kritériá

- Tri weby sa dajú otvárať nezávisle.
- Prepínanie nevytvára nekonečne nové iframe.
- Stav sa korektne uvoľňuje.
- Žiadny cross-origin postMessage bez validácie.
- Mobile layout je použiteľný.

⏳ **PROMPT 8 — SUPABASE RLS A TENANT SECURITY AUDIT** (ČAKÁ NA PRISTUP)

Sprav detailný bezpečnostný audit Supabase migrácií, tabuliek a Edge Functions.

Audituj

- všetky tabuľky leadov,
- CRM tabuľky,
- user settings,
- workspace web apps,
- activities,
- outreach drafts,
- invoice counters,
- realtime publication,
- automatické RLS migrácie,
- Edge Functions:
  - lead-assistant
  - ai-router
  - wp-proxy.

Over

- RLS je zapnuté na každej verejnej tabuľke.
- Neexistuje USING (true) pre citlivé dáta.
- Tenant ID nemožno podvrhnúť z klienta.
- auth.uid() alebo overená serverová identita určuje vlastníctvo.
- Insert, select, update, delete majú samostatné politiky.
- Edge Functions overujú Authorization header.
- CORS nie je \* pre privilegované operácie.
- Service role key sa nevyskytuje v klientskom kóde.
- Realtime neposiela dáta cudzieho tenantovi.

Výstup

Vytvor:

docs/SUPABASE_SECURITY_AUDIT.md

s tabuľkou:

Finding
Severity
Affected file
Exploit scenario
Fix
Verification

Akceptačné kritériá

- Každý P0/P1 nález je opravený.
- SQL testy overia izoláciu dvoch používateľov/tenantov.
- Anon používateľ nečíta cudzie dáta.
- Realtime izolácia je testovaná.

✅ **PROMPT 9 — TESTY, KTORÉ NEKLAMÚ** (KOMPELTNÉ)

Oprav testovaciu infraštruktúru projektu.

Aktuálny uložený log obsahuje:

- zlyhanie načítania libisar.dylib,
- timeout E2E testu AI odpovede,
- HTTP volania vracajúce 400 v widget testoch.

Úlohy

1. Oddeľ:
   - unit testy,
   - widget testy,
   - repository testy,
   - integration testy,
   - web integration testy.
2. Nevytváraj reálny Isar runtime tam, kde stačí fake repository.
3. Vytvor injectable abstractions pre:
   - AI service,
   - auth,
   - lead repository,
   - connectivity,
   - clock,
   - UUID generator.
4. Testy nesmú čakať na konkrétny text simulovanej odpovede.
   Použi stabilný widget key alebo stav.
5. HTTP volania mockuj deterministicky.
6. README výsledky musia byť generované alebo aktualizované podľa reálneho test runu.

CI gate

Pipeline musí spúšťať:

dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build web --release

Samostatne spusti integračné testy, ak je dostupné podporované prostredie.

Akceptačné kritériá

- Žiadny Isar dylib error v unit/widget testoch.
- Testy fungujú bez secrets.
- Žiadne skryté network volania.
- CI padne pri zlyhaní testu.
- README neuvádza falošné PASS.

✅ **PROMPT 10 — FINÁLNY CENTRAL WORKSPACE REFACTOR** (KOMPELTNÉ)

Po dokončení predchádzajúcich fáz sprav finálny architektonický refactor aplikácie.

Cieľ

Premeniť projekt na stabilný Central Workspace pre:

- leady,
- CRM,
- projekty,
- bug tracking,
- AI,
- tri externé webové aplikácie.

Požadovaná štruktúra

lib/
├── app/
│ ├── app.dart
│ ├── router.dart
│ └── bootstrap.dart
├── core/
│ ├── auth/
│ ├── config/
│ ├── database/
│ ├── network/
│ ├── sync/
│ ├── security/
│ └── ui/
├── features/
│ ├── dashboard/
│ ├── leads/
│ ├── crm/
│ ├── projects/
│ ├── bugs/
│ ├── ai/
│ ├── web_apps/
│ └── settings/
└── shared/

Refactor pravidlá

- Žiadny screen nad približne 400 riadkov bez dôvodu.
- Žiadna business logika vo widgetoch.
- Žiadny priamy databázový klient v UI.
- Žiadne hardcoded produkčné URL.
- Centralizované error handling.
- Centralizovaný logging bez secrets.
- Stabilné route IDs.
- Deep link podpora pre:
  - lead detail,
  - CRM klienta,
  - web app workspace.

Výsledný UX

Desktop:

Sidebar | Main workspace | Optional detail panel

Mobile:

Drawer / bottom navigation
Main workspace
Full-screen detail routes

Finálny acceptance gate

- flutter analyze bez error/warning.
- Všetky unit/widget testy prejdú.
- Web release build prejde.
- Leady fungujú offline aj online.
- Tri web apps sa nastavujú cez UI.
- Sidebar sa generuje dynamicky.
- CSP-blocked iframe má fallback.
- Žiadne secrets alebo lokálne artefakty v Git.
- Vytvor finálny dokument:
  docs/PRODUCTION_READINESS_REPORT.md
- Nevytváraj commit, push ani deploy bez explicitného povolenia.

⸻

Odporúčané poradie

Spúšťaj ich takto:

1 → Security cleanup ✅
2 → Lead source of truth ✅
3 → Lead CRUD ✅
5 → Offline sync ✅
4 → Pipeline ✅
6 → Web Apps Hub ✅
7 → Multi-iframe workspace ✅
8 → Supabase security ⏳
9 → Tests ⏳
10 → Final refactor 🚧

Najkritickejšie sú 1, 2, 3, 6 a 7. Po nich už bude aplikácia robiť presne to, čo opisuješ: leady ako hlavný pracovný systém a tri tvoje weby otvoriteľné priamo z ľavého panelu.
