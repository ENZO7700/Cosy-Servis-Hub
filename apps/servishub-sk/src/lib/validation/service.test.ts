import { describe, expect, it } from "vitest";
import { serviceSchema } from "./service";

const valid = {
  title: "Upratovanie bytu",
  description: "",
  categoryId: "cat1",
  priceFrom: 40,
  priceTo: 80,
  durationMin: 60,
  isActive: true,
};

describe("serviceSchema", () => {
  it("accepts a valid service", () => {
    expect(serviceSchema.safeParse(valid).success).toBe(true);
  });

  it("treats empty price as undefined", () => {
    const result = serviceSchema.safeParse({
      ...valid,
      priceFrom: "",
      priceTo: "",
      durationMin: "",
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.priceFrom).toBeUndefined();
      expect(result.data.priceTo).toBeUndefined();
      expect(result.data.durationMin).toBeUndefined();
    }
  });

  it("rejects priceTo lower than priceFrom", () => {
    expect(
      serviceSchema.safeParse({ ...valid, priceFrom: 100, priceTo: 50 })
        .success,
    ).toBe(false);
  });

  it("enforces duration bounds 15–1440", () => {
    expect(
      serviceSchema.safeParse({ ...valid, durationMin: 10 }).success,
    ).toBe(false);
    expect(
      serviceSchema.safeParse({ ...valid, durationMin: 1500 }).success,
    ).toBe(false);
  });

  it("requires title min 3 chars", () => {
    expect(
      serviceSchema.safeParse({ ...valid, title: "ab" }).success,
    ).toBe(false);
  });
});
