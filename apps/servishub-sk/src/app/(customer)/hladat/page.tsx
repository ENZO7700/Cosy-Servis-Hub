import type { Metadata } from "next";
import Link from "next/link";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { isDatabaseConfigured } from "@/lib/data/db";
import { listCategories } from "@/lib/data/categories";
import {
  searchProviders,
  type SearchFilters,
  type SearchSort,
} from "@/lib/data/search";
import { formatEur, formatRating } from "@/lib/format";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Hľadať služby",
  description:
    "Vyhľadajte overených lokálnych profesionálov podľa mesta, kategórie, ceny a hodnotenia.",
};

type RawSearchParams = { [key: string]: string | string[] | undefined };

function firstParam(value: string | string[] | undefined): string | undefined {
  const raw = Array.isArray(value) ? value[0] : value;
  const trimmed = raw?.trim();
  return trimmed ? trimmed : undefined;
}

function parseNumber(value: string | undefined): number | undefined {
  if (!value) return undefined;
  const parsed = Number(value.replace(",", "."));
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : undefined;
}

function parseSort(value: string | undefined): SearchSort {
  if (value === "price_asc" || value === "price_desc") return value;
  return "rating";
}

function parseFilters(params: RawSearchParams): SearchFilters {
  const page = Number.parseInt(firstParam(params.page) ?? "1", 10);
  return {
    q: firstParam(params.q),
    city: firstParam(params.city),
    categoryId: firstParam(params.categoryId),
    priceMin: parseNumber(firstParam(params.priceMin)),
    priceMax: parseNumber(firstParam(params.priceMax)),
    minRating: parseNumber(firstParam(params.minRating)),
    sort: parseSort(firstParam(params.sort)),
    page: Number.isFinite(page) && page > 0 ? page : 1,
  };
}

function pageHref(filters: SearchFilters, page: number): string {
  const params = new URLSearchParams();
  if (filters.q) params.set("q", filters.q);
  if (filters.city) params.set("city", filters.city);
  if (filters.categoryId) params.set("categoryId", filters.categoryId);
  if (filters.priceMin !== undefined) params.set("priceMin", String(filters.priceMin));
  if (filters.priceMax !== undefined) params.set("priceMax", String(filters.priceMax));
  if (filters.minRating !== undefined) params.set("minRating", String(filters.minRating));
  if (filters.sort && filters.sort !== "rating") params.set("sort", filters.sort);
  if (page > 1) params.set("page", String(page));
  const query = params.toString();
  return query ? `/hladat?${query}` : "/hladat";
}

