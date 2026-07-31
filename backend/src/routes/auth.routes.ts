import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { verifyFirebaseToken } from '../firebase';
import { asyncHandler, validateBody } from '../middleware/error';
import { requireAuth, type AuthedRequest } from '../middleware/auth';

const router = Router();

const onboardSchema = z.object({
  name: z.string().min(2).max(100),
  phone: z.string().max(20).optional(),
});

/**
 * POST /auth/onboard
 * Body: { name: string, phone?: string }
 * Header: Authorization: Bearer <Firebase ID token>
 *
 * Called once after the user creates a Firebase account (via
 * FirebaseAuth.createUserWithEmailAndPassword on the client). Creates:
 *   1. A User row keyed by the Firebase UID (email pulled from the
 *      verified Firebase token, so we trust it 100%).
 *   2. The 3 conventional account pockets (agent_bKash, personal_bKash,
 *      physical_cash) with balance 0.
 *
 * Returns the new user profile. If the user is already onboarded
 * (User row already exists for this firebase_uid), returns 409.
 */
router.post(
  '/onboard',
  validateBody(onboardSchema),
  asyncHandler(async (req, res) => {
    const authHeader = req.headers.authorization || '';
    const [scheme, token] = authHeader.split(' ');
    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ message: 'Firebase ID token required' });
    }

    const decoded = await verifyFirebaseToken(token);
    const { name, phone } = req.body as z.infer<typeof onboardSchema>;

    // Idempotency check — if already onboarded, tell the client.
    const existing = await prisma.user.findUnique({
      where: { firebaseUid: decoded.uid },
    });
    if (existing) {
      return res.status(409).json({
        message: 'User already onboarded',
        user: sanitise(existing),
      });
    }

    // Email must be unique in our table. If a different firebaseUid already
    // claimed this email (shouldn't happen since Firebase verifies email
    // ownership, but defend against it), return 409.
    const emailOwner = await prisma.user.findUnique({
      where: { email: decoded.email ?? '' },
    });
    if (emailOwner && emailOwner.firebaseUid !== decoded.uid) {
      return res
        .status(409)
        .json({ message: 'Email already registered to a different account' });
    }

    // Create User + 3 default account pockets atomically.
    const user = await prisma.user.create({
      data: {
        firebaseUid: decoded.uid,
        email: decoded.email ?? '',
        name,
        phone,
        role: 'admin',
        accounts: {
          create: [
            { accountType: 'agent_bKash', balance: 0 },
            { accountType: 'personal_bKash', balance: 0 },
            { accountType: 'physical_cash', balance: 0 },
          ],
        },
      },
      include: { accounts: true },
    });

    res.status(201).json({ user: sanitise(user) });
  }),
);

/**
 * GET /auth/me
 * Header: Authorization: Bearer <Firebase ID token>
 *
 * Returns the current user's profile. Requires that the user has
 * already been onboarded (POST /auth/onboard called at least once).
 * If not onboarded, returns 404 with a hint.
 */
router.get('/me', requireAuth, asyncHandler(async (req, res) => {
  const authReq = req as AuthedRequest;
  const user = await prisma.user.findUnique({ where: { id: authReq.user.id } });
  if (!user) {
    return res.status(404).json({ message: 'User not found — onboard first' });
  }
  res.json({ user: sanitise(user) });
}));

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
