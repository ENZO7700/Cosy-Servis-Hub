import { NextResponse } from "next/server";
import { requireProviderProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { prisma } from "@/lib/prisma";

type RouteContext = { params: Promise<{ providerId: string }> };

function monthStart() {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
}

export async function GET(_request: Request, context: RouteContext) {
  if (!isDatabaseConfigured()) {
    return NextResponse.json(
      { error: "Databáza nie je nakonfigurovaná." },
      { status: 503 },
    );
  }

  try {
    const profile = await requireProviderProfile();
    const { providerId } = await context.params;
    const provider = await prisma.provider.findUnique({
      where: { id: providerId },
      select: { id: true, profileId: true, businessName: true },
    });

    if (!provider || (profile.role !== "ADMIN" && provider.profileId !== profile.id)) {
      return NextResponse.json({ error: "Prístup zamietnutý." }, { status: 403 });
    }

    const logs = await prisma.aiRevenueLog.findMany({
      where: { providerId, createdAt: { gte: monthStart() } },
      orderBy: { createdAt: "desc" },
      select: { source: true, amount: true, description: true, createdAt: true },
    });

    const breakdown = {
      returnEngine: 0,
      slotFiller: 0,
      noShowGuards: 0,
    };

    for (const log of logs) {
      const amount = Number(log.amount);
      if (log.source === "RETURN_ENGINE") breakdown.returnEngine += amount;
      if (log.source === "SLOT_FILLER") breakdown.slotFiller += amount;
      if (log.description?.toLowerCase().includes("no-show")) {
        breakdown.noShowGuards += amount;
      }
    }

    const dailyActions = [
      {
        id: "return-engine",
        title: "Osloviť klientov po termíne návratu",
        detail: "SALONOS vybral klientov, ktorí neboli viac ako 28 dní.",
        count: await prisma.clientProfileAi.count({
          where: {
            providerId,
            lastVisitAt: { lt: new Date(Date.now() - 28 * 24 * 60 * 60 * 1000) },
          },
        }),
      },
      {
        id: "slot-filler",
        title: "Doplniť najbližší voľný slot",
        detail: "Pripravený návrh pre klienta, ktorý zvykne rezervovať podobný čas.",
        count: 1,
      },
      {
        id: "risk-review",
        title: "Skontrolovať VIP klientov v riziku odchodu",
        detail: "Prioritizujte osobnú starostlivosť o klientov s vysokou hodnotou.",
        count: await prisma.clientProfileAi.count({
          where: { providerId, isRiskOfLoss: true },
        }),
      },
    ];

    return NextResponse.json({
      provider: { id: provider.id, businessName: provider.businessName },
      totalAiRevenue: breakdown.returnEngine + breakdown.slotFiller + breakdown.noShowGuards,
      ...breakdown,
      currency: "EUR",
      periodStart: monthStart().toISOString(),
      dailyActions,
      recentLogs: logs.map((log) => ({
        source: log.source,
        amount: Number(log.amount),
        description: log.description,
        createdAt: log.createdAt.toISOString(),
      })),
    });
  } catch (error) {
    if (error instanceof Error && error.message.includes("NEXT_REDIRECT")) throw error;
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Načítanie štatistík zlyhalo." },
      { status: 500 },
    );
  }
}