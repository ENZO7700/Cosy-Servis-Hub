-- Schema gap: payments, payouts, disputes, messages, notifications + booking/provider/lead extensions

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('REQUIRES_PAYMENT_METHOD', 'REQUIRES_CONFIRMATION', 'REQUIRES_ACTION', 'PROCESSING', 'REQUIRES_CAPTURE', 'SUCCEEDED', 'CANCELED', 'FAILED');
CREATE TYPE "CaptureMethod" AS ENUM ('AUTOMATIC', 'MANUAL');
CREATE TYPE "PayoutStatus" AS ENUM ('PENDING', 'IN_TRANSIT', 'PAID', 'FAILED', 'CANCELED');
CREATE TYPE "DisputeStatus" AS ENUM ('OPEN', 'UNDER_REVIEW', 'RESOLVED_REFUND', 'RESOLVED_PARTIAL', 'RESOLVED_RELEASE', 'CLOSED');
CREATE TYPE "NotificationChannel" AS ENUM ('EMAIL', 'SMS', 'PUSH');
CREATE TYPE "NotificationStatus" AS ENUM ('PENDING', 'SENT', 'FAILED', 'READ');

-- AlterTable providers
ALTER TABLE "providers" ADD COLUMN IF NOT EXISTS "lat" DOUBLE PRECISION;
ALTER TABLE "providers" ADD COLUMN IF NOT EXISTS "lng" DOUBLE PRECISION;
ALTER TABLE "providers" ADD COLUMN IF NOT EXISTS "kyc_external_id" TEXT;
ALTER TABLE "providers" ADD COLUMN IF NOT EXISTS "insurance_doc_ref" TEXT;
ALTER TABLE "providers" ADD COLUMN IF NOT EXISTS "stripe_account_id" TEXT;
CREATE INDEX IF NOT EXISTS "providers_postal_code_idx" ON "providers"("postal_code");
CREATE INDEX IF NOT EXISTS "providers_lat_lng_idx" ON "providers"("lat", "lng");

-- AlterTable services
ALTER TABLE "services" ADD COLUMN IF NOT EXISTS "extras" JSONB;
ALTER TABLE "services" ADD COLUMN IF NOT EXISTS "featured_rank" INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS "services_category_id_is_active_price_from_idx" ON "services"("category_id", "is_active", "price_from");
CREATE INDEX IF NOT EXISTS "services_featured_rank_idx" ON "services"("featured_rank");

-- AlterTable bookings
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "deposit_amount" DECIMAL(10,2);
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "stripe_payment_intent_id" TEXT;
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "captured_at" TIMESTAMP(3);
CREATE UNIQUE INDEX IF NOT EXISTS "bookings_stripe_payment_intent_id_key" ON "bookings"("stripe_payment_intent_id");
CREATE INDEX IF NOT EXISTS "bookings_provider_id_scheduled_at_idx" ON "bookings"("provider_id", "scheduled_at");

-- AlterTable reviews
ALTER TABLE "reviews" ADD COLUMN IF NOT EXISTS "moderation_status" TEXT NOT NULL DEFAULT 'published';

-- AlterTable subscriptions
ALTER TABLE "subscriptions" ADD COLUMN IF NOT EXISTS "stripe_price_id" TEXT;

-- AlterTable leads
ALTER TABLE "leads" ADD COLUMN IF NOT EXISTS "credit_cost" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "leads" ADD COLUMN IF NOT EXISTS "unlocked_by_id" TEXT;
ALTER TABLE "leads" ADD COLUMN IF NOT EXISTS "expires_at" TIMESTAMP(3);
CREATE INDEX IF NOT EXISTS "leads_expires_at_idx" ON "leads"("expires_at");

