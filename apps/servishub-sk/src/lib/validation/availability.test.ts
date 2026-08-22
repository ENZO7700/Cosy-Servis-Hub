import { describe, expect, it } from "vitest";
import {
  availabilityFormSchema,
  availabilityWindowSchema,
} from "./availability";

describe("availabilityWindowSchema", () => {
  it("requires end after start", () => {
    expect(
      availabilityWindowSchema.safeParse({
        dayOfWeek: 1,
        startTime: "10:00",
        endTime: "09:00",
      }).success,
    ).toBe(false);
    expect(
      availabilityWindowSchema.safeParse({
        dayOfWeek: 1,
        startTime: "09:00",
        endTime: "10:00",
      }).success,
    ).toBe(true);
  });

  it("rejects dayOfWeek outside 0–6", () => {
    expect(
      availabilityWindowSchema.safeParse({
        dayOfWeek: 7,
        startTime: "09:00",
        endTime: "10:00",
      }).success,
    ).toBe(false);
  });
});

describe("availabilityFormSchema", () => {
  it("allows adjacent windows on the same day", () => {
    expect(
      availabilityFormSchema.safeParse([
        { dayOfWeek: 1, startTime: "09:00", endTime: "12:00" },
        { dayOfWeek: 1, startTime: "12:00", endTime: "15:00" },
      ]).success,
    ).toBe(true);
  });

  it("rejects overlapping windows on the same day", () => {
    expect(
      availabilityFormSchema.safeParse([
        { dayOfWeek: 1, startTime: "09:00", endTime: "12:00" },
        { dayOfWeek: 1, startTime: "11:00", endTime: "14:00" },
      ]).success,
    ).toBe(false);
  });

  it("rejects more than 14 windows", () => {
    const windows = Array.from({ length: 15 }, (_, i) => ({
      dayOfWeek: i % 7,
      startTime: "09:00",
      endTime: "10:00",
    }));
    expect(availabilityFormSchema.safeParse(windows).success).toBe(false);
  });
});
