import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  private strip<T extends { passwordHash?: string }>(u: T) {
    const { passwordHash, ...rest } = u as any;
    return rest;
  }

  // UC04 View User List (+ search CR-13)
  async findAll(search?: string) {
    const users = await this.prisma.user.findMany({
      where: search
        ? { OR: [{ username: { contains: search, mode: 'insensitive' } }, { fullName: { contains: search, mode: 'insensitive' } }] }
        : undefined,
      orderBy: { fullName: 'asc' },
    });
    return users.map((u) => this.strip(u));
  }

  // UC02 Add User — CR-04 chặn trùng username
  async create(dto: CreateUserDto) {
    const exists = await this.prisma.user.findUnique({ where: { username: dto.username } });
    if (exists) throw new ConflictException('Username already exists'); // CR-04
    const passwordHash = await bcrypt.hash(dto.password, 10); // security: hash password
    const user = await this.prisma.user.create({
      data: {
        fullName: dto.fullName,
        username: dto.username,
        passwordHash,
        role: dto.role,
        isActive: dto.isActive ?? true,
      },
    });
    return this.strip(user);
  }

  // UC03 Edit User
  async update(id: number, dto: UpdateUserDto) {
    await this.ensureExists(id);
    if (dto.username) {
      const dup = await this.prisma.user.findFirst({ where: { username: dto.username, NOT: { id } } });
      if (dup) throw new ConflictException('Username already exists'); // CR-04
    }
    const data: any = { ...dto };
    if (dto.password) {
      data.passwordHash = await bcrypt.hash(dto.password, 10);
      delete data.password;
    }
    const user = await this.prisma.user.update({ where: { id }, data });
    return this.strip(user);
  }

  // UC04 Delete/Deactivate User
  async remove(id: number) {
    await this.ensureExists(id);
    // Soft-delete: deactivate thay vì xóa cứng để giữ lịch sử order/payment.
    const user = await this.prisma.user.update({ where: { id }, data: { isActive: false } });
    return this.strip(user);
  }

  private async ensureExists(id: number) {
    const u = await this.prisma.user.findUnique({ where: { id } });
    if (!u) throw new NotFoundException('User not found');
  }
}
