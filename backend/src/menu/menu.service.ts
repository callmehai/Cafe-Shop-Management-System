import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MenuService {
  constructor(private prisma: PrismaService) {}

  // Public-ish reads (cashier cần xem menu để tạo order)
  listProducts(search?: string) {
    return this.prisma.product.findMany({
      where: search ? { name: { contains: search, mode: 'insensitive' } } : undefined,
      include: { category: true },
    });
  }
  listCategories() {
    return this.prisma.category.findMany({ include: { products: true } });
  }

  // TODO UC13: CRUD Product (BR-05 chỉ Manager/Admin). Nhớ map recipe (ProductIngredient) cho BR-08.
  // TODO UC14: CRUD Category.
  // TODO BR-04: không cho set order khi isAvailable=false (kiểm tra ở orders.service).
}
