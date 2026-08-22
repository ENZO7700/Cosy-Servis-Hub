/**
 * Type stubs for optional runtime dependencies that are loaded dynamically
 * (see instrumentation.ts). Remove once the real package is installed.
 */
declare module "@sentry/nextjs" {
  export function init(options: {
    dsn: string;
    environment?: string;
    tracesSampleRate?: number;
    sendDefaultPii?: boolean;
  }): void;
}
