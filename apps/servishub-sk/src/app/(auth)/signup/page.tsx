import { SiteHeader } from "@/components/site-header";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { SignupForm } from "./signup-form";

type SearchParams = Promise<{ next?: string }>;

export default async function SignupPage({
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
            <CardTitle>Registrácia</CardTitle>
            <CardDescription>
              Vytvorte si účet ako zákazník alebo profesionál. Early-bird promo
              kód je voliteľný.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <SignupForm next={next} />
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
