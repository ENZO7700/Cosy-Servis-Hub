import type { Metadata } from "next";
import Link from "next/link";
import { SiteHeader } from "@/components/site-header";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { WaitlistForm } from "./waitlist-form";

export const metadata: Metadata = {
  title: "Upratovanie Bratislava · Overení profesionáli",
  description:
    "ServisHub SK — rezervujte upratovanie a lokálne služby v Bratislave. Overení profesionáli, online termíny, bezpečné platby.",
  alternates: { canonical: "/" },
  openGraph: {
    title: "ServisHub SK · Upratovanie Bratislava",
    description:
      "Marketplace lokálnych služieb — upratovanie, opravy a údržba s online rezerváciou.",
    locale: "sk_SK",
    type: "website",
  },
};

function appUrl(): string {
  return process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
}

const FAQ = [
  {
    q: "V ktorých mestách ServisHub funguje?",
    a: "Spúšťame soft-launch v Bratislave so zameraním na upratovanie. Ďalšie mestá a kategórie pribudnú podľa dopytu z waitlistu.",
  },
  {
    q: "Ako prebieha rezervácia upratovania?",
    a: "Vyberiete profesionála, službu a voľný termín v kalendári. Po odoslaní rezervácie dostanete potvrdenie emailom a môžete ju spravovať v Moje rezervácie.",
  },
  {
    q: "Sú profesionáli overení?",
    a: "Áno — profil, IČO/DIČ a stav overenia sú súčasťou onboarding procesu. Recenzie zákazníkov sa zobrazujú po dokončených službách.",
  },
  {
    q: "Ako fungujú platby?",
    a: "Platby idú cez Stripe Connect. Platforma si ponechá transparentnú províziu; profesionál dostane zvyšok na svoj Express účet.",
  },
] as const;

export default function MarketingHomePage() {
  const orgJsonLd = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: "ServisHub SK",
    url: appUrl(),
    logo: `${appUrl()}/favicon.ico`,
    description:
      "Marketplace lokálnych služieb na Slovensku — rezervácie, platby a CRM pre remeselníkov.",
    areaServed: {
      "@type": "City",
      name: "Bratislava",
    },
  };

  const websiteJsonLd = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: "ServisHub SK",
    url: appUrl(),
    inLanguage: "sk-SK",
    potentialAction: {
      "@type": "SearchAction",
      target: `${appUrl()}/hladat?q={search_term_string}`,
      "query-input": "required name=search_term_string",
    },
  };

  const faqJsonLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: FAQ.map((item) => ({
      "@type": "Question",
      name: item.q,
      acceptedAnswer: {
        "@type": "Answer",
        text: item.a,
      },
    })),
  };

  return (
    <div className="flex min-h-full flex-col">
      <SiteHeader />
      <main className="flex-1">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify(orgJsonLd).replace(/</g, "\\u003c"),
          }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify(websiteJsonLd).replace(/</g, "\\u003c"),
          }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify(faqJsonLd).replace(/</g, "\\u003c"),
          }}
        />

        <section className="relative overflow-hidden border-b border-border">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top_left,_rgba(0,121,107,0.18),_transparent_55%),radial-gradient(ellipse_at_bottom_right,_rgba(255,112,67,0.14),_transparent_50%)]"
          />
          <div className="relative mx-auto grid max-w-6xl gap-10 px-4 py-16 lg:grid-cols-2 lg:items-center lg:py-20">
            <div className="space-y-6">
              <Badge className="bg-primary text-primary-foreground">
                Soft-launch · Upratovanie Bratislava
              </Badge>
              <h1 className="text-4xl font-bold tracking-tight text-foreground sm:text-5xl">
                ServisHub SK
              </h1>
              <p className="text-xl font-medium text-foreground/90 sm:text-2xl">
                Overené upratovanie v Bratislave — rezervácia online za pár
                minút.
              </p>
              <p className="max-w-xl text-lg text-muted-foreground">
                Nájdite lokálnych profesionálov na upratovanie bytov, kancelárií
                a hĺbkové čistenie. Transparentné termíny, recenzie a bezpečné
                platby.
              </p>
              <div className="flex flex-wrap gap-3">
                <Button size="lg" asChild>
                  <Link href="/hladat?mesto=Bratislava">Nájsť upratovanie</Link>
                </Button>
                <Button size="lg" variant="secondary" asChild>
                  <Link href="/signup">Stať sa profesionálom</Link>
                </Button>
              </div>
            </div>

            <Card className="border-border/80 bg-card/90 shadow-sm backdrop-blur">
              <CardHeader>
                <CardTitle>Prihlásenie na waitlist</CardTitle>
                <CardDescription>
                  Spúšťame v Bratislave. Nechajte email — ozveme sa pri otvorení
                  rezervácií vo vašom okolí.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <WaitlistForm />
              </CardContent>
            </Card>
          </div>
        </section>

        <section className="border-b border-border bg-card">
          <div className="mx-auto grid max-w-6xl gap-6 px-4 py-12 sm:grid-cols-3">
            {[
              {
                title: "Pre zákazníkov",
                body: "Vyhľadávanie podľa mesta a kategórie, online termíny a prehľad rezervácií.",
              },
              {
                title: "Pre profesionálov",
                body: "Profil, cenník, týždenná dostupnosť, objednávky a Stripe Connect výplaty.",
              },
              {
                title: "Dôvera & bezpečnosť",
                body: "Overenie profilu, recenzie po dokončení a riešenie platieb cez platformu.",
              },
            ].map((item) => (
              <div key={item.title} className="space-y-2">
                <h2 className="text-lg font-semibold">{item.title}</h2>
                <p className="text-sm text-muted-foreground">{item.body}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="mx-auto max-w-3xl space-y-6 px-4 py-14">
          <div className="space-y-2 text-center">
            <h2 className="text-2xl font-bold tracking-tight">Často kladené otázky</h2>
            <p className="text-muted-foreground">
              Lokálne SEO fokus: upratovanie · Bratislava · online rezervácia.
            </p>
          </div>
          <div className="space-y-4">
            {FAQ.map((item) => (
              <details
                key={item.q}
                className="group rounded-lg border border-border px-4 py-3"
              >
                <summary className="cursor-pointer list-none font-medium marker:content-none">
                  {item.q}
                </summary>
                <p className="mt-2 text-sm text-muted-foreground">{item.a}</p>
              </details>
            ))}
          </div>
        </section>
      </main>
      <footer className="border-t border-border py-6 text-center text-sm text-muted-foreground">
        © {new Date().getFullYear()} ServisHub SK · Bratislava
      </footer>
    </div>
  );
}
