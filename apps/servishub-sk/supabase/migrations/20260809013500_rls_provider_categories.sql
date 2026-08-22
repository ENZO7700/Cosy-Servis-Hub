-- ServisHub SK — RLS for Provider↔Category join table (T1)
-- Applied via Supabase migrations. Prisma (direct Postgres) bypasses RLS.

ALTER TABLE IF EXISTS "_CategoryToProvider" ENABLE ROW LEVEL SECURITY;

-- Public read: category labels on public provider profiles
DROP POLICY IF EXISTS "category_to_provider_public_read" ON "_CategoryToProvider";
CREATE POLICY "category_to_provider_public_read" ON "_CategoryToProvider"
  FOR SELECT TO anon, authenticated
  USING (true);

-- Provider manages own category links (column "B" = providers.id)
DROP POLICY IF EXISTS "category_to_provider_owner_all" ON "_CategoryToProvider";
CREATE POLICY "category_to_provider_owner_all" ON "_CategoryToProvider"
  FOR ALL TO authenticated
  USING (
    "B" IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  )
  WITH CHECK (
    "B" IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  );
