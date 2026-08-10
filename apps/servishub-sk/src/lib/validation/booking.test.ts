import { describe, expect, it } from "vitest";
import { bookingSchema } from "./booking";

const valid = {
  serviceId: "svc_1",
  date: "2026-08-10",
  startTime: "09:00",
  addressLine: "",
  city: "",
  postalCode: "",
  notes: "",
};

describe("bookingSchema", () => {
  it("accepts a valid payload", () => {
    expect(bookingSchema.safeParse(valid).success).toBe(true);
  });

  it("rejects invalid date and time", () => {
    expect(
      bookingSchema.safeParse({ ...valid, date: "10.08.2026" }).success,
    ).toBe(false);
    expect(
      bookingSchema.safeParse({ ...valid, date: "2026-02-30" }).success,
    ).toBe(false);
    expect(
      bookingSchema.safeParse({ ...valid, startTime: "9:00" }).success,
    ).toBe(false);
  });

  it("rejects oversized address and notes", () => {
    expect(
      bookingSchema.safeParse({ ...valid, addressLine: "x".repeat(121) })
        .success,
    ).toBe(false);
    expect(
      bookingSchema.safeParse({ ...valid, notes: "n".repeat(1001) }).success,
    ).toBe(false);
  });

  it("allows empty optional strings", () => {
    const result = bookingSchema.safeParse(valid);
    expect(result.success).toBe(true);
  });
});
