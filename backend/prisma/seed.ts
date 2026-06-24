import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('admin123', 10);
  await prisma.user.upsert({
    where: { username: 'admin' },
    update: {},
    create: { username: 'admin', passwordHash, fullName: 'System Admin', role: Role.ADMINISTRATOR },
  });

  const coffee = await prisma.category.create({ data: { name: 'Coffee' } });
  await prisma.category.create({ data: { name: 'Tea' } });
  await prisma.product.create({
    data: { name: 'Cappuccino', categoryId: coffee.id, price: 45000, size: 'M', isAvailable: true },
  });

  console.log('Seeded: admin/admin123');
}

main().finally(() => prisma.$disconnect());
