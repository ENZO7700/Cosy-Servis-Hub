"use client";

import { useActionState } from "react";
import { submitReview, type ReviewFormState } from "@/lib/reviews/actions";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

const initialState: ReviewFormState = { status: "idle" };

export function ReviewForm({
  bookingId,
  providerSlug,
}: {
  bookingId: string;
  providerSlug: string;
}) {
  const [state, formAction, isPending] = useActionState(
    submitReview,
    initialState,
  );

  if (state.status === "success") {
    return (
      <p role="status" className="text-sm text-primary">
        {state.message ?? "Ďakujeme za recenziu."}
      </p>
    );
  }

  return (
    <form action={formAction} className="space-y-3">
      <input type="hidden" name="bookingId" value={bookingId} />
      <input type="hidden" name="providerSlug" value={providerSlug} />
      <div className="space-y-2">
        <Label htmlFor={`rating-${bookingId}`}>Hodnotenie</Label>
        <select
          id={`rating-${bookingId}`}
          name="rating"
          required
          defaultValue="5"
          className="border-input bg-background flex h-9 w-full max-w-[10rem] rounded-md border px-3 text-sm"
        >
          {[5, 4, 3, 2, 1].map((value) => (
            <option key={value} value={value}>
              {value} ★
            </option>
          ))}
        </select>
      </div>
      <div className="space-y-2">
        <Label htmlFor={`comment-${bookingId}`}>Komentár (voliteľné)</Label>
        <Textarea
          id={`comment-${bookingId}`}
          name="comment"
          rows={3}
          maxLength={1000}
          placeholder="Ako prebehla služba?"
        />
      </div>
      {state.message ? (
        <p role="alert" className="text-sm text-destructive">
          {state.message}
        </p>
      ) : null}
      <Button type="submit" size="sm" disabled={isPending}>
        {isPending ? "Odosielam…" : "Odoslať recenziu"}
      </Button>
    </form>
  );
}
