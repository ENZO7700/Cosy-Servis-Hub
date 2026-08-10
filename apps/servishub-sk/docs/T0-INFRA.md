# T0 — Infra stav a blokéry

> Stav k 2026-08-09 (večer). Auth + seed + live E2E smoke **prešli**.  
> Detail DB + Gate 0: [supabase.md](./supabase.md).  
> Soft launch: [LAUNCH-CHECKLIST.md](./LAUNCH-CHECKLIST.md).

## Hotové v kóde + overené

| Položka | Stav | Poznámka |
|---------|------|----------|
| GitHub Actions CI | ✅ | lint → typecheck → test → build + `prisma validate` |
| Security headers | ✅ | `next.config.ts` |
| Sentry wiring | ✅ stub | bez `SENTRY_DSN` / `@sentry/nextjs` — build warn |
| Auth UI + session | ✅ | login/signup/callback/logout |
| Prisma + RLS na cloude | ✅ | projekt `msmbhgnpyayjpgkmhcvw` |
| Gate 0 `.env.local` | ✅ | `pnpm env:check` exit 0 (Stripe stále prázdne) |
| Seed demo E2E | ✅ | `pnpm db:seed` — provider `e2e-upratovanie-ba` |
| Playwright E2E | ✅ | **7 passed / 3 skipped / 0 failed** (payments + signup soft-skip) |
| `pnpm env:check` | ✅ | `scripts/check-env.mjs` |
| Harden `_prisma_migrations` | ✅ | RLS on + revoke anon/authenticated |

## Cloud Supabase — aktuálne

| Položka | Stav |
|---------|------|
| MCP Supabase | ✅ pripojený |
| Categories | ✅ 5 |
| Profiles / provider / service / availability | ✅ seednuté |
| Bookings | vznikajú cez E2E |
| `supabase link` CLI | ❌ CLI účet bez práv (MCP OK) |

## Blokované — manuálne (mimo Agent)

### 1. Vercel link (preview deploys)

```bash
vercel link --yes --project servishub-sk
```

Env na Vercel: Supabase + `NEXT_PUBLIC_APP_URL` (+ Stripe/Resend podľa potreby).

### 2. Stripe (payments E2E)

Test keys → `.env.local` + Vercel: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`.

### 3. Sentry (voliteľné)

`pnpm add @sentry/nextjs` + `SENTRY_DSN`.

### 4. Auth hygiene

- Confirm email OFF (dev) — signup E2E inak rate-limit / confirm.
- Zapnúť leaked password protection (security WARN).

### 5. Admin user

```sql
UPDATE profiles SET role = 'ADMIN' WHERE email = '…';
```

## DoD T0

- [x] Gate 0 env + seed
- [x] Login seed customer E2E
- [x] `/hladat` → booking smoke E2E
- [ ] Vercel preview na PR
- [ ] Sentry test event (ak zapnuté)
