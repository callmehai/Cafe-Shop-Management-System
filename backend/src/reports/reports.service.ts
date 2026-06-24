import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}
  // TODO UC20 Sales report theo date range (sum payments). UC21 Export.
  // TODO Daily Sales Aggregation job (scheduled).
}
