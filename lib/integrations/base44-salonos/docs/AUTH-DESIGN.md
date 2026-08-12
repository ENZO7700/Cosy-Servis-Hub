# SALONOS integration credential design

## Current blocker

`GET /api/v1/salonos/stats/{providerId}` currently accepts a provider/admin Supabase
access token. Access tokens expire and an owner's refresh token or Supabase service role
must not be copied into Base44.

## Recommended server-side principal

Add a dedicated machine credential in a separate, explicitly approved implementation
stage. Suggested properties:

```text
id
providerId
tokenHash
scope = salonos:stats:read
expiresAt
revokedAt
lastUsedAt
createdAt
```

Security invariants:

1. Generate at least 256 bits of random token material.
2. Show the raw token once and store only a cryptographic hash server-side.
3. Bind the credential to one exact `Provider.id` primary key.
4. Deny route/provider mismatches with `403`.
5. Permit only `salonos:stats:read`; never infer broader scopes.
6. Support expiry, revocation, rotation, audit metadata, and rate limiting.
7. Never accept provider identity from token-unbound request data.
8. Never expose database, Supabase service-role, or owner session credentials.

The existing provider/admin cookie and Supabase bearer paths must remain unchanged. The
integration principal should be an additional deny-by-default authentication path, not a
replacement or weakened fallback.

## Base44 boundary

The Base44 function stores the raw integration token only in encrypted secret storage.
`SALONOS_PROVIDER_ID` is fixed in the same deployment and the returned `provider.id`
must match it exactly. The function drops `recentLogs` and does not persist the
response.

## Multi-tenant evolution

V1 uses one provider-scoped Base44 configuration per tenant. A future centralized
multi-tenant scheduler must resolve provider identity from the authenticated machine
credential, not from an arbitrary workflow argument.
