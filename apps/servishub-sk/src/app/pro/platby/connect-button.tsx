"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";

export function ConnectOnboardingButton({
  disabled,
  hasAccount,
}: {
  disabled?: boolean;
  hasAccount?: boolean;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function startOnboarding() {
    setError(null);
    startTransition(async () => {
      try {
        const res = await fetch("/api/payments/connect", { method: "POST" });
        const data = (await res.json()) as { url?: string; error?: string };
        if (!res.ok || !data.url) {
          setError(data.error ?? "Nepodarilo sa spustiť Connect onboarding.");
          return;
        }
        window.location.href = data.url;
      } catch {
        setError("Sieťová chyba pri spustení Connect.");
      }
    });
  }

  return (
    <div className="space-y-2">
      <Button
        type="button"
        disabled={disabled || pending}
        onClick={startOnboarding}
      >
        {pending
          ? "Pripravujem odkaz…"
          : hasAccount
            ? "Dokončiť / obnoviť Connect"
            : "Prepojiť Stripe Connect"}
      </Button>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  );
}
