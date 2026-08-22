"use client";

import { useActionState } from "react";
import Link from "next/link";
import type { Category } from "@/generated/prisma/client";
import { saveService, type ServiceFormState } from "./actions";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";

const initialState: ServiceFormState = { status: "idle" };

export type ServiceFormDefaults = {
  serviceId: string | null;
  title: string;
  description: string;
  categoryId: string;
  priceFrom: string;
  priceTo: string;
  durationMin: string;
  isActive: boolean;
};

export function ServiceForm({
  categories,
  defaults,
}: {
  categories: Category[];
  defaults: ServiceFormDefaults;
}) {
  const [state, formAction, isPending] = useActionState(
    saveService,
    initialState,
  );

  const fieldError = (field: string) =>
    state.fieldErrors?.[field]?.[0] ? (
      <p className="text-sm text-destructive">{state.fieldErrors[field][0]}</p>
    ) : null;

  return (
    <form action={formAction} className="space-y-6">
      {defaults.serviceId ? (
        <input type="hidden" name="serviceId" value={defaults.serviceId} />
      ) : null}

      {state.message ? (
        <div
          role="alert"
          className="rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-foreground"
        >
          {state.message}
        </div>
      ) : null}

      <div className="space-y-2">
        <Label htmlFor="title">Názov služby *</Label>
        <Input
          id="title"
          name="title"
          required
          maxLength={80}
          defaultValue={defaults.title}
          placeholder="napr. Upratovanie bytu"
          aria-invalid={Boolean(state.fieldErrors?.title)}
        />
        {fieldError("title")}
      </div>

      <div className="space-y-2">
        <Label htmlFor="description">Popis</Label>
        <Textarea
          id="description"
          name="description"
          rows={4}
          maxLength={2000}
          defaultValue={defaults.description}
          placeholder="Čo služba obsahuje, čo si má zákazník pripraviť…"
          aria-invalid={Boolean(state.fieldErrors?.description)}
        />
        {fieldError("description")}
      </div>

      <div className="space-y-2">
        <Label htmlFor="categoryId">Kategória *</Label>
        <Select
          id="categoryId"
          name="categoryId"
          required
          defaultValue={defaults.categoryId}
          aria-invalid={Boolean(state.fieldErrors?.categoryId)}
        >
          <option value="" disabled>
            Vyberte kategóriu
          </option>
          {categories.map((category) => (
            <option key={category.id} value={category.id}>
              {category.name}
            </option>
          ))}
        </Select>
        {categories.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            Kategórie sa načítajú po napojení databázy (seed).
          </p>
        ) : null}
        {fieldError("categoryId")}
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div className="space-y-2">
          <Label htmlFor="priceFrom">Cena od (€)</Label>
          <Input
            id="priceFrom"
            name="priceFrom"
            type="number"
            inputMode="decimal"
            min={0}
            step="0.01"
            defaultValue={defaults.priceFrom}
            placeholder="25"
            aria-invalid={Boolean(state.fieldErrors?.priceFrom)}
          />
          {fieldError("priceFrom")}
        </div>
        <div className="space-y-2">
          <Label htmlFor="priceTo">Cena do (€)</Label>
          <Input
            id="priceTo"
            name="priceTo"
            type="number"
            inputMode="decimal"
            min={0}
            step="0.01"
            defaultValue={defaults.priceTo}
            placeholder="60"
            aria-invalid={Boolean(state.fieldErrors?.priceTo)}
          />
          {fieldError("priceTo")}
        </div>
        <div className="space-y-2">
          <Label htmlFor="durationMin">Trvanie (min)</Label>
          <Input
            id="durationMin"
            name="durationMin"
            type="number"
            inputMode="numeric"
            min={15}
            step={15}
            defaultValue={defaults.durationMin}
            placeholder="120"
            aria-invalid={Boolean(state.fieldErrors?.durationMin)}
          />
          {fieldError("durationMin")}
        </div>
      </div>

      <label
        htmlFor="isActive"
        className="flex cursor-pointer items-center gap-2 text-sm"
      >
        <Checkbox
          id="isActive"
          name="isActive"
          defaultChecked={defaults.isActive}
        />
        Služba je aktívna (viditeľná vo vyhľadávaní)
      </label>

      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" disabled={isPending}>
          {isPending ? "Ukladám…" : "Uložiť službu"}
        </Button>
        <Button variant="ghost" asChild>
          <Link href="/pro/sluzby">Späť na zoznam</Link>
        </Button>
      </div>
    </form>
  );
}
