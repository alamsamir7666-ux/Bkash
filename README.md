# Smart Shop Ledger

A hybrid ledger app for **bKash agent shops** — track cash, agent bKash, and personal bKash balances, record every transaction with commission, and reconcile the cash drawer at end of day to catch missing money (the 5,170 TK mystery 🕵️).

This repository contains:

| Folder    | Stack                                   | Purpose                                   |
| --------- | --------------------------------------- | ----------------------------------------- |
| `frontend/` | Flutter (Dart) + Riverpod              | Cross-platform mobile app (Android/iOS/Web) |
| `backend/`  | Node.js + Express + Prisma + PostgreSQL | REST API with JWT auth + atomic balance writes |
| `.github/workflows/build-apk.yml` | GitHub Actions | Builds a debug APK on every push to `main` |

---

## Table of contents

1. [Architecture overview](#architecture-overview)
2. [Quick start — backend](#quick-start--backend)
3. [Quick start — Flutter app](#quick-start--flutter-app)
4. [Building the APK via GitHub Actions](#building-the-apk-via-github-actions)
5. [Installing the APK on your phone](#installing-the-apk-on-your-phone)
6. [Deploying the backend](#deploying-the-backend)
7. [Project structure](#project-structure)
8. [API reference](#api-reference)
9. [Troubleshooting](#troubleshooting)

---

## Architecture overview

```
┌──────────────────┐         HTTPS / JWT         ┌──────────────────┐
│  Flutter App     │  ───────────────────────►   │  Node.js API     │
│  (Riverpod)      │                              │  (Express)       │
│                  │  ◄───────────────────────   │                  │
└──────────────────┘         JSON                 └────────┬─────────┘
                                                            │ Prisma
                                                            ▼
                                                  ┌──────────────────┐
                                                  │  PostgreSQL      │
                                                  │  (Supabase/local)│
                                                  └──────────────────┘
```

**Auth flow**:
1. User submits email/password to `POST /api/auth/login`.
2. Backend verifies with bcrypt, signs a JWT (7-day expiry), returns it.
3. Flutter stores the JWT in `flutter_secure_storage`.
4. Every subsequent request includes `Authorization: Bearer <token>` via a Dio interceptor.
5. Backend's `requireAuth` middleware verifies the JWT and attaches `req.user = { id, role }`.

**Balance integrity**:
- Every transaction is written inside a `prisma.$transaction()` that atomically:
  1. Validates source/target account ownership.
  2. Decrements source account balance.
  3. Increments target account balance.
  4. Adds commission to target (for commission-eligible types).
  5. Inserts the `transactions` row.
- Deletion reverses the same balance changes — so the ledger always reconciles.

---

## Quick start — backend

### Prerequisites
- Node.js 18+ (`node -v`)
- A PostgreSQL database (local install **or** a free [Supabase](https://supabase.com) project — recommended)

### Steps

```bash
cd backend

# 1. Install deps
npm install

# 2. Configure env
cp .env.example .env
# Edit .env and set DATABASE_URL to your Postgres connection string.

# 3. Create the schema + apply migrations
npx prisma migrate dev --name init

# 4. (Optional) Seed demo data — creates admin@shop.test / admin123
npm run prisma:seed

# 5. Start dev server (hot reload on save)
npm run dev
```

The API will be live at `http://localhost:3000/api`. Health check: `GET http://localhost:3000/health` → `{ "ok": true }`.

### Demo credentials (after seeding)

| Email                | Password   | Role  |
| -------------------- | ---------- | ----- |
| `admin@shop.test`    | `admin123` | admin |

The seed also pre-creates 3 accounts (agent bKash 25,000, personal bKash 8,500, physical cash 12,350) plus 5 sample transactions.

---

## Quick start — Flutter app

### Prerequisites
- Flutter 3.22+ (`flutter --version`)
- Android Studio or VS Code with Flutter extension
- The backend running (see above) **or** a deployed backend URL

### Steps

```bash
cd frontend

# 1. Install deps
flutter pub get

# 2. Run on Android emulator (the default API URL points to 10.0.2.2:3000)
flutter run

# 3. Run on a physical device with a deployed backend
flutter run \
  --dart-define=API_BASE_URL=https://your-api.com/api
```

The `API_BASE_URL` is read by `lib/core/config/app_config.dart`. The default `http://10.0.2.2:3000/api` is the special address the Android emulator uses to reach `localhost` on the host machine.

---

## Building the APK via GitHub Actions

This repo includes a workflow at `.github/workflows/build-apk.yml` that automatically builds a **debug APK** on every push to `main`/`master`.

### First-time setup

1. **Push the repo to GitHub** (I'll do this once you share a token + repo name).
2. Go to the repo's **Actions** tab and confirm the workflow is enabled.
3. (Optional) Set the `API_BASE_URL` repository variable so the APK talks to your deployed backend:
   - Repo → Settings → Secrets and variables → Actions → **Variables** tab → New variable
   - Name: `API_BASE_URL`
   - Value: `https://your-deployed-backend.com/api` (or `http://10.0.2.2:3000/api` for emulator-only testing)
4. Push any commit to `main`. The workflow will:
   - Set up Java 17 + Flutter 3.22.3
   - Run `flutter pub get`
   - Build the debug APK with your `API_BASE_URL`
   - Upload the APK as a downloadable artifact

### Downloading the APK

1. Open the **Actions** tab in your GitHub repo.
2. Click the latest successful **Build Flutter APK** run.
3. Scroll to the **Artifacts** section at the bottom.
4. Click **smart-shop-ledger-apk** to download a `.zip` containing `smart-shop-ledger-debug.apk`.
5. Unzip and proceed to install (next section).

> 💡 GitHub artifact downloads require you to be **logged in** to GitHub. Artifact URLs are not public — only collaborators can download.

### Manual build (without GitHub Actions)

```bash
cd frontend
flutter pub get
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://your-backend:3000/api
# APK is at: build/app/outputs/flutter-apk/app-debug.apk
```

---

## Installing the APK on your phone

1. Transfer the `smart-shop-ledger-debug.apk` file to your Android phone (USB, Google Drive, etc.).
2. Open the **Files** app and tap the APK.
3. If prompted, allow "Install unknown apps" for your file manager.
4. Tap **Install** → **Open**.
5. Sign in with `admin@shop.test` / `admin123` (if you seeded the backend) or register a new account.

> ⚠️ The APK is debug-signed. If you want a release-signed APK for the Play Store, you'll need to add a keystore as a GitHub secret and switch `--debug` to `--release` in the workflow. See [Flutter Android signing docs](https://docs.flutter.dev/deployment/android).

---

## Deploying the backend

The backend is a standard Node.js app — any container host works. Recommended options:

### Option A: Railway (easiest)

1. Push the repo to GitHub.
2. Go to [railway.app](https://railway.app) → New Project → Deploy from GitHub repo.
3. Set the root directory to `backend`.
4. Add a PostgreSQL database (Railway provisions one for you).
5. Set env vars: `DATABASE_URL` (auto-injected), `JWT_SECRET`, `CORS_ORIGIN`.
6. Railway auto-runs `npm install` + `npm run build` + `npm start`.
7. Run `npx prisma migrate deploy && npm run prisma:seed` once via the Railway shell.

### Option B: Render

Same flow as Railway — see [Render docs for Node + Postgres](https://render.com/docs/deploy-node-express-app).

### Option C: Supabase + Vercel/Render

1. Create a free [Supabase](https://supabase.com) project — gives you a Postgres DB.
2. Copy the connection string from Supabase → Settings → Database → Connection string → URI.
3. Set it as `DATABASE_URL` in your backend host.
4. Run `npx prisma migrate deploy` to create tables.
5. Run `npm run prisma:seed` to create demo data.

After deploying, update the Flutter app's `API_BASE_URL` (either via `--dart-define` or the GitHub Actions variable) and rebuild the APK.

---

## Project structure

```
smart-shop-ledger/
├── .github/workflows/
│   └── build-apk.yml                 # GitHub Actions: builds debug APK
├── frontend/                          # Flutter app
│   ├── lib/
│   │   ├── main.dart                  # App entry
│   │   ├── core/
│   │   │   ├── config/app_config.dart # API_BASE_URL + constants
│   │   │   ├── theme/app_theme.dart   # bKash-pink Material 3 theme
│   │   │   ├── utils/formatters.dart  # BDT currency, dates, signed amounts
│   │   │   ├── utils/validators.dart  # Form validators
│   │   │   └── router.dart            # GoRouter config with auth redirect
│   │   ├── models/                    # User, Account, Transaction, DailyClosing
│   │   ├── services/                  # Dio API client + per-resource services
│   │   ├── providers/                 # Riverpod StateNotifier providers
│   │   ├── shared/widgets/            # PrimaryButton, AppTextField, StatusPill
│   │   └── features/
│   │       ├── auth/                  # Login + Register screens
│   │       ├── dashboard/             # Balance cards, profit summary, recent trx
│   │       ├── transactions/          # Add transaction form, list, detail
│   │       └── reconciliation/        # Daily closing + history
│   ├── android/                       # Android build config
│   ├── pubspec.yaml
│   └── README.md (this file's frontend half)
└── backend/                           # Node.js + Prisma API
    ├── prisma/
    │   ├── schema.prisma              # User, Account, Transaction, DailyClosing models
    │   └── seed.ts                    # Demo user + sample data
    ├── src/
    │   ├── server.ts                  # Express app entry
    │   ├── prisma.ts                  # PrismaClient singleton
    │   ├── middleware/
    │   │   ├── auth.ts                # JWT sign/verify + requireAuth middleware
    │   │   └── error.ts               # Zod validation + error handler
    │   └── routes/
    │       ├── auth.routes.ts         # /api/auth/{register,login,me}
    │       ├── account.routes.ts      # /api/accounts (CRUD)
    │       ├── transaction.routes.ts  # /api/{transactions,transactions/summary}
    │       └── closing.routes.ts      # /api/closings/{preview,/,history,resolve}
    ├── package.json
    └── .env.example
```

---

## API reference

### Auth

| Method | Path                 | Body                                  | Returns                          |
| ------ | -------------------- | ------------------------------------- | -------------------------------- |
| POST   | `/api/auth/register` | `{name, email, password, phone?}`     | `{token, user}` + creates 3 default accounts |
| POST   | `/api/auth/login`    | `{email, password}`                   | `{token, user}`                  |
| GET    | `/api/auth/me`       | — (Bearer token)                      | `{user}`                         |

### Accounts

| Method | Path                  | Auth | Returns                |
| ------ | --------------------- | ---- | ---------------------- |
| GET    | `/api/accounts`       | ✅    | `{accounts: [...]}`    |
| POST   | `/api/accounts`       | ✅    | `{account}`            |
| PATCH  | `/api/accounts/:id`   | ✅    | `{account}` (admin only) |

### Transactions

| Method | Path                       | Auth | Body / Query                                          |
| ------ | -------------------------- | ---- | ----------------------------------------------------- |
| GET    | `/api/transactions`        | ✅    | `?limit&offset&trx_type&from&to`                       |
| POST   | `/api/transactions`        | ✅    | `{trx_type, amount, commission?, source_account?, target_account?, customer_phone?, note?}` |
| GET    | `/api/transactions/summary`| ✅    | `?date=YYYY-MM-DD`                                    |
| DELETE | `/api/transactions/:id`    | ✅    | Reverses balance changes                              |

### Closings

| Method | Path                          | Auth | Body / Returns                            |
| ------ | ----------------------------- | ---- | ----------------------------------------- |
| GET    | `/api/closings/preview`       | ✅    | `?date` → `{closing}` (computed, not saved) |
| POST   | `/api/closings`               | ✅    | `{date, actual_cash, note?}` → `{closing}` |
| GET    | `/api/closings`               | ✅    | `?limit` → `{closings: [...]}`             |
| PATCH  | `/api/closings/:id/resolve`   | ✅    | Marks mismatch as resolved                |

---

## Troubleshooting

**`flutter pub get` fails with version conflicts**
- Make sure you're on Flutter 3.22+. Run `flutter upgrade`.

**APK build fails on GitHub Actions with `minSdkVersion` error**
- The workflow pins `minSdk 21` (Android 5.0+). Most modern devices are fine. If you need older Android, lower it in `frontend/android/app/build.gradle`.

**App cannot reach the backend on a real phone**
- `10.0.2.2` only works inside the Android emulator. On a real device, use your computer's LAN IP (`http://192.168.x.x:3000/api`) or a deployed backend URL.
- Make sure your computer's firewall allows port 3000.

**`PrismaClientInitializationError` on first backend run**
- The database doesn't exist yet. Create it: `createdb smart_shop_ledger` (or via Supabase dashboard), then re-run `npx prisma migrate dev`.

**JWT invalid immediately after login**
- The backend's `JWT_SECRET` env var changed. Either keep it stable or re-login.

**APK installs but shows "Network error"**
- Open the backend URL in a browser on the same phone — if it doesn't load, the network/firewall is the issue, not the app.
- If using HTTPS, make sure your cert is valid (Android blocks self-signed certs by default).

---

## Roadmap

The original blueprint mentioned Firebase Auth (Phone OTP). The current backend uses email/password + JWT — sufficient for v1. To add Phone OTP:

1. Enable Firebase Auth in a Firebase project.
2. Add `firebase_auth` to `pubspec.yaml`.
3. Replace `AuthService.login()` with `FirebaseAuth.instance.signInWithCredential(...)`.
4. After Firebase login, send the Firebase ID token to a new `POST /api/auth/firebase` endpoint that verifies it with `firebase-admin` and issues your internal JWT.

The rest of the app (accounts, transactions, closings) stays exactly the same — only the auth layer swaps.
