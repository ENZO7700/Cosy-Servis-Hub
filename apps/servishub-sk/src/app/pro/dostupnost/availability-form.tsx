"use client";

import { useActionState } from "react";
import { saveAvailability, type AvailabilityFormState } from "./actions";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";

const initialState: AvailabilityFormState = { status: "idle" };

export type AvailabilityDefaults = {
  /** Map dayOfWeek (0=Sunday … 6=Saturday) → first window of that day. */
  windows: Record<number, { startTime: string; endTime: string } | undefined>;
};

// Slovak week starts on Monday.
const DAY_ROWS = [
  { dayOfWeek: 1, label: "Pondelok" },
  { dayOfWeek: 2, label: "Utorok" },
  { dayOfWeek: 3, label: "Streda" },
  { dayOfWeek: 4, label: "Štvrtok" },
  { dayOfWeek: 5, label: "Piatok" },
  { dayOfWeek: 6, label: "Sobota" },
  { dayOfWeek: 0, label: "Nedeľa" },
] as const;

export function AvailabilityForm({ defaults }: { defaults: AvailabilityDefaults }) {
  const [state, formAction, isPending] = useActionState(
    saveAvailability,
    initialState,
  );

  return (
    <form action={formAction} className="space-y-6">
      {state.message ? (
        <div
          role="status"
          className={
            state.status === "success"
              ? "rounded-lg border border-primary/30 bg-primary/10 px-4 py-3 text-sm text-foreground"
              : "rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-foreground"
          }
        >
          {state.message}
        </div>
      ) : null}

      <div className="space-y-2">
        {DAY_ROWS.map(({ dayOfWeek, label }) => {
          const window = defaults.windows[dayOfWeek];
          return (
            <div
              key={dayOfWeek}
              className="flex flex-wrap items-center gap-3 rounded-lg border border-border px-3 py-2"
            >
              <label
                htmlFor={`day-${dayOfWeek}-enabled`}
                className="flex w-32 cursor-pointer items-center gap-2 text-sm font-medium"
              >
                <Checkbox
                  id={`day-${dayOfWeek}-enabled`}
                  name={`day-${dayOfWeek}-enabled`}
                  defaultChecked={Boolean(window)}
                />
                {label}
              </label>
              <div className="flex items-center gap-2">
                <Input
                  type="time"
                  name={`day-${dayOfWeek}-start`}
                  defaultValue={window?.startTime ?? "08:00"}
                  aria-label={`${label} — od`}
                  className="w-28"
                  step={900}
                />
                <span className="text-sm text-muted-foreground">–</span>
                <Input
                  type="time"
                  name={`day-${dayOfWeek}-end`}
                  defaultValue={window?.endTime ?? "17:00"}
                  aria-label={`${label} — do`}
                  className="w-28"
                  step={900}
                />
              </div>
            </div>
          );
        })}
      </div>

      <p className="text-sm text-muted-foreground">
        Zákazníci si budú môcť rezervovať termíny len v týchto oknách
        (čas Europe/Bratislava). Jedno okno na deň; výnimky a prestávky prídu
        v ďalšej verzii.
      </p>

      <Button type="submit" disabled={isPending}>
        {isPending ? "Ukladám…" : "Uložiť dostupnosť"}
      </Button>
    </form>
  );
}
