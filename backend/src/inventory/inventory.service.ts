import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class InventoryService {
  constructor(private prisma: PrismaService) {}
  // TODO UC15 CRUD Ingredient.
  // TODO Purchase Order + UC16 Stock-In (BR-12: tham chiếu PO line; cộng quantityOnHand).
  // TODO Low-stock report: ingredients có quantityOnHand <= reorderThreshold.
}
