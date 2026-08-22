"use client";

import { useState, useTransition } from "react";
import { cancelBooking } from "./actions";
import { Button } from "@/components/ui/button";

export function CancelBookingButton({ bookingId }: { bookingId: string }) {
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  return (
    <div className="flex flex-col items-start gap-1">
      <Button
        variant="outline"
        size="sm"
        disabled={isPending}
        onClick={() => {
          setError(null);
          startTransition(async () => {
            const result = await cancelBooking(bookingId);
            if (result.status === "error") {
              setError(result.message ?? "Zrušenie zlyhalo.");
            }
          });
        }}
      >
        {isPending ? "Zrušujem…" : "Zrušiť rezerváciu"}
      </Button>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  );
}
