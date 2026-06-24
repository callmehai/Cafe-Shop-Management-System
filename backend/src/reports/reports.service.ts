import { Injectable } from '@nestjs/common';
import { OrderStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  // UC20 Sales report theo khoảng ngày (tổng từ payments + top products).
  async sales(fromStr?: string, toStr?: string) {
    const now = new Date();
    const from = fromStr
      ? new Date(fromStr)
      : new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6);
    const to = toStr ? new Date(toStr) : now;

    const payments = await this.prisma.payment.findMany({
      where: { paidAt: { gte: from, lte: to } },
      include: { order: { include: { items: { include: { product: true } } } } },
    });

    const totalRevenue = payments.reduce((s, p) => s + Number(p.amount), 0);
    const orderCount = payments.length;
    const avgTicket = orderCount ? Math.round(totalRevenue / orderCount) : 0;

    // Top products theo doanh thu.
    const agg = new Map<string, { name: string; qty: number; revenue: number }>();
    for (const p of payments) {
      for (const it of p.order.items) {
        const cur = agg.get(it.product.name) ?? { name: it.product.name, qty: 0, revenue: 0 };
        cur.qty += it.quantity;
        cur.revenue += Number(it.linePrice);
        agg.set(it.product.name, cur);
      }
    }
    const topProducts = [...agg.values()].sort((a, b) => b.revenue - a.revenue).slice(0, 5);

    return {
      from: from.toISOString(),
      to: to.toISOString(),
      totalRevenue,
      orderCount,
      avgTicket,
      topProducts,
    };
  }

  // Số liệu dashboard (mọi role gọi). Gộp đủ field để FE chọn theo role.
  async dashboard() {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const [todayPayments, openOrders, tables, ingredients, users] = await Promise.all([
      this.prisma.payment.findMany({ where: { paidAt: { gte: startOfDay } }, select: { amount: true } }),
      this.prisma.order.count({ where: { status: OrderStatus.OPEN } }),
      this.prisma.table.findMany({ select: { occupancyStatus: true } }),
      this.prisma.ingredient.findMany(),
      this.prisma.user.findMany({ select: { isActive: true } }),
    ]);

    const revenueToday = todayPayments.reduce((s, p) => s + Number(p.amount), 0);
    const lowStock = ingredients
      .filter((i) => Number(i.quantityOnHand) <= Number(i.reorderThreshold))
      .map((i) => i.name);

    return {
      revenueToday,
      ordersToday: todayPayments.length,
      openOrders,
      tablesTotal: tables.length,
      tablesFree: tables.filter((t) => t.occupancyStatus === 'FREE').length,
      lowStockCount: lowStock.length,
      lowStock,
      userCount: users.length,
      activeUsers: users.filter((u) => u.isActive).length,
    };
  }
}
