import { describe, expect, it } from "vitest";
import { providerProfileSchema } from "./provider";

const valid = {
  businessName: "Upratovanie BA",
  bio: "",
  ico: "12345678",
  dic: "1234567890",
  city: "Bratislava",
  postalCode: "811 01",
  categoryIds: ["cat1"],
};

describe("providerProfileSchema", () => {
  it("accepts valid IČO, DIČ and PSČ", () => {
    expect(providerProfileSchema.safeParse(valid).success).toBe(true);
    expect(
      providerProfileSchema.safeParse({ ...valid, postalCode: "81101" })
        .success,
    ).toBe(true);
  });

  it("rejects invalid IČO and DIČ", () => {
    expect(
      providerProfileSchema.safeParse({ ...valid, ico: "123" }).success,
    ).toBe(false);
    expect(
      providerProfileSchema.safeParse({ ...valid, dic: "abc" }).success,
    ).toBe(false);
  });

  it("requires businessName min 2 chars", () => {
    expect(
      providerProfileSchema.safeParse({ ...valid, businessName: "A" }).success,
    ).toBe(false);
  });

  it("limits categoryIds to 10", () => {
    expect(
      providerProfileSchema.safeParse({
        ...valid,
        categoryIds: Array.from({ length: 11 }, (_, i) => `c${i}`),
      }).success,
    ).toBe(false);
  });
});
