# ServisHub SK — Produktový & engineering backlog

> Zdroj pravdy pre post-scaffold prácu. Sync s plánom `servishub_sk_scaffold`.  
> Scaffold (Fáza 0) = hotový v `~/HUB/01-Projekty/ServisHUB-SK`.

## Stav scaffoldu

| Položka | Stav |
|---------|------|
| Repo root `ServisHUB-SK` | Done |
| Next.js App Router + Turbopack | Done (Next 16) |
| Supabase init + Auth SSR + middleware | Done (cloud create blokovaný free limitom) |
| Prisma v7 + init migrácia + RLS draft | Partial (apply proti DB TODO) |
| README + CLAUDE.md + `.env.example` | Done |
| `.github/` CI | Done (+ vitest) |
| Security headers + Sentry stub | Done (Sentry čaká na DSN — pozri [T0-INFRA](T0-INFRA.md)) |

---

## Stack (kanonický)

Next.js App Router · Vercel · Supabase (Postgres + RLS + Auth) · Prisma v7 · Stripe Connect Express · GoPay (SK fallback) · SuperFaktura · Google Calendar · Google Maps · Resend / Twilio / FCM · Sentry + Vercel Analytics

---

## Dátový model — gap vs. scaffold

**Už v schéme:** Profile (+ promoCode), Provider, Category, Service, ServiceArea, Availability, Booking, Review, Subscription, Lead, Payment, Payout, Dispute, Message, Notification

**Doplniť neskôr (post-MVP):**

| Tabuľka / pole | Poznámka |
|----------------|----------|
| `providers` geo | PostGIS point neskôr |
| `leads` marketplace | credit unlock UX |
| disputes UI | admin workflow |

**Indexy:** city/PSČ, category+price, `bookings(provider_id, scheduled_at)`, UNIQUE `payments(intent_id)`, geo (GiST) neskôr.

**RLS:** customer = own rows; provider = own catalog + party bookings; admin = all; anon = public catalog/reviews. Prisma = trusted server (authorize in app).

---

## MVP sprinty (4–6 týždňov)

### T0 — Infra + Auth + CI
Supabase link, Auth E2E, Vercel preview, GitHub Actions, Sentry.  
**Metrika:** green CI; login < 5 s; preview na každom PR.

**Stav (2026-08-09):** Auth E2E **code-complete** (`/login`, `/signup`, `/auth/callback`, `/auth/logout`, Google OAuth stub). Blokéry: Supabase link, Vercel project, Sentry DSN — [T0-INFRA](T0-INFRA.md).

### T1 — Profily + služby + search
Provider onboarding (bez full KYC), CRUD services, search (mesto, kategória, cena, rating).  
**Metrika:** ≥ 10 seed providerov; search P95 < 400 ms.

**Stav (2026-08-09):** kód hotový, čaká na live DB (Supabase link — pozri [T0-INFRA](T0-INFRA.md)).

- [x] `/pro/profil` — onboarding forma (businessName, bio, IČO/DIČ, mesto, PSČ, kategórie), zod validácia, server action, guard PROVIDER/ADMIN
- [x] `/pro/sluzby` — CRUD služieb (list + create `/nova` + edit `/[id]`, soft-delete cez `isActive`), server actions
- [x] `/hladat` — reálny search cez Prisma (q, mesto, kategória, cena, min. rating, sort rating/cena, stránkovanie 12/str., GET forma pre SEO/share)
- [x] `/p/[slug]` — verejný profil (generateMetadata, JSON-LD LocalBusiness, služby, recenzie placeholder, 404 pri neznámom slug)
- [x] Data layer `src/lib/data/*` + zod schémy `src/lib/validation/*`; graceful empty states bez DATABASE_URL
- [x] Schema: Provider↔Category M:N (`_CategoryToProvider`) + migrácia `20260809013500` + RLS
- [ ] Overiť proti live DB: migrácie apply, seed kategórií + ≥ 10 providerov, search P95 < 400 ms
- [ ] KYC (Veriff/Onfido) — mimo T1 scope

### T2 — Rezervácie + kalendár
Slots (reuse mistral patterns), booking create/cancel, conflict guards, Resend confirm.  
**Metrika:** 0 double-bookings v e2e; happy-path success ≥ 95 %.

**Stav (2026-08-09):** kód hotový (bez live DB).

- [x] `src/lib/booking/slots.ts` — Europe/Bratislava, overlap exclusion + vitest
- [x] `/pro/dostupnost` — weekly Availability CRUD
- [x] Booking UI na `/p/[slug]` + Prisma `$transaction` double-booking guard
- [x] `/moje-rezervacie` — customer list + cancel
- [x] `/pro/objednavky` — provider booking list + status actions
- [x] `src/lib/notifications/email.ts` — Resend alebo console.log
- [x] Vitest + CI test step
- [ ] E2E proti live DB (0 double-bookings)

### T3 — Stripe Connect + admin
Express onboarding, charge + `application_fee_amount`, webhooks, admin overview.  
**Metrika:** test charge + fee; webhook reconcile 100 % (test mode).

