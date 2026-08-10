"use client";

import { useActionState, useEffect, useState, useTransition } from "react";
import Link from "next/link";
import { sk } from "react-day-picker/locale";
import {
  createBooking,
  getAvailableSlots,
  type BookingFormState,
  type SerializedSlot,
} from "./actions";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

const initialState: BookingFormState = { status: "idle" };

export type BookableServiceOption = {
  id: string;
  title: string;
  durationMin: number | null;
  priceLabel: string;
};

function toDateString(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function BookingSection({
  providerId,
  providerSlug,
  services,
}: {
  providerId: string;
  providerSlug: string;
  services: BookableServiceOption[];
}) {
  const [serviceId, setServiceId] = useState(services[0]?.id ?? "");
  const [date, setDate] = useState<string | null>(null);
  const [slots, setSlots] = useState<SerializedSlot[]>([]);
  const [selectedSlot, setSelectedSlot] = useState<string | null>(null);
  const [slotsPending, startSlotsTransition] = useTransition();
  const [state, formAction, isPending] = useActionState(
    createBooking,
    initialState,
  );

  const selectedService = services.find((service) => service.id === serviceId);

  useEffect(() => {
    if (!date || !serviceId) return;
    let cancelled = false;
    startSlotsTransition(async () => {
      const result = await getAvailableSlots(providerId, serviceId, date);
      if (!cancelled) setSlots(result);
    });
    return () => {
      cancelled = true;
    };
  }, [date, serviceId, providerId]);

  if (services.length === 0) {
    return null;
  }

  if (state.status === "success" && state.summary) {
    return (
      <div className="space-y-3 rounded-lg border border-primary/30 bg-primary/10 px-4 py-4">
        <p className="font-medium text-foreground">{state.message}</p>
        <p className="text-sm text-muted-foreground">
          {state.summary.serviceTitle} · {state.summary.date} ·{" "}
          {state.summary.timeRange}
        </p>
        <Button variant="outline" size="sm" asChild>
          <Link href="/moje-rezervacie">Zobraziť moje rezervácie</Link>
        </Button>
      </div>
    );
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const horizon = new Date(today);
  horizon.setDate(horizon.getDate() + 60);

  const fieldError = (field: string) =>
    state.fieldErrors?.[field]?.[0] ? (
      <p className="text-sm text-destructive">{state.fieldErrors[field][0]}</p>
    ) : null;

  return (
    <div className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="booking-service">Služba</Label>
        <select
          id="booking-service"
          value={serviceId}
          onChange={(event) => {
            setServiceId(event.target.value);
            setSelectedSlot(null);
            setSlots([]);
          }}
          className="border-input bg-background focus-visible:border-ring focus-visible:ring-ring/50 flex h-9 w-full rounded-md border px-3 text-sm shadow-xs outline-none focus-visible:ring-[3px]"
        >
          {services.map((service) => (
            <option key={service.id} value={service.id}>
              {service.title}
              {service.durationMin ? ` (${service.durationMin} min)` : ""} ·{" "}
              {service.priceLabel}
            </option>
          ))}
        </select>
      </div>

      <div className="space-y-2">
        <Label>Dátum</Label>
        <Calendar
          mode="single"
          locale={sk}
          selected={date ? new Date(`${date}T12:00:00`) : undefined}
          onSelect={(selected) => {
            setSelectedSlot(null);
            setSlots([]);
            setDate(selected ? toDateString(selected) : null);
          }}
          disabled={{ before: today, after: horizon }}
          className="rounded-lg border border-border"
        />
      </div>

      {date ? (
        <div className="space-y-2">
          <Label>Voľné termíny</Label>
          {slotsPending ? (
            <p className="text-sm text-muted-foreground">Načítavam termíny…</p>
          ) : slots.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              V tento deň nie sú k dispozícii žiadne termíny.
            </p>
          ) : (
            <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
              {slots.map((slot) => {
                const value = slot.startTime;
                const isSelected = selectedSlot === value;
                return (
                  <Button
                    key={value}
                    type="button"
                    variant={isSelected ? "default" : "outline"}
                    size="sm"
                    disabled={!slot.isAvailable}
                    onClick={() => setSelectedSlot(value)}
                  >
                    {slot.startTime}
                  </Button>
                );
              })}
            </div>
          )}
        </div>
      ) : null}

      {date && selectedSlot && selectedService ? (
        <form action={formAction} className="space-y-4 border-t border-border pt-4">
          <input type="hidden" name="providerId" value={providerId} />
          <input type="hidden" name="slug" value={providerSlug} />
          <input type="hidden" name="serviceId" value={serviceId} />
          <input type="hidden" name="date" value={date} />
          <input type="hidden" name="startTime" value={selectedSlot} />

          {state.message ? (
            <div
              role="status"
              className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-foreground"
            >
              {state.message}{" "}
              {state.code === "UNAUTHENTICATED" ? (
                <Link
                  href={`/login?next=/p/${providerSlug}`}
                  className="font-medium text-primary underline-offset-4 hover:underline"
                >
                  Prihlásiť sa
                </Link>
              ) : null}
            </div>
          ) : null}

          <p className="text-sm font-medium">
            {selectedService.title} · {date} · {selectedSlot}
          </p>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="addressLine">Adresa realizácie</Label>
              <Input
                id="addressLine"
                name="addressLine"
                maxLength={120}
                placeholder="Ulica a číslo"
                aria-invalid={Boolean(state.fieldErrors?.addressLine)}
              />
              {fieldError("addressLine")}
            </div>
            <div className="space-y-2">
              <Label htmlFor="city">Mesto</Label>
              <Input
                id="city"
                name="city"
                maxLength={60}
                placeholder="Bratislava"
                aria-invalid={Boolean(state.fieldErrors?.city)}
              />
              {fieldError("city")}
            </div>
            <div className="space-y-2">
              <Label htmlFor="postalCode">PSČ</Label>
              <Input
                id="postalCode"
                name="postalCode"
                maxLength={10}
                inputMode="numeric"
                placeholder="811 01"
                aria-invalid={Boolean(state.fieldErrors?.postalCode)}
              />
              {fieldError("postalCode")}
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="notes">Poznámka pre profesionála</Label>
            <Textarea
              id="notes"
              name="notes"
              rows={3}
              maxLength={1000}
              placeholder="Rozsah prác, prístup, špeciálne požiadavky…"
              aria-invalid={Boolean(state.fieldErrors?.notes)}
            />
            {fieldError("notes")}
          </div>

          <Button type="submit" disabled={isPending}>
            {isPending ? "Rezervujem…" : "Odoslať rezerváciu"}
          </Button>
        </form>
      ) : null}
    </div>
  );
}
