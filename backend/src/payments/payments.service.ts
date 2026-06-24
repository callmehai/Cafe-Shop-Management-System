import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Customer, LoyaltyType, OccupancyStatus, OrderStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePaymentDto } from './dto/create-payment.dto';

// Quy ước loyalty (BR-11): 1 điểm = 100₫ khi đổi; tích 1 điểm mỗi 10.000₫ thực trả.
const POINT_VALUE = 100;
const EARN_PER = 10000;

@Injectable()
export class PaymentsService {
  constructor(private prisma: PrismaService) {}

  // UC10 Process Payment — atomic.
  async process(dto: CreatePaymentDto, cashierId: number) {
    const order = await this.prisma.order.findUnique({
      where: { id: dto.orderId },
      include: { items: { include: { product: { include: { recipe: true } } } } },
    });
    if (!order) throw new NotFoundException('Order not found');
    if (order.status !== OrderStatus.OPEN) {
      throw new ConflictException('Only open orders can be paid.'); // BR-07
    }
    if (order.items.length === 0) throw new BadRequestException('Order has no items.'); // BR-01

    const subtotal = order.items.reduce((s, it) => s + Number(it.linePrice), 0);

    // ----- Loyalty redeem -----
    const pointsRedeemed = dto.pointsRedeemed ?? 0;
    let customer: Customer | null = null;
    if (dto.customerId) {
      customer = await this.prisma.customer.findUnique({ where: { id: dto.customerId } });
      if (!customer) throw new BadRequestException('Customer not found.');
    }
    if (pointsRedeemed > 0) {
      if (!customer) throw new BadRequestException('Select a customer to redeem points.');
      if (pointsRedeemed > customer.loyaltyPoints) {
        throw new BadRequestException('Not enough loyalty points.');
      }
    }
    const loyaltyDiscount = pointsRedeemed * POINT_VALUE;
    const manualDiscount = dto.discount ?? 0;
    let totalDiscount = loyaltyDiscount + manualDiscount;
    if (totalDiscount > subtotal) totalDiscount = subtotal; // không âm

    // ----- BR-06: giảm > 50% subtotal cần Manager duyệt -----
    if (totalDiscount > subtotal * 0.5) {
      if (!dto.approvalManagerId) {
        throw new ConflictException('Manager approval required for discounts above 50%.');
      }
      const mgr = await this.prisma.user.findUnique({ where: { id: dto.approvalManagerId } });
      if (!mgr || !mgr.isActive || (mgr.role !== Role.MANAGER && mgr.role !== Role.ADMINISTRATOR)) {
        throw new ForbiddenException('Invalid manager approval.');
      }
    }

    const amount = subtotal - totalDiscount; // BR-02

    // ----- CASH: kiểm tra tiền khách đưa + tính thối -----
    let change = 0;
    if (dto.method === 'CASH' && dto.cashTendered !== undefined) {
      if (dto.cashTendered < amount) {
        throw new BadRequestException('Cash tendered is less than amount due.');
      }
      change = dto.cashTendered - amount;
    }

    // ----- BR-08: gộp lượng nguyên liệu cần trừ theo công thức -----
    const deductions = new Map<number, number>();
    for (const item of order.items) {
      for (const r of item.product.recipe) {
        const need = Number(r.quantity) * item.quantity;
        deductions.set(r.ingredientId, (deductions.get(r.ingredientId) ?? 0) + need);
      }
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const payment = await tx.payment.create({
        data: {
          orderId: order.id,
          userId: cashierId,
          customerId: dto.customerId ?? null,
          method: dto.method,
          amount,
          pointsRedeemed,
        },
      });

      await tx.order.update({ where: { id: order.id }, data: { status: OrderStatus.PAID } });
      if (order.tableId) {
        await tx.table.update({
          where: { id: order.tableId },
          data: { occupancyStatus: OccupancyStatus.FREE },
        });
      }

      // BR-08 trừ kho
      const lowStock: string[] = [];
      for (const [ingredientId, qty] of deductions) {
        const ing = await tx.ingredient.update({
          where: { id: ingredientId },
          data: { quantityOnHand: { decrement: qty } },
        });
        if (Number(ing.quantityOnHand) <= Number(ing.reorderThreshold)) {
          lowStock.push(ing.name);
        }
      }

      // Loyalty: REDEEM trước, EARN sau.
      let pointsEarned = 0;
      let newBalance: number | null = null;
      if (customer) {
        pointsEarned = Math.floor(amount / EARN_PER);
        if (pointsRedeemed > 0) {
          await tx.loyaltyTransaction.create({
            data: { customerId: customer.id, paymentId: payment.id, type: LoyaltyType.REDEEM, points: pointsRedeemed },
          });
        }
        if (pointsEarned > 0) {
          await tx.loyaltyTransaction.create({
            data: { customerId: customer.id, paymentId: payment.id, type: LoyaltyType.EARN, points: pointsEarned },
          });
        }
        const updated = await tx.customer.update({
          where: { id: customer.id },
          data: { loyaltyPoints: { increment: pointsEarned - pointsRedeemed } },
        });
        newBalance = updated.loyaltyPoints;
      }

      return { payment, lowStock, pointsEarned, newBalance };
    });

    return {
      payment: result.payment,
      orderNo: `ORD-${1000 + order.id}`,
      subtotal,
      discount: totalDiscount,
      amount,
      change,
      pointsRedeemed,
      pointsEarned: result.pointsEarned,
      newBalance: result.newBalance,
      lowStock: result.lowStock,
    };
  }
}
