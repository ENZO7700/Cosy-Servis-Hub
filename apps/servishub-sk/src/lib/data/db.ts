/**
 * Shared helpers for the data-access layer.
 * Reads must degrade gracefully when DATABASE_URL is not wired yet (T0 infra).
 */

export function isDatabaseConfigured(): boolean {
  return Boolean(process.env.DATABASE_URL);
}

/**
 * Runs a read query; returns `fallback` when the DB is not configured or
 * unreachable, so pages render empty states instead of erroring.
 * Use only for reads — mutations should throw and be handled by the caller.
 */
export async function safeDb<T>(query: () => Promise<T>, fallback: T): Promise<T> {
  if (!isDatabaseConfigured()) return fallback;
  try {
    return await query();
  } catch (error) {
    console.error("[data] database read failed:", error);
    return fallback;
  }
}
