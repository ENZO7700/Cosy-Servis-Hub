import type { Category } from "@/generated/prisma/client";
import { prisma } from "@/lib/prisma";
import { safeDb } from "@/lib/data/db";

/** All categories ordered for display. Empty array when DB is not reachable. */
export async function listCategories(): Promise<Category[]> {
  return safeDb(
    () =>
      prisma.category.findMany({
        orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
      }),
    [],
  );
}
