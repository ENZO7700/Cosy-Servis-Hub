import Link from "next/link";
import { Button } from "@/components/ui/button";

export function SiteHeader() {
  return (
    <header className="border-b border-border bg-card">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4">
        <Link href="/" className="text-lg font-semibold text-primary">
          ServisHub SK
        </Link>
        <nav className="flex items-center gap-2 sm:gap-3">
          <Button variant="ghost" asChild>
            <Link href="/hladat">Hľadať služby</Link>
          </Button>
          <Button variant="ghost" asChild>
            <Link href="/moje-rezervacie">Moje rezervácie</Link>
          </Button>
          <Button variant="ghost" asChild>
            <Link href="/pro">Pre profesionálov</Link>
          </Button>
          <Button variant="outline" asChild>
            <Link href="/login">Prihlásenie</Link>
          </Button>
          <Button asChild>
            <Link href="/signup">Registrácia</Link>
          </Button>
          <Button variant="ghost" size="sm" asChild>
            <Link href="/auth/logout">Odhlásiť</Link>
          </Button>
        </nav>
      </div>
    </header>
  );
}
