import { z } from "zod";
import { isValidTimeString, timeToMinutes } from "@/lib/booking/slots";

const timeField = z
  .string()
  .refine(isValidTimeString, "Zadajte čas vo formáte HH:mm");

export const availabilityWindowSchema = z
  .object({
    dayOfWeek: z
      .number()
      .int("Deň musí byť celé číslo")
      .min(0, "Neplatný deň v týždni")
      .max(6, "Neplatný deň v týždni"),
    startTime: timeField,
    endTime: timeField,
  })
  .refine((window) => timeToMinutes(window.endTime) > timeToMinutes(window.startTime), {
    message: "Koniec okna musí byť po začiatku",
    path: ["endTime"],
  });

export const availabilityFormSchema = z
  .array(availabilityWindowSchema)
  .max(14, "Maximálne 14 okien týždenne")
  .refine(
    (windows) => {
      const byDay = new Map<number, { start: number; end: number }[]>();
      for (const window of windows) {
        const ranges = byDay.get(window.dayOfWeek) ?? [];
        const next = {
          start: timeToMinutes(window.startTime),
          end: timeToMinutes(window.endTime),
        };
        // Half-open overlap: [a.start, a.end) vs [b.start, b.end)
        if (
          ranges.some(
            (range) => next.start < range.end && range.start < next.end,
          )
        ) {
          return false;
        }
        ranges.push(next);
        byDay.set(window.dayOfWeek, ranges);
      }
      return true;
    },
    { message: "Okná v rovnaký deň sa nesmú prekrývať" },
  );

export type AvailabilityWindowInput = z.infer<typeof availabilityWindowSchema>;
