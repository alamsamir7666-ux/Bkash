import { Router } from 'express';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';
import { requireAuth, type AuthedRequest } from '../middleware/auth';
import { asyncHandler, validateBody } from '../middleware/error';

const router = Router();
router.use(requireAuth);

const TRX_TYPES = [
  'cash_in',
  'cash_out',
  'b2b_receive',
  'b2b_send',
  'send_money',
  'expense',
  'capital_add',
] as const;

const createSchema = z.object({
  trx_type: z.enum(TRX_TYPES),
  amount: z.number().positive(),
  commission: z.number().min(0).default(0),
  source_account: z.string().uuid().nullable().optional(),
  target_account: z.string().uuid().nullable().optional(),
  customer_phone: z.string().optional(),
  note: z.string().optional(),
});

/** POST /transactions — atomically writes the trx + updates balances. */
router.post(
  '/',
  validateBody(createSchema),
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const body = req.body as z.infer<typeof createSchema>;

    const trx = await prisma.$transaction(async (tx) => {
      // Validate source / target accounts belong to this shop.
      if (body.source_account) {
        const acc = await tx.account.findFirst({
          where: { id: body.source_account, shopId: authReq.user.id },
        });
        if (!acc) throw new HttpError(400, 'Invalid source account');
      }
      if (body.target_account) {
        const acc = await tx.account.findFirst({
          where: { id: body.target_account, shopId: authReq.user.id },
        });
        if (!acc) throw new HttpError(400, 'Invalid target account');
      }

      // Update balances: source decreases, target increases.
      if (body.source_account) {
        await tx.account.update({
          where: { id: body.source_account },
          data: { balance: { decrement: body.amount } },
        });
      }
      if (body.target_account) {
        await tx.account.update({
          where: { id: body.target_account },
          data: { balance: { increment: body.amount } },
        });
      }

      // For expense, commission is paid out separately from the source.
      // For commission earning types, add commission to the target account.
      if (
        body.commission > 0 &&
        body.target_account &&
        body.trx_type !== 'expense'
      ) {
        await tx.account.update({
          where: { id: body.target_account },
          data: { balance: { increment: body.commission } },
        });
      }

      return tx.transaction.create({
        data: {
          shopId: authReq.user.id,
          trxType: body.trx_type,
          amount: body.amount,
          commission: body.commission,
          sourceAccount: body.source_account ?? null,
          targetAccount: body.target_account ?? null,
          customerPhone: body.customer_phone ?? null,
          note: body.note ?? null,
        },
      });
    });

    res.status(201).json({ transaction: serialise(trx) });
  }),
);

/** GET /transactions — paginated list with optional filters. */
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const limit = Math.min(Number(req.query.limit ?? 50), 200);
    const offset = Math.max(Number(req.query.offset ?? 0), 0);
    const trxType = req.query.trx_type as string | undefined;
    const from = req.query.from ? new Date(req.query.from as string) : undefined;
    const to = req.query.to ? new Date(req.query.to as string) : undefined;

    const where: Prisma.TransactionWhereInput = { shopId: authReq.user.id };
    if (trxType) where.trxType = trxType;
    if (from || to) {
      where.createdAt = {};
      if (from) where.createdAt.gte = from;
      if (to) where.createdAt.lte = to;
    }

    const transactions = await prisma.transaction.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    });

    res.json({
      transactions: transactions.map(serialise),
      count: transactions.length,
    });
  }),
);

/** GET /transactions/summary — aggregated stats for the dashboard. */
router.get(
  '/summary',
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const now = req.query.date ? new Date(req.query.date as string) : new Date();

    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(now);
    endOfDay.setHours(23, 59, 59, 999);

    const startOfWeek = new Date(startOfDay);
    startOfWeek.setDate(startOfWeek.getDate() - 6);
    const startOfMonth = new Date(startOfDay);
    startOfMonth.setDate(startOfMonth.getDate() - 29);

    const [todayAgg, weekAgg, monthAgg, todayCountAgg] = await Promise.all([
      prisma.transaction.aggregate({
        where: { shopId: authReq.user.id, createdAt: { gte: startOfDay, lte: endOfDay } },
        _sum: { amount: true, commission: true },
      }),
      prisma.transaction.aggregate({
        where: { shopId: authReq.user.id, createdAt: { gte: startOfWeek } },
        _sum: { commission: true },
      }),
      prisma.transaction.aggregate({
        where: { shopId: authReq.user.id, createdAt: { gte: startOfMonth } },
        _sum: { commission: true },
      }),
      prisma.transaction.count({
        where: { shopId: authReq.user.id, createdAt: { gte: startOfDay, lte: endOfDay } },
      }),
    ]);

    res.json({
      summary: {
        today_profit: todayAgg._sum.commission?.toString() ?? '0',
        today_volume: todayAgg._sum.amount?.toString() ?? '0',
        today_count: todayCountAgg,
        week_profit: weekAgg._sum.commission?.toString() ?? '0',
        month_profit: monthAgg._sum.commission?.toString() ?? '0',
      },
    });
  }),
);

/** DELETE /transactions/:id — reverses balance changes then deletes. */
router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const trx = await prisma.transaction.findFirst({
      where: { id: req.params.id, shopId: authReq.user.id },
    });
    if (!trx) {
      return res.status(404).json({ message: 'Transaction not found' });
    }

    await prisma.$transaction(async (tx) => {
      // Reverse the balance changes.
      if (trx.sourceAccount) {
        await tx.account.update({
          where: { id: trx.sourceAccount },
          data: { balance: { increment: trx.amount } },
        });
      }
      if (trx.targetAccount) {
        await tx.account.update({
          where: { id: trx.targetAccount },
          data: { balance: { decrement: trx.amount } },
        });
      }
      if (trx.commission > 0 && trx.targetAccount && trx.trxType !== 'expense') {
        await tx.account.update({
          where: { id: trx.targetAccount },
          data: { balance: { decrement: trx.commission } },
        });
      }
      await tx.transaction.delete({ where: { id: trx.id } });
    });

    res.json({ message: 'Transaction deleted' });
  }),
);

class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

function serialise(t: {
  id: string;
  shopId: string;
  trxType: string;
  amount: Prisma.Decimal;
  commission: Prisma.Decimal;
  sourceAccount: string | null;
  targetAccount: string | null;
  customerPhone: string | null;
  note: string | null;
  createdAt: Date;
}) {
  return {
    id: t.id,
    shop_id: t.shopId,
    trx_type: t.trxType,
    amount: t.amount.toString(),
    commission: t.commission.toString(),
    source_account: t.sourceAccount,
    target_account: t.targetAccount,
    customer_phone: t.customerPhone,
    note: t.note,
    created_at: t.createdAt.toISOString(),
  };
}

export default router;
