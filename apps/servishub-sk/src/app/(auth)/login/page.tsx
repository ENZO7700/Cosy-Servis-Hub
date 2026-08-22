import { SiteHeader } from "@/components/site-header";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { LoginForm } from "./login-form";

type SearchParams = Promise<{ next?: string; error?: string }>;

export default async function LoginPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const params = await searchParams;
  const next =
    params.next && params.next.startsWith("/") && !params.next.startsWith("//")
      ? params.next
      : "/";

  return (
    <div className="flex min-h-full flex-col">
      <SiteHeader />
      <main className="mx-auto flex w-full max-w-md flex-1 items-center px-4 py-12">
        <Card className="w-full">
          <CardHeader>
            <CardTitle>Prihlásenie</CardTitle>
            <CardDescription>
              Prihláste sa emailom a heslom, alebo voliteľne cez Google.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <LoginForm next={next} initialError={params.error ?? null} />
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
