import { z } from "zod";

const optionalPrice = z.preprocess(
  (value) => (value === "" || value === null || value === undefined ? undefined : value),
  z.coerce
    .number()
    .min(0, "Cena nemôže byť záporná")
    .max(999999, "Cena je príliš vysoká")
    .optional(),
);

const optionalDuration = z.preprocess(
  (value) => (value === "" || value === null || value === undefined ? undefined : value),
  z.coerce
    .number()
    .int("Trvanie musí byť celé číslo")
    .min(15, "Minimálne 15 minút")
    .max(1440, "Maximálne 24 hodín")
    .optional(),
);

export const serviceSchema = z
  .object({
    title: z
      .string()
      .trim()
      .min(3, "Zadajte názov služby (min. 3 znaky)")
      .max(80, "Názov je príliš dlhý (max. 80 znakov)"),
    description: z
      .string()
      .trim()
      .max(2000, "Popis je príliš dlhý (max. 2000 znakov)")
      .optional()
      .or(z.literal("")),
    categoryId: z.string().min(1, "Vyberte kategóriu"),
    priceFrom: optionalPrice,
    priceTo: optionalPrice,
    durationMin: optionalDuration,
    isActive: z.boolean(),
  })
  .refine(
    (data) =>
      data.priceFrom === undefined ||
      data.priceTo === undefined ||
      data.priceTo >= data.priceFrom,
    { message: "Cena do musí byť väčšia alebo rovná cene od", path: ["priceTo"] },
  );

export type ServiceInput = z.infer<typeof serviceSchema>;
