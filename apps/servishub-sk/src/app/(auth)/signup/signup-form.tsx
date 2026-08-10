"use client";

import { useActionState } from "react";
import Link from "next/link";
import { signupAction, type AuthFormState } from "../actions";
import { GoogleOAuthButton } from "../google-oauth-button";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const initialState: AuthFormState = { status: "idle" };

export function SignupForm({ next = "/" }: { next?: string }) {
  const [state, formAction, isPending] = useActionState(
    signupAction,
    initialState,
  );

  const fieldError = (field: string) =>
    state.fieldErrors?.[field]?.[0] ? (
      <p className="text-sm text-destructive">{state.fieldErrors[field][0]}</p>
    ) : null;

  if (state.status === "success" && state.message) {
    return (
      <div className="space-y-4">
        <div
          role="status"
          className="rounded-lg border border-primary/30 bg-primary/10 px-4 py-3 text-sm text-foreground"
        >
          {state.message}
        </div>
        <p className="text-sm text-muted-foreground">
          Po potvrdení emailu sa{" "}
          <Link
            href={`/login${next !== "/" ? `?next=${encodeURIComponent(next)}` : ""}`}
            className="text-primary underline-offset-4 hover:underline"
          >
            prihláste
          </Link>
          .
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {state.message ? (
        <div
          role="status"
          className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-foreground"
        >
          {state.message}
        </div>
      ) : null}

      <form action={formAction} className="space-y-4">
        <input type="hidden" name="next" value={next} />
        <div className="space-y-2">
          <Label htmlFor="fullName">Meno a priezvisko</Label>
          <Input
            id="fullName"
            name="fullName"
            autoComplete="name"
            placeholder="Ján Novák"
            required
            aria-invalid={Boolean(state.fieldErrors?.fullName)}
          />
          {fieldError("fullName")}
        </div>
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            name="email"
            type="email"
            autoComplete="email"
            placeholder="vas@email.sk"
            required
            aria-invalid={Boolean(state.fieldErrors?.email)}
          />
          {fieldError("email")}
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">Heslo</Label>
          <Input
            id="password"
            name="password"
            type="password"
            autoComplete="new-password"
            placeholder="••••••••"
            required
            minLength={6}
            aria-invalid={Boolean(state.fieldErrors?.password)}
          />
          {fieldError("password")}
        </div>

        <fieldset className="space-y-2">
          <legend className="text-sm font-medium">Typ účtu</legend>
          <div className="flex flex-col gap-2 sm:flex-row">
            <label className="border-border flex flex-1 cursor-pointer items-center gap-2 rounded-md border px-3 py-2 text-sm">
              <input
                type="radio"
                name="role"
                value="CUSTOMER"
                defaultChecked
                className="accent-primary"
              />
              Zákazník
            </label>
            <label className="border-border flex flex-1 cursor-pointer items-center gap-2 rounded-md border px-3 py-2 text-sm">
              <input
                type="radio"
                name="role"
                value="PROVIDER"
                className="accent-primary"
              />
              Profesionál
            </label>
          </div>
        </fieldset>

        <div className="space-y-2">
          <Label htmlFor="promoCode">Promo / referral kód (voliteľné)</Label>
          <Input
            id="promoCode"
            name="promoCode"
            placeholder="EARLYBIRD"
            maxLength={40}
            aria-invalid={Boolean(state.fieldErrors?.promoCode)}
          />
          {fieldError("promoCode")}
        </div>

        <Button type="submit" className="w-full" disabled={isPending}>
          {isPending ? "Vytváram účet…" : "Vytvoriť účet"}
        </Button>
      </form>

      <div className="relative py-1 text-center text-xs text-muted-foreground">
        <span className="bg-card relative z-10 px-2">alebo</span>
        <div className="border-border absolute inset-x-0 top-1/2 border-t" />
      </div>

      <GoogleOAuthButton next={next} label="Registrovať sa cez Google" />

      <p className="text-sm text-muted-foreground">
        Už máte účet?{" "}
        <Link
          href={`/login${next !== "/" ? `?next=${encodeURIComponent(next)}` : ""}`}
          className="text-primary underline-offset-4 hover:underline"
        >
          Prihlásenie
        </Link>
      </p>
    </div>
  );
}
