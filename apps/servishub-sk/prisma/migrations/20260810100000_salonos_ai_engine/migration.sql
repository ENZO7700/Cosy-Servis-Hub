-- SALONOS AI revenue attribution and return-engine signals.
CREATE TYPE "AiEngineSource" AS ENUM ('SLOT_FILLER', 'RETURN_ENGINE', 'AI_RECEPTIONIST');

CREATE TABLE "ai_revenue_logs" (
    "id" TEXT NOT NULL,
    "provider_id" TEXT NOT NULL,
    "booking_id" TEXT,
    "source" "AiEngineSource" NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ai_revenue_logs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "client_profile_ai" (
    "id" TEXT NOT NULL,
    "profile_id" TEXT NOT NULL,
    "provider_id" TEXT,
    "average_days_gap" INTEGER NOT NULL DEFAULT 28,
    "last_visit_at" TIMESTAMP(3),
    "next_predicted_at" TIMESTAMP(3),
    "preferred_barber" TEXT,
    "is_risk_of_loss" BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT "client_profile_ai_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "client_profile_ai_profile_id_key" ON "client_profile_ai"("profile_id");
CREATE INDEX "ai_revenue_logs_provider_id_idx" ON "ai_revenue_logs"("provider_id");
CREATE INDEX "ai_revenue_logs_provider_id_created_at_idx" ON "ai_revenue_logs"("provider_id", "created_at");
CREATE INDEX "ai_revenue_logs_source_idx" ON "ai_revenue_logs"("source");
CREATE INDEX "client_profile_ai_provider_id_idx" ON "client_profile_ai"("provider_id");
CREATE INDEX "client_profile_ai_last_visit_at_idx" ON "client_profile_ai"("last_visit_at");
CREATE INDEX "client_profile_ai_is_risk_of_loss_idx" ON "client_profile_ai"("is_risk_of_loss");

ALTER TABLE "ai_revenue_logs"
  ADD CONSTRAINT "ai_revenue_logs_provider_id_fkey"
  FOREIGN KEY ("provider_id") REFERENCES "providers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "client_profile_ai"
  ADD CONSTRAINT "client_profile_ai_profile_id_fkey"
  FOREIGN KEY ("profile_id") REFERENCES "profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "client_profile_ai"
  ADD CONSTRAINT "client_profile_ai_provider_id_fkey"
  FOREIGN KEY ("provider_id") REFERENCES "providers"("id") ON DELETE CASCADE ON UPDATE CASCADE;