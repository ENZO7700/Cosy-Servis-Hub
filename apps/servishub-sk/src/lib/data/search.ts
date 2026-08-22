import type { Category, Prisma, Provider, Service } from "@/generated/prisma/client";
import { prisma } from "@/lib/prisma";
import { safeDb } from "@/lib/data/db";

export const SEARCH_PAGE_SIZE = 12;
/** MVP safeguard: filters run in DB, final sort/pagination in memory up to this cap. */
const SEARCH_FETCH_CAP = 200;

export type SearchSort = "rating" | "price_asc" | "price_desc";

export type SearchFilters = {
  q?: string;
  city?: string;
  categoryId?: string;
  priceMin?: number;
  priceMax?: number;
  minRating?: number;
  sort?: SearchSort;
  page?: number;
};

export type ProviderSearchHit = {
  provider: Provider & { categories: Category[] };
  services: (Service & { category: Category })[];
  minPrice: number | null;
};

export type SearchResult = {
  hits: ProviderSearchHit[];
  total: number;
  page: number;
  totalPages: number;
};

function buildWhere(filters: SearchFilters): Prisma.ProviderWhereInput {
  const where: Prisma.ProviderWhereInput = { isActive: true };

  if (filters.q) {
    where.OR = [
      { businessName: { contains: filters.q, mode: "insensitive" } },
      { bio: { contains: filters.q, mode: "insensitive" } },
    ];
  }
  if (filters.city) {
    where.city = { contains: filters.city, mode: "insensitive" };
  }
  if (filters.minRating !== undefined) {
    where.ratingAvg = { gte: filters.minRating };
  }

  const serviceSome: Prisma.ServiceWhereInput = { isActive: true };
  let needsServiceFilter = false;
  if (filters.categoryId) {
    serviceSome.categoryId = filters.categoryId;
    needsServiceFilter = true;
  }
  if (filters.priceMin !== undefined || filters.priceMax !== undefined) {
    serviceSome.priceFrom = {
      ...(filters.priceMin !== undefined ? { gte: filters.priceMin } : {}),
      ...(filters.priceMax !== undefined ? { lte: filters.priceMax } : {}),
    };
    needsServiceFilter = true;
  }
  if (needsServiceFilter) {
    where.services = { some: serviceSome };
  }

  return where;
}

function toMinPrice(services: { priceFrom: unknown }[]): number | null {
  for (const service of services) {
    if (service.priceFrom !== null && service.priceFrom !== undefined) {
      return Number(service.priceFrom);
    }
  }
  return null;
}

/**
 * Searches active providers with their active services.
 * Filters are applied in Postgres; price sorting and pagination are applied
 * in memory over a capped result set (fine for MVP scale).
 * Returns an empty result when the DB is not configured or unreachable.
 */
export async function searchProviders(filters: SearchFilters): Promise<SearchResult> {
  const page = Math.max(1, filters.page ?? 1);
  const empty: SearchResult = { hits: [], total: 0, page, totalPages: 0 };

  const where = buildWhere(filters);

  const result = await safeDb(async () => {
    const [providers, total] = await Promise.all([
      prisma.provider.findMany({
        where,
        include: {
          categories: true,
          services: {
            where: { isActive: true },
            include: { category: true },
            orderBy: { priceFrom: "asc" },
          },
        },
        orderBy: [{ ratingAvg: "desc" }, { ratingCount: "desc" }, { createdAt: "asc" }],
        take: SEARCH_FETCH_CAP,
      }),
      prisma.provider.count({ where }),
    ]);

    const hits: ProviderSearchHit[] = providers.map(({ services, ...provider }) => ({
      provider,
      services,
      minPrice: toMinPrice(services),
    }));

    if (filters.sort === "price_asc" || filters.sort === "price_desc") {
      const direction = filters.sort === "price_asc" ? 1 : -1;
      hits.sort((a, b) => {
        if (a.minPrice === null && b.minPrice === null) return 0;
        if (a.minPrice === null) return 1;
        if (b.minPrice === null) return -1;
        return (a.minPrice - b.minPrice) * direction;
      });
    }

    const totalPages = Math.ceil(total / SEARCH_PAGE_SIZE);
    const effectivePage = Math.min(page, Math.max(totalPages, 1));
    const start = (effectivePage - 1) * SEARCH_PAGE_SIZE;
    return {
      hits: hits.slice(start, start + SEARCH_PAGE_SIZE),
      total,
      page: effectivePage,
      totalPages,
    } satisfies SearchResult;
  }, empty);

  return result;
}
