# ServisHub SK — Launch checklist

> Postup od odblokovania T0 infra po soft launch **Upratovanie · Bratislava**.  
> Zdroj pravdy pre infra blokéry: [T0-INFRA.md](./T0-INFRA.md) · produktový backlog: [BACKLOG.md](./BACKLOG.md).

**Aktuálny stav:** MVP kód T0–T4 je code-complete; nižšie sú kroky, ktoré vyžadujú credentials, live DB a manuálne overenie.

---

## Fáza 1 — Odblokovať T0 infra

### 1.1 Supabase cloud projekt

- [ ] Uvoľniť slot: pause/delete nepoužívaný projekt **alebo** upgrade plánu (free limit = 2 aktívne projekty)
- [ ] Dashboard → **New project** `servishub-sk`, region **eu-central-1**
- [ ] Skopírovať do `.env.local` (podľa `.env.example`):
  - [ ] `NEXT_PUBLIC_SUPABASE_URL`
  - [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - [ ] `SUPABASE_SERVICE_ROLE_KEY`
  - [ ] `DATABASE_URL` (pooled, port **6543**, `?pgbouncer=true`)
  - [ ] `DIRECT_URL` (direct, port **5432** — len migrácie)
- [ ] `supabase link --project-ref <ref>`
- [ ] (Voliteľné) Authentication → Providers → **Google OAuth** (redirect URL: `{APP_URL}/auth/callback`)

**DoD:** `.env.local` vyplnené; `supabase status` / dashboard ukazuje projekt `servishub-sk`.

### 1.2 Vercel + Git

- [ ] Overiť push na `origin` (you640/SERVIShub) — green CI na `main`
- [ ] `vercel login` alebo `VERCEL_TOKEN`
- [ ] Import repa → project **servishub-sk**, region **fra1**
- [ ] Vercel env (Production + Preview):
  - [ ] Supabase vars (rovnaké ako `.env.local`)
  - [ ] `NEXT_PUBLIC_APP_URL` = preview/prod URL
  - [ ] Stripe + Resend (Fáza 4)
  - [ ] `SENTRY_DSN` (Fáza 1.3)

**DoD:** PR na `main` dostane Vercel preview URL; build prejde.

### 1.3 Sentry (voliteľné pre T0, odporúčané pred launch)

- [ ] Vytvoriť Sentry projekt (Next.js)
- [ ] `pnpm add @sentry/nextjs`
- [ ] `SENTRY_DSN` do `.env.local` + Vercel
- [ ] (Voliteľné) `SENTRY_AUTH_TOKEN` + `withSentryConfig` pre source maps
- [ ] Po deployi: vyvolať test error → event v Sentry dashboarde

**DoD T0 (z [T0-INFRA.md](./T0-INFRA.md)):**

- [ ] `pnpm db:migrate` proti cloud DB prejde
- [ ] Login/signup E2E < 5 s (`/login` → profil cez `ensureProfileAfterSignup`)
- [ ] Každý PR má Vercel preview + green CI
- [ ] Sentry zobrazuje test event (ak zapnuté)

---

## Fáza 2 — Apply migrácie + RLS

```bash
pnpm install
cp .env.example .env.local   # ak ešte nie je
# vyplň DATABASE_URL + DIRECT_URL + Supabase keys

pnpm db:generate
pnpm db:migrate                # prisma migrate deploy / migrate dev proti cloud DB
supabase db push               # alebo manuálne spusti supabase/migrations/*.sql v SQL editore
```

- [ ] Všetky 4 Prisma migrácie aplikované (`init`, `schema_gap`, `provider_categories`, `profile_promo_code`)
- [ ] Všetky 3 RLS migrácie aplikované (`rls_policies`, `rls_extend`, `rls_provider_categories`)
- [ ] Overiť v Supabase SQL: tabuľky `profiles`, `providers`, `bookings`, `payments` existujú
- [ ] Overiť RLS: anon môže čítať verejný katalóg; auth user vidí len svoje riadky

**DoD:** `pnpm exec prisma migrate status` = all applied; žiadne chyby pri `supabase db push`.

---

## Fáza 3 — Seed + demo dáta

### 3.1 Kategórie (hotový skript)

```bash
pnpm db:seed
```

- [ ] 5 kategórií BA/upratovanie upsertnutých (Upratovanie, Hĺbkové, Po renovácii, Okná, Údržba)

### 3.2 Provideri (≥ 10 pre search metriku T1)

Seed dnes obsahuje **iba kategórie**. Providerov treba doplniť jedným z:

- [ ] **A)** Rozšíriť `prisma/seed.ts` o demo providerov + služby + availability (odporúčané)
- [ ] **B)** Manuálne: 10× signup ako PROVIDER → `/pro/profil` → `/pro/sluzby` → `/pro/dostupnost`

