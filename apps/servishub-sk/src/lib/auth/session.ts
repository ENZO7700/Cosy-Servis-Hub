import { redirect } from "next/navigation";
import type { User } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";
import { prisma } from "@/lib/prisma";
import type { Profile, UserRole } from "@/generated/prisma/client";

export type SessionProfile = Profile;

/**
 * Returns the Supabase Auth user for the current request, or null.
 * Uses getUser() (JWT validation) — never getSession() alone on the server.
 */
export async function getSessionUser(): Promise<User | null> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anon) return null;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}

/**
 * Loads the app Profile row for the authenticated user.
 * Does not auto-create — call ensureProfileAfterSignup from auth callbacks.
 */
export async function getSessionProfile(): Promise<SessionProfile | null> {
  const user = await getSessionUser();
  if (!user) return null;

  return prisma.profile.findUnique({
    where: { userId: user.id },
  });
}

/**
 * Ensures a Profile exists after signup/OAuth (idempotent upsert by userId).
 * Call from auth callback / first login — not from every page render.
 */
export async function ensureProfileAfterSignup(input: {
  userId: string;
  email: string;
  fullName?: string | null;
  role?: UserRole;
  promoCode?: string | null;
}): Promise<SessionProfile> {
  return prisma.profile.upsert({
    where: { userId: input.userId },
    create: {
      userId: input.userId,
      email: input.email,
      fullName: input.fullName ?? null,
      role: input.role ?? "CUSTOMER",
      promoCode: input.promoCode?.trim() || null,
    },
    update: {
      email: input.email,
      ...(input.fullName ? { fullName: input.fullName } : {}),
      ...(input.promoCode?.trim()
        ? { promoCode: input.promoCode.trim() }
        : {}),
    },
  });
}

/**
 * Server-side role gate. Redirects to /login or / if unauthorized.
 * Prisma path bypasses RLS — always use this (or equivalent) before mutations.
 */
export async function requireRole(
  roles: UserRole | UserRole[],
  options?: { next?: string },
): Promise<SessionProfile> {
  const allowed = Array.isArray(roles) ? roles : [roles];
  const profile = await getSessionProfile();

  if (!profile) {
    const next = options?.next ? `?next=${encodeURIComponent(options.next)}` : "";
    redirect(`/login${next}`);
  }

  if (!allowed.includes(profile.role)) {
    redirect("/");
  }

  return profile;
}

export async function requireProviderProfile(): Promise<SessionProfile> {
  return requireRole(["PROVIDER", "ADMIN"], { next: "/pro" });
}

export async function requireAdminProfile(): Promise<SessionProfile> {
  return requireRole("ADMIN", { next: "/admin" });
}
