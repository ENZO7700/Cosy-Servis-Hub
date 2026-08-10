"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";

function appOrigin(): string {
  if (typeof window !== "undefined") return window.location.origin;
  return process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
}

/**
 * Optional Google OAuth. If the provider is not enabled in Supabase,
 * we surface a friendly error instead of crashing the page.
 */
export function GoogleOAuthButton({
  next = "/",
  label = "Pokračovať cez Google",
}: {
  next?: string;
  label?: string;
}) {
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function handleClick() {
    setError(null);
    setPending(true);

    if (
      !process.env.NEXT_PUBLIC_SUPABASE_URL ||
      !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
    ) {
      setError("OAuth nie je nakonfigurovaný (chýbajú Supabase kľúče).");
      setPending(false);
      return;
    }

    try {
      const supabase = createClient();
      const redirectTo = `${appOrigin()}/auth/callback?next=${encodeURIComponent(next)}`;
      const { error: oauthError } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo },
      });
      if (oauthError) {
        setError(
          oauthError.message.includes("provider is not enabled")
            ? "Google prihlásenie nie je zapnuté v Supabase. Použite email a heslo."
            : oauthError.message,
        );
        setPending(false);
      }
      // On success the browser navigates away.
    } catch (err) {
      console.error("[auth] Google OAuth failed:", err);
      setError("Google prihlásenie zlyhalo. Skúste email a heslo.");
      setPending(false);
    }
  }

  return (
    <div className="space-y-2">
      <Button
        type="button"
        variant="outline"
        className="w-full"
        disabled={pending}
        onClick={handleClick}
      >
        {pending ? "Presmerovávam…" : label}
      </Button>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  );
}
