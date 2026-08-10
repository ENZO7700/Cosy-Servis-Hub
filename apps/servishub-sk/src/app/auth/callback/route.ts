import { NextResponse, type NextRequest } from "next/server";
import type { UserRole } from "@/generated/prisma/client";
import { ensureProfileAfterSignup } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { createClient } from "@/lib/supabase/server";

const ALLOWED_ROLES: UserRole[] = ["CUSTOMER", "PROVIDER"];

function safeNextPath(next: string | null): string {
  if (!next || !next.startsWith("/") || next.startsWith("//")) return "/";
  return next;
}

function parseRole(value: unknown): UserRole {
  if (typeof value === "string" && ALLOWED_ROLES.includes(value as UserRole)) {
    return value as UserRole;
  }
  return "CUSTOMER";
}

/**
 * Supabase Auth PKCE / email-confirm callback.
 * Exchanges `code` for a session, upserts Profile, redirects to `next` or /.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = safeNextPath(searchParams.get("next"));

  if (!code) {
    return NextResponse.redirect(`${origin}/login?error=missing_code`);
  }

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!supabaseUrl || !anonKey) {
    return NextResponse.redirect(`${origin}/login?error=auth_not_configured`);
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.exchangeCodeForSession(code);

  if (error || !data.user) {
    console.error("[auth/callback] exchange failed:", error?.message);
    return NextResponse.redirect(`${origin}/login?error=auth_callback`);
  }

  const user = data.user;
  const meta = user.user_metadata ?? {};
  const role = parseRole(meta.role);
  const fullName =
    (typeof meta.full_name === "string" && meta.full_name) ||
    (typeof meta.fullName === "string" && meta.fullName) ||
    (typeof meta.name === "string" && meta.name) ||
    null;
  const promoCode =
    typeof meta.promo_code === "string"
      ? meta.promo_code
      : typeof meta.promoCode === "string"
        ? meta.promoCode
        : null;

  if (isDatabaseConfigured()) {
    try {
      await ensureProfileAfterSignup({
        userId: user.id,
        email: user.email ?? `${user.id}@users.servishub.sk`,
        fullName,
        role,
        promoCode,
      });
    } catch (profileError) {
      // Session is valid even if Profile upsert fails (e.g. DB briefly down).
      console.error("[auth/callback] ensureProfileAfterSignup failed:", profileError);
    }
  }

  const redirectTo =
    role === "PROVIDER" && next === "/" ? "/pro" : next;

  return NextResponse.redirect(`${origin}${redirectTo}`);
}
