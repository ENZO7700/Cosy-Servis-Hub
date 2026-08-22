import type { Metadata } from "next";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { getSessionProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { getProviderByProfileId } from "@/lib/data/providers";
import { ConnectOnboardingButton } from "./connect-button";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Platby · ServisHub SK Pro",
};

export default async function ProviderPaymentsPage() {
  const profile = isDatabaseConfigured() ? await getSessionProfile() : null;
  const provider = profile ? await getProviderByProfileId(profile.id) : null;
  const stripeReady = Boolean(process.env.STRIPE_SECRET_KEY);

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="text-2xl">Platby · Stripe Connect</CardTitle>
          <CardDescription>
            Prepojte Express účet, aby ste mohli prijímať platby za rezervácie.
            Platforma si ponechá províziu (COMMISSION_PERCENT, predvolene 15 %).
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {!isDatabaseConfigured() ? (
            <p className="text-sm text-muted-foreground">
              Platby budú dostupné po napojení databázy.
            </p>
          ) : !provider ? (
            <p className="text-sm text-muted-foreground">
              Najprv vyplňte profil profesionála.
            </p>
          ) : (
            <>
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-sm text-muted-foreground">Stav:</span>
                {provider.stripeAccountId ? (
                  <Badge>Connect prepojený</Badge>
                ) : (
                  <Badge variant="secondary">Neprepojené</Badge>
                )}
                {!stripeReady ? (
                  <Badge variant="outline">STRIPE_SECRET_KEY chýba</Badge>
                ) : null}
              </div>
              {provider.stripeAccountId ? (
                <p className="text-sm text-muted-foreground">
                  Account ID:{" "}
                  <code className="text-xs">{provider.stripeAccountId}</code>
                </p>
              ) : null}
              <ConnectOnboardingButton
                disabled={!stripeReady}
                hasAccount={Boolean(provider.stripeAccountId)}
              />
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
