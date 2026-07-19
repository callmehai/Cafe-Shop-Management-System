import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Customer, LoyaltyType, OccupancyStatus, OrderStatus, Role } from '@prisma/client';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { AuditLogService } from '../audit-log/audit-log.service';

function sortObject(obj: any) {
  const sorted: any = {};
  const keys = Object.keys(obj).sort();
  for (const key of keys) {
    sorted[key] = encodeURIComponent(obj[key]).replace(/%20/g, '+');
  }
  return sorted;
}

function formatVnPayDate(date: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  const y = date.getFullYear();
  const m = pad(date.getMonth() + 1);
  const d = pad(date.getDate());
  const h = pad(date.getHours());
  const min = pad(date.getMinutes());
  const s = pad(date.getSeconds());
  return `${y}${m}${d}${h}${min}${s}`;
}

// Quy ước loyalty (BR-11): 1 điểm = 100₫ khi đổi; tích 1 điểm mỗi 10.000₫ thực trả.
const POINT_VALUE = 100;
const EARN_PER = 10000;

// Lượng nguyên liệu lưu Decimal(12,2). Cộng dồn bằng float sinh sai số
// (0.41 * 2 = 0.8200000000000001), nên chốt về 2 chữ số thập phân.
const round2 = (n: number) => Number(n.toFixed(2));

