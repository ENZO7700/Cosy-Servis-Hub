import { z } from "zod";
import { isValidDateString, isValidTimeString } from "@/lib/booking/slots";

export const bookingSchema = z.object({
  serviceId: z.string().min(1, "Vyberte službu"),
  date: z
    .string()
    .refine(isValidDateString, "Zadajte dátum vo formáte DD.MM.YYYY"),
  startTime: z
    .string()
    .refine(isValidTimeString, "Vyberte časový slot"),
  addressLine: z
    .string()
    .trim()
    .max(120, "Adresa je príliš dlhá (max. 120 znakov)")
    .optional()
    .or(z.literal("")),
  city: z
    .string()
    .trim()
    .max(60, "Názov mesta je príliš dlhý")
    .optional()
    .or(z.literal("")),
  postalCode: z
    .string()
    .trim()
    .max(10, "PSČ je príliš dlhé")
    .optional()
    .or(z.literal("")),
  notes: z
    .string()
    .trim()
    .max(1000, "Poznámka je príliš dlhá (max. 1000 znakov)")
    .optional()
    .or(z.literal("")),
});

export type BookingInput = z.infer<typeof bookingSchema>;
