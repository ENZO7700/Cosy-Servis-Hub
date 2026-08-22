import type { Metadata } from "next";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { getSessionProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { getProviderByProfileId } from "@/lib/data/providers";
import { listProviderServices } from "@/lib/data/services";
import { formatEur } from "@/lib/format";
import { deactivateServiceAction } from "./actions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Moje služby",
};

export default async function ProServicesPage() {
  const dbReady = isDatabaseConfigured();
  const profile = dbReady ? await getSessionProfile() : null;
  const provider = profile ? await getProviderByProfileId(profile.id) : null;
  const services = provider ? await listProviderServices(provider.id) : [];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Moje služby</h1>
          <p className="text-muted-foreground">
            Cenník služieb, ktoré uvidia zákazníci vo vyhľadávaní.
          </p>
        </div>
        {provider ? (
          <Button asChild>
            <Link href="/pro/sluzby/nova">Nová služba</Link>
          </Button>
        ) : null}
      </div>

      {!dbReady ? (
        <Card className="border-secondary/50">
          <CardHeader>
            <CardTitle className="text-base">Databáza nie je nakonfigurovaná</CardTitle>
            <CardDescription>
              Zoznam služieb sa zobrazí po napojení Supabase/Postgres
              (DATABASE_URL) — pozri docs/T0-INFRA.md.
            </CardDescription>
          </CardHeader>
        </Card>
      ) : !provider ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Najprv vytvorte profil</CardTitle>
            <CardDescription>
              Služby sa viažu na profil profesionála.{" "}
              <Link
                href="/pro/profil"
                className="text-primary underline-offset-4 hover:underline"
              >
                Vyplniť profil
              </Link>
            </CardDescription>
          </CardHeader>
        </Card>
      ) : services.length === 0 ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Zatiaľ žiadne služby</CardTitle>
            <CardDescription>
              Pridajte prvú službu, aby vás zákazníci našli vo vyhľadávaní.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button asChild>
              <Link href="/pro/sluzby/nova">Pridať službu</Link>
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-4">
          {services.map((service) => (
            <Card key={service.id}>
              <CardHeader>
                <div className="flex flex-wrap items-center gap-2">
                  <CardTitle className="text-base">{service.title}</CardTitle>
                  <Badge variant="secondary">{service.category.name}</Badge>
                  {service.isActive ? (
                    <Badge>Aktívna</Badge>
                  ) : (
                    <Badge variant="outline">Neaktívna</Badge>
                  )}
                </div>
                <CardDescription>
                  {service.priceFrom !== null
                    ? `od ${formatEur(Number(service.priceFrom))}`
                    : "Cena dohodou"}
                  {service.priceTo !== null
                    ? ` – ${formatEur(Number(service.priceTo))}`
                    : ""}
                  {service.durationMin !== null
                    ? ` · ${service.durationMin} min`
                    : ""}
                </CardDescription>
              </CardHeader>
              {service.description ? (
                <CardContent>
                  <p className="line-clamp-2 text-sm text-muted-foreground">
                    {service.description}
                  </p>
                </CardContent>
              ) : null}
              <CardContent className="flex flex-wrap gap-2 pt-0">
                <Button variant="outline" size="sm" asChild>
                  <Link href={`/pro/sluzby/${service.id}`}>Upraviť</Link>
                </Button>
                {service.isActive ? (
                  <form action={deactivateServiceAction.bind(null, service.id)}>
                    <Button variant="ghost" size="sm" type="submit">
                      Deaktivovať
                    </Button>
                  </form>
                ) : null}
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
