import type { Request, Response, NextFunction } from 'express';
import { prisma } from '../prisma';
import { verifyFirebaseToken } from '../firebase';

/**
 * Express middleware that requires a valid Firebase ID token in the
 * Authorization: Bearer <token> header.
 *
 * On success, attaches `req.user = { id, role, firebaseUid, email }`
 * to the request. The User row is lazily created on first request —
 * but only if the client has already called POST /auth/onboard to
 * capture the display name. If the User row doesn't exist yet, we
 * return 404 with a hint to call /auth/onboard first.
 */
export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    res.status(401).json({ message: 'Authentication required' });
    return;
  }

  let decoded;
  try {
    decoded = await verifyFirebaseToken(token);
  } catch (err) {
    res
      .status(401)
      .json({ message: 'Invalid or expired Firebase token', error: String(err) });
    return;
  }

  // Look up our User row by Firebase UID. We do NOT auto-create here
  // because the user must go through /auth/onboard first to capture
  // their display name (which Firebase doesn't enforce).
  const user = await prisma.user.findUnique({
    where: { firebaseUid: decoded.uid },
  });

  if (!user) {
    res.status(404).json({
      message: 'Onboarding required — call POST /auth/onboard with your name first.',
      firebaseUid: decoded.uid,
      email: decoded.email,
    });
    return;
  }

  (req as AuthedRequest).user = {
    id: user.id,
    role: user.role,
    firebaseUid: user.firebaseUid,
    email: user.email,
  };
  next();
}

export interface AuthedRequest extends Request {
  user: {
    id: string;
    role: string;
    firebaseUid: string;
    email: string;
  };
}
