"use client";

import { useActionState } from "react";
import type { Category } from "@/generated/prisma/client";
import { saveProviderProfile, type ProviderFormState } from "./actions";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

const initialState: ProviderFormState = { status: "idle" };

export type ProviderProfileDefaults = {
  businessName: string;
  bio: string;
  ico: string;
  dic: string;
  city: string;
  postalCode: string;
  categoryIds: string[];
};

export function ProviderProfileForm({
  categories,
  defaults,
}: {
  categories: Category[];
  defaults: ProviderProfileDefaults;
}) {
  const [state, formAction, isPending] = useActionState(
    saveProviderProfile,
    initialState,
  );

  const fieldError = (field: string) =>
    state.fieldErrors?.[field]?.[0] ? (
      <p className="text-sm text-destructive">{state.fieldErrors[field][0]}</p>
    ) : null;

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
        <Label htmlFor="businessName">Názov firmy / živnosti *</Label>
        <Input
          id="businessName"
          name="businessName"
          required
          maxLength={80}
          defaultValue={defaults.businessName}
          placeholder="napr. Kováč & syn, s.r.o."
          aria-invalid={Boolean(state.fieldErrors?.businessName)}
        />
        {fieldError("businessName")}
      </div>

      <div className="space-y-2">
        <Label htmlFor="bio">O vás a vašich službách</Label>
        <Textarea
          id="bio"
          name="bio"
          rows={4}
          maxLength={1000}
          defaultValue={defaults.bio}
          placeholder="Skúsenosti, certifikáty, čím sa vyznačujete…"
          aria-invalid={Boolean(state.fieldErrors?.bio)}
        />
        {fieldError("bio")}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor="ico">IČO</Label>
          <Input
            id="ico"
            name="ico"
            inputMode="numeric"
            maxLength={8}
            defaultValue={defaults.ico}
            placeholder="12345678"
            aria-invalid={Boolean(state.fieldErrors?.ico)}
          />
          {fieldError("ico")}
        </div>
        <div className="space-y-2">
          <Label htmlFor="dic">DIČ</Label>
          <Input
            id="dic"
            name="dic"
            inputMode="numeric"
            maxLength={10}
            defaultValue={defaults.dic}
            placeholder="1234567890"
            aria-invalid={Boolean(state.fieldErrors?.dic)}
          />
          {fieldError("dic")}
        </div>
        <div className="space-y-2">
          <Label htmlFor="city">Mesto</Label>
          <Input
            id="city"
            name="city"
            maxLength={60}
            defaultValue={defaults.city}
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
            inputMode="numeric"
            maxLength={6}
            defaultValue={defaults.postalCode}
            placeholder="811 01"
            aria-invalid={Boolean(state.fieldErrors?.postalCode)}
          />
          {fieldError("postalCode")}
        </div>
      </div>

      <fieldset className="space-y-3">
        <legend className="text-sm leading-none font-medium">
          Kategórie služieb
        </legend>
        {categories.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            Kategórie sa načítajú po napojení databázy (seed).
          </p>
        ) : (
          <div className="grid gap-2 sm:grid-cols-2">
            {categories.map((category) => (
              <label
                key={category.id}
                htmlFor={`cat-${category.id}`}
                className="flex cursor-pointer items-center gap-2 rounded-lg border border-border px-3 py-2 text-sm transition-colors hover:bg-muted"
              >
                <Checkbox
                  id={`cat-${category.id}`}
                  name="categoryIds"
                  value={category.id}
                  defaultChecked={defaults.categoryIds.includes(category.id)}
                />
                {category.name}
              </label>
            ))}
          </div>
        )}
        {fieldError("categoryIds")}
      </fieldset>

      <Button type="submit" disabled={isPending}>
        {isPending ? "Ukladám…" : "Uložiť profil"}
      </Button>
    </form>
  );
}
