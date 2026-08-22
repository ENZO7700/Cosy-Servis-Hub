import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { isDatabaseConfigured, safeDb } from "@/lib/data/db";
import { prisma } from "@/lib/prisma";
import { formatEur } from "@/lib/format";
import {
  formatZonedDate,
  formatZonedTime,
} from "@/lib/booking/slots";

export const dynamic = "force-dynamic";

type AdminStats = {
  profiles: number;
  providers: number;
  bookings: number;
  payments: number;
  leads: number;
};

async function loadStats(): Promise<AdminStats> {
  return safeDb(async () => {
    const [profiles, providers, bookings, payments, leads] = await Promise.all([
      prisma.profile.count(),
      prisma.provider.count(),
      prisma.booking.count(),
      prisma.payment.count(),
      prisma.lead.count(),
    ]);
    return { profiles, providers, bookings, payments, leads };
  }, { profiles: 0, providers: 0, bookings: 0, payments: 0, leads: 0 });
}

export default async function AdminPage() {
  const dbReady = isDatabaseConfigured();
  const stats = await loadStats();

  const recentBookings = await safeDb(
    () =>
      prisma.booking.findMany({
        take: 10,
        orderBy: { createdAt: "desc" },
        include: {
          provider: { select: { businessName: true } },
          customer: { select: { email: true, fullName: true } },
        },
      }),
    [],
  );

  const recentPayments = await safeDb(
    () =>
      prisma.payment.findMany({
        take: 10,
        orderBy: { createdAt: "desc" },
        include: {
          booking: {
            select: {
              id: true,
              provider: { select: { businessName: true } },
            },
          },
        },
      }),
    [],
  );

  const recentProfiles = await safeDb(
    () =>
      prisma.profile.findMany({
        take: 10,
        orderBy: { createdAt: "desc" },
        select: {
          id: true,
          email: true,
          fullName: true,
          role: true,
          createdAt: true,
        },
      }),
    [],
  );

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Admin & operácie</h1>
        <p className="text-muted-foreground">
          Prehľad používateľov, rezervácií a platieb.
          {!dbReady ? " Databáza zatiaľ nie je napojená — čísla sú 0." : null}
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
        {[
          { title: "Profily", value: stats.profiles },
          { title: "Profesionáli", value: stats.providers },
          { title: "Rezervácie", value: stats.bookings },
          { title: "Platby", value: stats.payments },
          { title: "Leady / waitlist", value: stats.leads },
        ].map((card) => (
          <Card key={card.title}>
            <CardHeader className="pb-2">
              <CardDescription>{card.title}</CardDescription>
              <CardTitle className="text-3xl tabular-nums">{card.value}</CardTitle>
            </CardHeader>
          </Card>
        ))}
      </div>

      <section className="space-y-3" id="users">
        <h2 className="text-lg font-semibold">Používatelia</h2>
        <Card>
          <CardContent className="divide-y divide-border p-0">
            {recentProfiles.length === 0 ? (
              <p className="p-4 text-sm text-muted-foreground">Žiadne profily.</p>
            ) : (
              recentProfiles.map((profile) => (
                <div
                  key={profile.id}
                  className="flex flex-wrap items-center justify-between gap-2 px-4 py-3 text-sm"
                >
                  <div>
                    <p className="font-medium">
                      {profile.fullName ?? profile.email}
                    </p>
                    <p className="text-muted-foreground">{profile.email}</p>
                  </div>
                  <Badge variant="secondary">{profile.role}</Badge>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </section>

      <section className="space-y-3" id="bookings">
        <h2 className="text-lg font-semibold">Rezervácie</h2>
        <Card>
          <CardContent className="divide-y divide-border p-0">
            {recentBookings.length === 0 ? (
              <p className="p-4 text-sm text-muted-foreground">
                Žiadne rezervácie.
              </p>
            ) : (
              recentBookings.map((booking) => (
                <div
                  key={booking.id}
                  className="flex flex-wrap items-center justify-between gap-2 px-4 py-3 text-sm"
                >
                  <div>
                    <p className="font-medium">{booking.provider.businessName}</p>
                    <p className="text-muted-foreground">
                      {booking.customer.fullName ?? booking.customer.email} ·{" "}
                      {formatZonedDate(booking.scheduledAt)}{" "}
                      {formatZonedTime(booking.scheduledAt)}
                    </p>
                  </div>
                  <Badge variant="outline">{booking.status}</Badge>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </section>

      <section className="space-y-3" id="payments">
        <h2 className="text-lg font-semibold">Platby</h2>
        <Card>
          <CardContent className="divide-y divide-border p-0">
            {recentPayments.length === 0 ? (
              <p className="p-4 text-sm text-muted-foreground">Žiadne platby.</p>
            ) : (
              recentPayments.map((payment) => (
                <div
                  key={payment.id}
                  className="flex flex-wrap items-center justify-between gap-2 px-4 py-3 text-sm"
                >
                  <div>
                    <p className="font-medium">
                      {payment.booking.provider.businessName}
                    </p>
                    <p className="text-muted-foreground">
                      {formatEur(Number(payment.amount))}
                      {payment.applicationFee != null
                        ? ` · fee ${formatEur(Number(payment.applicationFee))}`
                        : ""}
                    </p>
                  </div>
                  <Badge variant="secondary">{payment.status}</Badge>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
