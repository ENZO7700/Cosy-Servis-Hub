import type { Metadata } from "next";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { SiteHeader } from "@/components/site-header";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ReviewForm } from "@/app/(customer)/moje-rezervacie/review-form";
import { getSessionProfile } from "@/lib/auth/session";
import { isDatabaseConfigured, safeDb } from "@/lib/data/db";
import { getPublicProviderBySlug } from "@/lib/data/providers";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

type PageParams = Promise<{ slug: string }>;
type SearchParams = Promise<{ booking?: string }>;

export async function generateMetadata({
  params,
}: {
  params: PageParams;
}): Promise<Metadata> {
  const { slug } = await params;
  const provider = await getPublicProviderBySlug(slug);
  return {
    title: provider
      ? `Recenzia · ${provider.businessName}`
      : "Recenzia",
  };
}

export default async function ProviderReviewPage({
  params,
  searchParams,
}: {
  params: PageParams;
  searchParams: SearchParams;
}) {
  const { slug } = await params;
  const { booking: bookingId } = await searchParams;
  const dbReady = isDatabaseConfigured();

  if (!dbReady) {
    return (
      <div className="flex min-h-full flex-col">
        <SiteHeader />
        <main className="mx-auto w-full max-w-lg flex-1 px-4 py-10">
          <Card>
            <CardHeader>
              <CardTitle>Recenzie nedostupné</CardTitle>
              <CardDescription>
                Databáza ešte nie je napojená (T0 infra).
              </CardDescription>
            </CardHeader>
          </Card>
        </main>
      </div>
    );
  }

  const provider = await getPublicProviderBySlug(slug);
  if (!provider) notFound();

  const profile = await getSessionProfile();
  if (!profile) {
    redirect(`/login?next=${encodeURIComponent(`/p/${slug}/recenzia${bookingId ? `?booking=${bookingId}` : ""}`)}`);
  }

  const eligibleBooking = await safeDb(async () => {
    if (bookingId) {
      return prisma.booking.findFirst({
        where: {
          id: bookingId,
          customerId: profile.id,
          providerId: provider.id,
          status: "COMPLETED",
          review: null,
        },
        select: { id: true },
      });
    }
    return prisma.booking.findFirst({
      where: {
        customerId: profile.id,
        providerId: provider.id,
        status: "COMPLETED",
        review: null,
      },
      orderBy: { scheduledAt: "desc" },
      select: { id: true },
    });
  }, null);

  return (
    <div className="flex min-h-full flex-col">
      <SiteHeader />
      <main className="mx-auto w-full max-w-lg flex-1 space-y-6 px-4 py-10">
        <Card>
          <CardHeader>
            <CardTitle>Recenzia · {provider.businessName}</CardTitle>
            <CardDescription>
              Ohodnoťte dokončenú službu. Recenzia aktualizuje priemerné
              hodnotenie profesionála.
            </CardDescription>
          </CardHeader>
          <CardContent>
            {eligibleBooking ? (
              <ReviewForm
                bookingId={eligibleBooking.id}
                providerSlug={provider.slug}
              />
            ) : (
              <div className="space-y-3">
                <p className="text-sm text-muted-foreground">
                  Nemáte dokončenú rezerváciu bez recenzie u tohto
                  profesionála.
                </p>
                <Button variant="outline" asChild>
                  <Link href="/moje-rezervacie">Moje rezervácie</Link>
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
