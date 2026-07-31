import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const email = 'admin@shop.test';
  const password = 'admin123';

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    console.log(`Seed user already exists: ${email}`);
    return;
  }

  const hashed = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: {
      name: 'Demo Shop Owner',
      email,
      password: hashed,
      phone: '01700000000',
      role: 'admin',
    },
  });

  await prisma.account.createMany({
    data: [
      { shopId: user.id, accountType: 'agent_bKash', balance: 25000 },
      { shopId: user.id, accountType: 'personal_bKash', balance: 8500 },
      { shopId: user.id, accountType: 'physical_cash', balance: 12350 },
    ],
  });

  // Seed a few sample transactions for the dashboard to look alive.
  const [agentBkash, , cash] = await prisma.account.findMany({
    where: { shopId: user.id },
  });

  const now = new Date();
  await prisma.transaction.createMany({
    data: [
      {
        shopId: user.id,
        trxType: 'cash_in',
        amount: 2000,
        commission: 20,
        sourceAccount: cash.id,
        targetAccount: agentBkash.id,
        customerPhone: '01711111111',
        note: 'Cash in for customer',
        createdAt: new Date(now.getTime() - 60 * 60 * 1000),
      },
      {
        shopId: user.id,
        trxType: 'cash_out',
        amount: 5000,
        commission: 50,
        sourceAccount: agentBkash.id,
        targetAccount: cash.id,
        customerPhone: '01822222222',
        createdAt: new Date(now.getTime() - 2 * 60 * 60 * 1000),
      },
      {
        shopId: user.id,
        trxType: 'expense',
        amount: 300,
        sourceAccount: cash.id,
        note: 'Tea and snacks',
        createdAt: new Date(now.getTime() - 3 * 60 * 60 * 1000),
      },
      {
        shopId: user.id,
        trxType: 'send_money',
        amount: 1500,
        commission: 15,
        sourceAccount: agentBkash.id,
        customerPhone: '01933333333',
        createdAt: new Date(now.getTime() - 5 * 60 * 60 * 1000),
      },
      {
        shopId: user.id,
        trxType: 'capital_add',
        amount: 5000,
        targetAccount: cash.id,
        note: 'Owner injected capital from pocket',
        createdAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
      },
    ],
  });

  console.log(`Seeded demo user: ${email} / ${password}`);
  console.log(`Shop ID: ${user.id}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
