# Base44 → SALONOS read-only integration

Local preparation for a Base44 backend function that reads the canonical SALONOS V1
stats contract. It does not deploy, persist data, send messages, or modify SALONOS.

## Scope

```text
Authenticated Base44 admin/service caller
  → Base44 Deno function (POST)
  → SALONOS stats endpoint (GET only)
  → strict contract and provider validation
  → whitelisted aggregate response
```

The returned response contains only:

- `provider`
- `totalAiRevenue`
- `breakdown`
- `dailyActions`
- `currency`
- `periodStart`

`recentLogs` and every unknown upstream field are removed. The current `dailyActions`
are aggregate counts, not per-client execution records.

## Base44 layout

Copy the function directory into a linked Base44 project only after the runbook gates
are satisfied:

```text
base44/functions/salonosDailyStats/
├── entry.ts
├── reader.ts
└── function.jsonc
```

The function follows Base44's documented `Deno.serve()` entry-point convention and uses
`createClientFromRequest()` to require an authenticated Base44 admin or service
identity.

## Required secrets

Configure through Base44's Secrets UI or CLI. Never paste values into chat, source,
logs, or Git.

| Name                   | Purpose                                                |
| ---------------------- | ------------------------------------------------------ |
| `SALONOS_API_BASE_URL` | Credential-free HTTPS origin of ServisHub              |
| `SALONOS_PROVIDER_ID`  | Exact provider primary key bound to this function      |
| `SALONOS_API_TOKEN`    | Future provider-scoped `salonos:stats:read` credential |

The existing SALONOS endpoint currently validates Supabase user access tokens. Do not
store an owner's session or a Supabase service-role key in Base44. Deployment remains
blocked until SALONOS has a revocable provider-scoped integration credential.

## Local checks

```bash
deno check --no-config --no-lock --node-modules-dir=none base44/functions/salonosDailyStats/entry.ts base44/functions/salonosDailyStats/reader.ts tests/entry_test.ts
deno test --no-config --no-lock --node-modules-dir=none tests/entry_test.ts
```

No network, environment, or filesystem permissions are required by the tests.

## Intentional stop points

- No Base44 deploy.
- No active automation or schedule.
- No cloud database migration.
- No real token.
- No Gmail/SMS connector.
- No client-level action feed.

See `docs/RUNBOOK.md`, `docs/AUTH-DESIGN.md`, and `docs/SUPERAGENT-INSTRUCTIONS.md`
before any live configuration.
