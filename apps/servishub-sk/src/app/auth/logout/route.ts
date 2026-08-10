import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

/** GET /auth/logout — clears Supabase session and redirects home. */
export async function GET(request: NextRequest) {
  const origin = new URL(request.url).origin;

  if (
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  ) {
    try {
      const supabase = await createClient();
      await supabase.auth.signOut();
    } catch (error) {
      console.error("[auth/logout] signOut failed:", error);
    }
  }

  return NextResponse.redirect(`${origin}/`);
}
