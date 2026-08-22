/**
 * Next.js instrumentation hook — runs once at server startup.
 * Sentry activates only when SENTRY_DSN is set; `@sentry/nextjs` is loaded
 * dynamically so the app builds and runs without the package installed.
 * TODO (T0): pnpm add @sentry/nextjs + set SENTRY_DSN once Sentry project exists.
 */
export async function register() {
  const dsn = process.env.SENTRY_DSN;
  if (!dsn) return;

  try {
    const Sentry = await import("@sentry/nextjs");
    Sentry.init({
      dsn,
      environment: process.env.VERCEL_ENV ?? process.env.NODE_ENV,
      tracesSampleRate: process.env.VERCEL_ENV === "production" ? 0.1 : 1.0,
      sendDefaultPii: false,
    });
  } catch {
    console.warn(
      "[instrumentation] SENTRY_DSN is set but @sentry/nextjs is not installed — skipping Sentry init. Run: pnpm add @sentry/nextjs",
    );
  }
}
