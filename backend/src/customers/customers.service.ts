import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCustomerDto, UpdateCustomerDto } from './dto/customer.dto';

@Injectable()
export class CustomersService {
  constructor(private prisma: PrismaService) {}

  // List + search (CR-13). Cashier dùng khi gắn khách vào order/payment (loyalty).
  list(search?: string) {
    return this.prisma.customer.findMany({
      where: search
        ? {
            OR: [
              { fullName: { contains: search, mode: 'insensitive' } },
              { phone: { contains: search } },
            ],
          }
        : undefined,
      orderBy: { fullName: 'asc' },
    });
  }

  // UC19 Customer Details + lịch sử điểm (màn 27).
  async findOne(id: number) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      include: {
        loyaltyTxns: {
          include: { payment: { select: { orderId: true, amount: true } } },
          orderBy: { createdAt: 'desc' },
          take: 30,
        },
      },
    });
    if (!customer) throw new NotFoundException('Customer not found');
    const activity = customer.loyaltyTxns.map((t) => ({
      id: t.id,
      type: t.type,
      points: t.points,
      createdAt: t.createdAt,
      orderNo: t.payment ? `ORD-${1000 + t.payment.orderId}` : null,
      amount: t.payment ? Number(t.payment.amount) : null,
    }));
    const { loyaltyTxns, ...rest } = customer;
    return { ...rest, activity };
  }

  create(dto: CreateCustomerDto) {
    return this.prisma.customer.create({ data: { ...dto } });
  }

  async update(id: number, dto: UpdateCustomerDto) {
    await this.ensure(id);
    return this.prisma.customer.update({ where: { id }, data: { ...dto } });
  }

  // UC19 Delete Customer — chặn nếu còn lịch sử order/payment (giữ toàn vẹn dữ liệu).
  async remove(id: number) {
    await this.ensure(id);
    const orders = await this.prisma.order.count({ where: { customerId: id } });
    const payments = await this.prisma.payment.count({ where: { customerId: id } });
    if (orders > 0 || payments > 0) {
      throw new ConflictException('Cannot delete a customer with order or payment history.');
    }
    await this.prisma.loyaltyTransaction.deleteMany({ where: { customerId: id } });
    await this.prisma.customer.delete({ where: { id } });
    return { id };
  }

  private async ensure(id: number) {
    const c = await this.prisma.customer.findUnique({ where: { id } });
    if (!c) throw new NotFoundException('Customer not found');
    return c;
  }
}
