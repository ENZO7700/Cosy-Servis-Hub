import { NextResponse } from "next/server";
import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import { requireProviderProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { prisma } from "@/lib/prisma";
import type { BusinessType, Profile } from "@/generated/prisma/client";

type RouteContext = { params: Promise<{ providerId: string }> };

type SalonosBreakdown = {
  returnEngine: number;
  slotFiller: number;
  noShowGuards: number;
};

type SalonosDailyAction = {
  id: string;
  title: string;
  detail: string;
  count: number;
};

export type SalonosStatsResponse = {
  provider: { id: string; businessName: string; businessType: BusinessType };
  totalAiRevenue: number;
  breakdown: SalonosBreakdown;
  dailyActions: SalonosDailyAction[];
  currency: "EUR";
  periodStart: string;
  recentLogs: Array<{
    source: string;
    amount: number;
    description: string | null;
    createdAt: string;
  }>;
};

function corsHeaders(request: Request): Record<string, string> {
  const allowedOrigin = process.env.SALONOS_DASHBOARD_ORIGIN;
  const origin = request.headers.get("origin");
  if (!allowedOrigin || origin !== allowedOrigin) return {};

  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    Vary: "Origin",
  };
}

function json(request: Request, body: unknown, status = 200) {
  return NextResponse.json(body, { status, headers: corsHeaders(request) });
}

async function requireApiProfile(request: Request): Promise<Profile | null> {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return requireProviderProfile();
  }

  const token = authorization.slice("Bearer ".length).trim();
  if (!token) return null;

  const supabase = createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) return null;

  const profile = await prisma.profile.findUnique({
    where: { userId: data.user.id },
  });
  if (!profile || (profile.role !== "PROVIDER" && profile.role !== "ADMIN"))
    return null;
  return profile;
}

function monthStart() {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
}

export function OPTIONS(request: Request) {
  return new Response(null, { status: 204, headers: corsHeaders(request) });
}

export async function GET(request: Request, context: RouteContext) {
  if (!isDatabaseConfigured()) {
    return json(request, { error: "Databáza nie je nakonfigurovaná." }, 503);
  }

  try {
    const profile = await requireApiProfile(request);
    if (!profile) return json(request, { error: "Neplatné prihlásenie." }, 401);

    const { providerId } = await context.params;
    const provider = await prisma.provider.findUnique({
      where: { id: providerId },
      select: {
        id: true,
        profileId: true,
        businessName: true,
        businessType: true,
      },
    });

    if (
      !provider ||
      (profile.role !== "ADMIN" && provider.profileId !== profile.id)
    ) {
      return json(request, { error: "Prístup zamietnutý." }, 403);
    }

    const logs = await prisma.aiRevenueLog.findMany({
      where: { providerId, createdAt: { gte: monthStart() } },
      orderBy: { createdAt: "desc" },
      select: {
        source: true,
        amount: true,
        description: true,
        createdAt: true,
      },
    });

    const breakdown = {
      returnEngine: 0,
      slotFiller: 0,
      noShowGuards: 0,
    };

    for (const log of logs) {
      const amount = Number(log.amount);
      switch (log.source) {
        case "RETURN_ENGINE":
          breakdown.returnEngine += amount;
          break;
        case "SLOT_FILLER":
          breakdown.slotFiller += amount;
          break;
        case "AI_RECEPTIONIST":
          breakdown.noShowGuards += amount;
          break;
      }
    }

    const [returnCandidateCount, slotCandidateCount, riskCandidateCount] =
      await Promise.all([
        prisma.clientProfileAi.count({
          where: {
            providerId,
            OR: [
              {
                lastVisitAt: {
                  lt: new Date(Date.now() - 28 * 24 * 60 * 60 * 1000),
                },
              },
              { lastVisitAt: null, nextPredictedAt: { lt: new Date() } },
            ],
          },
        }),
        prisma.clientProfileAi.count({ where: { providerId } }),
        prisma.clientProfileAi.count({
          where: { providerId, isRiskOfLoss: true },
        }),
      ]);

    const dailyActions: SalonosDailyAction[] = [
      {
        id: "return-engine",
        title: "Osloviť klientov po termíne návratu",
        detail: "SALONOS vybral klientov pripravených na ďalší kontakt.",
        count: returnCandidateCount,
      },
      {
        id: "slot-filler",
        title: "Pripraviť klientov pre voľnú kapacitu",
        detail: "Klienti dostupní pre najbližšiu ponuku služby.",
        count: slotCandidateCount,
      },
      {
        id: "risk-review",
        title: "Skontrolovať VIP klientov v riziku odchodu",
        detail:
          "Prioritizujte osobnú starostlivosť o klientov s vysokou hodnotou.",
        count: riskCandidateCount,
      },
    ];

    const response: SalonosStatsResponse = {
      provider: {
        id: provider.id,
        businessName: provider.businessName,
        businessType: provider.businessType,
      },
      totalAiRevenue:
        breakdown.returnEngine + breakdown.slotFiller + breakdown.noShowGuards,
      breakdown,
      currency: "EUR",
      periodStart: monthStart().toISOString(),
      dailyActions,
      recentLogs: logs.map((log) => ({
        source: log.source,
        amount: Number(log.amount),
        description: log.description,
        createdAt: log.createdAt.toISOString(),
      })),
    };
    return json(request, response);
  } catch (error) {
    if (error instanceof Error && error.message.includes("NEXT_REDIRECT"))
      throw error;
    return json(
      request,
      {
        error:
          error instanceof Error
            ? error.message
            : "Načítanie štatistík zlyhalo.",
      },
      500,
    );
  }
}
