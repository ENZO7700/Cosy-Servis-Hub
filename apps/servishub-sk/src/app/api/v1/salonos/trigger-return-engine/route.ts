import { NextResponse } from "next/server";
import { requireProviderProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { prisma } from "@/lib/prisma";

const STALE_DAYS = 28;

export async function POST(request: Request) {
  if (!isDatabaseConfigured()) {
    return NextResponse.json(
      { error: "Databáza nie je nakonfigurovaná." },
      { status: 503 },
    );
  }

  try {
    const profile = await requireProviderProfile();
    const body = (await request.json().catch(() => ({}))) as {
      providerId?: string;
    };
    const providerId =
      body.providerId ??
      (
        await prisma.provider.findUnique({
          where: { profileId: profile.id },
          select: { id: true },
        })
      )?.id;

    if (!providerId) {
      return NextResponse.json(
        { error: "Prevádzka nebola nájdená." },
        { status: 404 },
      );
    }
    if (profile.role !== "ADMIN") {
      const owned = await prisma.provider.findFirst({
        where: { id: providerId, profileId: profile.id },
        select: { id: true },
      });
      if (!owned)
        return NextResponse.json(
          { error: "Prístup zamietnutý." },
          { status: 403 },
        );
    }

    const staleSince = new Date(Date.now() - STALE_DAYS * 24 * 60 * 60 * 1000);
    const clients = await prisma.clientProfileAi.findMany({
      where: {
        providerId,
        OR: [
          { lastVisitAt: { lt: staleSince } },
          { lastVisitAt: null, nextPredictedAt: { lt: new Date() } },
        ],
      },
      include: {
        profile: {
          select: { id: true, fullName: true, phone: true, email: true },
        },
      },
      orderBy: [{ isRiskOfLoss: "desc" }, { lastVisitAt: "asc" }],
      take: 100,
    });

    return NextResponse.json({
      source: "RETURN_ENGINE",
      generatedAt: new Date().toISOString(),
      providerId,
      count: clients.length,
      batch: clients.map((client) => ({
        clientProfileAiId: client.id,
        profileId: client.profileId,
        name: client.profile.fullName ?? "Klient",
        phone: client.profile.phone,
        email: client.profile.email,
        preferredTeamMember: client.preferredTeamMember,
        isRiskOfLoss: client.isRiskOfLoss,
        lastVisitAt: client.lastVisitAt?.toISOString() ?? null,
        draft: `Ahoj ${client.profile.fullName ?? ""}, radi by sme ti ponúkli ďalší termín. Máš záujem o rezerváciu služby?`,
      })),
    });
  } catch (error) {
    if (error instanceof Error && error.message.includes("NEXT_REDIRECT"))
      throw error;
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Return engine zlyhal.",
      },
      { status: 500 },
    );
  }
}
