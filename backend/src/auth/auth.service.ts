import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwt: JwtService) {}

  // UC10 Login. MSG09 nếu sai. BR-10: khóa 15' sau 5 lần sai liên tiếp.
  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { username: dto.username } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Incorrect user name or password. Please check again.');
    }

    // Check if account is locked
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      const remainingMs = user.lockedUntil.getTime() - Date.now();
      const remainingMins = Math.ceil(remainingMs / 60000);
      throw new ForbiddenException(
        `Account is temporarily locked. Please try again after ${remainingMins} minute(s).`
      );
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      const failedAttempts = user.failedAttempts + 1;
      let lockedUntil: Date | null = null;
      let isLockedNow = false;

      if (failedAttempts >= 5) {
        lockedUntil = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes lockout
        isLockedNow = true;
      }

      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          failedAttempts,
          lockedUntil,
        },
      });

      if (isLockedNow) {
        throw new ForbiddenException('Incorrect password. Account is now locked for 15 minutes.');
      }
      throw new UnauthorizedException('Incorrect user name or password. Please check again.');
    }

    // Reset attempts on successful login
    if (user.failedAttempts > 0 || user.lockedUntil) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          failedAttempts: 0,
          lockedUntil: null,
        },
      });
    }

    const token = await this.jwt.signAsync({
      sub: user.id,
      username: user.username,
      role: user.role,
    });
    return {
      accessToken: token,
      user: { id: user.id, username: user.username, fullName: user.fullName, role: user.role },
    };
  }

  // CR-06: trả hồ sơ user hiện tại (lấy tươi từ DB để phản ánh role/isActive mới nhất).
  async me(userId: number) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Session is no longer valid. Please sign in again.');
    }
    return { id: user.id, username: user.username, fullName: user.fullName, role: user.role };
  }
}
