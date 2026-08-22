import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { isDatabaseConfigured, safeDb } from "./db";

describe("isDatabaseConfigured", () => {
  const original = process.env.DATABASE_URL;

  afterEach(() => {
    if (original === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = original;
  });

  it("is false when DATABASE_URL is unset", () => {
    delete process.env.DATABASE_URL;
    expect(isDatabaseConfigured()).toBe(false);
  });

  it("is true when DATABASE_URL is set", () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    expect(isDatabaseConfigured()).toBe(true);
  });
});

describe("safeDb", () => {
  const original = process.env.DATABASE_URL;

  beforeEach(() => {
    vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
    if (original === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = original;
  });

  it("returns fallback when DB is not configured", async () => {
    delete process.env.DATABASE_URL;
    const result = await safeDb(async () => "ok", "fallback");
    expect(result).toBe("fallback");
  });

  it("returns query result when DB is configured", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    const result = await safeDb(async () => "ok", "fallback");
    expect(result).toBe("ok");
  });

  it("returns fallback when query throws", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    const result = await safeDb(async () => {
      throw new Error("boom");
    }, "fallback");
    expect(result).toBe("fallback");
  });
});
