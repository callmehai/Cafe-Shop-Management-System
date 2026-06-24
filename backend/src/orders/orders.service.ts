import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OccupancyStatus, OrderStatus, Prisma, PrepStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderDto } from './dto/update-order.dto';
import { CreateOrderItemDto } from './dto/create-order-item.dto';

const ORDER_INCLUDE = {
  items: { include: { product: true }, orderBy: { id: 'asc' } },
  table: true,
  customer: true,
  createdBy: { select: { id: true, fullName: true } },
} satisfies Prisma.OrderInclude;

@Injectable()
export class OrdersService {
  constructor(private prisma: PrismaService) {}

  // UC06 Create Order — BR-01 (>=1 item, validate ở DTO), BR-04 (product available).
  async create(dto: CreateOrderDto, userId: number) {
    const items = await this.buildItems(dto.items);
    if (dto.tableId) await this.ensureTableExists(dto.tableId);

    const order = await this.prisma.$transaction(async (tx) => {
      const created = await tx.order.create({
        data: {
          createdById: userId,
          tableId: dto.tableId ?? null,
          customerId: dto.customerId ?? null,
          status: OrderStatus.OPEN,
        },
      });
      await tx.orderItem.createMany({
        data: items.map((i) => ({ ...i, orderId: created.id })),
      });
      if (dto.tableId) {
        await tx.table.update({
          where: { id: dto.tableId },
          data: { occupancyStatus: OccupancyStatus.OCCUPIED },
        });
      }
      return tx.order.findUnique({ where: { id: created.id }, include: ORDER_INCLUDE });
    });
    return this.serialize(order);
  }

  async findOne(id: number) {
    const order = await this.prisma.order.findUnique({ where: { id }, include: ORDER_INCLUDE });
    if (!order) throw new NotFoundException('Order not found');
    return this.serialize(order);
  }

  // UC11 View Order Queue — các order đang OPEN.
  async queue() {
    const orders = await this.prisma.order.findMany({
      where: { status: OrderStatus.OPEN },
      include: ORDER_INCLUDE,
      orderBy: { createdAt: 'asc' },
    });
    return orders.map((o) => this.serialize(o));
  }

  // UC07 Update Order — chỉ khi OPEN (BR-07).
  async update(id: number, dto: UpdateOrderDto) {
    const existing = await this.prisma.order.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Order not found');
    if (existing.status !== OrderStatus.OPEN) {
      throw new ConflictException('Only open orders can be edited.');
    }
    const items = dto.items ? await this.buildItems(dto.items) : null;
    if (dto.tableId) await this.ensureTableExists(dto.tableId);

    const order = await this.prisma.$transaction(async (tx) => {
      if (items) {
        await tx.orderItem.deleteMany({ where: { orderId: id } });
        await tx.orderItem.createMany({ data: items.map((i) => ({ ...i, orderId: id })) });
      }
      // UC09 Assign Table: chuyển bàn -> cập nhật occupancy 2 bàn.
      if (dto.tableId !== undefined && dto.tableId !== existing.tableId) {
        if (existing.tableId) {
          await tx.table.update({
            where: { id: existing.tableId },
            data: { occupancyStatus: OccupancyStatus.FREE },
          });
        }
        await tx.table.update({
          where: { id: dto.tableId },
          data: { occupancyStatus: OccupancyStatus.OCCUPIED },
        });
      }
      return tx.order.update({
        where: { id },
        data: {
          tableId: dto.tableId ?? existing.tableId,
          customerId: dto.customerId ?? existing.customerId,
        },
        include: ORDER_INCLUDE,
      });
    });
    return this.serialize(order);
  }

  // UC08 Cancel Order — OPEN -> CANCELLED, giải phóng bàn.
  async cancel(id: number) {
    const existing = await this.prisma.order.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Order not found');
    if (existing.status !== OrderStatus.OPEN) {
      throw new ConflictException('Only open orders can be cancelled.');
    }
    const order = await this.prisma.$transaction(async (tx) => {
      if (existing.tableId) {
        await tx.table.update({
          where: { id: existing.tableId },
          data: { occupancyStatus: OccupancyStatus.FREE },
        });
      }
      return tx.order.update({
        where: { id },
        data: { status: OrderStatus.CANCELLED },
        include: ORDER_INCLUDE,
      });
    });
    return this.serialize(order);
  }

  // UC12 Update Item Prep Status (Barista đẩy pending -> making -> done).
  async updateItemPrep(orderId: number, itemId: number, status: PrepStatus) {
    const item = await this.prisma.orderItem.findUnique({ where: { id: itemId } });
    if (!item || item.orderId !== orderId) throw new NotFoundException('Order item not found');
    await this.prisma.orderItem.update({ where: { id: itemId }, data: { prepStatus: status } });
    return this.findOne(orderId);
  }

  // Đánh dấu cả order đã chuẩn bị xong (tất cả item DONE).
  async markPrepDone(orderId: number) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');
    await this.prisma.orderItem.updateMany({ where: { orderId }, data: { prepStatus: PrepStatus.DONE } });
    return this.findOne(orderId);
  }

  // ---------- helpers ----------
  // linePrice tính lại từ giá DB (không tin client) + chặn món không available (BR-04).
  private async buildItems(items: CreateOrderItemDto[]) {
    const ids = [...new Set(items.map((i) => i.productId))];
    const products = await this.prisma.product.findMany({ where: { id: { in: ids } } });
    const byId = new Map(products.map((p) => [p.id, p]));
    return items.map((i) => {
      const p = byId.get(i.productId);
      if (!p) throw new BadRequestException(`Product ${i.productId} not found.`);
      if (!p.isAvailable) throw new BadRequestException(`${p.name} is not available.`); // BR-04
      return {
        productId: i.productId,
        quantity: i.quantity,
        options: i.options ?? null,
        linePrice: new Prisma.Decimal(p.price).mul(i.quantity),
      };
    });
  }

  private async ensureTableExists(tableId: number) {
    const t = await this.prisma.table.findUnique({ where: { id: tableId } });
    if (!t) throw new BadRequestException('Table not found.');
  }

  // Thêm orderNo + subtotal + itemCount cho client (không lưu DB).
  private serialize(order: any) {
    const subtotal = order.items.reduce((sum: number, it: any) => sum + Number(it.linePrice), 0);
    const itemCount = order.items.reduce((n: number, it: any) => n + it.quantity, 0);
    return { ...order, orderNo: `ORD-${1000 + order.id}`, subtotal, itemCount };
  }
}
