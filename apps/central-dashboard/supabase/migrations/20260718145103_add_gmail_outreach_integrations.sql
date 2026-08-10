-- Server-only OAuth credentials. Lead and draft content remains on the device.
create table public.cmr_gmail_outreach_integrations (
  firebase_uid text primary key,
  gmail_address text not null,
  encrypted_refresh_token text not null,
  token_iv text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.cmr_gmail_outreach_integrations enable row level security;
revoke all on public.cmr_gmail_outreach_integrations from public, anon, authenticated;

create table public.cmr_gmail_outreach_sends (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text not null,
  idempotency_key uuid not null,
  lead_id text not null,
  recipient_hash text not null,
  gmail_message_id text,
  status text not null check (status in ('processing', 'sent', 'failed')),
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (firebase_uid, idempotency_key)
);

alter table public.cmr_gmail_outreach_sends enable row level security;
revoke all on public.cmr_gmail_outreach_sends from public, anon, authenticated;

create index cmr_gmail_outreach_sends_user_created_idx
  on public.cmr_gmail_outreach_sends (firebase_uid, created_at desc);

comment on table public.cmr_gmail_outreach_integrations is
  'Server-only encrypted Gmail OAuth refresh tokens keyed by verified Firebase UID.';
comment on table public.cmr_gmail_outreach_sends is
  'Server-only idempotency and minimal delivery audit; message content is never stored.';
