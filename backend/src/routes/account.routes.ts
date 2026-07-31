import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { requireAuth, type AuthedRequest } from '../middleware/auth';
import { asyncHandler, validateBody } from '../middleware/error';

const router = Router();
router.use(requireAuth);

const createSchema = z.object({
  account_type: z.string(),
  initial_balance: z.number().min(0).default(0),
});

/** GET /accounts — list all accounts for the current shop. */
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const accounts = await prisma.account.findMany({
      where: { shopId: authReq.user.id },
      orderBy: { accountType: 'asc' },
    });
    res.json({
      accounts: accounts.map((a) => ({
        id: a.id,
        shop_id: a.shopId,
        account_type: a.accountType,
        balance: a.balance.toString(),
        last_updated: a.lastUpdated.toISOString(),
      })),
    });
  }),
);

/** POST /accounts — create a new account pocket. */
router.post(
  '/',
  validateBody(createSchema),
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const { account_type, initial_balance } = req.body as z.infer<
      typeof createSchema
    >;
    const account = await prisma.account.create({
      data: {
        shopId: authReq.user.id,
        accountType: account_type,
        balance: initial_balance,
      },
    });
    res.status(201).json({
      account: {
        id: account.id,
        shop_id: account.shopId,
        account_type: account.accountType,
        balance: account.balance.toString(),
        last_updated: account.lastUpdated.toISOString(),
      },
    });
  }),
);

/** PATCH /accounts/:id — manually adjust balance (admin only). */
router.patch(
  '/:id',
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    const { id } = req.params;
    const balance = Number(req.body?.balance);
    if (Number.isNaN(balance)) {
      return res.status(400).json({ message: 'balance must be a number' });
    }
    const account = await prisma.account.findFirst({
      where: { id, shopId: authReq.user.id },
    });
    if (!account) {
      return res.status(404).json({ message: 'Account not found' });
    }
    const updated = await prisma.account.update({
      where: { id },
      data: { balance },
    });
    res.json({
      account: {
        id: updated.id,
        shop_id: updated.shopId,
        account_type: updated.accountType,
        balance: updated.balance.toString(),
        last_updated: updated.lastUpdated.toISOString(),
      },
    });
  }),
);

export default router;