**Stav (2026-08-09):** code paths hotové; live Stripe účet stále manuálny.

- [x] `stripe` SDK + `src/lib/stripe/client.ts` (lazy)
- [x] `/pro/platby` + `/api/payments/connect` Account Link
- [x] `/api/payments/create-intent` s `application_fee_amount` (`COMMISSION_PERCENT` default 15)
- [x] `/api/payments/webhook` — signature verify, Payment upsert, Booking status
- [x] `/admin` — users / bookings / payments (graceful empty)
- [x] `.env.example` Stripe Connect vars
- [ ] Test charge + webhook v Stripe test mode (vyžaduje keys)

### T4 — Recenzie + waitlist + landing
Reviews po COMPLETED, SEO landing + structured data, waitlist.  
**Metrika:** CWV green; waitlist funguje; 1× review e2e.

**Stav (2026-08-09):** kód hotový (bez live DB).

- [x] Review flow po COMPLETED (`/moje-rezervacie`, `/p/[slug]/recenzia`) + ratingAvg/ratingCount transaction
- [x] Waitlist → Lead `source=waitlist` + toast
- [x] SEO landing: hero, JSON-LD Organization/WebSite/FAQ, BA upratovanie copy
- [x] Early-bird / referral: promo kód na signup (`Profile.promoCode`) + waitlist notes
- [ ] Live E2E review + CWV na preview URL

### Buffer T5–T6
Bugfix, UX, BA soft-launch prep (upratovanie · Bratislava).

---

## Monetizácia (fázy)

| Fáza | Scope |
|------|--------|
| MVP T3 | Connect Express, immediate capture, application fee 10–20 % |
| Fáza 2 | Manual capture escrow; Stripe Billing tiers; lead kredity |
| Fáza 2+ | GoPay fallback; SuperFaktura auto-faktúry (DPH na províziu) |

---

## Bezpečnosť / GDPR / právne

- RLS všade; service-role len server
- KYC cez Veriff/Onfido — **neskladovať ID scany** v app DB
- Retention + audit log (admin, payouts, disputes)
- Consent UI; zmluvy sprostredkovania; anti-leak (poistenie len cez platformu, penalty)

---

## DevOps / testovanie

- Feature-branch → PR → Vercel preview
- CI: lint / typecheck / vitest / build
- [x] Vitest unit + mocked integration (`pnpm test`, `pnpm test:coverage`, prah ≥60 % lines)
- [ ] Playwright e2e (po live Supabase)
- Sentry, Vercel Analytics, uptime; k6 pred soft launch
- Prisma migrate + `supabase/migrations` RLS; PITR keď Pro
- Terraform IaC = post-MVP

---

## UX rozhodnutia

- Dual onboarding (zákazník rýchly / profík wizard)
- Verifikácia PENDING → VERIFIED/REJECTED
- Booking: service → slot → extras → deposit → confirm; collision = najbližšie sloty
- Notifikácie: email P0, SMS reminders, push neskôr
- MVP locale `sk`; i18n sk/en vo Fáze 2; a11y baseline od T0

---

## Škálovanie (post-MVP)

Lead marketplace (pay-per-lead) · prioritné zobrazenie podľa tieru · dispute workflow · payout cadence · fraud rate-limits / anomaly scoring

---

## Go-to-market

**Upratovanie · Bratislava** → supply cez agentúry + referral + early-bird PRO → demand SEO + waitlist → partner poistenie

---

## Komponentový katalóg

| Komponent | Priorita |
|-----------|----------|
| Landing + Waitlist (SEO, JSON-LD) | P0 ✅ code |
| Auth (email / OTP / OAuth) | P0 ✅ code |
| Provider onboarding wizard | P0 (KYC P1) ✅ code |
| Search & map | P0 (mapa P1) ✅ search |
| Service detail + booking modal | P0 ✅ |
| Booking flow + PaymentIntent | P0 ✅ code |
| Provider dashboard | P0 ✅ |
| Admin dashboard | P0 ✅ overview |
| Payments service + webhooks | P0 ✅ code |
| SuperFaktura worker | P1 |
| Notifications (Resend/Twilio/FCM) | P0/P1 ✅ Resend stub |
| Background jobs (capture/refund) | P1 |
| Google Calendar / Maps | P1 |
| Monitoring (Sentry…) | P0 stub |
| Feature flags | P1 |
| Rate limiter / fraud middleware | P1 |
| I18n sk/en + a11y utils | P1 |

### Reuse (mistral-booking-whitelabel)

- `apps/web/src/lib/booking/calendar.utils.ts`
- `TimeSlotPicker.tsx`, `Calendar.tsx`
- `supabase/migrations/009_booking_concurrency_hardening.sql`

---

## Execution order (ďalej)

1. Manuálne T0 blokéry: Supabase projekt + link, Vercel link, Sentry DSN — [T0-INFRA.md](T0-INFRA.md)
2. Apply migrácie + `pnpm db:seed` + soft-launch E2E (booking / platba / review)
3. Buffer T5–T6: UX polish, CWV, BA launch prep
