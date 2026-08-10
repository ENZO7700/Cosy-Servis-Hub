/**
 * Seed — Bratislava cleaning categories + optional E2E demo users.
 *
 *   pnpm db:seed
 *
 * Requires DIRECT_URL or DATABASE_URL.
 * Demo provider/customer require SUPABASE_SERVICE_ROLE_KEY + E2E_*_PASSWORD.
 */
import { config as loadEnv } from "dotenv";
import { createClient } from "@supabase/supabase-js";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../src/generated/prisma/client";

loadEnv({ path: ".env.local" });
loadEnv();

const CATEGORIES = [
  {
    name: "Upratovanie",
    slug: "upratovanie",
    description: "Domáce a kancelárske upratovanie v Bratislave a okolí.",
    icon: "sparkles",
    sortOrder: 10,
  },
  {
    name: "Hĺbkové upratovanie",
    slug: "hlbkove-upratovanie",
    description: "Jednorazové hĺbkové upratovanie bytov a domov.",
    icon: "home",
    sortOrder: 20,
  },
  {
    name: "Upratovanie po renovácie",
    slug: "upratovanie-po-renovacii",
    description: "Odstránenie stavebného prachu a príprava na odovzdanie.",
    icon: "hammer",
    sortOrder: 30,
  },
  {
    name: "Umývanie okien",
    slug: "umyvanie-okien",
    description: "Interiérové a exterérové umývanie okien.",
    icon: "droplets",
    sortOrder: 40,
  },
  {
    name: "Údržba domácnosti",
    slug: "udrzba-domacnosti",
    description: "Drobná údržba a pomoc v domácnosti.",
    icon: "wrench",
    sortOrder: 50,
  },
] as const;

const DEMO_PROVIDER_SLUG = "e2e-upratovanie-ba";
const WEEKDAY_AVAILABILITY = [
  { dayOfWeek: 1, startTime: "08:00", endTime: "17:00" },
  { dayOfWeek: 2, startTime: "08:00", endTime: "17:00" },
  { dayOfWeek: 3, startTime: "08:00", endTime: "17:00" },
  { dayOfWeek: 4, startTime: "08:00", endTime: "17:00" },
  { dayOfWeek: 5, startTime: "08:00", endTime: "17:00" },
] as const;

function isUsableConnectionString(value: string | undefined): value is string {
  if (!value) return false;
  return !/YOUR_PROJECT|PASSWORD|your-anon|placeholder/i.test(value);
}

function requireEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`[seed] missing env ${name}`);
  }
  return value;
}

