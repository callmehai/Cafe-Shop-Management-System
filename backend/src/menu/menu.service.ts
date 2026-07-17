import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class MenuService {
  constructor(private prisma: PrismaService) {}

  // ---------- PRODUCTS ----------
  // Public-ish reads (cashier cần xem menu để tạo order).
  listProducts(search?: string) {
    return this.prisma.product.findMany({
      where: search ? { name: { contains: search, mode: 'insensitive' } } : undefined,
      include: { category: true },
      orderBy: [{ categoryId: 'asc' }, { name: 'asc' }],
    });
  }

  // UC13 Add Product (BR-05: chỉ Manager/Admin — enforce ở controller).
  async createProduct(dto: CreateProductDto) {
    await this.ensureCategory(dto.categoryId);
    return this.prisma.product.create({
      data: {
        name: dto.name,
        categoryId: dto.categoryId,
        price: dto.price,
        size: dto.size,
        description: dto.description,
        isAvailable: dto.isAvailable ?? true,
        imageUrl: dto.imageUrl,
      },
      include: { category: true },
    });
  }

  // UC13 Edit Product (kèm bật/tắt isAvailable — BR-04).
  async updateProduct(id: number, dto: UpdateProductDto) {
    await this.ensureProduct(id);
    if (dto.categoryId !== undefined) await this.ensureCategory(dto.categoryId);
    return this.prisma.product.update({
      where: { id },
      data: { ...dto },
      include: { category: true },
    });
  }

  async deleteProduct(id: number) {
    await this.ensureProduct(id);
    // Không xóa cứng món đã từng vào order (giữ lịch sử); yêu cầu ẩn thay vì xóa.
    const used = await this.prisma.orderItem.count({ where: { productId: id } });
    if (used > 0) {
      throw new ConflictException('Cannot delete a product used in orders. Hide it instead.');
    }
    await this.prisma.product.delete({ where: { id } });
    return { id };
  }

  // ---------- CATEGORIES ----------
  listCategories() {
    return this.prisma.category.findMany({
      include: { _count: { select: { products: true } } },
      orderBy: { id: 'asc' },
    });
  }

  // UC14 Add Category.
  createCategory(dto: CreateCategoryDto) {
    return this.prisma.category.create({ data: { name: dto.name } });
  }

  async updateCategory(id: number, dto: UpdateCategoryDto) {
    await this.ensureCategory(id);
    return this.prisma.category.update({ where: { id }, data: { ...dto } });
  }

  // UC14 Delete Category — MSG06: chặn xóa khi còn sản phẩm.
  async deleteCategory(id: number) {
    await this.ensureCategory(id);
    const products = await this.prisma.product.count({ where: { categoryId: id } });
    if (products > 0) {
      throw new ConflictException('Cannot delete a category that still has products.');
    }
    await this.prisma.category.delete({ where: { id } });
    return { id };
  }

  // ---------- helpers ----------
  private async ensureProduct(id: number) {
    const p = await this.prisma.product.findUnique({ where: { id } });
    if (!p) throw new NotFoundException('Product not found');
    return p;
  }

  private async ensureCategory(id: number) {
    const c = await this.prisma.category.findUnique({ where: { id } });
    if (!c) throw new NotFoundException('Category not found');
    return c;
  }
}
