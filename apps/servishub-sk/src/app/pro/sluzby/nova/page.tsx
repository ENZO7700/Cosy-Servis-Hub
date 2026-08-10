import type { Metadata } from "next";
import Link from "next/link";
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
import { ServiceForm, type ServiceFormDefaults } from "../service-form";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Nová služba",
};

const createDefaults: ServiceFormDefaults = {
  serviceId: null,
  title: "",
  description: "",
  categoryId: "",
  priceFrom: "",
  priceTo: "",
  durationMin: "",
  isActive: true,
};

export default async function NewServicePage() {
  const dbReady = isDatabaseConfigured();
  const [categories, profile] = await Promise.all([
    listCategories(),
    dbReady ? getSessionProfile() : Promise.resolve(null),
  ]);
  const provider = profile ? await getProviderByProfileId(profile.id) : null;

  if (dbReady && profile && !provider) {
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

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Nová služba</h1>
        <p className="text-muted-foreground">
          Služba sa po uložení zobrazí vo vyhľadávaní a na verejnom profile.
        </p>
      </div>
      <Card>
        <CardContent>
          <ServiceForm categories={categories} defaults={createDefaults} />
        </CardContent>
      </Card>
    </div>
  );
}
