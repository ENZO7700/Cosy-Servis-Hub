# Firebase Development Prompt

> **Poznámka:** Tento prompt je pre **iný** repozitár (`issue-shepherd-pro`, Vite + React + shadcn). **Nie** je to návod pre tento Flutter projekt (`centralny_dashboard`). Aktuálny Flutter stav: [`../README.md`](../README.md), diagnostika: [`PROJECT_DIAGNOSTICS.md`](PROJECT_DIAGNOSTICS.md).

Pouzi tento prompt pre dalsiu vyvojovu fazu:

```text
Pracuj v repozitari issue-shepherd-pro ako senior TypeScript/React/Firebase developer. Projekt je Vite + React + shadcn/ui a uz ma pripravenu Firebase konfiguraciu cez VITE_FIREBASE_* env pre projekt machinegunslots.

Ciel: dopln Firebase vyvojovu vrstvu bez rozbitia existujucej Supabase integracie.

Urob male, reverzibilne zmeny:
1. Pridaj Firebase Auth s email/password a Google providerom, vratane chranenych rout a cisteho loading/error stavu.
2. Navrhni Firestore kolekcie pre issues, projects, comments, users a activity log; pridaj TypeScript typy a validaciu cez zod.
3. Priprav security rules pre Firestore a Storage s least-privilege pristupom.
4. Pridaj Firebase Emulator Suite workflow pre auth, firestore, storage a hosting.
5. Pridaj Storage upload pre prilohy k issue, s kontrolou typu a velkosti suboru.
6. Pridaj zakladne testy pre auth/context data layer a manualne Playwright kroky pre hlavny user flow.
7. Aktualizuj README o lokalny setup, env premenne, emulator workflow, build a deploy na Firebase Hosting.

Obmedzenia:
- Neprintuj a necommituj secrets.
- Nedas authenticated API responses do PWA cache.
- Zachovaj existujuce UI konvencie a nepremienaj appku na landing page.
- Pred dokoncenim spusti lint, testy a build, potom vypis rizika a rollback kroky.
```
