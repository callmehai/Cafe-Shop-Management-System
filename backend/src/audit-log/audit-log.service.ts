import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AuditLogService {
  constructor(private readonly prisma: PrismaService) {}

  async log(params: {
    userId?: number;
    username?: string;
    action: string;
    details: string;
    ipAddress?: string;
  }) {
    try {
      return await this.prisma.auditLog.create({
        data: {
          userId: params.userId ?? null,
          username: params.username ?? null,
          action: params.action,
          details: params.details,
          ipAddress: params.ipAddress ?? null,
        },
      });
    } catch (err) {
      console.error('Failed to write audit log:', err);
    }
  }
}