-- CreateTable payments
CREATE TABLE IF NOT EXISTS "payments" (
    "id" TEXT NOT NULL,
    "booking_id" TEXT NOT NULL,
    "intent_id" TEXT NOT NULL,
    "capture_method" "CaptureMethod" NOT NULL DEFAULT 'AUTOMATIC',
    "amount" DECIMAL(10,2) NOT NULL,
    "application_fee" DECIMAL(10,2),
    "currency" TEXT NOT NULL DEFAULT 'EUR',
    "status" "PaymentStatus" NOT NULL DEFAULT 'REQUIRES_PAYMENT_METHOD',
    "stripe_charge_id" TEXT,
    "webhook_payload" JSONB,
    "captured_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "payments_booking_id_key" ON "payments"("booking_id");
CREATE UNIQUE INDEX IF NOT EXISTS "payments_intent_id_key" ON "payments"("intent_id");
CREATE INDEX IF NOT EXISTS "payments_status_idx" ON "payments"("status");

-- CreateTable payouts
CREATE TABLE IF NOT EXISTS "payouts" (
    "id" TEXT NOT NULL,
    "provider_id" TEXT NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'EUR',
    "status" "PayoutStatus" NOT NULL DEFAULT 'PENDING',
    "stripe_transfer_id" TEXT,
    "cadence" TEXT,
    "period_start" TIMESTAMP(3),
    "period_end" TIMESTAMP(3),
    "paid_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "payouts_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "payouts_stripe_transfer_id_key" ON "payouts"("stripe_transfer_id");
CREATE INDEX IF NOT EXISTS "payouts_provider_id_idx" ON "payouts"("provider_id");
CREATE INDEX IF NOT EXISTS "payouts_status_idx" ON "payouts"("status");

-- CreateTable disputes
CREATE TABLE IF NOT EXISTS "disputes" (
    "id" TEXT NOT NULL,
    "booking_id" TEXT NOT NULL,
    "opened_by_id" TEXT NOT NULL,
    "status" "DisputeStatus" NOT NULL DEFAULT 'OPEN',
    "reason" TEXT,
    "evidence" JSONB,
    "resolution" TEXT,
    "resolved_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "disputes_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "disputes_booking_id_key" ON "disputes"("booking_id");
CREATE INDEX IF NOT EXISTS "disputes_status_idx" ON "disputes"("status");
CREATE INDEX IF NOT EXISTS "disputes_opened_by_id_idx" ON "disputes"("opened_by_id");

-- CreateTable messages
CREATE TABLE IF NOT EXISTS "messages" (
    "id" TEXT NOT NULL,
    "thread_id" TEXT NOT NULL,
    "booking_id" TEXT,
    "sender_id" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "read_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "messages_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "messages_thread_id_created_at_idx" ON "messages"("thread_id", "created_at");
CREATE INDEX IF NOT EXISTS "messages_sender_id_idx" ON "messages"("sender_id");
CREATE INDEX IF NOT EXISTS "messages_booking_id_idx" ON "messages"("booking_id");

-- CreateTable notifications
CREATE TABLE IF NOT EXISTS "notifications" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "template" TEXT NOT NULL,
    "payload" JSONB,
    "status" "NotificationStatus" NOT NULL DEFAULT 'PENDING',
    "sent_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "notifications_user_id_status_idx" ON "notifications"("user_id", "status");
CREATE INDEX IF NOT EXISTS "notifications_channel_idx" ON "notifications"("channel");

-- ForeignKeys (idempotent-ish: drop if exists then add)
DO $$ BEGIN
  ALTER TABLE "leads" ADD CONSTRAINT "leads_unlocked_by_id_fkey" FOREIGN KEY ("unlocked_by_id") REFERENCES "profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "payments" ADD CONSTRAINT "payments_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "payouts" ADD CONSTRAINT "payouts_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "providers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "disputes" ADD CONSTRAINT "disputes_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "disputes" ADD CONSTRAINT "disputes_opened_by_id_fkey" FOREIGN KEY ("opened_by_id") REFERENCES "profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "messages" ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "messages" ADD CONSTRAINT "messages_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
