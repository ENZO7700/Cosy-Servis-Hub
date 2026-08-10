-- ServisHub SK — RLS policies
-- Applied via Supabase migrations. Prisma (direct Postgres) bypasses RLS.
-- Supabase anon/authenticated clients enforce these policies.

-- Enable RLS on public tables
ALTER TABLE IF EXISTS profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS services ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS service_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS leads ENABLE ROW LEVEL SECURITY;

-- Profiles: users read/update own row; admins read all
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text OR EXISTS (
    SELECT 1 FROM profiles p WHERE p.user_id = auth.uid()::text AND p.role = 'ADMIN'
  ));

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

-- Categories: public read
DROP POLICY IF EXISTS "categories_public_read" ON categories;
CREATE POLICY "categories_public_read" ON categories
  FOR SELECT TO anon, authenticated
  USING (true);

-- Providers: public read of active verified; owners manage own
DROP POLICY IF EXISTS "providers_public_read" ON providers;
CREATE POLICY "providers_public_read" ON providers
  FOR SELECT TO anon, authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS "providers_owner_all" ON providers;
CREATE POLICY "providers_owner_all" ON providers
  FOR ALL TO authenticated
  USING (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
  )
  WITH CHECK (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
  );

-- Services: public read active; provider manages own
DROP POLICY IF EXISTS "services_public_read" ON services;
CREATE POLICY "services_public_read" ON services
  FOR SELECT TO anon, authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS "services_provider_manage" ON services;
CREATE POLICY "services_provider_manage" ON services
  FOR ALL TO authenticated
  USING (
    provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  )
  WITH CHECK (
    provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  );

-- Service areas / availability: same ownership pattern
DROP POLICY IF EXISTS "service_areas_public_read" ON service_areas;
CREATE POLICY "service_areas_public_read" ON service_areas
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "service_areas_provider_manage" ON service_areas;
CREATE POLICY "service_areas_provider_manage" ON service_areas
  FOR ALL TO authenticated
  USING (
    provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  )
  WITH CHECK (
    provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  );

DROP POLICY IF EXISTS "availability_public_read" ON availability;
CREATE POLICY "availability_public_read" ON availability
  FOR SELECT TO anon, authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS "availability_provider_manage" ON availability;
CREATE POLICY "availability_provider_manage" ON availability
  FOR ALL TO authenticated
  USING (
    provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  )
  WITH CHECK (
    provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  );

-- Bookings: customer or provider party can read; customer creates
DROP POLICY IF EXISTS "bookings_party_read" ON bookings;
CREATE POLICY "bookings_party_read" ON bookings
  FOR SELECT TO authenticated
  USING (
    customer_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
    OR provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  );

DROP POLICY IF EXISTS "bookings_customer_insert" ON bookings;
CREATE POLICY "bookings_customer_insert" ON bookings
  FOR INSERT TO authenticated
  WITH CHECK (
    customer_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
  );

-- Reviews: public read; customer who booked can insert
DROP POLICY IF EXISTS "reviews_public_read" ON reviews;
CREATE POLICY "reviews_public_read" ON reviews
  FOR SELECT TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "reviews_customer_insert" ON reviews;
CREATE POLICY "reviews_customer_insert" ON reviews
  FOR INSERT TO authenticated
  WITH CHECK (
    customer_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
  );

-- Subscriptions: provider owns
DROP POLICY IF EXISTS "subscriptions_owner" ON subscriptions;
CREATE POLICY "subscriptions_owner" ON subscriptions
  FOR ALL TO authenticated
  USING (
    provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  )
  WITH CHECK (
    provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  );

-- Leads: provider sees assigned; customers see own
DROP POLICY IF EXISTS "leads_party_read" ON leads;
CREATE POLICY "leads_party_read" ON leads
  FOR SELECT TO authenticated
  USING (
    customer_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
    OR provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
  );
