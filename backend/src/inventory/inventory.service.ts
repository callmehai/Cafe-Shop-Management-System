import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateIngredientDto, UpdateIngredientDto } from './dto/ingredient.dto';
import { StockInDto } from './dto/stock-in.dto';

@Injectable()
export class InventoryService {
  constructor(private prisma: PrismaService) {}

  // ---------- Ingredients (UC15) ----------
  async listIngredients() {
    const items = await this.prisma.ingredient.findMany({ orderBy: { name: 'asc' } });
    return items.map((i) => this.withFlag(i));
  }

  async lowStock() {
    const items = await this.prisma.ingredient.findMany({ orderBy: { name: 'asc' } });
    return items
      .filter((i) => Number(i.quantityOnHand) <= Number(i.reorderThreshold))
      .map((i) => this.withFlag(i));
  }

  createIngredient(dto: CreateIngredientDto) {
    return this.prisma.ingredient.create({ data: { ...dto } });
  }

  async updateIngredient(id: number, dto: UpdateIngredientDto) {
    await this.ensureIngredient(id);
    return this.prisma.ingredient.update({ where: { id }, data: { ...dto } });
  }

  // ---------- Purchase Orders history ----------
  listPurchaseOrders() {
    return this.prisma.purchaseOrder.findMany({
      include: { stockIns: { include: { ingredient: true } }, user: { select: { fullName: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ---------- Stock-In / Goods receipt (UC16, BR-12) ----------
  // Tạo Purchase Order + StockIn line + cộng quantityOnHand cho từng nguyên liệu.
  async receiveStock(dto: StockInDto, userId: number) {
    const ids = [...new Set(dto.items.map((i) => i.ingredientId))];
    const existing = await this.prisma.ingredient.findMany({ where: { id: { in: ids } } });
    if (existing.length !== ids.length) {
      throw new BadRequestException('One or more ingredients not found.');
    }
    const totalAmount = dto.items.reduce((s, i) => s + i.quantity * i.unitCost, 0);

    return this.prisma.$transaction(async (tx) => {
      const created = await tx.purchaseOrder.create({
        data: { userId, supplierName: dto.supplierName, status: 'RECEIVED', totalAmount },
      });
      for (const line of dto.items) {
        await tx.stockIn.create({
          data: {
            purchaseOrderId: created.id,
            ingredientId: line.ingredientId,
            quantity: line.quantity,
            unitCost: line.unitCost,
          },
        });
        await tx.ingredient.update({
          where: { id: line.ingredientId },
          data: { quantityOnHand: { increment: new Prisma.Decimal(line.quantity) } },
        });
      }
      return tx.purchaseOrder.findUnique({
        where: { id: created.id },
        include: { stockIns: { include: { ingredient: true } } },
      });
    });
  }

  private withFlag(i: { quantityOnHand: Prisma.Decimal; reorderThreshold: Prisma.Decimal }) {
    return { ...i, lowStock: Number(i.quantityOnHand) <= Number(i.reorderThreshold) };
  }

  private async ensureIngredient(id: number) {
    const i = await this.prisma.ingredient.findUnique({ where: { id } });
    if (!i) throw new NotFoundException('Ingredient not found');
    return i;
  }
}
