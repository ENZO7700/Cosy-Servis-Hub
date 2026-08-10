"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import type { UserRole } from "@/generated/prisma/client";
import { ensureProfileAfterSignup } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { createClient } from "@/lib/supabase/server";

function isAuthConfigured(): boolean {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  );
}

function appOrigin(): string {
  return process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
}

function safeNextPath(next: string | null | undefined): string {
  if (!next || !next.startsWith("/") || next.startsWith("//")) return "/";
  return next;
}

const loginSchema = z.object({
  email: z.string().trim().email("Zadajte platný email"),
  password: z.string().min(6, "Heslo musí mať aspoň 6 znakov"),
  next: z.string().optional(),
});

const signupSchema = z.object({
  fullName: z
    .string()
    .trim()
    .min(2, "Zadajte meno a priezvisko")
    .max(80, "Meno je príliš dlhé"),
  email: z.string().trim().email("Zadajte platný email"),
  password: z.string().min(6, "Heslo musí mať aspoň 6 znakov"),
  role: z.enum(["CUSTOMER", "PROVIDER"]).default("CUSTOMER"),
  promoCode: z
    .string()
    .trim()
    .max(40, "Promo kód je príliš dlhý")
    .optional()
    .or(z.literal("")),
  next: z.string().optional(),
});

export type AuthFormState = {
  status: "idle" | "success" | "error";
  message?: string;
  fieldErrors?: Record<string, string[] | undefined>;
};

export async function loginAction(
  _prev: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  if (!isAuthConfigured()) {
    return {
      status: "error",
      message:
        "Prihlásenie nie je dostupné — chýba konfigurácia Supabase Auth (T0 infra).",
    };
  }

  const parsed = loginSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
    next: formData.get("next")?.toString() || undefined,
  });

  if (!parsed.success) {
    return {
      status: "error",
      message: "Skontrolujte email a heslo.",
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
    };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email: parsed.data.email,
    password: parsed.data.password,
  });

  if (error || !data.user) {
    return {
      status: "error",
      message: error?.message ?? "Prihlásenie zlyhalo. Skontrolujte údaje.",
    };
  }

  if (isDatabaseConfigured()) {
    try {
      const meta = data.user.user_metadata ?? {};
      await ensureProfileAfterSignup({
        userId: data.user.id,
        email: data.user.email ?? parsed.data.email,
        fullName:
          (typeof meta.full_name === "string" && meta.full_name) ||
          (typeof meta.fullName === "string" && meta.fullName) ||
          null,
        role:
          meta.role === "PROVIDER" || meta.role === "CUSTOMER"
            ? (meta.role as UserRole)
            : "CUSTOMER",
      });
    } catch (profileError) {
      console.error("[auth] ensureProfileAfterSignup on login:", profileError);
    }
  }

  redirect(safeNextPath(parsed.data.next));
}

export async function signupAction(
  _prev: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  if (!isAuthConfigured()) {
    return {
      status: "error",
      message:
        "Registrácia nie je dostupná — chýba konfigurácia Supabase Auth (T0 infra).",
    };
  }

  const parsed = signupSchema.safeParse({
    fullName: formData.get("fullName"),
    email: formData.get("email"),
    password: formData.get("password"),
    role: formData.get("role") || "CUSTOMER",
    promoCode: formData.get("promoCode"),
    next: formData.get("next")?.toString() || undefined,
  });

  if (!parsed.success) {
    return {
      status: "error",
      message: "Skontrolujte vyznačené polia formulára.",
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
    };
  }

  const { fullName, email, password, role, promoCode, next } = parsed.data;
  const supabase = await createClient();

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: `${appOrigin()}/auth/callback?next=${encodeURIComponent(safeNextPath(next))}`,
      data: {
        full_name: fullName,
        role,
        promo_code: promoCode || null,
      },
    },
  });

  if (error) {
    return {
      status: "error",
      message: error.message,
    };
  }

  // Immediate session (email confirmation disabled) → create Profile + redirect.
  if (data.session && data.user) {
    if (isDatabaseConfigured()) {
      try {
        await ensureProfileAfterSignup({
          userId: data.user.id,
          email: data.user.email ?? email,
          fullName,
          role,
          promoCode: promoCode || null,
        });
      } catch (profileError) {
        console.error("[auth] ensureProfileAfterSignup on signup:", profileError);
      }
    }
    const dest =
      role === "PROVIDER" && safeNextPath(next) === "/"
        ? "/pro"
        : safeNextPath(next);
    redirect(dest);
  }

  // Email confirmation required — user must click the link.
  return {
    status: "success",
    message:
      "Účet bol vytvorený. Skontrolujte email a potvrďte registráciu odkazom.",
  };
}

export async function logoutAction(): Promise<void> {
  if (!isAuthConfigured()) {
    redirect("/");
  }
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/");
}
