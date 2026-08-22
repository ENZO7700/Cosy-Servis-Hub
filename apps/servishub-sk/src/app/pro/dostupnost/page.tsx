import type { Metadata } from "next";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { isDatabaseConfigured } from "@/lib/data/db";
import { getSessionProfile } from "@/lib/auth/session";
import { getProviderByProfileId } from "@/lib/data/providers";
import { listProviderAvailability } from "@/lib/data/availability";
import { AvailabilityForm, type AvailabilityDefaults } from "./availability-form";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Dostupnosť · ServisHub SK Pro",
};

export default async function AvailabilityPage() {
  // Layout already enforces the PROVIDER role when infra is configured;
  // profile/provider can be null during build (no env) — render empty state.
  const profile = isDatabaseConfigured() ? await getSessionProfile() : null;
  const provider = profile ? await getProviderByProfileId(profile.id) : null;
  const windows = provider ? await listProviderAvailability(provider.id) : [];

  const defaults: AvailabilityDefaults = {
    windows: Object.fromEntries(
      windows
        .filter((window) => window.isActive)
        .map((window) => [
          window.dayOfWeek,
          { startTime: window.startTime, endTime: window.endTime },
        ]),
    ),
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="text-2xl">Dostupnosť</CardTitle>
          <CardDescription>
            Nastavte týždenné okná, v ktorých vám zákazníci môžu rezervovať
            termíny.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {!isDatabaseConfigured() ? (
            <p className="text-sm text-muted-foreground">
              Dostupnosť sa dá spravovať po napojení databázy (T0 infra).
            </p>
          ) : !provider ? (
            <p className="text-sm text-muted-foreground">
              Najprv vyplňte profil profesionála na stránke Profil.
            </p>
          ) : (
            <AvailabilityForm defaults={defaults} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
