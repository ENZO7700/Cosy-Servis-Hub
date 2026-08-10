import type { Metadata } from "next";
import Link from "next/link";
import { SiteHeader } from "@/components/site-header";
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
import {
  formatZonedDate,
  formatZonedTime,
} from "@/lib/booking/slots";
import { isDatabaseConfigured } from "@/lib/data/db";
import { listCustomerBookings } from "@/lib/data/bookings";
import { formatEur } from "@/lib/format";
import { CancelBookingButton } from "./cancel-booking-button";
import { ReviewForm } from "./review-form";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Moje rezervácie",
};

const STATUS_LABEL: Record<string, string> = {
  PENDING: "Čaká na potvrdenie",
  CONFIRMED: "Potvrdená",
  IN_PROGRESS: "Prebieha",
  COMPLETED: "Dokončená",
  CANCELLED: "Zrušená",
  DISPUTED: "Spor",
};

export default async function MyBookingsPage() {
  const dbReady = isDatabaseConfigured();
  const profile =
    dbReady &&
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
      ? await getSessionProfile()
      : null;

  const bookings = profile ? await listCustomerBookings(profile.id) : [];

  return (
    <div className="flex min-h-full flex-col">
      <SiteHeader />
      <main className="mx-auto w-full max-w-3xl flex-1 space-y-6 px-4 py-10">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Moje rezervácie</h1>
          <p className="text-muted-foreground">
            Prehľad termínov, zrušenie a recenzie po dokončení.
          </p>
        </div>

        {!dbReady ? (
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Databáza nie je pripojená</CardTitle>
              <CardDescription>
                Rezervácie sa zobrazia po napojení DATABASE_URL (T0 infra).
              </CardDescription>
            </CardHeader>
          </Card>
        ) : !profile ? (
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Prihláste sa</CardTitle>
              <CardDescription>
                Pre zobrazenie rezervácií potrebujete účet.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Button asChild>
                <Link href="/login?next=/moje-rezervacie">Prihlásiť sa</Link>
              </Button>
            </CardContent>
          </Card>
        ) : bookings.length === 0 ? (
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Zatiaľ žiadne rezervácie</CardTitle>
              <CardDescription>
                Nájdite profesionála a rezervujte si termín.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Button asChild>
                <Link href="/hladat">Hľadať služby</Link>
              </Button>
            </CardContent>
          </Card>
        ) : (
          <ul className="space-y-4">
            {bookings.map((booking) => {
              const date = formatZonedDate(booking.scheduledAt);
              const time = formatZonedTime(booking.scheduledAt);
              const canCancel =
                booking.status === "PENDING" || booking.status === "CONFIRMED";
              const canReview = booking.status === "COMPLETED";

              return (
                <li key={booking.id}>
                  <Card>
                    <CardHeader className="flex flex-row flex-wrap items-start justify-between gap-3 space-y-0">
                      <div className="space-y-1">
                        <CardTitle className="text-base">
                          {booking.service?.title ?? "Služba"}
                        </CardTitle>
                        <CardDescription>
                          <Link
                            href={`/p/${booking.provider.slug}`}
                            className="text-primary underline-offset-4 hover:underline"
                          >
                            {booking.provider.businessName}
                          </Link>
                          {" · "}
                          {date} · {time}
                          {booking.priceAmount != null
                            ? ` · ${formatEur(Number(booking.priceAmount))}`
                            : ""}
                        </CardDescription>
                      </div>
                      <Badge variant="secondary">
                        {STATUS_LABEL[booking.status] ?? booking.status}
                      </Badge>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      {booking.addressLine || booking.city ? (
                        <p className="text-sm text-muted-foreground">
                          {[booking.addressLine, booking.city, booking.postalCode]
                            .filter(Boolean)
                            .join(", ")}
                        </p>
                      ) : null}
                      {canCancel ? (
                        <CancelBookingButton bookingId={booking.id} />
                      ) : null}
                      {canReview ? (
                        <div className="border-t border-border pt-4">
                          <ReviewForm
                            bookingId={booking.id}
                            providerSlug={booking.provider.slug}
                          />
                        </div>
                      ) : null}
                      {canReview ? (
                        <Button variant="outline" size="sm" asChild>
                          <Link href={`/p/${booking.provider.slug}/recenzia?booking=${booking.id}`}>
                            Recenzia na profile
                          </Link>
                        </Button>
                      ) : null}
                    </CardContent>
                  </Card>
                </li>
              );
            })}
          </ul>
        )}
      </main>
    </div>
  );
}
