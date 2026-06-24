import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { OccupancyStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTableDto } from './dto/create-table.dto';
import { UpdateTableDto } from './dto/update-table.dto';

@Injectable()
export class TablesService {
  constructor(private prisma: PrismaService) {}

  // Đọc: mọi role đã đăng nhập (cashier cần chọn bàn khi tạo order).
  list() {
    return this.prisma.table.findMany({
      orderBy: [{ floor: 'asc' }, { number: 'asc' }],
    });
  }

  create(dto: CreateTableDto) {
    return this.prisma.table.create({
      data: {
        number: dto.number,
        capacity: dto.capacity,
        floor: dto.floor,
        shape: dto.shape,
        occupancyStatus: dto.occupancyStatus ?? OccupancyStatus.FREE,
      },
    });
  }

  async update(id: number, dto: UpdateTableDto) {
    await this.ensure(id);
    return this.prisma.table.update({ where: { id }, data: { ...dto } });
  }

  // UC: Remove Table — MSG06. Chặn nếu bàn đang bận/đặt trước hoặc còn order mở.
  async remove(id: number) {
    const table = await this.ensure(id);
    if (table.occupancyStatus !== OccupancyStatus.FREE) {
      throw new ConflictException('Cannot remove a table that is occupied or reserved.');
    }
    const openOrders = await this.prisma.order.count({
      where: { tableId: id, status: 'OPEN' },
    });
    if (openOrders > 0) {
      throw new ConflictException('Cannot remove a table with active orders.');
    }
    // Gỡ liên kết các order lịch sử (tableId nullable) rồi xóa.
    await this.prisma.order.updateMany({ where: { tableId: id }, data: { tableId: null } });
    await this.prisma.table.delete({ where: { id } });
    return { id };
  }

  private async ensure(id: number) {
    const t = await this.prisma.table.findUnique({ where: { id } });
    if (!t) throw new NotFoundException('Table not found');
    return t;
  }
}