export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<RawSearchParams>;
}) {
  const filters = parseFilters(await searchParams);
  const dbReady = isDatabaseConfigured();

  const [categories, result] = await Promise.all([
    listCategories(),
    searchProviders(filters),
  ]);

  return (
    <div className="flex min-h-full flex-col">
      <SiteHeader />
      <main className="mx-auto w-full max-w-6xl flex-1 space-y-6 px-4 py-10">
        <div className="space-y-2">
          <h1 className="text-3xl font-bold tracking-tight">Hľadať služby</h1>
          <p className="text-muted-foreground">
            Overení profesionáli podľa lokality, kategórie, ceny a hodnotenia.
          </p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Filtre</CardTitle>
          </CardHeader>
          <CardContent>
            <form
              action="/hladat"
              method="get"
              className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4"
            >
              <div className="space-y-1.5">
                <Label htmlFor="q">Hľadaný výraz</Label>
                <Input
                  id="q"
                  name="q"
                  defaultValue={filters.q ?? ""}
                  placeholder="napr. upratovanie"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="city">Mesto</Label>
                <Input
                  id="city"
                  name="city"
                  defaultValue={filters.city ?? ""}
                  placeholder="Bratislava"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="categoryId">Kategória</Label>
                <Select
                  id="categoryId"
                  name="categoryId"
                  defaultValue={filters.categoryId ?? ""}
                >
                  <option value="">Všetky kategórie</option>
                  {categories.map((category) => (
                    <option key={category.id} value={category.id}>
                      {category.name}
                    </option>
                  ))}
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="minRating">Min. hodnotenie</Label>
                <Select
                  id="minRating"
                  name="minRating"
                  defaultValue={
                    filters.minRating !== undefined ? String(filters.minRating) : ""
                  }
                >
                  <option value="">Akékoľvek</option>
                  <option value="3">3+ ★</option>
                  <option value="4">4+ ★</option>
                  <option value="4.5">4,5+ ★</option>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="priceMin">Cena od (€)</Label>
                <Input
                  id="priceMin"
                  name="priceMin"
                  type="number"
                  min={0}
                  step="1"
                  defaultValue={
                    filters.priceMin !== undefined ? String(filters.priceMin) : ""
                  }
                  placeholder="0"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="priceMax">Cena do (€)</Label>
                <Input
                  id="priceMax"
                  name="priceMax"
                  type="number"
                  min={0}
                  step="1"
                  defaultValue={
                    filters.priceMax !== undefined ? String(filters.priceMax) : ""
                  }
                  placeholder="100"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="sort">Zoradiť</Label>
                <Select id="sort" name="sort" defaultValue={filters.sort ?? "rating"}>
                  <option value="rating">Podľa hodnotenia</option>
                  <option value="price_asc">Od najlacnejších</option>
                  <option value="price_desc">Od najdrahších</option>
                </Select>
              </div>
              <div className="flex items-end gap-2">
                <Button type="submit" className="flex-1">
                  Hľadať
                </Button>
                <Button variant="ghost" asChild>
                  <Link href="/hladat">Zrušiť</Link>
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>

        {!dbReady ? (
          <Card className="border-secondary/50">
            <CardHeader>
              <CardTitle className="text-base">
                Vyhľadávanie sa práve spúšťa
              </CardTitle>
              <CardDescription>
                Katalóg profesionálov bude dostupný po napojení databázy.
                Skúste to neskôr, prípadne sa prihláste na waitlist na
                hlavnej stránke.
              </CardDescription>
            </CardHeader>
          </Card>
        ) : result.total === 0 ? (
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Žiadne výsledky</CardTitle>
              <CardDescription>
                Pre zadané filtre sa nenašiel žiadny profesionál. Skúste
                upraviť kritériá alebo vyhľadávanie zrušiť.
              </CardDescription>
            </CardHeader>
          </Card>
        ) : (
          <>
            <p className="text-sm text-muted-foreground">
              Nájdených profesionálov: {result.total}
            </p>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {result.hits.map((hit) => (
                <Card key={hit.provider.id}>
                  <CardHeader>
                    <div className="flex items-start justify-between gap-2">
                      <CardTitle className="text-base">
                        <Link
                          href={`/p/${hit.provider.slug}`}
                          className="underline-offset-4 hover:underline"
                        >
                          {hit.provider.businessName}
                        </Link>
                      </CardTitle>
                      <Badge variant="secondary">
                        {formatRating(
                          hit.provider.ratingAvg,
                          hit.provider.ratingCount,
                        )}
                      </Badge>
                    </div>
                    <CardDescription>
                      {hit.provider.city ?? "Slovensko"}
                      {hit.minPrice !== null
                        ? ` · od ${formatEur(hit.minPrice)}`
                        : " · cena dohodou"}
                    </CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    {hit.provider.categories.length > 0 ? (
                      <div className="flex flex-wrap gap-1.5">
                        {hit.provider.categories.slice(0, 3).map((category) => (
                          <Badge key={category.id} variant="outline">
                            {category.name}
                          </Badge>
                        ))}
                      </div>
                    ) : null}
                    {hit.services.length > 0 ? (
                      <ul className="space-y-1 text-sm text-muted-foreground">
                        {hit.services.slice(0, 3).map((service) => (
                          <li key={service.id} className="flex justify-between gap-2">
                            <span className="truncate">{service.title}</span>
                            <span className="shrink-0">
                              {service.priceFrom !== null
                                ? formatEur(Number(service.priceFrom))
                                : "—"}
                            </span>
                          </li>
                        ))}
                      </ul>
                    ) : null}
                    <Button variant="outline" size="sm" asChild>
                      <Link href={`/p/${hit.provider.slug}`}>Zobraziť profil</Link>
                    </Button>
                  </CardContent>
                </Card>
              ))}
            </div>

            {result.totalPages > 1 ? (
              <nav
                aria-label="Stránkovanie"
                className="flex items-center justify-center gap-3 pt-2"
              >
                {result.page > 1 ? (
                  <Button variant="outline" size="sm" asChild>
                    <Link href={pageHref(filters, result.page - 1)}>
                      ← Predchádzajúca
                    </Link>
                  </Button>
                ) : null}
                <span className="text-sm text-muted-foreground">
                  Strana {result.page} z {result.totalPages}
                </span>
                {result.page < result.totalPages ? (
                  <Button variant="outline" size="sm" asChild>
                    <Link href={pageHref(filters, result.page + 1)}>
                      Ďalšia →
                    </Link>
                  </Button>
                ) : null}
              </nav>
            ) : null}
          </>
        )}
      </main>
    </div>
  );
}
