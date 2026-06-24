import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CustomersService {
  constructor(private prisma: PrismaService) {}
  // TODO UC19 CRUD Customer (+ search CR-13). Loyalty points đọc kèm.
}
