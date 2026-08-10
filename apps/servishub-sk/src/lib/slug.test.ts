import { describe, expect, it } from "vitest";
import { slugify } from "./slug";

describe("slugify", () => {
  it("strips Slovak diacritics", () => {
    expect(slugify("Čistá Ľúbosť Ťažká")).toBe("cista-lubost-tazka");
  });

  it("collapses punctuation and spaces to hyphens and trims edges", () => {
    expect(slugify("  Hello!!! World??  ")).toBe("hello-world");
  });

  it("caps length at 64", () => {
    const long = "a".repeat(80);
    expect(slugify(long).length).toBe(64);
  });

  it("returns empty string for symbols-only input", () => {
    expect(slugify("!!!@@@")).toBe("");
  });
});
