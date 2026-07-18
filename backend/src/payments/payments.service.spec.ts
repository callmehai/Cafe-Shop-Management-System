import { Test, TestingModule } from '@nestjs/testing';
import { PaymentsService } from './payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { OrderStatus, OccupancyStatus, Role, PaymentMethod, LoyaltyType } from '@prisma/client';

describe('PaymentsService', () => {
  let service: PaymentsService;
  let prisma: PrismaService;
  let audit: AuditLogService;

  const mockPrisma = {
    order: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    customer: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    user: {
      findUnique: jest.fn(),
    },
    payment: {
      create: jest.fn(),
    },
    ingredient: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    loyaltyTransaction: {
      create: jest.fn(),
    },
    table: {
      update: jest.fn(),
    },
    $transaction: jest.fn((callback) => callback(mockPrisma)),
  };

  const mockAudit = {
    log: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: AuditLogService, useValue: mockAudit },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
    prisma = module.get<PrismaService>(PrismaService);
    audit = module.get<AuditLogService>(AuditLogService);
    jest.clearAllMocks();
  });

  describe('process', () => {
    it('should throw ConflictException if order status is not OPEN (BR-07)', async () => {
      mockPrisma.order.findUnique.mockResolvedValue({ id: 1, status: OrderStatus.PAID, items: [] });

      await expect(
        service.process({ orderId: 1, method: PaymentMethod.CASH }, 1),
      ).rejects.toThrow(ConflictException);
    });

    it('should throw ConflictException if discount is > 50% and no manager approval (BR-06)', async () => {
      mockPrisma.order.findUnique.mockResolvedValue({
        id: 1,
        status: OrderStatus.OPEN,
        items: [{ id: 1, linePrice: '100000', product: { recipe: [] } }],
      });

      await expect(
        service.process(
          {
            orderId: 1,
            method: PaymentMethod.CASH,
            discount: 60000, // 60% discount
          },
          1,
        ),
      ).rejects.toThrow(ConflictException);
    });

    it('should throw BadRequestException if ingredient stock is insufficient (BR-08)', async () => {
      mockPrisma.order.findUnique.mockResolvedValue({
        id: 1,
        status: OrderStatus.OPEN,
        items: [
          {
            id: 1,
            quantity: 2,
            linePrice: '100000',
            product: {
              recipe: [
                { ingredientId: 10, quantity: '100.0' }, // recipe quantity
              ],
            },
          },
        ],
      });
      mockPrisma.ingredient.findUnique.mockResolvedValue({
        id: 10,
        name: 'Coffee Bean',
        quantityOnHand: '50.0', // only 50 available, 200 required
      });

      await expect(
        service.process(
          {
            orderId: 1,
            method: PaymentMethod.CASH,
          },
          1,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should complete payment, deduct stock, earn loyalty, and audit log successfully', async () => {
      mockPrisma.order.findUnique.mockResolvedValue({
        id: 1,
        status: OrderStatus.OPEN,
        tableId: 2,
        customerId: 20,
        items: [
          {
            id: 1,
            quantity: 2,
            linePrice: '100000',
            product: {
              recipe: [
                { ingredientId: 10, quantity: '10.0' },
              ],
            },
          },
        ],
      });
      mockPrisma.customer.findUnique.mockResolvedValue({
        id: 20,
        fullName: 'Jane Doe',
        loyaltyPoints: 100, // has 100 points
      });
      mockPrisma.ingredient.findUnique.mockResolvedValue({
        id: 10,
        name: 'Coffee Bean',
        quantityOnHand: '50.0',
        reorderThreshold: '5.0',
      });
      mockPrisma.ingredient.update.mockResolvedValue({
        id: 10,
        name: 'Coffee Bean',
        quantityOnHand: '30.0',
        reorderThreshold: '5.0',
      });
      mockPrisma.payment.create.mockResolvedValue({ id: 99 });
      mockPrisma.customer.update.mockResolvedValue({ loyaltyPoints: 105 }); // earned points = 100000/10000 = 10; redeemed = 5. balance = 100 - 5 + 10 = 105

      const result = await service.process(
        {
          orderId: 1,
          method: PaymentMethod.CASH,
          customerId: 20,
          pointsRedeemed: 5, // redeemed 5 points (500đ value)
          cashTendered: 100000,
        },
        1,
      );

      expect(result.amount).toBe(99500); // 100000 - 500 = 99500
      expect(result.change).toBe(500); // 100000 - 99500 = 500
      expect(result.pointsEarned).toBe(9); // 99500 / 10000 = 9
      expect(mockPrisma.payment.create).toHaveBeenCalled();
      expect(mockPrisma.order.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: { status: OrderStatus.PAID },
      });
      expect(mockPrisma.table.update).toHaveBeenCalledWith({
        where: { id: 2 },
        data: { occupancyStatus: OccupancyStatus.FREE },
      });
      expect(audit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 1,
          action: 'PROCESS_PAYMENT',
        }),
      );
    });
  });
});
