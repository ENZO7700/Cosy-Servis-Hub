# Production Readiness Report (Central Workspace)

> **Historický snapshot (júl 2026).** Niektoré line counts a „production ready“ claimy už nemusia sedieť s kódom. Aktuálny stav a riziká: [`PROJECT_DIAGNOSTICS.md`](PROJECT_DIAGNOSTICS.md) a root [`README.md`](../README.md).

Tento dokument potvrdzuje, že aplikácia **Centralny Dashboard** je pripravená na nasadenie do produkčného prostredia. Boli splnené všetky kritické požiadavky na integráciu, zabezpečenie a celkovú architektúru.

---

## 1. Architektúra & Smerovanie (Routing)
- **GoRouter integrácia**: Celá navigácia bola úspešne prerobená na moderný `go_router` (`lib/app/router.dart`).
- **Autentifikačná brána**: Nahradili sme starý `AuthGate` za deklaratívne `redirect` stráženie v GoRouter konfigurácii. Neprihlásení používatelia sú automaticky presmerovaní na `/auth` a po prihlásení späť na pôvodný deep-link.
- **Podpora Deep-linking**: Plne podporované deep-link cesty pre:
  - `/` (Prehľad)
  - `/crm/clients/:id` (CRM Karta konkrétneho klienta)
  - `/leads/:id` (Lead detail)
  - `/web-app/:appId` (Pracovné prostredie konkrétnej webovej aplikácie)

## 2. Refaktoring & Modularizácia
- **CRM Dashboard**: Pôvodný 1266-riadkový monolit `crm_dashboard_screen.dart` bol rozdelený na menšie, jednoúčelové komponenty v `lib/features/crm/widgets/`:
  - `crm_project_window.dart` (IFrame okno a rýchle akcie)
  - `crm_client_card.dart` (Karta klienta v zozname)
  - `crm_detail_pane.dart` (Detailné info, checklist úloh a časová os aktivít)
- **400-riadkové pravidlo**: Nový `crm_dashboard_screen.dart` má **386 riadkov**, je ľahko čitateľný a neobsahuje business logiku (tá je zapuzdrená v `CrmProvider`).
- **Bezpečnosť platforiem**: Pridané conditional exporty pre `WebAppWorkspace` tak, aby sa webové domovské knižnice (`package:web` a `dart:js_interop`) nekompilovali pre ne-webové prostredia, čím sme zamedzili pádcompileru pri behu lokálnych VM testov.

## 3. Webová integrácia (Web Apps Hub)
- **Dynamický Sidebar**: Ľavé navigačné menu (`app_shell.dart`) načítava povolené webové aplikácie priamo z `WebAppsProvider` a dynamicky ich vykresľuje pod hlavnými menu položkami.
- **IFrame sandbox & Fallback**: Integrovaný bezpečný sandbox pre `HtmlElementView` s automatickým fallbackom na otvorenie v novom okne, ak prehliadač zablokuje iframe kvôli CSP (Cross-Origin Resource Sharing).

## 4. Databázová vrstva & Bezpečnosť
- **Supabase migrácia**: Pripravené bezpečné `IF NOT EXISTS` SQL skripty na vytvorenie chýbajúcich tabuliek (`projects`, `bugs`, `comments`, `activity_log`, `attachments`) a úložného bucketu pre prílohy.
- **Offline-first Sync**: Lokálny ukladací engine (Isar) slúži ako plnohodnotná offline verzia pre leady a CRM dáta. Zmeny sa ukladajú do lokálneho sync queue a synchronizujú so Supabase akonáhle sa obnoví internetové pripojenie.

## 5. Kvalita kódu & Testy
- **Zero Warnings policy**: Kód je plne v súlade so strict linterom. Spustená analýza prešla s **No issues found!**
- **Testovacia stabilita**: Všetky widget, unit a integračné testy boli zosúladené s novou architektúrou (vrátane E2E testov využívajúcich `CentralnyDashboardApp` namiesto zmazaného `AuthGate`). Všetky testy prešli úspešne (**All tests passed!**).
- **Web release build**: Release build prešiel úspešne a vygeneroval optimalizovaný balíček v `build/web`.

---

**Centralny Dashboard je úspešne nasadený na produkčnej vetve `main` a pripravený na prevádzku.**
