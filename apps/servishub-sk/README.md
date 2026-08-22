# ServisHub SK

Marketplace a SaaS pre lokálne služby na Slovensku — rezervácie, platby, CRM pre remeselníkov a lead-generation.

> Stav: **scaffold** (Next.js + Supabase Auth wiring + Prisma schéma + route placeholders). Biznis fičúry ešte nie sú implementované.

## Quick start

```bash
cd ~/HUB/01-Projekty/ServisHUB-SK
pnpm install
cp .env.example .env.local
# vyplň Supabase + DATABASE_URL
pnpm dev
```

Otvor [http://localhost:3000](http://localhost:3000).

## Stack

| Vrstva | Technológia |
|--------|-------------|
| App | Next.js 16 App Router, React 19, TypeScript |
| UI | Tailwind 4, shadcn/ui, Inter |
| Auth/DB | Supabase (Auth + Postgres + RLS) |
| ORM | Prisma 7 + `@prisma/adapter-pg` |
| Package manager | pnpm |

## Routes

| Path | Účel |
|------|------|
| `/` | Landing + waitlist placeholder |
| `/login`, `/signup` | Auth placeholders |
| `/hladat` | Vyhľadávanie (placeholder) |
| `/pro` | Dashboard profesionála (auth guard) |
| `/admin` | Admin panel (auth guard) |

## Database

```bash
pnpm exec prisma generate
pnpm exec prisma migrate dev --name init
# potom aplikuj RLS:
# supabase db push   # alebo spusť supabase/migrations/*.sql
```

Modely: `Profile`, `Provider`, `Category`, `Service`, `ServiceArea`, `Availability`, `Booking`, `Review`, `Subscription`, `Lead`.



## Testovanie

Unit / mocked integration cez **Vitest** (bez živej DB). Playwright e2e až po napojení Supabase.

```bash
pnpm test              # celá sada
pnpm test:watch        # watch mód
pnpm test:coverage     # coverage (v8), prah ≥60 % lines na pokrytých moduloch
```

Colocated `*.test.ts` vedľa source. Mocky: Prisma, Supabase Auth, Stripe, `next/cache` (`redirect` / `revalidatePath`).

## Docs pre agentov

Pozri [CLAUDE.md](./CLAUDE.md) — stack, commands, infra checklist (Supabase/Stripe), reuse cesty z `mistral-booking-whitelabel`.

Produktový backlog (sprinty T0–T4, monetizácia, komponenty): [docs/BACKLOG.md](./docs/BACKLOG.md).

## Design tokens

- Primary: `#00796B`
- Secondary: `#FF7043`
- Background: `#F7F9FA`
- Text: `#1F2933`
