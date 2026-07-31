-- Prisma migration for Smart Shop Ledger
-- Creates the 4 tables (users, accounts, transactions, daily_closings)
-- with proper indexes, foreign keys, and unique constraints.
-- Mirrors backend/prisma/schema.prisma.

-- ─── users ─────────────────────────────────────────────────────────────────
CREATE TABLE "users" (
    "id"         TEXT        NOT NULL,
    "email"      TEXT        NOT NULL,
    "password"   TEXT        NOT NULL,
    "name"       TEXT        NOT NULL,
    "phone"      TEXT,
    "role"       TEXT        NOT NULL DEFAULT 'admin',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- ─── accounts ──────────────────────────────────────────────────────────────
CREATE TABLE "accounts" (
    "account_id"    UUID         NOT NULL,
    "shop_id"       TEXT         NOT NULL,
    "account_type"  TEXT         NOT NULL,
    "balance"       DECIMAL(14,2) NOT NULL DEFAULT 0,
    "last_updated"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "accounts_pkey" PRIMARY KEY ("account_id")
);

CREATE UNIQUE INDEX "accounts_shop_id_account_type_key"
    ON "accounts"("shop_id", "account_type");

CREATE INDEX "accounts_shop_id_idx" ON "accounts"("shop_id");

ALTER TABLE "accounts"
    ADD CONSTRAINT "accounts_shop_id_fkey"
    FOREIGN KEY ("shop_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- ─── transactions ──────────────────────────────────────────────────────────
CREATE TABLE "transactions" (
    "trx_id"          UUID          NOT NULL,
    "shop_id"         TEXT          NOT NULL,
    "trx_type"        TEXT          NOT NULL,
    "amount"          DECIMAL(14,2) NOT NULL,
    "commission"      DECIMAL(14,2) NOT NULL DEFAULT 0,
    "source_account"  UUID,
    "target_account"  UUID,
    "customer_phone"  TEXT,
    "note"            TEXT,
    "created_at"      TIMESTAMP(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "transactions_pkey" PRIMARY KEY ("trx_id")
);

CREATE INDEX "transactions_shop_id_created_at_idx"
    ON "transactions"("shop_id", "created_at");

CREATE INDEX "transactions_shop_id_trx_type_idx"
    ON "transactions"("shop_id", "trx_type");

ALTER TABLE "transactions"
    ADD CONSTRAINT "transactions_shop_id_fkey"
    FOREIGN KEY ("shop_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "transactions"
    ADD CONSTRAINT "transactions_source_account_fkey"
    FOREIGN KEY ("source_account") REFERENCES "accounts"("account_id")
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "transactions"
    ADD CONSTRAINT "transactions_target_account_fkey"
    FOREIGN KEY ("target_account") REFERENCES "accounts"("account_id")
    ON DELETE SET NULL ON UPDATE CASCADE;

-- ─── daily_closings ────────────────────────────────────────────────────────
CREATE TABLE "daily_closings" (
    "closing_id"     UUID          NOT NULL,
    "shop_id"        TEXT          NOT NULL,
    "date"           DATE          NOT NULL,
    "expected_cash"  DECIMAL(14,2) NOT NULL,
    "actual_cash"    DECIMAL(14,2) NOT NULL,
    "discrepancy"    DECIMAL(14,2) NOT NULL,
    "total_profit"   DECIMAL(14,2) NOT NULL DEFAULT 0,
    "is_resolved"    BOOLEAN       NOT NULL DEFAULT false,
    "note"           TEXT,
    "created_at"     TIMESTAMP(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "daily_closings_pkey" PRIMARY KEY ("closing_id")
);

CREATE UNIQUE INDEX "daily_closings_shop_id_date_key"
    ON "daily_closings"("shop_id", "date");

CREATE INDEX "daily_closings_shop_id_date_idx"
    ON "daily_closings"("shop_id", "date");

ALTER TABLE "daily_closings"
    ADD CONSTRAINT "daily_closings_shop_id_fkey"
    FOREIGN KEY ("shop_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- ─── Add Prisma migration metadata ────────────────────────────────────────
-- Required so `prisma migrate deploy` records the migration as applied.
CREATE TABLE IF NOT EXISTS "_prisma_migrations" (
    "id"                    VARCHAR(36)   NOT NULL,
    "checksum"              VARCHAR(64)   NOT NULL,
    "finished_at"           TIMESTAMP(3),
    "migration_name"        VARCHAR(255)  NOT NULL,
    "logs"                  TEXT,
    "rolled_back_at"        TIMESTAMP(3),
    "started_at"            TIMESTAMP(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "applied_steps_count"   INTEGER       NOT NULL DEFAULT 0,

    CONSTRAINT "_prisma_migrations_pkey" PRIMARY KEY ("id")
);
