# AI Lead Inbox setup

The Flutter app stores lead and draft content locally:

- native platforms: the existing Isar database
- Flutter Web: Sembast on IndexedDB

Native builds perform a one-time, non-destructive import from the earlier
`cmr_plus_lead_inbox.db` Sembast file when it exists. The legacy file is left in
place for rollback.

The `lead-assistant` Supabase Edge Function handles Mistral requests and Gmail
OAuth/send operations. It must be deployed separately after review.

## Shared Supabase project

CMR+ and BizAgent use the same Supabase project:

```text
project: bizagent-app-2026
ref: kpsnwpuydqqojwmrnkdy
```

The applications are isolated by ownership and naming. Existing BizAgent tables
and migrations remain unchanged. CMR+ creates only the server-only tables
`cmr_gmail_outreach_integrations` and `cmr_gmail_outreach_sends`. Lead and draft
content is never copied into the shared database.

## Required Edge Function secrets

Configure these only in the Supabase Edge Function environment:

| Secret | Purpose |
|---|---|
| `FIREBASE_PROJECT_ID` | Firebase ID token audience and issuer validation |
| `MISTRAL_API_KEY` | Server-side Mistral API access |
| `GMAIL_CLIENT_ID` | Google OAuth web client |
| `GMAIL_CLIENT_SECRET` | Google OAuth confidential client secret |
| `GMAIL_REDIRECT_URI` | Exact callback URL for `lead-assistant` |
| `CRM_APP_URL` | Fixed post-OAuth redirect back to the app |
| `CRM_ALLOWED_ORIGIN` | Comma-separated allowlist of exact Flutter Web origins |
| `OAUTH_STATE_SECRET` | Random high-entropy OAuth state signing secret |
| `TOKEN_ENCRYPTION_KEY` | Base64-encoded random 32-byte AES-GCM key |

The Google OAuth client needs only:

```text
openid
email
https://www.googleapis.com/auth/gmail.send
```

Enable the Gmail API and register `GMAIL_REDIRECT_URI` as an authorized redirect
URI. Do not put any of these secrets in Flutter `--dart-define` values.

Production callback:

```text
https://kpsnwpuydqqojwmrnkdy.supabase.co/functions/v1/lead-assistant
```

## Chunked Mistral parse

Flutter splits the pasted report locally (`LeadReportSplitter`, ~5k / max 3
`LEAD` blocks) and calls Edge action `parse_leads_chunk` with concurrency 2.
Each chunk uses `mistral-small-latest` with retry ladder to
`mistral-large-latest`. Partial failures keep successful leads and expose
“Zopakovať zlyhané” in the import dialog.

Legacy bulk action `parse_leads` still works (server-side split + partial
`stats` / `failed_chunks`) but the app path is client-orchestrated chunks.

After changing `supabase/functions/lead-assistant`, redeploy:

```sh
supabase functions deploy lead-assistant --project-ref kpsnwpuydqqojwmrnkdy
```

## Local verification

Run:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test test/unit/lead_report_splitter_test.dart
flutter test test/integration/lead_inbox_test.dart
flutter test test/smoke/lead_import_smoke_test.dart
# Optional end-to-end smoke (CORS + edge):
./tool/smoke_lead_diagnostic.sh
flutter analyze
flutter build web
```

The migration creates only server-accessible Gmail integration and send
idempotency tables. It does not create a remote leads table.
