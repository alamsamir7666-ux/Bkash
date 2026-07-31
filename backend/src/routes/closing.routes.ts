import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { requireAuth, type AuthedRequest } from '../middleware/auth';
import { asyncHandler, validateBody } from '../middleware/error';

const router = Router();
router.use(requireAuth);

const submitSchema = z.object({
  date: z.string(), // YYYY-MM-DD
  actual_cash: z.number().min(0),
  note: z.string().optional(),
});

/** GET /closings/preview — compute expected cash + profit without persisting. */
router.get(
  '/preview',
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const date = req.query.date
      ? new Date(req.query.date as string)
      : new Date();
    const { startOfDay, endOfDay } = dayBounds(date);

    const cashAccount = await prisma.account.findFirst({
      where: { shopId: authReq.user.id, accountType: 'physical_cash' },
    });
    const expectedCash = cashAccount?.balance ?? 0;

    const agg = await prisma.transaction.aggregate({
      where: {
        shopId: authReq.user.id,
        createdAt: { gte: startOfDay, lte: endOfDay },
      },
      _sum: { commission: true },
    });
    const totalProfit = agg._sum.commission ?? 0;

    // Check if a closing already exists for this date.
    const existing = await prisma.dailyClosing.findUnique({
      where: {
        shopId_date: { shopId: authReq.user.id, date: startOfDay },
      },
    });

    res.json({
      closing: {
        id: existing?.id ?? 'preview',
        shop_id: authReq.user.id,
        date: startOfDay.toISOString(),
        expected_cash: (existing?.expectedCash ?? expectedCash).toString(),
        actual_cash: (existing?.actualCash ?? 0).toString(),
        discrepancy: (existing?.discrepancy ?? 0).toString(),
        total_profit: (existing?.totalProfit ?? totalProfit).toString(),
        is_resolved: existing?.isResolved ?? false,
        created_at: existing?.createdAt?.toISOString(),
      },
    });
  }),
);

/** POST /closings — submit a closing for the given date. */
router.post(
  '/',
  validateBody(submitSchema),
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const body = req.body as z.infer<typeof submitSchema>;
    const date = new Date(body.date);
    const { startOfDay, endOfDay } = dayBounds(date);

    const cashAccount = await prisma.account.findFirst({
      where: { shopId: authReq.user.id, accountType: 'physical_cash' },
    });
    const expectedCash = cashAccount?.balance ?? 0;

    const agg = await prisma.transaction.aggregate({
      where: {
        shopId: authReq.user.id,
        createdAt: { gte: startOfDay, lte: endOfDay },
      },
      _sum: { commission: true },
    });
    const totalProfit = agg._sum.commission ?? 0;
    const discrepancy = body.actual_cash - Number(expectedCash);

    // Upsert so re-submitting for the same date updates the record.
    const closing = await prisma.dailyClosing.upsert({
      where: { shopId_date: { shopId: authReq.user.id, date: startOfDay } },
      create: {
        shopId: authReq.user.id,
        date: startOfDay,
        expectedCash,
        actualCash: body.actual_cash,
        discrepancy,
        totalProfit,
        note: body.note,
      },
      update: {
        expectedCash,
        actualCash: body.actual_cash,
        discrepancy,
        totalProfit,
        note: body.note,
      },
    });

    res.status(201).json({ closing: serialise(closing) });
  }),
);

/** GET /closings — list recent closings. */
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const limit = Math.min(Number(req.query.limit ?? 30), 100);
    const closings = await prisma.dailyClosing.findMany({
      where: { shopId: authReq.user.id },
      orderBy: { date: 'desc' },
      take: limit,
    });
    res.json({ closings: closings.map(serialise) });
  }),
);

/** PATCH /closings/:id/resolve — mark a mismatch as reviewed. */
router.patch(
  '/:id/resolve',
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const closing = await prisma.dailyClosing.findFirst({
      where: { id: req.params.id, shopId: authReq.user.id },
    });
    if (!closing) {
      return res.status(404).json({ message: 'Closing not found' });
    }
    const updated = await prisma.dailyClosing.update({
      where: { id: closing.id },
      data: { isResolved: true },
    });
    res.json({ closing: serialise(updated) });
  }),
);

function dayBounds(date: Date) {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);
  return { startOfDay, endOfDay };
}

function serialise(c: {
  id: string;
  shopId: string;
  date: Date;
  expectedCash: any;
  actualCash: any;
  discrepancy: any;
  totalProfit: any;
  isResolved: boolean;
  note: string | null;
  createdAt: Date;
}) {
  return {
    id: c.id,
    shop_id: c.shopId,
    date: c.date.toISOString(),
    expected_cash: c.expectedCash.toString(),
    actual_cash: c.actualCash.toString(),
    discrepancy: c.discrepancy.toString(),
    total_profit: c.totalProfit.toString(),
    is_resolved: c.isResolved,
    note: c.note,
    created_at: c.createdAt.toISOString(),
  };
}

export default router;
