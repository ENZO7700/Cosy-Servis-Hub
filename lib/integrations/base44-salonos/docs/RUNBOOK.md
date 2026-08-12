# Base44 → SALONOS manual cutover runbook

## Gate 0 — local evidence

1. Run `deno check` and `deno test` from this package.
2. Review the exact diff and confirm no application, database, or cloud changes.
3. Confirm the canonical response excludes `recentLogs` and unknown fields.

## Gate 1 — SALONOS machine credential

This gate is currently **BLOCKED BY DESIGN**.

1. Implement and review a provider-scoped `salonos:stats:read` credential.
2. Verify expiry, revocation, tenant mismatch rejection, rate limiting, and audit.
3. Obtain the exact `Provider.id` through a read-only identity check.
4. Never use an owner refresh token or Supabase service-role key.

## Gate 2 — Base44 manual function

1. Copy `base44/functions/salonosDailyStats` into the linked Base44 project.
2. Configure the three secrets using Base44's secure Secrets UI or CLI.
3. Do not put secret values in chat, Git, screenshots, logs, or `function.jsonc`.
4. Deploy only `salonosDailyStats`; never use a destructive `--force` deployment.
5. Invoke it manually while signed in as a Base44 app admin.
6. Compare the returned provider ID and every canonical field with SALONOS.
7. Confirm an ordinary Base44 user receives `403` and an anonymous call receives `401`.

## Gate 3 — operator dry run

1. Give the validated aggregate response to the Daily Growth Operator.
2. Confirm it produces only an aggregate summary.
3. Confirm it does not invent clients, contact details, services, consent, or slots.
4. Confirm no connector was used and the result ends in `NEEDS_DATA` or `NO_ACTIONS`.

## Gate 4 — scheduling

Do not enable scheduling during the first cutover.

Before activation, verify from the deployed Base44 environment:

- the authentication identity used by scheduled automations,
- the schedule timezone and daylight-saving behavior,
- logs and alerting for failed runs,
- that response data is not persisted,
- that retries cannot trigger writes or external communication.

Start with an inactive automation and one manual `Run now`. Enable the recurring
schedule only after explicit approval.

## Gate 5 — client actions and communication

Deferred. The current stats endpoint contains aggregate counts only.

Client-level records require a separately reviewed contract containing purpose-bound
consent and authorized channel data. Gmail/SMS remains disconnected until the approval
workflow is implemented and verified end to end.

## Rollback

1. Disable or archive the Base44 automation.
2. Revoke the provider-scoped SALONOS integration credential.
3. Remove the three Base44 secrets.
4. Review logs for attempted calls without copying sensitive payloads.

No SALONOS data rollback is required because this integration performs no writes.
