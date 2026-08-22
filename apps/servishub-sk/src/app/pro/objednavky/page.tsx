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
import {
  formatZonedDate,
  formatZonedTime,
} from "@/lib/booking/slots";
import { isDatabaseConfigured } from "@/lib/data/db";
import { listProviderBookings } from "@/lib/data/provider-bookings";
import { getProviderByProfileId } from "@/lib/data/providers";
import { formatEur } from "@/lib/format";
import { BookingStatusActions } from "./booking-status-actions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Objednávky · ServisHub SK Pro",
};

const STATUS_LABEL: Record<string, string> = {
  PENDING: "Nová",
  CONFIRMED: "Potvrdená",
  IN_PROGRESS: "Prebieha",
  COMPLETED: "Dokončená",
  CANCELLED: "Zrušená",
  DISPUTED: "Spor",
};

export default async function ProviderOrdersPage() {
  const profile = isDatabaseConfigured() ? await getSessionProfile() : null;
  const provider = profile ? await getProviderByProfileId(profile.id) : null;
  const bookings = provider ? await listProviderBookings(provider.id) : [];

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="text-2xl">Objednávky</CardTitle>
          <CardDescription>
            Rezervácie zákazníkov — potvrdenie, dokončenie a zrušenie.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {!isDatabaseConfigured() ? (
            <p className="text-sm text-muted-foreground">
              Objednávky budú dostupné po napojení databázy.
            </p>
          ) : !provider ? (
            <p className="text-sm text-muted-foreground">
              Najprv vyplňte profil profesionála.
            </p>
          ) : bookings.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              Zatiaľ žiadne rezervácie.
            </p>
          ) : (
            <ul className="space-y-4">
              {bookings.map((booking) => (
                <li
                  key={booking.id}
                  className="space-y-3 rounded-lg border border-border p-4"
                >
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div>
                      <p className="font-medium">
                        {booking.service?.title ?? "Služba"}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {formatZonedDate(booking.scheduledAt)} ·{" "}
                        {formatZonedTime(booking.scheduledAt)}
                        {booking.priceAmount != null
                          ? ` · ${formatEur(Number(booking.priceAmount))}`
                          : ""}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {booking.customer.fullName ?? booking.customer.email}
                        {booking.customer.phone
                          ? ` · ${booking.customer.phone}`
                          : ""}
                      </p>
                    </div>
                    <Badge variant="secondary">
                      {STATUS_LABEL[booking.status] ?? booking.status}
                    </Badge>
                  </div>
                  <BookingStatusActions
                    bookingId={booking.id}
                    status={booking.status}
                  />
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
