import { afterEach, describe, expect, it, vi } from "vitest";

const findMany = vi.fn();
const count = vi.fn();

vi.mock("@/lib/prisma", () => ({
  prisma: {
    provider: {
      findMany: (...args: unknown[]) => findMany(...args),
      count: (...args: unknown[]) => count(...args),
    },
  },
}));

import { SEARCH_PAGE_SIZE, searchProviders } from "./search";

describe("searchProviders", () => {
  const original = process.env.DATABASE_URL;

  afterEach(() => {
    findMany.mockReset();
    count.mockReset();
    if (original === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = original;
  });

  it("returns empty result when DB is not configured", async () => {
    delete process.env.DATABASE_URL;
    const result = await searchProviders({ page: 1 });
    expect(result).toEqual({
      hits: [],
      total: 0,
      page: 1,
      totalPages: 0,
    });
    expect(findMany).not.toHaveBeenCalled();
  });

  it("applies filters and paginates", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    const providers = Array.from({ length: 15 }, (_, i) => ({
      id: `p${i}`,
      businessName: `Firma ${i}`,
      ratingAvg: 5 - i * 0.1,
      ratingCount: 10,
      categories: [],
      services: [
        {
          id: `s${i}`,
          priceFrom: 20 + i,
          isActive: true,
          category: { id: "c1", name: "Upratovanie" },
        },
      ],
    }));
    findMany.mockResolvedValue(providers);
    count.mockResolvedValue(15);

    const page1 = await searchProviders({ page: 1, sort: "rating" });
    expect(page1.total).toBe(15);
    expect(page1.totalPages).toBe(Math.ceil(15 / SEARCH_PAGE_SIZE));
    expect(page1.hits).toHaveLength(SEARCH_PAGE_SIZE);

    const page2 = await searchProviders({ page: 2 });
    expect(page2.hits).toHaveLength(3);
  });

  it("sorts by price_asc with nulls last", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    findMany.mockResolvedValue([
      {
        id: "a",
        categories: [],
        services: [{ priceFrom: 50, isActive: true, category: {} }],
      },
      {
        id: "b",
        categories: [],
        services: [{ priceFrom: null, isActive: true, category: {} }],
      },
      {
        id: "c",
        categories: [],
        services: [{ priceFrom: 20, isActive: true, category: {} }],
      },
    ]);
    count.mockResolvedValue(3);

    const result = await searchProviders({ sort: "price_asc" });
    expect(result.hits.map((h) => h.provider.id)).toEqual(["c", "a", "b"]);
  });
});
