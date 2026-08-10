import "server-only";
import OpenAI from "openai";

/** Default model used for SalonOS AI features (Return Engine, Slot Filler, insights). */
export const DEFAULT_MODEL = "anthropic/claude-sonnet-latest";

/** Fallback model when the default is unavailable or rate-limited. */
export const FALLBACK_MODEL = "deepseek/deepseek-chat";

let cached: OpenAI | null = null;

/**
 * Lazy OpenRouter client (OpenAI SDK pointed at OpenRouter's OpenAI-compatible API).
 * Throws a clear error only when actually called without OPENROUTER_API_KEY —
 * import/build without keys stays safe.
 */
export function getOpenRouterClient(): OpenAI {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    throw new Error(
      "OPENROUTER_API_KEY is not set. Add it to .env.local (see .env.example).",
    );
  }
  if (!cached) {
    cached = new OpenAI({
      apiKey,
      baseURL: process.env.OPENROUTER_BASE_URL || "https://openrouter.ai/api/v1",
    });
  }
  return cached;
}
