import { PrismaClient, Role, OccupancyStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  // ---------- USERS (idempotent qua upsert) ----------
  // admin/admin123 ; nhân viên demo dùng mật khẩu 123456.
  const adminPw = await bcrypt.hash('admin123', 10);
  const staffPw = await bcrypt.hash('123456', 10);
  const users = [
    { username: 'admin', fullName: 'System Admin', role: Role.ADMINISTRATOR, hash: adminPw },
    { username: 'manager.an', fullName: 'Tran Van An', role: Role.MANAGER, hash: staffPw },
    { username: 'cashier.linh', fullName: 'Linh Nguyen', role: Role.CASHIER, hash: staffPw },
    { username: 'barista.huy', fullName: 'Pham Quang Huy', role: Role.BARISTA, hash: staffPw },
  ];
  for (const u of users) {
    await prisma.user.upsert({
      where: { username: u.username },
      update: { fullName: u.fullName, role: u.role, isActive: true },
      create: { username: u.username, passwordHash: u.hash, fullName: u.fullName, role: u.role },
    });
  }

  // ---------- RESET dữ liệu demo (cho phép chạy seed lại nhiều lần) ----------
  // Xóa theo thứ tự phụ thuộc FK.
  await prisma.loyaltyTransaction.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.stockIn.deleteMany();
  await prisma.purchaseOrder.deleteMany();
  await prisma.productIngredient.deleteMany();
  await prisma.product.deleteMany();
  await prisma.category.deleteMany();
  await prisma.ingredient.deleteMany();
  await prisma.customer.deleteMany();
  await prisma.table.deleteMany();

  // ---------- CATEGORIES (khớp tab trong màn Create Order) ----------
  const coffee = await prisma.category.create({ data: { name: 'Coffee' } });
  const tea = await prisma.category.create({ data: { name: 'Tea' } });
  const pastry = await prisma.category.create({ data: { name: 'Pastry' } });
  const cold = await prisma.category.create({ data: { name: 'Cold' } });

  // ---------- INGREDIENTS (đơn vị: L cho sữa, kg cho phần còn lại) ----------
  const milk = await prisma.ingredient.create({ data: { name: 'Fresh Milk', quantityOnHand: 25, reorderThreshold: 10 } });
  const beans = await prisma.ingredient.create({ data: { name: 'Coffee Beans', quantityOnHand: 18, reorderThreshold: 5 } });
  const matchaPowder = await prisma.ingredient.create({ data: { name: 'Matcha Powder', quantityOnHand: 3, reorderThreshold: 2 } });
  await prisma.ingredient.create({ data: { name: 'Sugar', quantityOnHand: 40, reorderThreshold: 8 } });

  // ---------- PRODUCTS (giá & size khớp mockup Figma) ----------
  const cappuccino = await prisma.product.create({ data: { name: 'Cappuccino', categoryId: coffee.id, price: 45000, size: 'S/M/L', imageUrl: '/uploads/default/cappuccino.png' } });
  const latte = await prisma.product.create({ data: { name: 'Latte', categoryId: coffee.id, price: 50000, size: 'S/M/L', imageUrl: '/uploads/default/latte.png' } });
  const espresso = await prisma.product.create({ data: { name: 'Espresso', categoryId: coffee.id, price: 35000, size: 'S', imageUrl: '/uploads/default/espresso.png' } });
  const matchaLatte = await prisma.product.create({ data: { name: 'Matcha Latte', categoryId: tea.id, price: 60000, size: 'M/L', imageUrl: '/uploads/default/matcha_latte.png' } });
  await prisma.product.create({ data: { name: 'Croissant', categoryId: pastry.id, price: 40000, imageUrl: '/uploads/default/croissant.png' } });
  await prisma.product.create({ data: { name: 'Pain au Chocolat', categoryId: pastry.id, price: 45000, imageUrl: '/uploads/default/pain_au_chocolat.png' } });
  // Cold Brew: demo trạng thái hết hàng (BR-04 -> ẩn khỏi order menu).
  const coldBrew = await prisma.product.create({ data: { name: 'Cold Brew', categoryId: cold.id, price: 52000, size: 'M/L', isAvailable: false, imageUrl: '/uploads/default/cold_brew.png' } });

  // ---------- RECIPE / BOM (BR-08: tự trừ kho khi thanh toán) ----------
  await prisma.productIngredient.createMany({
    data: [
      { productId: cappuccino.id, ingredientId: beans.id, quantity: 0.018 },
      { productId: cappuccino.id, ingredientId: milk.id, quantity: 0.15 },
      { productId: latte.id, ingredientId: beans.id, quantity: 0.018 },
      { productId: latte.id, ingredientId: milk.id, quantity: 0.2 },
      { productId: espresso.id, ingredientId: beans.id, quantity: 0.018 },
      { productId: matchaLatte.id, ingredientId: matchaPowder.id, quantity: 0.01 },
      { productId: matchaLatte.id, ingredientId: milk.id, quantity: 0.2 },
      { productId: coldBrew.id, ingredientId: beans.id, quantity: 0.025 },
    ],
  });

  // ---------- TABLES (12 bàn · 2 zone: Main floor 8 + Terrace 4) ----------
  const shapes = ['Square', 'Round', 'Booth', 'Bar'];
  const statuses = [OccupancyStatus.FREE, OccupancyStatus.OCCUPIED, OccupancyStatus.RESERVED];
  const tables = Array.from({ length: 12 }, (_, i) => {
    const n = i + 1;
    return {
      number: n,
      capacity: n % 3 === 0 ? 6 : (n % 2 === 0 ? 4 : 2),
      floor: n <= 8 ? 'Main floor' : 'Terrace',
      shape: shapes[i % shapes.length],
      occupancyStatus: statuses[i % 3],
    };
  });
  await prisma.table.createMany({ data: tables });

  // ---------- CUSTOMERS (Mai Le 1,240 pts khớp màn Payment) ----------
  await prisma.customer.createMany({
    data: [
      { fullName: 'Mai Le', phone: '0901234567', loyaltyPoints: 1240 },
      { fullName: 'Tuan Anh', phone: '0907654321', loyaltyPoints: 90 },
      { fullName: 'Hoa Pham', phone: '0912000111', loyaltyPoints: 530 },
    ],
  });

  console.log('Seeded:');
  console.log('  users   : admin/admin123 · manager.an/cashier.linh/barista.huy = 123456');
  console.log('  catalog : 4 categories · 7 products · 4 ingredients (recipes linked)');
  console.log('  ops     : 12 tables · 3 customers');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
