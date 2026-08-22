/** SK locale formatting helpers (EUR, DD.MM.YYYY conventions). */

export function formatEur(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return "—";
  return new Intl.NumberFormat("sk-SK", {
    style: "currency",
    currency: "EUR",
    maximumFractionDigits: value % 1 === 0 ? 0 : 2,
  }).format(value);
}

export function formatRating(avg: number, count: number): string {
  if (count === 0) return "Nový profil";
  return `${avg.toFixed(1).replace(".", ",")} ★ (${count})`;
}
