/**
 * Slot generation and overlap logic for bookings.
 *
 * Adapted from mistral-booking-whitelabel `calendar.utils.ts` — the core ideas
 * (slots stepped by service duration, half-open interval overlap `[start, end)`)
 * are kept, but this version is timezone-correct: all provider-facing times are
 * Europe/Bratislava wall-clock times, converted to UTC `Date`s for storage and
 * comparison. No date library — Intl only, so the logic is pure and testable.
 */

export const BOOKING_TIMEZONE = "Europe/Bratislava";

/** Weekly recurring availability window (dayOfWeek: 0 = Sunday … 6 = Saturday). */
export type WeeklyWindow = {
  dayOfWeek: number;
  startTime: string; // HH:mm, local (BOOKING_TIMEZONE)
  endTime: string; // HH:mm, local (BOOKING_TIMEZONE)
};

/** Already-reserved time range in absolute time (UTC instants). */
export type BookedRange = {
  start: Date;
  end: Date;
};

export type Slot = {
  /** Absolute start/end instants — store `start` in Booking.scheduledAt. */
  start: Date;
  end: Date;
  /** Local wall-clock labels (HH:mm) for display and round-trip validation. */
  startTime: string;
  endTime: string;
  isPast: boolean;
  isBooked: boolean;
  isAvailable: boolean;
};

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

export function isValidTimeString(time: string): boolean {
  return TIME_RE.test(time);
}

/** Parse "HH:mm" to minutes from midnight. Throws on invalid input. */
export function timeToMinutes(time: string): number {
  if (!TIME_RE.test(time)) {
    throw new Error(`Invalid time string: ${time}`);
  }
  const [hours, minutes] = time.split(":").map(Number);
  return hours * 60 + minutes;
}

/** Format minutes from midnight as "HH:mm". */
export function minutesToTime(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return `${String(hours).padStart(2, "0")}:${String(mins).padStart(2, "0")}`;
}

/**
 * Half-open interval overlap: [aStart, aEnd) overlaps [bStart, bEnd)
 * iff aStart < bEnd AND bStart < aEnd. Adjacent ranges (10:00–11:00 vs
 * 11:00–12:00) do NOT overlap — same rule as the DB EXCLUDE constraint
 * on tstzrange(..., '[)') documented in supabase/migrations.
 */
