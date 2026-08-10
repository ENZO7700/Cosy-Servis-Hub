# CLAUDE.md — ServisHub SK

@AGENTS.md

## Project

- **Name:** ServisHub SK
- **Purpose:** Marketplace + SaaS pre lokálne služby (opravy, údržba, upratovanie, inštalácie) — rezervácie, platby, CRM pre remeselníkov, lead-generation
- **Status:** active (scaffold)
- **Primary path:** `~/HUB/01-Projekty/ServisHUB-SK`
- **Prod URL:** TBD
- **Repo:** https://github.com/you640/SERVIShub.git (`main`; backup remote `upstream-auto` → youh4ck3dme/servishub-sk)

## Stack (pin exact versions when critical)

- Framework: Next.js 16 (App Router, Turbopack) + React 19
- Language: TypeScript
- Styling: Tailwind CSS 4 + shadcn/ui (radix-nova)
- Palette: Primary `#00796B`, Secondary `#FF7043`, Background `#F7F9FA`, Text `#1F2933`
- Font: Inter (`latin` + `latin-ext`)
- Backend / DB: Supabase Postgres + Auth + RLS
- ORM: Prisma 7 (`@prisma/adapter-pg`, client in `src/generated/prisma`)
- Auth: Supabase Auth via `@supabase/ssr`
- Hosting: Vercel (not linked yet)
- Package manager: pnpm 11.8.0

## Commands

```bash
pnpm install
pnpm dev                 # Next.js Turbopack
pnpm build
pnpm lint
pnpm typecheck
pnpm db:generate         # prisma generate
pnpm db:migrate          # prisma migrate dev
supabase start           # local Supabase stack (Docker)
supabase status          # local URLs + keys
```

## Architecture notes

- Key folders:
  - `src/app/(marketing)` — landing
  - `src/app/(auth)` — login/signup placeholders
  - `src/app/(customer)` — zákaznícke stránky (`/hladat`)
  - `src/app/pro` — dashboard profesionála (middleware protected)
  - `src/app/admin` — admin (middleware protected)
  - `src/lib/supabase` — browser/server/middleware clients
  - `src/lib/prisma.ts` — Prisma client (adapter-pg)
  - `prisma/schema.prisma` — marketplace models
  - `supabase/migrations` — RLS policies (apply after Prisma migrate)
- Data model summary: Profile → Provider → Service/Availability/ServiceArea; Booking → Review; Subscription; Lead
- External services: Supabase, Stripe Connect (TBD), Google Maps (TBD), Resend (TBD), SuperFaktura (TBD)

### Auth / data access split

- **Supabase client** (`@supabase/ssr`): browser + RSC with RLS
- **Prisma** (direct connection): trusted server-side writes (bypasses RLS) — always authorize in app code
- Middleware guards `/pro/*` and `/admin/*` (session via `getUser()`). Admin role check is TODO.

## Non-negotiables

- [x] SK/CZ locale (DD.MM.YYYY, 24h, EUR) — `lang="sk"`, currency default EUR
- [x] No secrets in git (`.env*` ignored, `.env.example` committed)
- [x] RLS / server-side auth checks (RLS SQL + middleware)
- [x] Mobile-first UI
- [ ] Loading / empty / error states (MVP)

## Current focus

1. ~~Next 5 (T0 batch)~~ — hotové, pozri [docs/NEXT-5.md](docs/NEXT-5.md)
2. T0 infra blokéry + manuálne kroky — [docs/T0-INFRA.md](docs/T0-INFRA.md) (Supabase free limit, Vercel link, Sentry DSN)
3. MVP sprinty T1–T4 — [docs/BACKLOG.md](docs/BACKLOG.md)

## Infra checklist (manuálne)

### Supabase cloud

Free org má limit 2 aktívne projekty — CLI create zlyhalo s:
`maximum limits for the number of active free projects`.

1. Pause/delete nepoužívaný projekt alebo upgrade plánu
2. Dashboard → New project `servishub-sk`, region `eu-central-1`
3. Skopíruj API keys do `.env.local`
4. `supabase link --project-ref <ref>`
5. Aplikuj Prisma migrate + RLS migráciu z `supabase/migrations/`

### Stripe

1. Založiť Stripe účet (SK business)
2. Aktivovať **Connect** (Express accounts)
3. `stripe login` + test keys do `.env.local`
4. Implementácia platieb je mimo scaffold scope

## Reuse referencie (mistral-booking-whitelabel)

Pre MVP booking/calendar (nekopírované do scaffoldu — adaptovať):

- `~/HUB/07-Klienti/mistral-booking-whitelabel/apps/web/src/lib/booking/calendar.utils.ts`
- `~/HUB/07-Klienti/mistral-booking-whitelabel/apps/web/src/lib/booking/TimeSlotPicker.tsx`
- `~/HUB/07-Klienti/mistral-booking-whitelabel/apps/web/src/lib/booking/Calendar.tsx`
- `~/HUB/07-Klienti/mistral-booking-whitelabel/supabase/migrations/003_booking_functions.sql`
- `~/HUB/07-Klienti/mistral-booking-whitelabel/supabase/migrations/009_booking_concurrency_hardening.sql`
- Auth SSR pattern: `apps/web/src/utils/supabase/{client,server,middleware}.ts`

Poznámka: mistral je Next 14 monorepo **bez Prisma** (raw Supabase SQL). ServisHub je Next 16 single-app + Prisma 7.

## Do not

- Commitovať `.env`, `.env.local`, service role keys
- Implementovať Stripe/escrow v scaffold commitoch bez explicitného scope
- Kopírovať mistral monorepo štruktúru namiesto adaptácie slot logiky
