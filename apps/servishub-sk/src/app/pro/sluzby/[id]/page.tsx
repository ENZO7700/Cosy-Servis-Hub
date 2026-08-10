import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { getSessionProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { listCategories } from "@/lib/data/categories";
import { getProviderByProfileId } from "@/lib/data/providers";
import { getProviderService } from "@/lib/data/services";
import { ServiceForm, type ServiceFormDefaults } from "../service-form";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Upraviť službu",
};

export default async function EditServicePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const dbReady = isDatabaseConfigured();

  if (!dbReady) {
    return (
      <Card className="border-secondary/50">
        <CardHeader>
          <CardTitle className="text-base">Databáza nie je nakonfigurovaná</CardTitle>
          <CardDescription>
            Úprava služby bude dostupná po napojení Supabase/Postgres
            (DATABASE_URL) — pozri docs/T0-INFRA.md.
          </CardDescription>
        </CardHeader>
      </Card>
    );
  }

  const profile = await getSessionProfile();
  const provider = profile ? await getProviderByProfileId(profile.id) : null;

  if (profile && !provider) {
    return (
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
    );
  }

  const service = provider ? await getProviderService(provider.id, id) : null;
  if (provider && !service) {
    notFound();
  }

  const categories = await listCategories();

  const defaults: ServiceFormDefaults = service
    ? {
        serviceId: service.id,
        title: service.title,
        description: service.description ?? "",
        categoryId: service.categoryId,
        priceFrom: service.priceFrom !== null ? String(service.priceFrom) : "",
        priceTo: service.priceTo !== null ? String(service.priceTo) : "",
        durationMin:
          service.durationMin !== null ? String(service.durationMin) : "",
        isActive: service.isActive,
      }
    : {
        serviceId: id,
        title: "",
        description: "",
        categoryId: "",
        priceFrom: "",
        priceTo: "",
        durationMin: "",
        isActive: true,
      };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Upraviť službu</h1>
        <p className="text-muted-foreground">
          Zmeny sa po uložení prejavia vo vyhľadávaní a na verejnom profile.
        </p>
      </div>
      <Card>
        <CardContent>
          <ServiceForm categories={categories} defaults={defaults} />
        </CardContent>
      </Card>
    </div>
  );
}
