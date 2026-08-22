import { describe, expect, expectTypeOf, it } from "vitest";
import type { SalonosStatsResponse } from "./route";

describe("SALONOS V1 stats contract", () => {
  it("keeps the provider vertical and nested revenue breakdown", () => {
    const response: SalonosStatsResponse = {
      provider: {
        id: "provider-1",
        businessName: "Example Services",
        businessType: "HOME_SERVICES",
      },
      totalAiRevenue: 1250,
      breakdown: {
        returnEngine: 500,
        slotFiller: 450,
        noShowGuards: 300,
      },
      dailyActions: [],
      currency: "EUR",
      periodStart: "2026-08-01T00:00:00.000Z",
      recentLogs: [],
    };

    expect(response.provider.businessType).toBe("HOME_SERVICES");
    expect(response.breakdown).toEqual({
      returnEngine: 500,
      slotFiller: 450,
      noShowGuards: 300,
    });
    expectTypeOf(response).toMatchTypeOf<SalonosStatsResponse>();
  });
});