Pre každého demo providera:

- [ ] `businessName`, slug, mesto **Bratislava**, PSČ, kategória **Upratovanie**
- [ ] Min. 1 aktívna služba s cenou (EUR)
- [ ] Týždenná dostupnosť (napr. Po–Pi 8:00–17:00)
- [ ] `verificationStatus` = VERIFIED (admin/DB) pre verejný profil

**DoD:** `/hladat?mesto=Bratislava` vráti ≥ 10 výsledkov; search P95 < 400 ms (Chrome DevTools / opakované requesty).

---

## Fáza 4 — E2E: booking · platba · recenzia

Pred testom platieb:

- [ ] Stripe účet (SK), Connect **Express** aktivovaný
- [ ] Test keys v `.env.local` + Vercel: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- [ ] `COMMISSION_PERCENT=15` (alebo podľa biznisu)
- [ ] Stripe CLI: `stripe listen --forward-to localhost:3000/api/payments/webhook` (lokálne) alebo webhook endpoint na preview URL

### 4.1 Auth smoke

| # | Scenár | Očakávaný výsledok | OK |
|---|--------|-------------------|-----|
| 1 | Signup CUSTOMER (`/signup`) | Redirect, Profile v DB, rola CUSTOMER | [ ] |
| 2 | Signup PROVIDER + promo `EARLYBIRD` | Profile.promoCode uložený | [ ] |
| 3 | Login existujúceho usera | Session, `/pro` prístup len pre PROVIDER | [ ] |
| 4 | Logout | Session cleared, redirect | [ ] |

### 4.2 Provider onboarding

| # | Scenár | OK |
|---|--------|-----|
| 1 | `/pro/profil` — uložiť IČO, mesto BA, kategórie | [ ] |
| 2 | `/pro/sluzby/nova` — vytvoriť službu | [ ] |
| 3 | `/pro/dostupnost` — nastaviť sloty | [ ] |
| 4 | `/pro/platby` — Stripe Connect onboarding (test mode) | [ ] |
| 5 | Verejný profil `/p/[slug]` viditeľný anonymne | [ ] |

### 4.3 Booking happy path

| # | Scenár | OK |
|---|--------|-----|
| 1 | Customer: `/p/[slug]` → vybrať službu + slot + adresa | [ ] |
| 2 | Rezervácia vytvorená, status PENDING/CONFIRMED | [ ] |
| 3 | Email potvrdenie (Resend **alebo** console.log fallback) | [ ] |
| 4 | `/moje-rezervacie` — rezervácia viditeľná | [ ] |
| 5 | `/pro/objednavky` — provider vidí objednávku | [ ] |
| 6 | Provider: zmena statusu → COMPLETED | [ ] |
| 7 | **Double-booking:** rovnaký slot 2× → druhý request zlyhá | [ ] |

### 4.4 Platba (Stripe test mode)

| # | Scenár | OK |
|---|--------|-----|
| 1 | PaymentIntent cez `/api/payments/create-intent` | [ ] |
| 2 | Test karta `4242…` — platba SUCCEEDED | [ ] |
| 3 | Webhook: Payment row + Booking status sync | [ ] |
| 4 | `application_fee` = očakávaná provízia (napr. 15 %) | [ ] |
| 5 | `/admin` — platba v prehľade | [ ] |

### 4.5 Recenzia + waitlist

| # | Scenár | OK |
|---|--------|-----|
| 1 | Po COMPLETED: review z `/moje-rezervacie` alebo `/p/[slug]/recenzia` | [ ] |
| 2 | `ratingAvg` / `ratingCount` na Provider aktualizované | [ ] |
| 3 | Recenzia na verejnom profile | [ ] |
| 4 | Waitlist na `/` → Lead `source=waitlist` v DB | [ ] |

