"use client";

import { useActionState, useEffect } from "react";
import { toast } from "sonner";
import { joinWaitlist, type WaitlistFormState } from "./waitlist-actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const initialState: WaitlistFormState = { status: "idle" };

export function WaitlistForm() {
  const [state, formAction, isPending] = useActionState(
    joinWaitlist,
    initialState,
  );

  useEffect(() => {
    if (state.status === "success" && state.message) {
      toast.success(state.message);
    } else if (state.status === "error" && state.message) {
      toast.error(state.message);
    }
  }, [state]);

  return (
    <form action={formAction} className="flex flex-col gap-3">
      <div className="flex flex-col gap-3 sm:flex-row">
        <Input
          type="email"
          name="email"
          placeholder="vas@email.sk"
          required
          className="flex-1"
          aria-label="Email"
        />
        <Button type="submit" variant="secondary" disabled={isPending}>
          {isPending ? "Ukladám…" : "Chcem vedieť"}
        </Button>
      </div>
      <Input
        type="text"
        name="city"
        placeholder="Mesto (predvolene Bratislava)"
        aria-label="Mesto"
      />
      <Input
        type="text"
        name="promoCode"
        placeholder="Promo / referral kód (voliteľné)"
        maxLength={40}
        aria-label="Promo kód"
      />
      {state.message && state.status !== "idle" ? (
        <p
          role="status"
          className={
            state.status === "success"
              ? "text-sm text-primary"
              : "text-sm text-destructive"
          }
        >
          {state.message}
        </p>
      ) : null}
    </form>
  );
}
