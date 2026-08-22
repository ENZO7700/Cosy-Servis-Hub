"use client";

import { useActionState } from "react";
import Link from "next/link";
import { loginAction, type AuthFormState } from "../actions";
import { GoogleOAuthButton } from "../google-oauth-button";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const initialState: AuthFormState = { status: "idle" };

export function LoginForm({
  next = "/",
  initialError,
}: {
  next?: string;
  initialError?: string | null;
}) {
  const [state, formAction, isPending] = useActionState(
    loginAction,
    initialState,
  );

  const fieldError = (field: string) =>
    state.fieldErrors?.[field]?.[0] ? (
      <p className="text-sm text-destructive">{state.fieldErrors[field][0]}</p>
    ) : null;

  return (
    <div className="space-y-4">
      {initialError || state.message ? (
        <div
          role="status"
          className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-foreground"
        >
          {state.message ??
            (initialError === "auth_callback"
              ? "Prihlásenie cez odkaz zlyhalo. Skúste to znova."
              : initialError === "missing_code"
                ? "Chýba overovací kód. Skúste sa prihlásiť znova."
                : initialError === "auth_not_configured"
                  ? "Auth ešte nie je nakonfigurovaný (T0 infra)."
                  : initialError)}
        </div>
      ) : null}

      <form action={formAction} className="space-y-4">
        <input type="hidden" name="next" value={next} />
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
            autoComplete="current-password"
            placeholder="••••••••"
            required
            aria-invalid={Boolean(state.fieldErrors?.password)}
          />
          {fieldError("password")}
        </div>
        <Button type="submit" className="w-full" disabled={isPending}>
          {isPending ? "Prihlasujem…" : "Prihlásiť sa"}
        </Button>
      </form>

      <div className="relative py-1 text-center text-xs text-muted-foreground">
        <span className="bg-card relative z-10 px-2">alebo</span>
        <div className="border-border absolute inset-x-0 top-1/2 border-t" />
      </div>

      <GoogleOAuthButton next={next} />

      <p className="text-sm text-muted-foreground">
        Nemáte účet?{" "}
        <Link
          href={`/signup${next !== "/" ? `?next=${encodeURIComponent(next)}` : ""}`}
          className="text-primary underline-offset-4 hover:underline"
        >
          Registrácia
        </Link>
      </p>
    </div>
  );
}
