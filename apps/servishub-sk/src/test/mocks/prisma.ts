/**
 * Lightweight Prisma stand-in for unit/integration tests.
 * Only the methods our data-layer tests need.
 */

export type FakeBooking = {
  id: string;
  customerId: string;
  providerId: string;
  serviceId: string | null;
  status: string;
  scheduledAt: Date;
  durationMin: number | null;
  review?: { id: string } | null;
};

export function createTxBookingsStore(initial: FakeBooking[] = []) {
  const bookings = [...initial];
  let idSeq = 1;

  const store = {
    bookings,
    booking: {
      findMany: async (args?: {
        where?: {
          providerId?: string;
          status?: { in: string[] };
          scheduledAt?: { gte?: Date; lt?: Date };
        };
        select?: unknown;
      }) => {
        let rows = [...bookings];
        const where = args?.where;
        if (where?.providerId) {
          rows = rows.filter((b) => b.providerId === where.providerId);
        }
        if (where?.status?.in) {
          rows = rows.filter((b) => where.status!.in.includes(b.status));
        }
        if (where?.scheduledAt?.gte) {
          rows = rows.filter(
            (b) => b.scheduledAt.getTime() >= where.scheduledAt!.gte!.getTime(),
          );
        }
        if (where?.scheduledAt?.lt) {
          rows = rows.filter(
            (b) => b.scheduledAt.getTime() < where.scheduledAt!.lt!.getTime(),
          );
        }
        return rows.map((b) =>
          args?.select
            ? { scheduledAt: b.scheduledAt, durationMin: b.durationMin }
            : b,
        );
      },
      findFirst: async (args?: {
        where?: { id?: string; customerId?: string };
        include?: { review?: boolean };
      }) => {
        const row = bookings.find((b) => {
          if (args?.where?.id && b.id !== args.where.id) return false;
          if (args?.where?.customerId && b.customerId !== args.where.customerId)
            return false;
          return true;
        });
        if (!row) return null;
        if (args?.include?.review) {
          return { ...row, review: row.review ?? null };
        }
        return row;
      },
      create: async (args: {
        data: {
          customerId: string;
          providerId: string;
          serviceId: string;
          status: string;
          scheduledAt: Date;
          durationMin: number;
          addressLine?: string | null;
          city?: string | null;
          postalCode?: string | null;
          notes?: string | null;
          priceAmount?: number | null;
          currency?: string;
        };
      }) => {
        const created: FakeBooking = {
          id: `bk_${idSeq++}`,
          customerId: args.data.customerId,
          providerId: args.data.providerId,
          serviceId: args.data.serviceId,
          status: args.data.status,
          scheduledAt: args.data.scheduledAt,
          durationMin: args.data.durationMin,
          review: null,
        };
        bookings.push(created);
        return created;
      },
      updateMany: async (args: {
        where: {
          id: string;
          customerId: string;
          status: { in: string[] };
        };
        data: { status: string };
      }) => {
        const match = bookings.find(
          (b) =>
            b.id === args.where.id &&
            b.customerId === args.where.customerId &&
            args.where.status.in.includes(b.status),
        );
        if (!match) return { count: 0 };
        match.status = args.data.status;
        return { count: 1 };
      },
    },
    review: {
      create: async (args: {
        data: {
          bookingId: string;
          customerId: string;
          providerId: string;
          rating: number;
          comment: string | null;
        };
      }) => {
        const booking = bookings.find((b) => b.id === args.data.bookingId);
        const id = `rv_${idSeq++}`;
        if (booking) booking.review = { id };
        return { id, ...args.data };
      },
    },
    provider: {
      findUniqueOrThrow: async (_args: {
        where: { id: string };
        select: { ratingAvg: true; ratingCount: true };
      }) => {
        void _args;
        return { ratingAvg: 4, ratingCount: 1 };
      },
      update: async (args: {
        where: { id: string };
        data: { ratingAvg: number; ratingCount: number };
      }) => args.data,
    },
  };

  return store;
}
