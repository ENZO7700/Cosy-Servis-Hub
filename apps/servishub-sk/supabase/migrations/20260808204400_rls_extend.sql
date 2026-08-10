-- ServisHub SK — RLS extend for payments, payouts, disputes, messages, notifications

ALTER TABLE IF EXISTS payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS notifications ENABLE ROW LEVEL SECURITY;

-- Helper: current profile id
-- (inline subqueries keep policies portable without custom functions)

-- Payments: booking parties can read; inserts via service role / trusted server
DROP POLICY IF EXISTS "payments_party_read" ON payments;
CREATE POLICY "payments_party_read" ON payments
  FOR SELECT TO authenticated
  USING (
    booking_id IN (
      SELECT b.id FROM bookings b
      WHERE b.customer_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
         OR b.provider_id IN (
           SELECT pr.id FROM providers pr
           JOIN profiles p ON p.id = pr.profile_id
           WHERE p.user_id = auth.uid()::text
         )
    )
    OR EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = auth.uid()::text AND p.role = 'ADMIN')
  );

-- Payouts: provider owns; admin read
DROP POLICY IF EXISTS "payouts_owner_read" ON payouts;
CREATE POLICY "payouts_owner_read" ON payouts
  FOR SELECT TO authenticated
  USING (
    provider_id IN (
      SELECT pr.id FROM providers pr
      JOIN profiles p ON p.id = pr.profile_id
      WHERE p.user_id = auth.uid()::text
    )
    OR EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = auth.uid()::text AND p.role = 'ADMIN')
  );

-- Disputes: parties on booking + opener; admin all
DROP POLICY IF EXISTS "disputes_party_read" ON disputes;
CREATE POLICY "disputes_party_read" ON disputes
  FOR SELECT TO authenticated
  USING (
    opened_by_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
    OR booking_id IN (
      SELECT b.id FROM bookings b
      WHERE b.customer_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
         OR b.provider_id IN (
           SELECT pr.id FROM providers pr
           JOIN profiles p ON p.id = pr.profile_id
           WHERE p.user_id = auth.uid()::text
         )
    )
    OR EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = auth.uid()::text AND p.role = 'ADMIN')
  );

DROP POLICY IF EXISTS "disputes_party_insert" ON disputes;
CREATE POLICY "disputes_party_insert" ON disputes
  FOR INSERT TO authenticated
  WITH CHECK (
    opened_by_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
    AND booking_id IN (
      SELECT b.id FROM bookings b
      WHERE b.customer_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
         OR b.provider_id IN (
           SELECT pr.id FROM providers pr
           JOIN profiles p ON p.id = pr.profile_id
           WHERE p.user_id = auth.uid()::text
         )
    )
  );

-- Messages: sender or booking party
DROP POLICY IF EXISTS "messages_party_read" ON messages;
CREATE POLICY "messages_party_read" ON messages
  FOR SELECT TO authenticated
  USING (
    sender_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
    OR booking_id IN (
      SELECT b.id FROM bookings b
      WHERE b.customer_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
         OR b.provider_id IN (
           SELECT pr.id FROM providers pr
           JOIN profiles p ON p.id = pr.profile_id
           WHERE p.user_id = auth.uid()::text
         )
    )
    OR EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = auth.uid()::text AND p.role = 'ADMIN')
  );

DROP POLICY IF EXISTS "messages_sender_insert" ON messages;
CREATE POLICY "messages_sender_insert" ON messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text)
  );

-- Notifications: own rows only
DROP POLICY IF EXISTS "notifications_own" ON notifications;
CREATE POLICY "notifications_own" ON notifications
  FOR ALL TO authenticated
  USING (user_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text))
  WITH CHECK (user_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()::text));
