import { Test, TestingModule } from '@nestjs/testing';
import { OrdersService } from './orders.service';
import { PrismaService } from '../prisma/prisma.service';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { OrderStatus, OccupancyStatus } from '@prisma/client';

describe('OrdersService', () => {
  let service: OrdersService;
  let prisma: PrismaService;

  const mockPrisma = {
    order: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    orderItem: {
      createMany: jest.fn(),
      deleteMany: jest.fn(),
      updateMany: jest.fn(),
      findMany: jest.fn(),
    },
    productIngredient: {
      findMany: jest.fn(),
    },
    ingredient: {
      findMany: jest.fn(),
    },
    table: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    product: {
      findMany: jest.fn(),
    },
    $transaction: jest.fn((callback) => callback(mockPrisma)),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<OrdersService>(OrdersService);
    prisma = module.get<PrismaService>(PrismaService);
    jest.clearAllMocks();
    // Mặc định: món không có công thức -> guard BR-08 không chặn.
    mockPrisma.productIngredient.findMany.mockResolvedValue([]);
    mockPrisma.orderItem.findMany.mockResolvedValue([]);
    mockPrisma.ingredient.findMany.mockResolvedValue([]);
  });

  describe('create', () => {
    it('should throw BadRequestException if product is not available (BR-04)', async () => {
      mockPrisma.product.findMany.mockResolvedValue([
        { id: 101, name: 'Espresso', price: '30000', isAvailable: false },
      ]);

      await expect(
        service.create(
          {
            items: [{ productId: 101, quantity: 2, options: 'S' }],
          },
          1,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should successfully create order and lock table', async () => {
      mockPrisma.product.findMany.mockResolvedValue([
        { id: 101, name: 'Espresso', price: '30000', isAvailable: true },
      ]);
      mockPrisma.table.findUnique.mockResolvedValue({ id: 5, number: 5 });
      mockPrisma.order.create.mockResolvedValue({ id: 1 });
      mockPrisma.order.findUnique.mockResolvedValue({
        id: 1,
        createdById: 1,
        tableId: 5,
        status: OrderStatus.OPEN,
        items: [
          {
            id: 1,
            productId: 101,
            quantity: 2,
            linePrice: '60000',
            product: { id: 101, name: 'Espresso', price: '30000' },
          },
        ],
      });

      const res = await service.create(
        {
          tableId: 5,
          items: [{ productId: 101, quantity: 2, options: 'S' }],
        },
        1,
      );

      expect(res.orderNo).toBe('ORD-1001');
      expect(res.subtotal).toBe(60000);
      expect(mockPrisma.table.update).toHaveBeenCalledWith({
        where: { id: 5 },
        data: { occupancyStatus: OccupancyStatus.OCCUPIED },
      });
    });
  });

  // BR-08: thiếu nguyên liệu phải bị chặn ngay khi TẠO order, không để tới thanh toán.
  describe('create — stock guard (BR-08)', () => {
    beforeEach(() => {
      mockPrisma.product.findMany.mockResolvedValue([
        { id: 101, name: 'Espresso', price: '30000', isAvailable: true },
      ]);
      // 1 Espresso = 18g cà phê.
      mockPrisma.productIngredient.findMany.mockResolvedValue([
        { productId: 101, ingredientId: 9, quantity: '18' },
      ]);
    });

    it('should throw BadRequestException when stock is insufficient', async () => {
      mockPrisma.ingredient.findMany.mockResolvedValue([
        { id: 9, name: 'Coffee Beans', quantityOnHand: '20' }, // cần 36
      ]);

      await expect(
        service.create({ items: [{ productId: 101, quantity: 2 }] }, 1),
      ).rejects.toThrow(/Not enough "Coffee Beans"/);

      expect(mockPrisma.order.create).not.toHaveBeenCalled();
    });

    it('should account for stock reserved by other OPEN orders', async () => {
      mockPrisma.ingredient.findMany.mockResolvedValue([
        { id: 9, name: 'Coffee Beans', quantityOnHand: '50' },
      ]);
      // 1 order OPEN khác đã "giữ" 2 x 18 = 36g -> chỉ còn 14g, không đủ 18g.
      mockPrisma.orderItem.findMany.mockResolvedValue([{ productId: 101, quantity: 2 }]);

      await expect(
        service.create({ items: [{ productId: 101, quantity: 1 }] }, 1),
      ).rejects.toThrow(BadRequestException);
    });

    // 0.41 * 2 = 0.8200000000000001 trong float -> không được chặn nhầm khi kho có đúng 0.82.
    it('should not block an order due to float rounding error', async () => {
      mockPrisma.productIngredient.findMany.mockResolvedValue([
        { productId: 101, ingredientId: 9, quantity: '0.41' },
      ]);
      mockPrisma.ingredient.findMany.mockResolvedValue([
        { id: 9, name: 'Matcha Powder', quantityOnHand: '0.82' },
      ]);
      mockPrisma.order.create.mockResolvedValue({ id: 1 });
      mockPrisma.order.findUnique.mockResolvedValue({
        id: 1,
        status: OrderStatus.OPEN,
        items: [{ id: 1, productId: 101, quantity: 2, linePrice: '120000' }],
      });

      await expect(
        service.create({ items: [{ productId: 101, quantity: 2 }] }, 1),
      ).resolves.toMatchObject({ orderNo: 'ORD-1001' });
    });

    it('should report rounded quantities in the error message', async () => {
      mockPrisma.productIngredient.findMany.mockResolvedValue([
        { productId: 101, ingredientId: 9, quantity: '0.41' },
      ]);
      mockPrisma.ingredient.findMany.mockResolvedValue([
        { id: 9, name: 'Matcha Powder', quantityOnHand: '0.78' },
      ]);

      // Không được lộ "0.8200000000000001" ra message cho người dùng.
      await expect(
        service.create({ items: [{ productId: 101, quantity: 2 }] }, 1),
      ).rejects.toThrow('Not enough "Matcha Powder" in stock. Available: 0.78, Required: 0.82.');
    });

    it('should create the order when stock is sufficient', async () => {
      mockPrisma.ingredient.findMany.mockResolvedValue([
        { id: 9, name: 'Coffee Beans', quantityOnHand: '500' },
      ]);
      mockPrisma.order.create.mockResolvedValue({ id: 1 });
      mockPrisma.order.findUnique.mockResolvedValue({
        id: 1,
        status: OrderStatus.OPEN,
        items: [{ id: 1, productId: 101, quantity: 2, linePrice: '60000' }],
      });

      const res = await service.create({ items: [{ productId: 101, quantity: 2 }] }, 1);

      expect(res.orderNo).toBe('ORD-1001');
      expect(mockPrisma.order.create).toHaveBeenCalled();
    });
  });

  describe('update', () => {
    it('should throw ConflictException if order is not OPEN (BR-07)', async () => {
      mockPrisma.order.findUnique.mockResolvedValue({ id: 1, status: OrderStatus.PAID });

      await expect(
        service.update(1, {
          items: [{ productId: 101, quantity: 1 }],
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('cancel', () => {
    it('should set status to CANCELLED and free the table', async () => {
      mockPrisma.order.findUnique.mockResolvedValue({ id: 1, status: OrderStatus.OPEN, tableId: 5 });
      mockPrisma.order.update.mockResolvedValue({
        id: 1,
        status: OrderStatus.CANCELLED,
        items: [],
      });

      const res = await service.cancel(1);

      expect(res.status).toBe(OrderStatus.CANCELLED);
      expect(mockPrisma.table.update).toHaveBeenCalledWith({
        where: { id: 5 },
        data: { occupancyStatus: OccupancyStatus.FREE },
      });
    });
  });
});
