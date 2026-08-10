import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { requireProviderProfile } from "@/lib/auth/session";

export const dynamic = "force-dynamic";

const PRO_NAV_LINKS = [
  { href: "/pro", label: "Prehľad" },
  { href: "/pro/profil", label: "Profil" },
  { href: "/pro/sluzby", label: "Služby" },
  { href: "/pro/dostupnost", label: "Dostupnosť" },
  { href: "/pro/objednavky", label: "Objednávky" },
  { href: "/pro/platby", label: "Platby" },
] as const;

const PRO_NAV_PLACEHOLDERS = ["Leady", "Predplatné"] as const;

function isAuthConfigured() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY &&
      process.env.DATABASE_URL,
  );
}

export default async function ProLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  if (isAuthConfigured()) {
    await requireProviderProfile();
  }

  return (
    <div className="flex min-h-full flex-col">
      <header className="border-b border-border bg-card">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4">
          <div className="flex items-center gap-3">
            <Link href="/" className="font-semibold text-primary">
              ServisHub SK
            </Link>
            <Badge>Pro dashboard</Badge>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" asChild>
              <Link href="/login">Účet</Link>
            </Button>
            <Button variant="ghost" size="sm" asChild>
              <Link href="/auth/logout">Odhlásiť</Link>
            </Button>
          </div>
        </div>
      </header>
      <div className="mx-auto flex w-full max-w-6xl flex-1 flex-col gap-6 px-4 py-8 md:flex-row">
        <nav
          aria-label="Navigácia profesionála"
          className="flex gap-2 overflow-x-auto md:hidden"
        >
          {PRO_NAV_LINKS.map((item) => (
            <Button key={item.href} variant="outline" size="sm" asChild>
              <Link href={item.href}>{item.label}</Link>
            </Button>
          ))}
        </nav>
        <aside className="hidden w-52 shrink-0 space-y-2 md:block">
          {PRO_NAV_LINKS.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="block rounded-md px-3 py-2 text-sm text-foreground transition-colors hover:bg-muted"
            >
              {item.label}
            </Link>
          ))}
          {PRO_NAV_PLACEHOLDERS.map((item) => (
            <div
              key={item}
              className="rounded-md px-3 py-2 text-sm text-muted-foreground"
            >
              {item}
            </div>
          ))}
        </aside>
        <main className="flex-1">{children}</main>
      </div>
    </div>
  );
}
