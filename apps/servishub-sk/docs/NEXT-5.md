# Next 5 — Týždeň 0 (best practices)

Presný scope po skaffolde. Každá úloha má **DoD** (definition of done). Pracujeme v poradí 1→5; žiadne Stripe/GoPay/SuperFaktura v tomto batchi.

| # | Úloha | Prečo teraz | DoD |
|---|--------|-------------|-----|
| **1** | `docs/NEXT-5.md` + sync backlog | Jednoznačný scope pred kódom | Tento súbor existuje; CLAUDE.md odkazuje na Next 5 |
| **2** | Prisma schema gap | Bez Payment/Payout/Dispute/Message/Notification nie je MVP T3 | Modely + enums + indexy; `prisma generate` OK; migrácia SQL v `prisma/migrations/` |
| **3** | RLS pre nové tabuľky | Multi-tenant bezpečnosť pred Auth E2E | `supabase/migrations/*_rls_extend.sql`; party/admin/anon pravidlá |
| **4** | GitHub Actions CI | Green CI = metrika T0 | `.github/workflows/ci.yml`: pnpm install → lint → typecheck → build na PR/`main` |
| **5** | Auth session + Profile helper | Jednotný pattern pre `/pro` a `/admin` | `getSessionUser`, `getSessionProfile`, `requireRole`; bez hardcodovaných secrets |

## Out of scope (tento batch)

- Live Supabase cloud create / `prisma migrate deploy` (blokované free limítom / Docker)
- Stripe Connect, GoPay, SuperFaktura
- Booking UI, search, calendar
- Vercel link, Sentry DSN (vyžaduje credentials)

## Best-practice pravidlá tohto batchu

1. **Schema first** — typy a RLS pred UI
2. **CI pred features** — každý PR musí prejsť lint/typecheck/build
3. **Authorize in app + RLS** — Prisma bypassuje RLS; helpers vždy kontrolujú rolu
4. **Žiadne secrets v gite** — len `.env.example`
5. **Malé diffy** — jedna logická zmena na PR keď pôjdeme na remote

## Poradie commitov (odporúčané)

1. `docs: next-5 week-0 task list`
2. `feat(db): add payments payouts disputes messages notifications`
3. `feat(db): extend RLS for new marketplace tables`
4. `ci: add github actions lint typecheck build`
5. `feat(auth): session and profile role helpers`
