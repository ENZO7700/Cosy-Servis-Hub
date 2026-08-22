#!/usr/bin/env node
/**
 * ServisHub SK — Gate 0 kontrola .env.local (slovensky).
 * Nevypisuje hodnoty secrets — len stav a kde ich doplniť.
 *
 *   pnpm env:check
 */
import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { config as loadEnv } from "dotenv";

const root = process.cwd();
const envLocalPath = resolve(root, ".env.local");
const envPath = resolve(root, ".env");

const loadedFrom = existsSync(envLocalPath)
  ? ".env.local"
  : existsSync(envPath)
    ? ".env"
    : null;

if (loadedFrom === ".env.local") {
  loadEnv({ path: envLocalPath });
} else if (loadedFrom === ".env") {
  loadEnv({ path: envPath });
} else {
  loadEnv();
}

const PLACEHOLDER_RE =
  /YOUR_PROJECT|PASSWORD|your-anon|your-service|your-google|sk_test_xxx|pk_test_xxx|whsec_xxx|re_xxx|change-me|placeholder/i;

/**
 * @param {string | undefined} value
 * @returns {"OK" | "CHÝBA" | "PRÁZDNE" | "PLACEHOLDER"}
 */
function statusOf(value) {
  if (value === undefined) return "CHÝBA";
  const trimmed = value.trim();
  if (trimmed === "") return "PRÁZDNE";
  if (PLACEHOLDER_RE.test(trimmed)) return "PLACEHOLDER";
  return "OK";
}

/**
 * @typedef {{ key: string; where: string; required: boolean }} EnvItem
 */

/** @type {{ title: string; items: EnvItem[] }[]} */
const groups = [
  {
    title: "POVINNÉ — live DB / seed / E2E",
    items: [
      {
        key: "NEXT_PUBLIC_SUPABASE_URL",
        where: "Supabase → Project Settings → API → Project URL",
        required: true,
      },
      {
        key: "NEXT_PUBLIC_SUPABASE_ANON_KEY",
        where: "Supabase → Project Settings → API → anon public",
        required: true,
      },
      {
        key: "SUPABASE_SERVICE_ROLE_KEY",
        where: "Supabase → Project Settings → API → service_role (secret)",
        required: true,
      },
      {
        key: "DATABASE_URL",
        where:
          "Supabase → Database → Connection string (Transaction / pooler, port 6543, ?pgbouncer=true)",
        required: true,
      },
      {
        key: "DIRECT_URL",
        where:
          "Supabase → Database → Connection string (Session / direct, port 5432)",
        required: true,
      },
      {
        key: "E2E_PROVIDER_EMAIL",
        where: "Ľubovoľný test email (napr. e2e-provider@example.com) v .env.local",
        required: true,
      },
      {
        key: "E2E_PROVIDER_PASSWORD",
        where: "Silné test heslo providera v .env.local (nie change-me-*)",
        required: true,
      },
      {
        key: "E2E_CUSTOMER_EMAIL",
        where: "Ľubovoľný test email (napr. e2e-customer@example.com) v .env.local",
        required: true,
      },
      {
        key: "E2E_CUSTOMER_PASSWORD",
        where: "Silné test heslo zákazníka v .env.local (nie change-me-*)",
        required: true,
      },
    ],
  },
  {
    title: "POVINNÉ pre payments E2E (Stripe)",
    items: [
      {
        key: "STRIPE_SECRET_KEY",
        where: "Stripe Dashboard → Developers → API keys (test mode) → Secret key",
        required: true,
      },
      {
        key: "STRIPE_WEBHOOK_SECRET",
        where:
          "Stripe CLI `stripe listen` alebo Dashboard → Webhooks → signing secret",
        required: true,
      },
      {
        key: "NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY",
        where: "Stripe Dashboard → API keys (test mode) → Publishable key",
        required: true,
      },
    ],
  },
  {
    title: "VOLITEĽNÉ",
    items: [
      {
        key: "NEXT_PUBLIC_APP_URL",
        where: "Lokálne obvykle http://localhost:3000",
        required: false,
      },
      {
        key: "COMMISSION_PERCENT",
        where: "Provizia platformy v % (default 15)",
        required: false,
      },
      {
        key: "RESEND_API_KEY",
        where: "Resend Dashboard → API Keys (bez kľúča = console.log emailov)",
        required: false,
      },
      {
        key: "RESEND_FROM",
        where: "Odosielateľ emailov, napr. ServisHub SK <noreply@servishub.sk>",
        required: false,
      },
      {
        key: "NEXT_PUBLIC_GOOGLE_MAPS_KEY",
        where: "Google Cloud → Maps API key (zatiaľ placeholder OK)",
        required: false,
      },
      {
        key: "SENTRY_DSN",
        where: "Sentry projekt → Client Keys (DSN)",
        required: false,
      },
      {
        key: "SENTRY_AUTH_TOKEN",
        where: "Sentry → Auth Token (source maps)",
        required: false,
      },
    ],
  },
];

