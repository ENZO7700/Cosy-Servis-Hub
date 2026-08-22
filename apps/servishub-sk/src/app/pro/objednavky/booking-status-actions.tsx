"use client";

import { useState, useTransition } from "react";
import { updateBookingStatusAction } from "./actions";
import { Button } from "@/components/ui/button";

export function BookingStatusActions({
  bookingId,
  status,
}: {
  bookingId: string;
  status: string;
}) {
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<string | null>(null);

  function run(next: "CONFIRMED" | "COMPLETED" | "CANCELLED") {
    setMessage(null);
    startTransition(async () => {
      const result = await updateBookingStatusAction(bookingId, next);
      if (result.status === "error") {
        setMessage(result.message ?? "Chyba");
      }
    });
  }

  return (
    <div className="flex flex-wrap gap-2">
      {status === "PENDING" ? (
        <Button
          size="sm"
          disabled={pending}
          onClick={() => run("CONFIRMED")}
        >
          Potvrdiť
        </Button>
      ) : null}
      {status === "CONFIRMED" || status === "IN_PROGRESS" ? (
        <Button
          size="sm"
          disabled={pending}
          onClick={() => run("COMPLETED")}
        >
          Dokončiť
        </Button>
      ) : null}
      {status === "PENDING" || status === "CONFIRMED" ? (
        <Button
          size="sm"
          variant="outline"
          disabled={pending}
          onClick={() => run("CANCELLED")}
        >
          Zrušiť
        </Button>
      ) : null}
      {message ? (
        <p role="alert" className="w-full text-sm text-destructive">
          {message}
        </p>
      ) : null}
    </div>
  );
}
