-- Preserve existing provider and client preference data while introducing
-- the industry-neutral SALONOS business profile foundation.
CREATE TYPE "BusinessType" AS ENUM (
  'BEAUTY',
  'HEALTH_WELLNESS',
  'HOME_SERVICES',
  'AUTOMOTIVE',
  'PROFESSIONAL_SERVICES',
  'OTHER'
);

ALTER TABLE "providers"
  ADD COLUMN "business_type" "BusinessType" NOT NULL DEFAULT 'OTHER';

ALTER TABLE "client_profile_ai"
  RENAME COLUMN "preferred_barber" TO "preferred_team_member";
