import { z } from "zod";

const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max, `Príliš dlhé (max. ${max} znakov)`)
    .optional()
    .or(z.literal(""));

export const providerProfileSchema = z.object({
  businessName: z
    .string()
    .trim()
    .min(2, "Zadajte názov firmy (min. 2 znaky)")
    .max(80, "Názov je príliš dlhý (max. 80 znakov)"),
  bio: optionalText(1000),
  ico: z
    .string()
    .trim()
    .regex(/^\d{8}$/, "IČO musí mať presne 8 číslic")
    .optional()
    .or(z.literal("")),
  dic: z
    .string()
    .trim()
    .regex(/^\d{10}$/, "DIČ musí mať presne 10 číslic")
    .optional()
    .or(z.literal("")),
  city: optionalText(60),
  postalCode: z
    .string()
    .trim()
    .regex(/^\d{3}\s?\d{2}$/, "PSČ vo formáte 811 01")
    .optional()
    .or(z.literal("")),
  categoryIds: z.array(z.string().min(1)).max(10, "Vyberte najviac 10 kategórií"),
});

export type ProviderProfileInput = z.infer<typeof providerProfileSchema>;
