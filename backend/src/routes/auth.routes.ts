import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../prisma';
import { signToken } from '../middleware/auth';
import { asyncHandler, validateBody } from '../middleware/error';
import type { AuthedRequest } from '../middleware/auth';

const router = Router();

const registerSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(6),
  phone: z.string().optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

/** POST /auth/register — creates a user + the 3 default account pockets. */
router.post(
  '/register',
  validateBody(registerSchema),
  asyncHandler(async (req, res) => {
    const { name, email, password, phone } = req.body as z.infer<
      typeof registerSchema
    >;

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    const hashed = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        name,
        email,
        password: hashed,
        phone,
        role: 'admin',
      },
    });

    // Auto-create the 3 conventional account pockets.
    await prisma.account.createMany({
      data: [
        { shopId: user.id, accountType: 'agent_bKash', balance: 0 },
        { shopId: user.id, accountType: 'personal_bKash', balance: 0 },
        { shopId: user.id, accountType: 'physical_cash', balance: 0 },
      ],
    });

    const token = signToken(user);
    res.status(201).json({
      token,
      user: sanitise(user),
    });
  }),
);

/** POST /auth/login — verifies credentials and issues a JWT. */
router.post(
  '/login',
  validateBody(loginSchema),
  asyncHandler(async (req, res) => {
    const { email, password } = req.body as z.infer<typeof loginSchema>;
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }
    const ok = await bcrypt.compare(password, user.password);
    if (!ok) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }
    const token = signToken(user);
    res.json({ token, user: sanitise(user) });
  }),
);

/** GET /auth/me — returns the current user's profile. */
router.get(
  '/me',
  asyncHandler(async (req, res) => {
    const authReq = req as AuthedRequest;
    if (!authReq.user) {
      return res.status(401).json({ message: 'Authentication required' });
    }
    const user = await prisma.user.findUnique({ where: { id: authReq.user.id } });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json({ user: sanitise(user) });
  }),
);

function sanitise(user: {
  id: string;
  email: string;
  name: string;
  phone: string | null;
  role: string;
  createdAt: Date;
}) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    phone: user.phone,
    role: user.role,
    created_at: user.createdAt.toISOString(),
  };
}

export default router;
