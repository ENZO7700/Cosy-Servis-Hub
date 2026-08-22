import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { requireAdminProfile } from "@/lib/auth/session";

export const dynamic = "force-dynamic";

function isAuthConfigured() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY &&
      process.env.DATABASE_URL,
  );
}

export default async function AdminLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  if (isAuthConfigured()) {
    await requireAdminProfile();
  }

  return (
    <div className="flex min-h-full flex-col">
      <header className="border-b border-border bg-card">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4">
          <div className="flex items-center gap-3">
            <Link href="/" className="font-semibold text-primary">
              ServisHub SK
            </Link>
            <Badge variant="secondary">Admin</Badge>
          </div>
          <Button variant="outline" size="sm" asChild>
            <Link href="/login">Účet</Link>
          </Button>
        </div>
      </header>
      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8">{children}</main>
    </div>
  );
}