async function ensureAuthUser(input: {
  email: string;
  password: string;
  fullName: string;
  role: "CUSTOMER" | "PROVIDER";
}): Promise<string> {
  const url = requireEnv("NEXT_PUBLIC_SUPABASE_URL");
  const serviceRole = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const admin = createClient(url, serviceRole, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const created = await admin.auth.admin.createUser({
    email: input.email,
    password: input.password,
    email_confirm: true,
    user_metadata: {
      full_name: input.fullName,
      role: input.role,
    },
  });

  if (!created.error && created.data.user?.id) {
    return created.data.user.id;
  }

  const message = created.error?.message ?? "";
  if (!/already|registered|exists/i.test(message)) {
    throw new Error(
      `[seed] createUser ${input.email} failed: ${message || "unknown"}`,
    );
  }

  const listed = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
  if (listed.error) {
    throw new Error(`[seed] listUsers failed: ${listed.error.message}`);
  }
  const existing = listed.data.users.find(
    (user) => user.email?.toLowerCase() === input.email.toLowerCase(),
  );
  if (!existing) {
    throw new Error(
      `[seed] user ${input.email} reported as existing but not found via listUsers`,
    );
  }

  const updated = await admin.auth.admin.updateUserById(existing.id, {
    password: input.password,
    email_confirm: true,
    user_metadata: {
      full_name: input.fullName,
      role: input.role,
    },
  });
  if (updated.error) {
    throw new Error(
      `[seed] updateUser ${input.email} failed: ${updated.error.message}`,
    );
  }
  return existing.id;
}

async function seedDemoFixtures(prisma: PrismaClient): Promise<void> {
  const providerPassword = process.env.E2E_PROVIDER_PASSWORD?.trim();
  const customerPassword = process.env.E2E_CUSTOMER_PASSWORD?.trim();
  const serviceRole = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

  if (!providerPassword || !customerPassword || !serviceRole) {
    console.warn(
      "[seed] skip demo users — set SUPABASE_SERVICE_ROLE_KEY, E2E_PROVIDER_PASSWORD, E2E_CUSTOMER_PASSWORD",
    );
    return;
  }

  const providerEmail =
    process.env.E2E_PROVIDER_EMAIL?.trim() || "e2e-provider@example.com";
  const customerEmail =
    process.env.E2E_CUSTOMER_EMAIL?.trim() || "e2e-customer@example.com";

  const providerUserId = await ensureAuthUser({
    email: providerEmail,
    password: providerPassword,
    fullName: "E2E Provider",
    role: "PROVIDER",
  });
  const customerUserId = await ensureAuthUser({
    email: customerEmail,
    password: customerPassword,
    fullName: "E2E Customer",
    role: "CUSTOMER",
  });

  const providerProfile = await prisma.profile.upsert({
    where: { userId: providerUserId },
    create: {
      userId: providerUserId,
      email: providerEmail,
      fullName: "E2E Provider",
      role: "PROVIDER",
    },
    update: {
      email: providerEmail,
      fullName: "E2E Provider",
      role: "PROVIDER",
    },
  });

  await prisma.profile.upsert({
    where: { userId: customerUserId },
    create: {
      userId: customerUserId,
      email: customerEmail,
      fullName: "E2E Customer",
      role: "CUSTOMER",
    },
    update: {
      email: customerEmail,
      fullName: "E2E Customer",
      role: "CUSTOMER",
    },
  });

  const category = await prisma.category.findUnique({
    where: { slug: "upratovanie" },
  });
  if (!category) {
    throw new Error("[seed] category upratovanie missing after category upsert");
  }

  const provider = await prisma.provider.upsert({
    where: { slug: DEMO_PROVIDER_SLUG },
    create: {
      profileId: providerProfile.id,
      businessName: "E2E Upratovanie BA",
      slug: DEMO_PROVIDER_SLUG,
      bio: "Demo profesionál pre Playwright E2E — Bratislava upratovanie.",
      ico: "12345678",
      city: "Bratislava",
      postalCode: "81101",
      verificationStatus: "VERIFIED",
      isActive: true,
      categories: { connect: [{ id: category.id }] },
    },
    update: {
      profileId: providerProfile.id,
      businessName: "E2E Upratovanie BA",
      bio: "Demo profesionál pre Playwright E2E — Bratislava upratovanie.",
      ico: "12345678",
      city: "Bratislava",
      postalCode: "81101",
      verificationStatus: "VERIFIED",
      isActive: true,
      categories: { set: [{ id: category.id }] },
    },
  });

  const existingService = await prisma.service.findFirst({
    where: { providerId: provider.id, title: "Základné upratovanie bytu" },
  });

  const service =
    existingService ??
    (await prisma.service.create({
      data: {
        providerId: provider.id,
        categoryId: category.id,
        title: "Základné upratovanie bytu",
        description: "2–3 izby, kuchyňa, kúpeľňa. Demo E2E služba.",
        priceFrom: 45,
        priceTo: 75,
        currency: "EUR",
        durationMin: 120,
        isActive: true,
      },
    }));

  if (existingService) {
    await prisma.service.update({
      where: { id: existingService.id },
      data: {
        categoryId: category.id,
        description: "2–3 izby, kuchyňa, kúpeľňa. Demo E2E služba.",
        priceFrom: 45,
        priceTo: 75,
        durationMin: 120,
        isActive: true,
      },
    });
  }

  await prisma.availability.deleteMany({ where: { providerId: provider.id } });
  await prisma.availability.createMany({
    data: WEEKDAY_AVAILABILITY.map((row) => ({
      providerId: provider.id,
      dayOfWeek: row.dayOfWeek,
      startTime: row.startTime,
      endTime: row.endTime,
      isActive: true,
    })),
  });

  console.info(
    `[seed] demo fixtures ready — provider=${providerEmail} customer=${customerEmail} slug=${DEMO_PROVIDER_SLUG} service=${service.id}`,
  );
}

async function main() {
  const connectionString = process.env.DIRECT_URL ?? process.env.DATABASE_URL;
  if (!isUsableConnectionString(connectionString)) {
    throw new Error(
      "[seed] set a real DIRECT_URL (or DATABASE_URL) in .env.local — placeholder rejected",
    );
  }

  const adapter = new PrismaPg({ connectionString });
  const prisma = new PrismaClient({ adapter });

  try {
    for (const category of CATEGORIES) {
      await prisma.category.upsert({
        where: { slug: category.slug },
        create: { ...category },
        update: {
          name: category.name,
          description: category.description,
          icon: category.icon,
          sortOrder: category.sortOrder,
        },
      });
    }
    console.info(`[seed] upserted ${CATEGORIES.length} categories`);
    await seedDemoFixtures(prisma);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error("[seed] failed:", error);
  process.exit(1);
});
