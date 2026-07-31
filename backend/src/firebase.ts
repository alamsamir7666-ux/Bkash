/**
 * Firebase Admin SDK initialization.
 *
 * Reads credentials from environment variables (set on Render) so we
 * never commit a JSON key file to the repo.
 *
 * Required env vars:
 *   FIREBASE_PROJECT_ID   — e.g. "bkash-731a8"
 *   FIREBASE_CLIENT_EMAIL — e.g. "firebase-adminsdk-xxxx@bkash-731a8.iam.gserviceaccount.com"
 *   FIREBASE_PRIVATE_KEY  — the full PEM string including "-----BEGIN PRIVATE KEY-----" header.
 *                           In .env files the newlines must be escaped as \n; we restore them here.
 */
import admin from 'firebase-admin';
import type { ServiceAccount } from 'firebase-admin/app';

let initialised = false;

/** Initialises Firebase Admin on first call; no-op on subsequent calls. */
export function initFirebase(): void {
  if (initialised) return;

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY;

  if (!projectId || !clientEmail || !privateKeyRaw) {
    // In dev/CI we may not have credentials yet. Defer the crash to the
    // first verifyIdToken call so the server can still boot and serve /health.
    // eslint-disable-next-line no-console
    console.warn(
      '[firebase] FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY ' +
        'are not all set — Firebase token verification will fail at runtime.',
    );
    initialised = true;
    return;
  }

  const serviceAccount: ServiceAccount = {
    projectId,
    clientEmail,
    // Render stores env vars as single-line strings; the PEM key has real
    // newlines that we have to restore from the escaped "\\n" sequences.
    privateKey: privateKeyRaw.replace(/\\n/g, '\n'),
  };

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  initialised = true;
  // eslint-disable-next-line no-console
  console.log(`[firebase] initialised for project "${projectId}"`);
}

/** Verifies a Firebase ID token and returns the decoded payload. */
export async function verifyFirebaseToken(
  token: string,
): Promise<admin.auth.DecodedIdToken> {
  initFirebase();
  return admin.auth().verifyIdToken(token);
}

export { admin };