@Injectable()
export class PaymentsService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditLogService,
  ) {}

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

    // ----- CASH: kiểm tra tiền khách đưa + tính thối (BR-02) -----
    let change = 0;
    if (dto.method === 'CASH') {
      // cashTendered bắt buộc với CASH — chặn thanh toán thiếu tiền.
      if (dto.cashTendered === undefined || dto.cashTendered === null) {
        throw new BadRequestException('Cash tendered amount is required for CASH payments.');
      }
      if (dto.cashTendered < amount) {
        throw new BadRequestException(
          `Cash tendered (${dto.cashTendered}₫) is less than amount due (${amount}₫).`
        );
      }
      change = dto.cashTendered - amount;
    }

    // Card/E-Wallet: fake — coi như thanh toán thành công ngay (không gọi gateway).

    // ----- BR-08: gộp lượng nguyên liệu cần trừ theo công thức -----
    const deductions = new Map<number, number>();
    for (const item of order.items) {
      for (const r of item.product.recipe) {
        const need = Number(r.quantity) * item.quantity;
        deductions.set(r.ingredientId, round2((deductions.get(r.ingredientId) ?? 0) + need));
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

      // BR-08 check stock availability & deduct
      const lowStock: string[] = [];
      for (const [ingredientId, qty] of deductions) {
        const ing = await tx.ingredient.findUnique({ where: { id: ingredientId } });
        if (!ing) throw new NotFoundException(`Ingredient with ID ${ingredientId} not found.`);

        const currentStock = round2(Number(ing.quantityOnHand));
        if (currentStock < qty) {
          throw new BadRequestException(
            `Ingredient "${ing.name}" is out of stock. Available: ${currentStock}, Required: ${qty}.`
          );
        }

        const updated = await tx.ingredient.update({
          where: { id: ingredientId },
          data: { quantityOnHand: { decrement: qty } },
        });
        if (Number(updated.quantityOnHand) <= Number(updated.reorderThreshold)) {
          lowStock.push(updated.name);
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

    await this.auditService.log({
      userId: cashierId,
      action: 'PROCESS_PAYMENT',
      details: JSON.stringify({
        orderId: dto.orderId,
        method: dto.method,
        amount,
        pointsRedeemed,
        pointsEarned: result.pointsEarned,
      }),
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

  async getVnPayUrl(orderId: number, ipAddress: string): Promise<string> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        items: {
          include: {
            product: {
              include: {
                recipe: true,
              },
            },
          },
        },
      },
    });

    if (!order) {
      throw new NotFoundException(`Order with ID ${orderId} not found.`);
    }

    if (order.status !== OrderStatus.OPEN) {
      throw new BadRequestException('Order is not in OPEN status.');
    }

    const tmnCode = process.env.VNP_TMN_CODE;
    const secretKey = process.env.VNP_HASH_SECRET;
    const vnpUrl = process.env.VNP_URL;
    const returnUrl = process.env.VNP_RETURN_URL;


    const date = new Date();
    const createDate = formatVnPayDate(date);
    const subtotal = order.items.reduce((s, it) => s + Number(it.linePrice), 0);
    const amount = Math.round(subtotal * 100);

    const vnpParams: any = {};
    vnpParams['vnp_Version'] = '2.1.0';
    vnpParams['vnp_Command'] = 'pay';
    vnpParams['vnp_TmnCode'] = tmnCode;
    vnpParams['vnp_Locale'] = 'vn';
    vnpParams['vnp_CurrCode'] = 'VND';
    vnpParams['vnp_TxnRef'] = `ORD-${1000 + order.id}-${Date.now()}`;
    vnpParams['vnp_OrderInfo'] = `Thanh toan don hang ORD-${1000 + order.id}`;
    vnpParams['vnp_OrderType'] = 'other';
    vnpParams['vnp_Amount'] = amount.toString();
    vnpParams['vnp_ReturnUrl'] = returnUrl;
    vnpParams['vnp_IpAddr'] = ipAddress || '127.0.0.1';
    vnpParams['vnp_CreateDate'] = createDate;

    const sortedParams = sortObject(vnpParams);
    const signData = Object.keys(sortedParams)
      .map((key) => `${key}=${sortedParams[key]}`)
      .join('&');

    const hmac = crypto.createHmac('sha512', secretKey || '');
    const signed = hmac.update(Buffer.from(signData, 'utf-8')).digest('hex');

    const finalUrl = `${vnpUrl}?${signData}&vnp_SecureHash=${signed}`;
    return finalUrl;
  }

  async handleVnPayIpn(query: any): Promise<any> {
    const secureHash = query['vnp_SecureHash'];
    if (!secureHash) {
      return { RspCode: '97', Message: 'Invalid Checksum' };
    }

    const secretKey = process.env.VNP_HASH_SECRET;
    const tempQuery = { ...query };
    delete tempQuery['vnp_SecureHash'];
    delete tempQuery['vnp_SecureHashType'];

    const sortedParams = sortObject(tempQuery);
    const signData = Object.keys(sortedParams)
      .map((key) => `${key}=${sortedParams[key]}`)
      .join('&');

    const hmac = crypto.createHmac('sha512', secretKey || '');
    const calculatedHash = hmac.update(Buffer.from(signData, 'utf-8')).digest('hex');

    if (calculatedHash !== secureHash) {
      return { RspCode: '97', Message: 'Invalid Checksum' };
    }

    const txnRef = query['vnp_TxnRef'] as string;
    const orderNoIdStr = txnRef.replace('ORD-', '').split('-')[0];
    const orderId = parseInt(orderNoIdStr, 10) - 1000;

    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        items: {
          include: {
            product: {
              include: {
                recipe: true,
              },
            },
          },
        },
      },
    });

    if (!order) {
      return { RspCode: '01', Message: 'Order not found' };
    }

    const subtotal = order.items.reduce((s, it) => s + Number(it.linePrice), 0);
    const vnpAmount = Math.round(Number(query['vnp_Amount']) / 100);
    if (vnpAmount !== Math.round(subtotal)) {
      return { RspCode: '04', Message: 'Invalid amount' };
    }

    if (order.status === OrderStatus.PAID) {
      return { RspCode: '02', Message: 'Order already confirmed' };
    }

    const responseCode = query['vnp_ResponseCode'];

    if (responseCode === '00') {
      const EARN_PER = 10000;
      const amountValue = subtotal;
      
      const deductions = new Map<number, number>();
      for (const item of order.items) {
        for (const r of item.product.recipe) {
          const need = Number(r.quantity) * item.quantity;
          deductions.set(r.ingredientId, round2((deductions.get(r.ingredientId) ?? 0) + need));
        }
      }

      await this.prisma.$transaction(async (tx) => {
        const payment = await tx.payment.create({
          data: {
            orderId: order.id,
            userId: order.createdById,
            customerId: order.customerId,
            method: 'E_WALLET',
            amount: amountValue,
            pointsRedeemed: 0,
          },
        });

        await tx.order.update({
          where: { id: order.id },
          data: { status: OrderStatus.PAID },
        });

        if (order.tableId) {
          await tx.table.update({
            where: { id: order.tableId },
            data: { occupancyStatus: OccupancyStatus.FREE },
          });
        }

        for (const [ingredientId, qty] of deductions) {
          const ing = await tx.ingredient.findUnique({ where: { id: ingredientId } });
          if (!ing) throw new NotFoundException(`Ingredient with ID ${ingredientId} not found.`);

          const currentStock = round2(Number(ing.quantityOnHand));
          if (currentStock < qty) {
            throw new BadRequestException(
              `Ingredient "${ing.name}" is out of stock. Available: ${currentStock}, Required: ${qty}.`
            );
          }

          await tx.ingredient.update({
            where: { id: ingredientId },
            data: { quantityOnHand: { decrement: qty } },
          });
        }

        if (order.customerId) {
          const customer = await tx.customer.findUnique({ where: { id: order.customerId } });
          if (customer) {
            const pointsEarned = Math.floor(amountValue / EARN_PER);
            if (pointsEarned > 0) {
              await tx.loyaltyTransaction.create({
                data: {
                  customerId: customer.id,
                  paymentId: payment.id,
                  type: LoyaltyType.EARN,
                  points: pointsEarned,
                },
              });
              await tx.customer.update({
                where: { id: customer.id },
                data: { loyaltyPoints: { increment: pointsEarned } },
              });
            }
          }
        }
      });

      await this.auditService.log({
        userId: order.createdById,
        action: 'VNPAY_PAYMENT',
        details: JSON.stringify({
          orderId: order.id,
          txnRef,
          amount: amountValue,
          status: 'SUCCESS',
        }),
        ipAddress: query['vnp_IpAddr'],
      });

      return { RspCode: '00', Message: 'Confirm success' };
    } else {
      // Thanh toán thất bại/bị hủy — ghi log nhưng không cập nhật order.
      await this.auditService.log({
        userId: order.createdById,
        action: 'VNPAY_PAYMENT_FAILED',
        details: JSON.stringify({
          orderId: order.id,
          txnRef,
          responseCode,
        }),
        ipAddress: query['vnp_IpAddr'],
      });
      return { RspCode: '00', Message: 'Confirm received' };
    }
  }
}
