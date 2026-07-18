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
