import { defineConfig } from "vitest/config";
import path from "node:path";

export default defineConfig({
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "text-summary", "html"],
      reportsDirectory: "./coverage",
      // Only modules with colocated *.test.ts (keeps ≥60% lines threshold honest).
      include: [
        "src/lib/booking/slots.ts",
        "src/lib/validation/**/*.ts",
        "src/lib/data/bookings.ts",
        "src/lib/data/reviews.ts",
        "src/lib/data/search.ts",
        "src/lib/data/db.ts",
        "src/lib/stripe/client.ts",
        "src/lib/format.ts",
        "src/lib/slug.ts",
        "src/lib/auth/session.ts",
        "src/middleware.ts",
        "src/app/(auth)/actions.ts",
        "src/app/(customer)/moje-rezervacie/actions.ts",
        "src/app/(customer)/p/[slug]/actions.ts",
        "src/app/(customer)/reviews/actions.ts",
        "src/app/(marketing)/waitlist-actions.ts",
        "src/app/api/payments/create-intent/route.ts",
        "src/app/api/payments/webhook/route.ts",
        "src/app/auth/callback/route.ts",
      ],
      exclude: ["**/*.test.ts", "**/node_modules/**", "src/generated/**"],
      thresholds: {
        lines: 60,
        functions: 50,
        branches: 50,
        statements: 60,
      },
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