**DoD Fáza 4:** 1× kompletný flow customer signup → booking → platba → COMPLETED → recenzia bez manuálneho zásahu do DB.

---

## Fáza 5 — T5 UX polish

Položky z backlogu ešte otvorené pred launchom:

### 5.1 Loading / empty / error stavy

- [ ] `/hladat` — skeleton / prázdna stránka / chyba DB
- [ ] `/p/[slug]` — loading profilu, 404 slug
- [ ] Booking formulár — submitting state, validation errors
- [ ] `/moje-rezervacie`, `/pro/objednavky` — empty states
- [ ] `/pro/platby` — stav „Connect nie je dokončený“

### 5.2 Mobile-first & a11y baseline

- [ ] Otestovať hlavné flow na mobile viewport (375px)
- [ ] Formuláre: label + focus ring + aria-invalid
- [ ] Kontrast a čitateľnosť (primary `#00796B`, text `#1F2933`)

### 5.3 Performance (T4 metrika)

- [ ] Lighthouse / CWV na preview URL: LCP, CLS, INP v zelenej zóne
- [ ] Landing `/` — JSON-LD validácia (Rich Results Test)
- [ ] Obrázky / fonty — žiadne blocking regresie

### 5.4 Bugfix buffer

- [ ] Prejsť Sentry / Vercel logs z E2E session
- [ ] Opraviť P0 bugy z Fázy 4
- [ ] Aktualizovať zastaralý `README.md` (už nie „placeholder scaffold“)

**DoD T5:** Žiadne P0/P1 bugy; loading/empty/error na kľúčových stránkach; CWV green na landing.

---

## Fáza 6 — Soft launch Upratovanie · Bratislava

### 6.1 Právne & GDPR (minimum)

- [ ] Zásady ochrany osobných údajov + obchodné podmienky (link v footeri)
- [ ] Consent pri waitlist / signup
- [ ] Cookie banner ak používate analytics

### 6.2 Supply (profesionáli)

- [ ] Min. **10 reálnych alebo pilotných** providerov v BA (upratovanie)
- [ ] Overenie profilov: PENDING → VERIFIED workflow dohodnutý
- [ ] Stripe Connect dokončený u providerov prijímajúcich platby

### 6.3 Demand (zákazníci)

- [ ] Landing copy finálne SK, CTA → `/hladat` + waitlist
- [ ] SEO: title/description pre BA upratovanie; canonical URL
- [ ] (Voliteľné) Google Search Console + sitemap

### 6.4 Ops pred spustením

- [ ] Production env na Vercel (nie len preview)
- [ ] Stripe **live** keys a webhook (až po test mode E2E)
- [ ] Resend doména overená (`RESEND_FROM`)
- [ ] Monitoring: Sentry + Vercel Analytics; uptime check
- [ ] Rollback plán: posledný green deploy tagnutý

### 6.5 Launch day

- [ ] Prepnúť `NEXT_PUBLIC_APP_URL` na produkčnú doménu
- [ ] Smoke test na prod (login, search, 1 test booking v test mode **alebo** pilot s reálnym providerom)
- [ ] Oznámenie waitlistu / pilot partnerom
- [ ] Sledovať `/admin` + Stripe dashboard prvých 24–48 h

**DoD soft launch:** Verejná URL, ≥ 10 providerov v `/hladat`, aspoň 1 úspešná pilotná rezervácia v produkcii, monitoring aktívny.

---

## Rýchle príkazy (referencia)

```bash
# Lokálny dev
pnpm install && pnpm db:generate && pnpm dev

# DB
pnpm db:migrate
pnpm db:seed
pnpm db:studio

# Kvalita
pnpm lint && pnpm typecheck && pnpm test && pnpm build

# Stripe webhook (lokálne)
stripe listen --forward-to localhost:3000/api/payments/webhook
```

---

## Súvisiace dokumenty

| Súbor | Účel |
|-------|------|
| [T0-INFRA.md](./T0-INFRA.md) | Detail infra blokérov a env vars |
| [BACKLOG.md](./BACKLOG.md) | Sprinty T0–T4, metriky, komponenty |
| [NEXT-5.md](./NEXT-5.md) | Week-0 batch (historický) |
| `.env.example` | Všetky premenné prostredia |