export function rangesOverlap(
  aStart: Date,
  aEnd: Date,
  bStart: Date,
  bEnd: Date,
): boolean {
  return (
    aStart.getTime() < bEnd.getTime() && bStart.getTime() < aEnd.getTime()
  );
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function isValidDateString(date: string): boolean {
  if (!DATE_RE.test(date)) return false;
  const parsed = new Date(`${date}T00:00:00Z`);
  return !Number.isNaN(parsed.getTime()) && formatDateUtc(parsed) === date;
}

function formatDateUtc(date: Date): string {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * Day of week (0 = Sunday … 6 = Saturday) for a calendar date string.
 * Uses UTC noon so the result is independent of the host timezone.
 */
export function dayOfWeekForDate(date: string): number {
  return new Date(`${date}T12:00:00Z`).getUTCDay();
}

type ZonedParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
};

const zonedFormatters = new Map<string, Intl.DateTimeFormat>();

function getZonedFormatter(timeZone: string): Intl.DateTimeFormat {
  let formatter = zonedFormatters.get(timeZone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat("en-US", {
      timeZone,
      hour12: false,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
    zonedFormatters.set(timeZone, formatter);
  }
  return formatter;
}

function zonedPartsAt(utcDate: Date, timeZone: string): ZonedParts {
  const parts = getZonedFormatter(timeZone).formatToParts(utcDate);
  const values: Record<string, number> = {};
  for (const part of parts) {
    if (part.type !== "literal") values[part.type] = Number(part.value);
  }
  // "en-US" hour cycle can report 24 for midnight — normalise to 0.
  return {
    year: values.year,
    month: values.month,
    day: values.day,
    hour: values.hour % 24,
    minute: values.minute,
  };
}

/** Offset (ms) that must be added to UTC to get wall time in `timeZone`. */
function zoneOffsetMs(utcDate: Date, timeZone: string): number {
  const parts = zonedPartsAt(utcDate, timeZone);
  const asUtc = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
  );
  return asUtc - Math.floor(utcDate.getTime() / 60000) * 60000;
}

/**
 * Convert a wall-clock date+time in `timeZone` to the UTC instant.
 * Double-pass handles the offset changing across the target instant (DST).
 * Nonexistent wall times (spring-forward gap) resolve to the shifted instant —
 * callers that care can detect this via {@link localTimeExists}.
 */
export function zonedTimeToUtc(
  date: string,
  time: string,
  timeZone: string = BOOKING_TIMEZONE,
): Date {
  if (!isValidDateString(date) || !isValidTimeString(time)) {
    throw new Error(`Invalid zoned time: ${date} ${time}`);
  }
  const guess = new Date(`${date}T${time}:00Z`);
  const first = new Date(guess.getTime() - zoneOffsetMs(guess, timeZone));
  return new Date(guess.getTime() - zoneOffsetMs(first, timeZone));
}

/** True when the wall-clock time exists in the zone (false inside DST gaps). */
export function localTimeExists(
  date: string,
  time: string,
  timeZone: string = BOOKING_TIMEZONE,
): boolean {
  const utc = zonedTimeToUtc(date, time, timeZone);
  const parts = zonedPartsAt(utc, timeZone);
  const [hour, minute] = time.split(":").map(Number);
  return (
    formatDateUtcSafe(parts) === date && parts.hour === hour && parts.minute === minute
  );
}

function formatDateUtcSafe(parts: ZonedParts): string {
  const m = String(parts.month).padStart(2, "0");
  const d = String(parts.day).padStart(2, "0");
  return `${parts.year}-${m}-${d}`;
}

/** Format an instant as "HH:mm" wall time in the booking timezone. */
export function formatZonedTime(
  instant: Date,
  timeZone: string = BOOKING_TIMEZONE,
): string {
  const parts = zonedPartsAt(instant, timeZone);
  return minutesToTime(parts.hour * 60 + parts.minute);
}

/** Format an instant as "yyyy-MM-dd" in the booking timezone. */
export function formatZonedDate(
  instant: Date,
  timeZone: string = BOOKING_TIMEZONE,
): string {
  return formatDateUtcSafe(zonedPartsAt(instant, timeZone));
}

/** "yyyy-MM-dd" today in the booking timezone. */
export function todayInZone(timeZone: string = BOOKING_TIMEZONE): string {
  return formatZonedDate(new Date(), timeZone);
}

export type GenerateSlotsOptions = {
  /** Calendar date "yyyy-MM-dd" in the booking timezone. */
  date: string;
  /** Weekly windows; only those matching the date's dayOfWeek are used. */
  windows: WeeklyWindow[];
  /** Service duration in minutes — also the slot step (mistral pattern). */
  durationMin: number;
  /** Active bookings overlapping the day, as absolute ranges. */
  booked?: BookedRange[];
  /** Reference instant for past filtering (defaults to now). */
  now?: Date;
  /** Minimum lead time in minutes before a slot can be booked. */
  minLeadMin?: number;
};

/**
 * Generate bookable slots for one calendar date from weekly availability
 * windows, minus existing bookings and past/lead-time-filtered slots.
 */
export function generateDaySlots(options: GenerateSlotsOptions): Slot[] {
  const {
    date,
    windows,
    durationMin,
    booked = [],
    now = new Date(),
    minLeadMin = 0,
  } = options;

  if (!isValidDateString(date) || durationMin <= 0) return [];

  const dayOfWeek = dayOfWeekForDate(date);
  const earliestStart = now.getTime() + minLeadMin * 60000;
  const slots: Slot[] = [];

  const dayWindows = windows
    .filter((w) => w.dayOfWeek === dayOfWeek)
    .filter((w) => isValidTimeString(w.startTime) && isValidTimeString(w.endTime))
    .sort((a, b) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime));

  for (const window of dayWindows) {
    const windowStart = timeToMinutes(window.startTime);
    const windowEnd = timeToMinutes(window.endTime);

    for (
      let slotStart = windowStart;
      slotStart + durationMin <= windowEnd;
      slotStart += durationMin
    ) {
      const startTime = minutesToTime(slotStart);
      const endTime = minutesToTime(slotStart + durationMin);

      // Skip slots inside a DST spring-forward gap (nonexistent wall time).
      if (!localTimeExists(date, startTime)) continue;

      const start = zonedTimeToUtc(date, startTime);
      const end = zonedTimeToUtc(date, endTime);

      const isPast = start.getTime() < earliestStart;
      const isBooked = booked.some((range) =>
        rangesOverlap(start, end, range.start, range.end),
      );

      slots.push({
        start,
        end,
        startTime,
        endTime,
        isPast,
        isBooked,
        isAvailable: !isPast && !isBooked,
      });
    }
  }

  return slots;
}

/** First available slot from a generated day list, or null. */
export function getNextAvailableSlot(slots: Slot[]): Slot | null {
  return slots.find((slot) => slot.isAvailable) ?? null;
}

/** Slovak long date label for a calendar date, e.g. "utorok 11. augusta 2026". */
export function formatDateDisplaySk(date: string): string {
  return new Date(`${date}T12:00:00Z`).toLocaleDateString("sk-SK", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  });
}
