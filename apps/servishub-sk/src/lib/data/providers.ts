import type { Category, Provider, Service } from "@/generated/prisma/client";
import { prisma } from "@/lib/prisma";
import { safeDb } from "@/lib/data/db";
import { slugify } from "@/lib/slug";
import type { ProviderProfileInput } from "@/lib/validation/provider";

export type ProviderWithCategories = Provider & { categories: Category[] };

export type PublicProvider = Provider & {
  categories: Category[];
  services: (Service & { category: Category })[];
};

/** Provider row owned by the given app profile, or null (also when DB is down). */
export async function getProviderByProfileId(
  profileId: string,
): Promise<ProviderWithCategories | null> {
  return safeDb(
    () =>
      prisma.provider.findUnique({
        where: { profileId },
        include: { categories: true },
      }),
    null,
  );
}

/** Public provider profile by slug — only active providers are public. */
export async function getPublicProviderBySlug(
  slug: string,
): Promise<PublicProvider | null> {
  return safeDb(
    () =>
      prisma.provider.findFirst({
        where: { slug, isActive: true },
        include: {
          categories: true,
          services: {
            where: { isActive: true },
            include: { category: true },
            orderBy: { priceFrom: "asc" },
          },
        },
      }),
    null,
  );
}

async function uniqueProviderSlug(businessName: string): Promise<string> {
  const base = slugify(businessName) || "profesional";
  let candidate = base;
  let suffix = 2;
  while (
    await prisma.provider.findUnique({
      where: { slug: candidate },
      select: { id: true },
    })
  ) {
    candidate = `${base}-${suffix}`;
    suffix += 1;
  }
  return candidate;
}

/**
 * Creates or updates the Provider row for a profile.
 * Throws on DB errors — callers (server actions) must authorize first and
 * handle failures. Slug is generated once on create and kept stable.
 */
export async function upsertProviderProfile(
  profileId: string,
  input: ProviderProfileInput,
): Promise<Provider> {
  const scalarData = {
    businessName: input.businessName,
    bio: input.bio || null,
    ico: input.ico || null,
    dic: input.dic || null,
    city: input.city || null,
    postalCode: input.postalCode || null,
  };
  const categoryRefs = input.categoryIds.map((id) => ({ id }));

  const existing = await prisma.provider.findUnique({
    where: { profileId },
    select: { id: true, slug: true },
  });

  if (existing) {
    return prisma.provider.update({
      where: { id: existing.id },
      data: { ...scalarData, categories: { set: categoryRefs } },
    });
  }

  return prisma.provider.create({
    data: {
      ...scalarData,
      profileId,
      slug: await uniqueProviderSlug(input.businessName),
      categories: { connect: categoryRefs },
    },
  });
}
