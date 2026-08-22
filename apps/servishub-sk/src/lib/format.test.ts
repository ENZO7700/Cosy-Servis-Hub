import { describe, expect, it } from "vitest";
import { formatEur, formatRating } from "./format";

describe("formatEur", () => {
  it("returns em dash for nullish or NaN", () => {
    expect(formatEur(null)).toBe("—");
    expect(formatEur(undefined)).toBe("—");
    expect(formatEur(Number.NaN)).toBe("—");
  });

  it("formats whole euros without decimals", () => {
    const result = formatEur(25);
    expect(result).toContain("25");
    expect(result).toMatch(/€/);
  });

  it("formats fractional euros with two decimals", () => {
    const result = formatEur(12.5);
    expect(result).toMatch(/12[,.]50/);
  });
});

describe("formatRating", () => {
  it("returns Nový profil when count is 0", () => {
    expect(formatRating(0, 0)).toBe("Nový profil");
  });

  it("formats average with comma decimal and count", () => {
    expect(formatRating(4.5, 3)).toBe("4,5 ★ (3)");
  });
});
