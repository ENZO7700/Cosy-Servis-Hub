import type { Metadata } from "next";
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
import {
  ProviderProfileForm,
  type ProviderProfileDefaults,
} from "./provider-profile-form";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Profil profesionála",
};

const emptyDefaults: ProviderProfileDefaults = {
  businessName: "",
  bio: "",
  ico: "",
  dic: "",
  city: "",
  postalCode: "",
  categoryIds: [],
};

export default async function ProProfilePage() {
  const dbReady = isDatabaseConfigured();

  const [categories, profile] = await Promise.all([
    listCategories(),
    dbReady ? getSessionProfile() : Promise.resolve(null),
  ]);
  const provider = profile ? await getProviderByProfileId(profile.id) : null;

  const defaults: ProviderProfileDefaults = provider
    ? {
        businessName: provider.businessName,
        bio: provider.bio ?? "",
        ico: provider.ico ?? "",
        dic: provider.dic ?? "",
        city: provider.city ?? "",
        postalCode: provider.postalCode ?? "",
        categoryIds: provider.categories.map((category) => category.id),
      }
    : emptyDefaults;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Profil profesionála</h1>
        <p className="text-muted-foreground">
          Základné údaje, ktoré uvidia zákazníci vo vyhľadávaní a na verejnom
          profile.
        </p>
      </div>

      {!dbReady ? (
        <Card className="border-secondary/50">
          <CardHeader>
            <CardTitle className="text-base">Databáza nie je nakonfigurovaná</CardTitle>
            <CardDescription>
              Formulár je pripravený, ale uloženie bude fungovať až po napojení
              Supabase/Postgres (DATABASE_URL) — pozri docs/T0-INFRA.md.
            </CardDescription>
          </CardHeader>
        </Card>
      ) : null}

      <Card>
        <CardHeader>
          <CardTitle className="text-lg">
            {provider ? "Upraviť profil" : "Vytvoriť profil"}
          </CardTitle>
          <CardDescription>
            {provider
              ? `Verejný profil: /p/${provider.slug}`
              : "Po uložení vznikne vaša verejná stránka a môžete pridať služby."}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ProviderProfileForm categories={categories} defaults={defaults} />
        </CardContent>
      </Card>
    </div>
  );
}