/** Gate 0 = live DB / seed / E2E (nie Stripe) */
const GATE0_KEYS = new Set(
  groups[0].items.filter((i) => i.required).map((i) => i.key),
);

const okMark = "✓";
const badMark = "✗";
const softMark = "·";

/**
 * @param {string} status
 * @param {boolean} required
 */
function markFor(status, required) {
  if (status === "OK") return okMark;
  if (!required) return softMark;
  return badMark;
}

console.log("");
console.log("ServisHub SK — kontrola env");
if (loadedFrom) {
  console.log(`Súbor: ${loadedFrom}`);
} else {
  console.log("Súbor: nenašiel sa .env.local ani .env — skopíruj .env.example → .env.local");
}
console.log("");

/** @type {{ key: string; status: string; where: string; gate0: boolean; payments: boolean }[]} */
const problems = [];

for (const group of groups) {
  console.log(`[${group.title}]`);
  for (const item of group.items) {
    const status = statusOf(process.env[item.key]);
    const mark = markFor(status, item.required);
    const line = `  ${mark} ${item.key} — ${status}`;
    console.log(line);
    if (status !== "OK") {
      console.log(`      → ${item.where}`);
      if (item.required) {
        problems.push({
          key: item.key,
          status,
          where: item.where,
          gate0: GATE0_KEYS.has(item.key),
          payments: group.title.includes("Stripe"),
        });
      }
    }
  }
  console.log("");
}

const gate0Problems = problems.filter((p) => p.gate0);
const paymentProblems = problems.filter((p) => p.payments);

console.log("—".repeat(56));
if (gate0Problems.length === 0) {
  console.log("Gate 0 (DB / seed / E2E): HOTOVÉ — môžeš spustiť pnpm db:seed && pnpm test:e2e");
} else {
  console.log(
    `Gate 0: treba doplniť ${gate0Problems.length} povinných položiek do .env.local:`,
  );
  for (const p of gate0Problems) {
    console.log(`  • ${p.key} (${p.status})`);
  }
}

if (paymentProblems.length > 0) {
  console.log("");
  console.log(
    `Payments E2E: ešte ${paymentProblems.length} Stripe premenných (ostatné E2E môžu bežať bez nich).`,
  );
}

console.log("");
console.log("Manuálne kroky (nie sú v .env):");
console.log("  1. supabase link --project-ref msmbhgnpyayjpgkmhcvw");
console.log(
  "  2. Dashboard → Authentication → Email → Confirm email OFF (dev), inak rate limit",
);
console.log(
  "  3. Harden SQL pre _prisma_migrations — pozri docs/supabase.md",
);
console.log("");
console.log("Detail: docs/supabase.md");
console.log("");

process.exit(gate0Problems.length > 0 ? 1 : 0);
