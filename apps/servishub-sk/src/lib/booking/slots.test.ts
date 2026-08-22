import { describe, expect, it } from "vitest";
import {
  dayOfWeekForDate,
  formatDateDisplaySk,
  generateDaySlots,
  getNextAvailableSlot,
  isValidDateString,
  isValidTimeString,
  localTimeExists,
  minutesToTime,
  rangesOverlap,
  timeToMinutes,
  zonedTimeToUtc,
} from "./slots";

describe("time helpers", () => {
  it("parses and formats HH:mm", () => {
    expect(timeToMinutes("09:30")).toBe(570);
    expect(minutesToTime(570)).toBe("09:30");
  });

  it("rejects invalid time strings", () => {
    expect(isValidTimeString("9:00")).toBe(false);
    expect(isValidTimeString("24:00")).toBe(false);
    expect(() => timeToMinutes("99:99")).toThrow(/Invalid time/);
  });

  it("validates calendar dates", () => {
    expect(isValidDateString("2026-08-10")).toBe(true);
    expect(isValidDateString("2026-02-30")).toBe(false);
    expect(isValidDateString("10.08.2026")).toBe(false);
  });

  it("detects day of week from yyyy-MM-dd", () => {
    // 2026-08-10 is a Monday
    expect(dayOfWeekForDate("2026-08-10")).toBe(1);
  });

  it("converts Bratislava winter wall time to UTC (CET = UTC+1)", () => {
    const utc = zonedTimeToUtc("2026-01-15", "10:00");
    expect(utc.toISOString()).toBe("2026-01-15T09:00:00.000Z");
  });

  it("converts Bratislava summer wall time to UTC (CEST = UTC+2)", () => {
    const utc = zonedTimeToUtc("2026-07-15", "10:00");
    expect(utc.toISOString()).toBe("2026-07-15T08:00:00.000Z");
  });

  it("detects nonexistent wall times in spring-forward DST gap", () => {
    // EU spring forward 2026-03-29: 02:00 → 03:00, so 02:30 does not exist.
    expect(localTimeExists("2026-03-29", "02:30")).toBe(false);
    expect(localTimeExists("2026-03-29", "03:30")).toBe(true);
  });
});

describe("rangesOverlap", () => {
  it("treats adjacent half-open ranges as non-overlapping", () => {
    const aStart = new Date("2026-08-10T08:00:00Z");
    const aEnd = new Date("2026-08-10T09:00:00Z");
    const bStart = new Date("2026-08-10T09:00:00Z");
    const bEnd = new Date("2026-08-10T10:00:00Z");
    expect(rangesOverlap(aStart, aEnd, bStart, bEnd)).toBe(false);
  });

  it("detects partial overlap", () => {
    const aStart = new Date("2026-08-10T08:00:00Z");
    const aEnd = new Date("2026-08-10T09:30:00Z");
    const bStart = new Date("2026-08-10T09:00:00Z");
    const bEnd = new Date("2026-08-10T10:00:00Z");
    expect(rangesOverlap(aStart, aEnd, bStart, bEnd)).toBe(true);
  });
});

describe("generateDaySlots", () => {
  it("generates Europe/Bratislava slots and excludes booked overlaps", () => {
    const date = "2026-08-10"; // Monday
    const windows = [{ dayOfWeek: 1, startTime: "09:00", endTime: "12:00" }];
    const bookedStart = zonedTimeToUtc(date, "10:00");
    const bookedEnd = zonedTimeToUtc(date, "11:00");

    const slots = generateDaySlots({
      date,
      windows,
      durationMin: 60,
      booked: [{ start: bookedStart, end: bookedEnd }],
      now: zonedTimeToUtc("2026-08-01", "08:00"),
      minLeadMin: 0,
    });

    expect(slots.map((s) => s.startTime)).toEqual(["09:00", "10:00", "11:00"]);
    expect(slots.find((s) => s.startTime === "09:00")?.isAvailable).toBe(true);
    expect(slots.find((s) => s.startTime === "10:00")?.isAvailable).toBe(false);
    expect(slots.find((s) => s.startTime === "11:00")?.isAvailable).toBe(true);
  });

  it("marks past slots unavailable with lead time", () => {
    const date = "2026-08-10";
    const slots = generateDaySlots({
      date,
      windows: [{ dayOfWeek: 1, startTime: "09:00", endTime: "11:00" }],
      durationMin: 60,
      now: zonedTimeToUtc(date, "09:30"),
      minLeadMin: 60,
    });

    expect(slots.every((s) => !s.isAvailable)).toBe(true);
  });

  it("returns empty for invalid date, zero duration, or wrong weekday windows", () => {
    expect(
      generateDaySlots({
        date: "bad",
        windows: [{ dayOfWeek: 1, startTime: "09:00", endTime: "12:00" }],
        durationMin: 60,
      }),
    ).toEqual([]);
    expect(
      generateDaySlots({
        date: "2026-08-10",
        windows: [{ dayOfWeek: 1, startTime: "09:00", endTime: "12:00" }],
        durationMin: 0,
      }),
    ).toEqual([]);
    expect(
      generateDaySlots({
        date: "2026-08-10", // Monday
        windows: [{ dayOfWeek: 2, startTime: "09:00", endTime: "12:00" }],
        durationMin: 60,
      }),
    ).toEqual([]);
  });
});

describe("getNextAvailableSlot", () => {
  it("returns the first available slot or null", () => {
    const slots = generateDaySlots({
      date: "2026-08-10",
      windows: [{ dayOfWeek: 1, startTime: "09:00", endTime: "11:00" }],
      durationMin: 60,
      now: zonedTimeToUtc("2026-08-01", "08:00"),
    });
    expect(getNextAvailableSlot(slots)?.startTime).toBe("09:00");
    expect(getNextAvailableSlot([])).toBeNull();
  });
});

describe("formatDateDisplaySk", () => {
  it("returns a Slovak long date label", () => {
    const label = formatDateDisplaySk("2026-08-10");
    expect(label.toLowerCase()).toContain("2026");
    expect(label.toLowerCase()).toMatch(/august/);
  });
});
