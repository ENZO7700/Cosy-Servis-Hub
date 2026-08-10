import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { isDatabaseConfigured } from "@/lib/data/db";
import { getPublicProviderBySlug, type PublicProvider } from "@/lib/data/providers";
import { formatEur, formatRating } from "@/lib/format";
import { BookingSection } from "./booking-section";

export const dynamic = "force-dynamic";

type PageParams = Promise<{ slug: string }>;

function appUrl(): string {
  return process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
}

export async function generateMetadata({
  params,
}: {
  params: PageParams;
}): Promise<Metadata> {
  const { slug } = await params;
  const provider = await getPublicProviderBySlug(slug);

  if (!provider) {
    return { title: "Profesionál" };
  }

  const description =
    provider.bio?.slice(0, 160) ??
    `${provider.businessName} — ${provider.city ?? "Slovensko"}. Overený profesionál na ServisHub SK.`;

  return {
    title: provider.businessName,
    description,
    alternates: { canonical: `/p/${provider.slug}` },
    openGraph: {
      title: `${provider.businessName} · ServisHub SK`,
      description,
      type: "profile",
      locale: "sk_SK",
      url: `${appUrl()}/p/${provider.slug}`,
    },
  };
}

function localBusinessJsonLd(provider: PublicProvider) {
  return {
    "@context": "https://schema.org",
    "@type": "LocalBusiness",
    name: provider.businessName,
    url: `${appUrl()}/p/${provider.slug}`,
    ...(provider.bio ? { description: provider.bio } : {}),
    ...(provider.city
      ? {
          address: {
            "@type": "PostalAddress",
            addressLocality: provider.city,
            ...(provider.postalCode ? { postalCode: provider.postalCode } : {}),
            addressCountry: "SK",
          },
        }
      : {}),
    ...(provider.ratingCount > 0
      ? {
          aggregateRating: {
            "@type": "AggregateRating",
            ratingValue: provider.ratingAvg,
            reviewCount: provider.ratingCount,
          },
        }
      : {}),
    makesOffer: provider.services.map((service) => ({
      "@type": "Offer",
      name: service.title,
      category: service.category.name,
      ...(service.priceFrom !== null
        ? {
            priceSpecification: {
              "@type": "PriceSpecification",
              price: Number(service.priceFrom),
              priceCurrency: service.currency,
            },
          }
        : {}),
    })),
  };
}

export default async function ProviderPublicPage({
  params,
}: {
  params: PageParams;
}) {
  const { slug } = await params;
  const dbReady = isDatabaseConfigured();
  const provider = await getPublicProviderBySlug(slug);

  if (!provider) {
    // With a live DB a missing slug is a real 404; without DB we cannot know.
    if (dbReady) notFound();

    return (
      <div className="flex min-h-full flex-col">
        <SiteHeader />
        <main className="mx-auto flex w-full max-w-3xl flex-1 items-center px-4 py-12">
          <Card className="w-full border-secondary/50">
            <CardHeader>
              <CardTitle className="text-base">
                Profil je dočasne nedostupný
              </CardTitle>
              <CardDescription>
                Katalóg profesionálov sa načíta po napojení databázy. Skúste
                to neskôr alebo prejdite na{" "}
                <Link
                  href="/hladat"
                  className="text-primary underline-offset-4 hover:underline"
                >
                  vyhľadávanie
                </Link>
                .
              </CardDescription>
            </CardHeader>
          </Card>
        </main>
      </div>
    );
  }

  const jsonLd = JSON.stringify(localBusinessJsonLd(provider)).replace(
    /</g,
    "\\u003c",
  );

  return (
    <div className="flex min-h-full flex-col">
      <SiteHeader />
      <main className="mx-auto w-full max-w-4xl flex-1 space-y-6 px-4 py-10">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: jsonLd }}
        />

        <Card>
          <CardHeader>
            <div className="flex flex-wrap items-center gap-2">
              <CardTitle className="text-2xl">{provider.businessName}</CardTitle>
              {provider.verificationStatus === "VERIFIED" ? (
                <Badge>Overený</Badge>
              ) : null}
              <Badge variant="secondary">
                {formatRating(provider.ratingAvg, provider.ratingCount)}
              </Badge>
            </div>
            <CardDescription>
              {provider.city ?? "Slovensko"}
              {provider.postalCode ? ` · ${provider.postalCode}` : ""}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {provider.categories.length > 0 ? (
              <div className="flex flex-wrap gap-1.5">
                {provider.categories.map((category) => (
                  <Badge key={category.id} variant="outline">
                    {category.name}
                  </Badge>
                ))}
              </div>
            ) : null}
            {provider.bio ? (
              <p className="text-sm whitespace-pre-line text-muted-foreground">
                {provider.bio}
              </p>
            ) : null}
          </CardContent>
        </Card>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold tracking-tight">
            Rezervovať termín
          </h2>
          <Card>
            <CardContent className="pt-6">
              {dbReady && provider.services.length > 0 ? (
                <BookingSection
                  providerId={provider.id}
                  providerSlug={provider.slug}
                  services={provider.services.map((service) => ({
                    id: service.id,
                    title: service.title,
                    durationMin: service.durationMin,
                    priceLabel:
                      service.priceFrom !== null
                        ? `od ${formatEur(Number(service.priceFrom))}`
                        : "Cena dohodou",
                  }))}
                />
              ) : (
                <p className="text-sm text-muted-foreground">
                  {dbReady
                    ? "Profesionál zatiaľ nemá služby, ktoré by sa dali rezervovať."
                    : "Rezervácie budú dostupné po napojení databázy."}
                </p>
              )}
            </CardContent>
          </Card>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold tracking-tight">Služby a cenník</h2>
          {provider.services.length === 0 ? (
            <Card>
              <CardHeader>
                <CardDescription>
                  Profesionál zatiaľ nemá zverejnené žiadne služby.
                </CardDescription>
              </CardHeader>
            </Card>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2">
              {provider.services.map((service) => (
                <Card key={service.id}>
                  <CardHeader>
                    <div className="flex items-center justify-between gap-2">
                      <CardTitle className="text-base">{service.title}</CardTitle>
                      <Badge variant="outline">{service.category.name}</Badge>
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
                      <p className="text-sm text-muted-foreground">
                        {service.description}
                      </p>
                    </CardContent>
                  ) : null}
                </Card>
              ))}
            </div>
          )}
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold tracking-tight">Recenzie</h2>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">
                {formatRating(provider.ratingAvg, provider.ratingCount)}
              </CardTitle>
              <CardDescription>
                {provider.ratingCount === 0
                  ? "Zatiaľ žiadne recenzie — po dokončenej rezervácii môžete pridať hodnotenie."
                  : "Priemerné hodnotenie z dokončených rezervácií."}
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Link
                href={`/p/${provider.slug}/recenzia`}
                className="text-sm text-primary underline-offset-4 hover:underline"
              >
                Napísať recenziu
              </Link>
            </CardContent>
          </Card>
        </section>
      </main>
    </div>
  );
}
