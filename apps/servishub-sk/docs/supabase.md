# Supabase — stav, Gate 0 a DB audit

> Aktualizované 2026-08-09 (po Fáze A E2E). Project ref: **`msmbhgnpyayjpgkmhcvw`**.  
> URL: `https://msmbhgnpyayjpgkmhcvw.supabase.co`

## Gate 0 — kontrola

```bash
pnpm env:check
```

**Stav:** Gate 0 **HOTOVÉ** (service role, DB URL, E2E heslá v `.env.local`).  
Stripe keys stále chýbajú → `e2e/payments.spec.ts` sa skipne.

Demo loginy (heslá len v `.env.local`):

- `e2e-provider@example.com`
- `e2e-customer@example.com`
- slug providera: `e2e-upratovanie-ba`

```bash
pnpm db:seed
pnpm test:e2e
```

---

## DB audit (MCP)

| Tabuľka | RLS | Poznámka |
|---------|-----|----------|
| categories | on | 5 |
| profiles / providers / services / availability | on | seed |
| bookings | on | E2E vytvára |
| `_prisma_migrations` | **on** | revoke anon/authenticated hotové |

Security: ERROR `rls_disabled` vyriešený. Ostáva INFO „RLS no policy“ na `_prisma_migrations` (deny-by-default OK) + WARN leaked password protection.

---

## Výsledky testov (Fáza A)

### Vitest

113/113 PASS

### Playwright (`pnpm test:e2e`)

```text
7 passed
3 skipped   # signup soft-skip (domain/rate) + payments (bez Stripe)
0 failed
```

Prešlé DoD A scenáre:

- seed customer login + logout
- `/hladat` → `/p/e2e-upratovanie-ba` → rezervácia → `/moje-rezervacie`
- double-booking konflikt
- pro profil / služby / dostupnosť / verejný slug
- provider Potvrdiť → Dokončiť
- waitlist + review po COMPLETED

### Ostáva (Fáza B–D)

1. Commit E2E harness (bez `.env.local`, bez `ai-agents-base44/`, bez `cleanup-report-…`).
2. Vercel link + env.
3. Stripe test keys.
4. Confirm email OFF + leaked password protection.
5. Admin role SQL.
