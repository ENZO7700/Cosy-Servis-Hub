import {
  Card,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export default function ProDashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Dashboard profesionála</h1>
        <p className="text-muted-foreground">
          Chránené middleware (`/pro/*`). Kalendár, leady a reporting prídu v MVP.
        </p>
      </div>
      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { title: "Dnešné rezervácie", body: "—" },
          { title: "Nové leady", body: "—" },
          { title: "Mesačný príjem", body: "— €" },
        ].map((card) => (
          <Card key={card.title}>
            <CardHeader>
              <CardDescription>{card.title}</CardDescription>
              <CardTitle>{card.body}</CardTitle>
            </CardHeader>
          </Card>
        ))}
      </div>
    </div>
  );
}
