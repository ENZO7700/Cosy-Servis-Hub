import type { Category, Service } from "@/generated/prisma/client";
import { prisma } from "@/lib/prisma";
import { safeDb } from "@/lib/data/db";
import type { ServiceInput } from "@/lib/validation/service";

export type ServiceWithCategory = Service & { category: Category };

/** All services of a provider (active + inactive), newest first. */
export async function listProviderServices(
  providerId: string,
): Promise<ServiceWithCategory[]> {
  return safeDb(
    () =>
      prisma.service.findMany({
        where: { providerId },
        include: { category: true },
        orderBy: { createdAt: "desc" },
      }),
    [],
  );
}

/** Single service scoped to the owning provider (ownership check built in). */
export async function getProviderService(
  providerId: string,
  serviceId: string,
): Promise<Service | null> {
  return safeDb(
    () =>
      prisma.service.findFirst({
        where: { id: serviceId, providerId },
      }),
    null,
  );
}

function toServiceData(input: ServiceInput) {
  return {
    title: input.title,
    description: input.description || null,
    categoryId: input.categoryId,
    priceFrom: input.priceFrom ?? null,
    priceTo: input.priceTo ?? null,
    durationMin: input.durationMin ?? null,
    isActive: input.isActive,
  };
}

/** Creates a service. Throws on DB errors — authorize in the calling action. */
export async function createService(
  providerId: string,
  input: ServiceInput,
): Promise<Service> {
  return prisma.service.create({
    data: { ...toServiceData(input), providerId },
  });
}

/**
 * Updates a service owned by the provider.
 * Returns false when the service does not exist or belongs to someone else.
 */
export async function updateService(
  providerId: string,
  serviceId: string,
  input: ServiceInput,
): Promise<boolean> {
  const result = await prisma.service.updateMany({
    where: { id: serviceId, providerId },
    data: toServiceData(input),
  });
  return result.count > 0;
}

/**
 * Soft-deletes (deactivates) a service owned by the provider.
 * Returns false when the service does not exist or belongs to someone else.
 */
export async function deactivateService(
  providerId: string,
  serviceId: string,
): Promise<boolean> {
  const result = await prisma.service.updateMany({
    where: { id: serviceId, providerId },
    data: { isActive: false },
  });
  return result.count > 0;
}
