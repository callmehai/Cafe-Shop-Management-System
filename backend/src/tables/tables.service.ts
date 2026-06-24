import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TablesService {
  constructor(private prisma: PrismaService) {}
  // TODO CRUD Table; cập nhật OccupancyStatus khi assign order.
}
